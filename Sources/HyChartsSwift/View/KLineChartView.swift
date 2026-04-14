import UIKit

// MARK: - K 线图主视图（公共 API）
//
// 布局：
//   ┌──────────────────────────────────┐
//   │        主图（蜡烛 + 技术线）        │  mainView
//   ├──────────────────────────────────┤
//   │          成交量                   │  volumeView
//   ├──────────────────────────────────┤
//   │        副图（MACD/KDJ/RSI）       │  auxiliaryView
//   └──────────────────────────────────┘
//
// 手势：
//   - pan：通过 UIPanGestureRecognizer 手动控制 offsetX（不用 UIScrollView）
//   - pinch：UIPinchGestureRecognizer，以捏合中心为锚点缩放
//   - tap/longpress：显示/追踪十字线光标

@MainActor
public final class KLineChartView: UIView {

    // MARK: - 公共属性

    public var configuration: KLineConfiguration = .default {
        didSet { setNeedsFullRedraw() }
    }

    /// 数据更新后调用此方法触发重绘
    public func reloadData() {
        Task { await rebuildRenderModels() }
    }

    /// 追加新 K 线（实时行情）
    public func appendModels<M: KLineModel>(_ newModels: [M]) {
        Task {
            await store.append(newModels: newModels)
            await rebuildRenderModels()
        }
    }

    /// 更新最后一根 K 线（tick 刷新）
    public func updateLastModel<M: KLineModel>(_ model: M) {
        Task {
            await store.updateLast(model)
            await softRedraw()
        }
    }

    // MARK: - 数据源（外部设置）

    private let store = ChartDataStore()

    public func load<M: KLineModel>(_ source: some ChartDataSource<M>) {
        Task {
            await store.load(source)
            await rebuildRenderModels()
        }
    }

    // MARK: - 子视图 & 子层

    private let mainContainer      = UIView()
    private let volumeContainer    = UIView()
    private let auxiliaryContainer = UIView()

    private let mainLayer      = KLineMainLayer()
    private let volumeLayer    = KLineVolumeLayer()
    private let auxiliaryLayer = KLineAuxiliaryLayer()
    private let axisLayer      = AxisLayer()
    private let cursor         = KLineCursor()

    // MARK: - 手势状态

    private var scale:   CGFloat = 1.0
    private var offsetX: CGFloat = 0

    private var pinchAnchorIndex: Int    = 0
    private var pinchAnchorOffsetX: CGFloat = 0
    private var pinchStartScale: CGFloat = 1.0

    // MARK: - 渲染快照（主线程只读）

    private var renderModels: [KLineRenderModel] = []  // 当前可见切片
    private var totalModelCount: Int = 0               // 全量数量，用于滚动边界计算
    private var currentMapper: CoordinateMapper? = nil

    // MARK: - 初始化

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = configuration.chartBackgroundColor

        // 子视图层次
        addSubview(mainContainer)
        addSubview(volumeContainer)
        addSubview(auxiliaryContainer)

        mainContainer.layer.addSublayer(mainLayer)
        mainContainer.layer.addSublayer(axisLayer)
        mainContainer.layer.addSublayer(cursor)

        volumeContainer.layer.addSublayer(volumeLayer)
        auxiliaryContainer.layer.addSublayer(auxiliaryLayer)

        setupGestures()
    }

    // MARK: - 布局

    public override func layoutSubviews() {
        super.layoutSubviews()

        let config   = configuration
        let totalH   = bounds.height
        let totalW   = bounds.width
        let auxH     = totalH * config.auxiliaryHeightRatio
        let volH     = totalH * config.volumeHeightRatio
        let mainH    = totalH - auxH - volH

        mainContainer.frame      = CGRect(x: 0, y: 0,        width: totalW, height: mainH)
        volumeContainer.frame    = CGRect(x: 0, y: mainH,    width: totalW, height: volH)
        auxiliaryContainer.frame = CGRect(x: 0, y: mainH + volH, width: totalW, height: auxH)

        // 背景色
        backgroundColor                = config.chartBackgroundColor
        mainContainer.backgroundColor  = config.chartBackgroundColor
        volumeContainer.backgroundColor = config.chartBackgroundColor
        auxiliaryContainer.backgroundColor = config.auxiliaryBackgroundColor

        [mainLayer, axisLayer, cursor].forEach { $0.frame = mainContainer.bounds }
        volumeLayer.frame    = volumeContainer.bounds
        auxiliaryLayer.frame = auxiliaryContainer.bounds

        setNeedsFullRedraw()
    }

    // MARK: - 手势

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        addGestureRecognizer(longPress)

        pan.require(toFail: longPress)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        cursor.hide()
        let dx = g.translation(in: self).x
        g.setTranslation(.zero, in: self)
        scrollBy(dx: -dx)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            pinchStartScale   = scale
            let centerX       = g.location(in: self).x
            pinchAnchorIndex  = indexForVisibleX(centerX)
            pinchAnchorOffsetX = centerX
            cursor.hide()

        case .changed:
            let newScale = (pinchStartScale * g.scale)
                .clamped(to: configuration.minScale...configuration.maxScale)
            let stride   = scaledItemStride(scale: newScale)
            // 锚点 index 的 absoluteX = anchorIndex * stride + itemWidth/2
            let anchorAbs = CGFloat(pinchAnchorIndex) * stride + scaledItemWidth(scale: newScale) / 2
            offsetX = (anchorAbs - pinchAnchorOffsetX).clamped(to: 0...maxOffsetX(scale: newScale))
            scale   = newScale
            redraw()

        default: break
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        if !cursor.isHidden { cursor.hide(); return }
        showCursor(at: g.location(in: self))
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began, .changed:
            showCursor(at: g.location(in: self))
        case .ended, .cancelled:
            cursor.hide()
        default: break
        }
    }

    // MARK: - 滚动

    private func scrollBy(dx: CGFloat) {
        guard totalModelCount > 0 else { return }
        offsetX = (offsetX + dx).clamped(to: 0...maxOffsetX(scale: scale))
        redraw()
    }

    private func maxOffsetX(scale: CGFloat) -> CGFloat {
        let totalW = CGFloat(totalModelCount) * scaledItemStride(scale: scale)
        let chartW = bounds.width - configuration.yAxisWidth
        return max(0, totalW - chartW)
    }

    // MARK: - 十字线

    private func showCursor(at point: CGPoint) {
        guard let mapper = currentMapper, !renderModels.isEmpty else { return }
        let config   = configuration
        let chartW   = bounds.width
        let mainH    = mainContainer.bounds.height

        // 只响应主图区域的 Y
        guard point.y < mainH else { return }

        let idx      = mapper.index(forVisibleX: point.x, count: renderModels.count)
        let model    = renderModels[idx]
        let centerX  = model.centerX
        let priceY   = point.y  // 显示手指 Y 对应的价格线
        let price    = mapper.price(forY: priceY, in: mainH - config.xAxisHeight)
        let yLabel   = String(format: "%.\(2)f", price)

        cursor.show(info: KLineCursor.CursorInfo(
            centerX:     centerX,
            priceY:      priceY,
            xLabel:      model.xLabel,
            yLabel:      yLabel,
            chartSize:   CGSize(width: chartW, height: mainH),
            xAxisHeight: config.xAxisHeight,
            yAxisWidth:  config.yAxisWidth
        ), config: config)
    }

    // MARK: - 渲染管线

    /// 全量重建：从 Store 拉数据 + 计算指标 + 绘制
    private func rebuildRenderModels() async {
        let allModels = await store.models
        guard !allModels.isEmpty else { return }

        let config = configuration
        let mainH  = bounds.height * (1 - config.volumeHeightRatio - config.auxiliaryHeightRatio)
        let volH   = bounds.height * config.volumeHeightRatio
        let range  = visibleRange(totalCount: allModels.count)
        await store.setVisibleRange(range)
        let extremes = await store.extremes

        // Step 1: 先建 prelimMapper，仅用于填充 centerX / priceY / volumeY
        // 此时副图极值未知，auxiliaryY 暂不使用
        let prelimMapper = CoordinateMapper(
            chartSize:   CGSize(width: bounds.width, height: mainH),
            itemWidth:   scaledItemWidth(scale: scale),
            itemSpacing: scaledItemSpacing(scale: scale),
            scale:       scale,
            offsetX:     offsetX,
            startIndex:  range.lowerBound,
            extremes:    extremes
        )

        var visible = Array(allModels[range])
        prelimMapper.fillCoordinates(into: &visible, startIndex: range.lowerBound,
                                     mainHeight: mainH - config.xAxisHeight, volumeHeight: volH)
        renderModels    = visible
        totalModelCount = allModels.count

        // Step 2: 计算主图技术线 & 副图指标（只需价格值，不需要 auxiliaryY）
        let technicalData = await buildTechnicalResults(
            allModels: allModels, visible: visible, range: range,
            mapper: prelimMapper, config: config, store: store, mainH: mainH
        )
        let auxiliaryData = await buildAuxiliaryResults(
            allModels: allModels, visible: visible, range: range,
            config: config, store: store
        )

        // Step 3: 从实际指标数据提取副图极值，加 15% 上下留白
        let (auxMin, auxMax) = auxiliaryExtremes(from: auxiliaryData)
        let finalExtremes = KLineExtremes(
            maxPrice: extremes.maxPrice, minPrice: extremes.minPrice,
            maxVolume: extremes.maxVolume, minVolume: extremes.minVolume,
            maxAuxiliary: auxMax, minAuxiliary: auxMin
        )

        // Step 4: 用正确极值建最终 Mapper，供副图 Layer 的 auxiliaryY 使用
        let finalMapper = CoordinateMapper(
            chartSize:   CGSize(width: bounds.width, height: mainH),
            itemWidth:   scaledItemWidth(scale: scale),
            itemSpacing: scaledItemSpacing(scale: scale),
            scale:       scale,
            offsetX:     offsetX,
            startIndex:  range.lowerBound,
            extremes:    finalExtremes
        )
        currentMapper = finalMapper

        drawAll(visible: visible, technicalData: technicalData,
                auxiliaryData: auxiliaryData, mapper: finalMapper, config: config,
                allModels: allModels, mainH: mainH)
    }

    /// 从副图渲染数据中提取 min/max，并加留白
    private func auxiliaryExtremes(from data: AuxiliaryRenderData) -> (min: Double, max: Double) {
        func padded(_ mn: Double, _ mx: Double) -> (Double, Double) {
            let pad = max(abs(mx - mn) * 0.15, 0.001)
            return (mn - pad, mx + pad)
        }
        switch data {
        case .none:
            return (0, 1)
        case .volume(let bars):
            guard !bars.isEmpty else { return (0, 1) }
            let mx = bars.map(\.volume).max()!
            return padded(0, mx)
        case .macd(let points):
            guard !points.isEmpty else { return (-1, 1) }
            let vals = points.flatMap { [$0.dif, $0.dem, $0.macd] }
            return padded(vals.min()!, vals.max()!)
        case .kdj(let lines):
            let vals = lines.flatMap { $0.compactMap(\.value) }
            guard !vals.isEmpty else { return (0, 100) }
            return padded(min(vals.min()!, 0), max(vals.max()!, 100))
        case .rsi(let lines):
            let vals = lines.flatMap { $0.compactMap(\.value) }
            guard !vals.isEmpty else { return (0, 100) }
            return padded(min(vals.min()!, 0), max(vals.max()!, 100))
        }
    }

    /// 轻量重绘：数据不变，只刷新坐标和层（tick 刷新用）
    private func softRedraw() async {
        await rebuildRenderModels()
    }

    /// 仅触发主线程重绘（手势缩放/滚动时）
    private func redraw() {
        Task { await rebuildRenderModels() }
    }

    private func setNeedsFullRedraw() {
        Task { await rebuildRenderModels() }
    }

    // MARK: - 指标数据组装

    private func buildTechnicalResults(
        allModels: [KLineRenderModel],
        visible: [KLineRenderModel],
        range: Range<Int>,
        mapper: CoordinateMapper,
        config: KLineConfiguration,
        store: ChartDataStore,
        mainH: CGFloat
    ) async -> MainTechnicalResults {
        switch config.mainTechnical {
        case .none:
            return .none

        case .sma(let periods):
            var seriesList: [[(x: CGFloat, price: Double?)]] = []
            for period in periods {
                let all = await store.smaSeries(period: period)
                let pts = visible.indices.map { i -> (x: CGFloat, price: Double?) in
                    let ai = range.lowerBound + i
                    return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value : nil)
                }
                seriesList.append(pts)
            }
            return .sma(seriesList: seriesList)

        case .ema(let periods):
            var seriesList: [[(x: CGFloat, price: Double?)]] = []
            for period in periods {
                let all = await store.emaSeries(period: period)
                let pts = visible.indices.map { i -> (x: CGFloat, price: Double?) in
                    let ai = range.lowerBound + i
                    return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value : nil)
                }
                seriesList.append(pts)
            }
            return .ema(seriesList: seriesList)

        case .boll(let period, let mult):
            let all = await store.bollSeries(period: period, multiplier: mult)
            let mb    = visible.indices.map { i -> (x: CGFloat, price: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.mb : nil)
            }
            let upper = visible.indices.map { i -> (x: CGFloat, price: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.upper : nil)
            }
            let lower = visible.indices.map { i -> (x: CGFloat, price: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.lower : nil)
            }
            return .boll(mb: mb, upper: upper, lower: lower)
        }
    }

    private func buildAuxiliaryResults(
        allModels: [KLineRenderModel],
        visible: [KLineRenderModel],
        range: Range<Int>,
        config: KLineConfiguration,
        store: ChartDataStore
    ) async -> AuxiliaryRenderData {
        switch config.auxiliaryType {
        case .volume:
            let bars = visible.map { m -> (x: CGFloat, volume: Double, trend: KLineTrend) in
                (m.centerX, m.volume, m.trend)
            }
            return .volume(bars: bars)
        case .macd(let fast, let slow, let signal):
            let all = await store.macdSeries(fast: fast, slow: slow, signal: signal)
            let pts: [MACDPoint] = visible.indices.compactMap { i in
                let ai = range.lowerBound + i
                guard all.indices.contains(ai), let v = all[ai].value else { return nil }
                return MACDPoint(x: visible[i].centerX, dif: v.dif, dem: v.dem, macd: v.macd)
            }
            return .macd(points: pts)

        case .kdj(let n, let m1, let m2):
            let all = await store.kdjSeries(n: n, m1: m1, m2: m2)
            let kLine = visible.indices.map { i -> (x: CGFloat, value: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.k : nil)
            }
            let dLine = visible.indices.map { i -> (x: CGFloat, value: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.d : nil)
            }
            let jLine = visible.indices.map { i -> (x: CGFloat, value: Double?) in
                let ai = range.lowerBound + i
                return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value?.j : nil)
            }
            return .kdj(lines: [kLine, dLine, jLine])

        case .rsi(let periods):
            var lines: [[(x: CGFloat, value: Double?)]] = []
            for period in periods {
                let all = await store.rsiSeries(period: period)
                let pts = visible.indices.map { i -> (x: CGFloat, value: Double?) in
                    let ai = range.lowerBound + i
                    return (visible[i].centerX, all.indices.contains(ai) ? all[ai].value : nil)
                }
                lines.append(pts)
            }
            return .rsi(lines: lines)
        }
    }

    // MARK: - 实际绘制调用

    private func drawAll(
        visible: [KLineRenderModel],
        technicalData: MainTechnicalResults,
        auxiliaryData: AuxiliaryRenderData,
        mapper: CoordinateMapper,
        config: KLineConfiguration,
        allModels: [KLineRenderModel],
        mainH: CGFloat
    ) {
        let chartHeight = mainH - config.xAxisHeight

        // 周期分隔线 X 坐标
        let separators = computePeriodSeparators(visible: visible, period: config.chartPeriod)

        // 主图
        mainLayer.render(
            models: visible,
            config: config,
            mapper: mapper,
            allModels: allModels,
            technicalResults: technicalData
        )

        // 成交量
        volumeLayer.render(models: visible, config: config, mapper: mapper, maSeries: [],
                           verticalSeparators: separators)

        // 副图
        auxiliaryLayer.render(results: auxiliaryData, config: config, mapper: mapper,
                              verticalSeparators: separators)

        // 轴
        let yTicks = AxisCalculator.yTicks(
            maxPrice: mapper.maxPrice, minPrice: mapper.minPrice,
            count: config.yGridLines, chartHeight: chartHeight,
            mapper: mapper, scale: 2
        )
        let xTicks = AxisCalculator.xTicks(
            models: visible, startIndex: 0,
            count: config.xGridLines, mapper: mapper
        )
        axisLayer.render(data: AxisLayer.AxisData(
            yTicks: yTicks, xTicks: xTicks,
            verticalSeparators: separators,
            chartWidth: bounds.width, chartHeight: mainH,
            yAxisWidth: config.yAxisWidth, xAxisHeight: config.xAxisHeight
        ), config: config)
    }

    // MARK: - 周期分隔线计算

    private func computePeriodSeparators(visible: [KLineRenderModel], period: ChartPeriod) -> [CGFloat] {
        guard visible.count > 1 else { return [] }
        let calendar = Calendar.current
        var result: [CGFloat] = []

        for i in 1..<visible.count {
            guard let prev = visible[i - 1].timestamp,
                  let curr = visible[i].timestamp else { continue }

            let isBoundary: Bool
            switch period {
            case .minute:
                // 不同自然日 → 竖线
                isBoundary = !calendar.isDate(prev, inSameDayAs: curr)

            case .daily:
                // 不同月份 → 竖线
                let prevComps = calendar.dateComponents([.year, .month], from: prev)
                let currComps = calendar.dateComponents([.year, .month], from: curr)
                isBoundary = prevComps.year != currComps.year || prevComps.month != currComps.month

            case .weekly:
                // 不同季度 → 竖线
                let prevQ = (calendar.component(.month, from: prev) - 1) / 3
                let currQ = (calendar.component(.month, from: curr) - 1) / 3
                let prevY = calendar.component(.year, from: prev)
                let currY = calendar.component(.year, from: curr)
                isBoundary = prevY != currY || prevQ != currQ

            case .monthly:
                // 不同年份 → 竖线
                isBoundary = calendar.component(.year, from: prev) != calendar.component(.year, from: curr)

            case .yearly:
                // 每 5 年 → 竖线
                let prevY = calendar.component(.year, from: prev)
                let currY = calendar.component(.year, from: curr)
                isBoundary = (prevY / 5) != (currY / 5)
            }

            if isBoundary {
                result.append(visible[i].centerX)
            }
        }
        return result
    }

    // MARK: - 工具方法

    private func scaledItemWidth(scale: CGFloat) -> CGFloat {
        configuration.candleWidth * scale
    }

    private func scaledItemSpacing(scale: CGFloat) -> CGFloat {
        configuration.candleSpacing * scale
    }

    private func scaledItemStride(scale: CGFloat) -> CGFloat {
        scaledItemWidth(scale: scale) + scaledItemSpacing(scale: scale)
    }

    private func indexForVisibleX(_ x: CGFloat) -> Int {
        let stride = scaledItemStride(scale: scale)
        guard stride > 0 else { return 0 }
        let abs    = x + offsetX
        return max(0, min(renderModels.count - 1, Int(abs / stride)))
    }

    private func visibleRange(totalCount: Int) -> Range<Int> {
        let stride  = scaledItemStride(scale: scale)
        guard stride > 0, totalCount > 0 else { return 0..<0 }
        let chartW  = bounds.width - configuration.yAxisWidth
        let first   = max(0, Int(offsetX / stride) - 1)
        let last    = min(totalCount, Int((offsetX + chartW) / stride) + 2)
        return first..<max(first, last)
    }
}

// MARK: - Comparable clamped 扩展

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
