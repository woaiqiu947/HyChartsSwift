import UIKit

// MARK: - 分时图主视图
//
// 布局：
//   ┌──────────────────────────────────┐
//   │    价格折线 + 均价线 + 填充区       │  mainContainer (1 - volumeHeightRatio)
//   ├──────────────────────────────────┤
//   │    成交量柱                        │  volumeContainer (volumeHeightRatio)
//   └──────────────────────────────────┘
//
// 无滚动/缩放手势——所有数据等比铺满宽度。
// 五日线通过 dayCount > 1 触发日期分隔线。

@MainActor
public final class TimeShareChartView: UIView {

    // MARK: - 公共属性

    public var configuration: KLineConfiguration = .default {
        didSet {
            applyBackground()
            if !rawData.isEmpty { drawAll() }
        }
    }

    // MARK: - 子视图 & 层

    private let mainContainer   = UIView()
    private let volumeContainer = UIView()

    private let priceLayer  = TimeShareMainLayer()
    private let volLayer    = TimeShareVolumeLayer()
    private let axisLayer   = AxisLayer()

    // MARK: - 数据

    private var rawData:  [RawPoint] = []   // 原始数据（不含像素坐标）
    private var dayCount: Int = 1

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
        addSubview(mainContainer)
        addSubview(volumeContainer)
        mainContainer.layer.addSublayer(priceLayer)
        mainContainer.layer.addSublayer(axisLayer)
        volumeContainer.layer.addSublayer(volLayer)
        applyBackground()
    }

    // MARK: - 布局

    public override func layoutSubviews() {
        super.layoutSubviews()
        let config = configuration
        let w = bounds.width
        let h = bounds.height
        let volH  = h * config.volumeHeightRatio
        let mainH = h - volH

        mainContainer.frame   = CGRect(x: 0, y: 0,     width: w, height: mainH)
        volumeContainer.frame = CGRect(x: 0, y: mainH, width: w, height: volH)

        applyBackground()

        priceLayer.frame = mainContainer.bounds
        axisLayer.frame  = mainContainer.bounds
        volLayer.frame   = volumeContainer.bounds

        if !rawData.isEmpty { drawAll() }
    }

    // MARK: - 公共 API

    /// 加载分时数据
    /// - Parameters:
    ///   - models: 实现了 TimeShareModel 协议的数据数组
    ///   - dayCount: 天数，1 = 分时，5 = 五日线（会绘制日期分隔线）
    public func load<M: TimeShareModel>(_ models: [M], dayCount: Int = 1) {
        self.dayCount = dayCount
        rawData = convert(models)
        if bounds.width > 0 { drawAll() }
    }

    // MARK: - 私有：数据转换

    private func convert<M: TimeShareModel>(_ models: [M]) -> [RawPoint] {
        models.enumerated().map { (i, m) in
            let trend: KLineTrend
            if i == 0 { trend = .flat }
            else {
                let prev = models[i - 1].price
                trend = m.price > prev ? .up : (m.price < prev ? .down : .flat)
            }
            return RawPoint(price: m.price, average: m.average, volume: m.volume,
                            xLabel: m.xLabel, timestamp: m.timestamp, trend: trend)
        }
    }

    // MARK: - 私有：坐标计算

    private func computeRenderPoints() -> [TSRenderPoint] {
        guard !rawData.isEmpty else { return [] }
        let config   = configuration
        let mainH    = mainContainer.bounds.height
        let volH     = volumeContainer.bounds.height
        let contentW = bounds.width - config.yAxisWidth
        let contentH = mainH - config.xAxisHeight

        // 价格 / 均价 共用同一 Y 范围
        var allPrices = rawData.map(\.price)
        allPrices += rawData.compactMap(\.average)
        let maxP = allPrices.max() ?? 1
        let minP = allPrices.min() ?? 0
        let priceRange = max(maxP - minP, 0.001)

        let maxV = rawData.map(\.volume).max() ?? 1
        let n    = CGFloat(rawData.count)
        let step = contentW / n

        return rawData.enumerated().map { (i, raw) in
            var pt = TSRenderPoint(price: raw.price, average: raw.average,
                                   volume: raw.volume, xLabel: raw.xLabel,
                                   timestamp: raw.timestamp, trend: raw.trend)
            pt.x      = step * CGFloat(i) + step * 0.5
            pt.priceY = contentH * CGFloat(1.0 - (raw.price - minP) / priceRange)
            if let avg = raw.average {
                pt.avgY = contentH * CGFloat(1.0 - (avg - minP) / priceRange)
            }
            let volRatio  = maxV > 0 ? raw.volume / maxV : 0
            pt.volumeTopY = volH * CGFloat(1.0 - volRatio)
            return pt
        }
    }

    // MARK: - 私有：绘制

    private func drawAll() {
        let points = computeRenderPoints()
        guard !points.isEmpty else { return }
        let config = configuration

        // 计算日期分隔线 X
        let dayBoundaries = computeDayBoundaries(points: points)

        priceLayer.render(points: points, dayBoundaries: dayBoundaries, config: config)
        volLayer.render(points: points, config: config)

        // Y 轴刻度（价格）
        let prices = points.map(\.price)
        let maxP   = prices.max()!
        let minP   = prices.min()!
        let mainH  = mainContainer.bounds.height
        let contentH = mainH - config.xAxisHeight
        let priceRange = max(maxP - minP, 0.001)

        let yTicks: [(y: CGFloat, label: String)] = (0...config.yGridLines).map { i in
            let ratio = Double(i) / Double(config.yGridLines)
            let price = minP + priceRange * ratio
            let y     = contentH * CGFloat(1.0 - ratio)
            return (y, String(format: "%.2f", price))
        }

        // X 轴刻度（时间标签）
        let step = max(1, points.count / config.xGridLines)
        var xTicks: [(x: CGFloat, label: String)] = []
        var i = 0
        while i < points.count {
            xTicks.append((points[i].x, points[i].xLabel))
            i += step
        }

        axisLayer.render(data: AxisLayer.AxisData(
            yTicks: yTicks, xTicks: xTicks,
            verticalSeparators: dayBoundaries,
            chartWidth: bounds.width, chartHeight: mainH,
            yAxisWidth: config.yAxisWidth, xAxisHeight: config.xAxisHeight
        ), config: config)
    }

    private func computeDayBoundaries(points: [TSRenderPoint]) -> [CGFloat] {
        guard dayCount > 1 else { return [] }
        let calendar = Calendar.current
        var result: [CGFloat] = []
        for i in 1..<points.count {
            guard let prev = points[i - 1].timestamp,
                  let curr = points[i].timestamp,
                  !calendar.isDate(prev, inSameDayAs: curr) else { continue }
            result.append(points[i].x)
        }
        return result
    }

    private func applyBackground() {
        let config = configuration
        backgroundColor                = config.chartBackgroundColor
        mainContainer.backgroundColor  = config.chartBackgroundColor
        volumeContainer.backgroundColor = config.chartBackgroundColor
    }

    // MARK: - 内部原始数据点

    private struct RawPoint: Sendable {
        let price:     Double
        let average:   Double?
        let volume:    Double
        let xLabel:    String
        let timestamp: Date?
        let trend:     KLineTrend
    }
}
