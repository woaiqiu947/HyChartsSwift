import UIKit

// MARK: - 主图渲染层
//
// 负责绘制：蜡烛实体、上下影线、最新价横线、SMA/EMA/BOLL 技术线
// 设计要点：
//   - 所有上涨蜡烛合并为一条 CGPath，下跌同理，一次赋给 CAShapeLayer
//   - 技术指标线每条一个 CAShapeLayer，按需懒创建
//   - 不持有 Store，只接受不可变的 snapshot 数据

final class KLineMainLayer: CALayer {

    // MARK: - 子层

    private let upCandleLayer   = CAShapeLayer()
    private let downCandleLayer = CAShapeLayer()
    private let flatCandleLayer = CAShapeLayer()
    private let latestPriceLine = CAShapeLayer()
    private let latestPriceText = CATextLayer()

    // 技术指标线：key 对应 technicalColors 的下标
    private var technicalLineLayers: [Int: CAShapeLayer] = [:]

    // MARK: - 初始化

    override init() {
        super.init()
        setupSublayers()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setupSublayers() {
        [upCandleLayer, downCandleLayer, flatCandleLayer,
         latestPriceLine, latestPriceText].forEach { addSublayer($0) }

        upCandleLayer.lineWidth   = 0
        downCandleLayer.lineWidth = 0
        flatCandleLayer.lineWidth = 0

        latestPriceLine.lineWidth   = 0.5
        latestPriceLine.lineDashPattern = [4, 3]

        latestPriceText.contentsScale = UIScreen.main.scale
        latestPriceText.alignmentMode = .left
        latestPriceText.isWrapped     = false
    }

    // MARK: - 公共刷新入口

    /// - Parameters:
    ///   - models:  当前可见的渲染模型（已填充像素坐标）
    ///   - config:  渲染配置
    ///   - mapper:  坐标映射器（用于技术线和最新价）
    ///   - allModels: 全量模型（技术线需要完整序列）
    ///   - technicalResults: 主图技术指标数据（与 allModels 等长）
    func render(
        models: [KLineRenderModel],
        config: KLineConfiguration,
        mapper: CoordinateMapper,
        allModels: [KLineRenderModel],
        technicalResults: MainTechnicalResults
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        drawCandles(models: models, config: config, scale: mapper.scale)
        drawLatestPrice(models: models, config: config, mapper: mapper)
        drawTechnicalLines(
            visibleModels: models,
            allModels: allModels,
            config: config,
            mapper: mapper,
            results: technicalResults
        )

        CATransaction.commit()
    }

    // MARK: - 蜡烛绘制

    private func drawCandles(models: [KLineRenderModel], config: KLineConfiguration,
                             scale: CGFloat) {
        let upPath   = CGMutablePath()
        let downPath = CGMutablePath()
        let flatPath = CGMutablePath()

        let halfWidth = config.candleWidth * scale / 2
        let wickWidth: CGFloat = max(1, config.wickLineWidth)

        for m in models {
            let path: CGMutablePath
            switch m.trend {
            case .up:   path = upPath
            case .down: path = downPath
            case .flat: path = flatPath
            }

            let cx = m.centerX
            // 影线（细线用 rect 宽度=1 模拟）
            let wickRect = CGRect(x: cx - wickWidth / 2, y: m.highY,
                                  width: wickWidth, height: m.lowY - m.highY)
            path.addRect(wickRect)

            // 实体
            let bodyTop    = min(m.openY, m.closeY)
            let bodyHeight = max(abs(m.openY - m.closeY), 1)   // 至少 1pt，避免十字星消失
            let bodyRect   = CGRect(x: cx - halfWidth, y: bodyTop,
                                    width: halfWidth * 2, height: bodyHeight)
            path.addRect(bodyRect)
        }

        upCandleLayer.path      = upPath
        upCandleLayer.fillColor = config.upColor.cgColor

        downCandleLayer.path      = downPath
        downCandleLayer.fillColor = config.downColor.cgColor

        flatCandleLayer.path      = flatPath
        flatCandleLayer.fillColor = config.flatColor.cgColor
    }

    // MARK: - 最新价横线

    private func drawLatestPrice(
        models: [KLineRenderModel],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        guard let last = models.last else {
            latestPriceLine.path = nil
            latestPriceText.string = nil
            return
        }

        let y = last.closeY
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 0, y: y))
        linePath.addLine(to: CGPoint(x: mapper.chartSize.width - config.yAxisWidth, y: y))

        latestPriceLine.path        = linePath
        latestPriceLine.strokeColor = config.latestPriceLineColor.cgColor

        let price = last.close
        let text  = String(format: "%.\(2)f", price)   // 小数位数后续从 config 读
        latestPriceText.string    = text
        latestPriceText.fontSize  = config.axisTextFont.pointSize
        latestPriceText.foregroundColor = config.latestPriceLineColor.cgColor
        latestPriceText.frame     = CGRect(x: mapper.chartSize.width - config.yAxisWidth + 4,
                                           y: y - 8, width: config.yAxisWidth - 4, height: 16)
    }

    // MARK: - 技术指标线

    private func drawTechnicalLines(
        visibleModels: [KLineRenderModel],
        allModels: [KLineRenderModel],
        config: KLineConfiguration,
        mapper: CoordinateMapper,
        results: MainTechnicalResults
    ) {
        // 先隐藏所有已有技术线层
        technicalLineLayers.values.forEach { $0.path = nil }

        switch results {
        case .none:
            break

        case .sma(let seriesList), .ema(let seriesList):
            for (idx, series) in seriesList.enumerated() {
                let layer = technicalLineLayer(at: idx, config: config)
                layer.path = buildLinePath(
                    values: series,
                    mapper: mapper,
                    chartHeight: mapper.chartSize.height
                )
            }

        case .boll(let mb, let upper, let lower):
            let mbLayer    = technicalLineLayer(at: 0, config: config)
            let upperLayer = technicalLineLayer(at: 1, config: config)
            let lowerLayer = technicalLineLayer(at: 2, config: config)

            mbLayer.strokeColor    = config.bollMidColor.cgColor
            upperLayer.strokeColor = config.bollUpperColor.cgColor
            lowerLayer.strokeColor = config.bollLowerColor.cgColor

            mbLayer.path    = buildLinePath(values: mb,    mapper: mapper, chartHeight: mapper.chartSize.height)
            upperLayer.path = buildLinePath(values: upper, mapper: mapper, chartHeight: mapper.chartSize.height)
            lowerLayer.path = buildLinePath(values: lower, mapper: mapper, chartHeight: mapper.chartSize.height)
        }
    }

    /// 将价格值数组连成折线 path（nil 表示断点）
    private func buildLinePath(
        values: [(x: CGFloat, price: Double?)],
        mapper: CoordinateMapper,
        chartHeight: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        var penDown = false
        for (x, price) in values {
            guard let p = price else { penDown = false; continue }
            let y = mapper.priceY(p, in: chartHeight)
            if penDown {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.move(to: CGPoint(x: x, y: y))
                penDown = true
            }
        }
        return path
    }

    /// 懒创建技术线 CAShapeLayer
    private func technicalLineLayer(at index: Int, config: KLineConfiguration) -> CAShapeLayer {
        if let existing = technicalLineLayers[index] { return existing }
        let layer = CAShapeLayer()
        layer.lineWidth   = config.technicalLineWidth
        layer.fillColor   = UIColor.clear.cgColor
        layer.strokeColor = (config.technicalColors.indices.contains(index)
            ? config.technicalColors[index]
            : .white).cgColor
        addSublayer(layer)
        technicalLineLayers[index] = layer
        return layer
    }
}

// MARK: - 主图技术指标数据载体（传入 Layer 的快照，不含 any）

enum MainTechnicalResults {
    case none
    /// [(centerX, price?)]，与可见模型对应
    case sma(seriesList: [[(x: CGFloat, price: Double?)]])
    case ema(seriesList: [[(x: CGFloat, price: Double?)]])
    case boll(
        mb:    [(x: CGFloat, price: Double?)],
        upper: [(x: CGFloat, price: Double?)],
        lower: [(x: CGFloat, price: Double?)]
    )
}
