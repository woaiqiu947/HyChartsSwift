import UIKit

// MARK: - 轴与网格渲染层
//
// 绘制：水平网格线、Y 轴价格标签、X 轴时间标签
// 轻量层，不持有 Store，只接受纯数据。

final class AxisLayer: CALayer {

    private var gridLayers: [CAShapeLayer] = []
    private var yLabelLayers: [CATextLayer] = []
    private var xLabelLayers: [CATextLayer] = []
    private let periodSeparatorLayer = CAShapeLayer()

    override init() {
        super.init()
        periodSeparatorLayer.lineWidth = 0.5
        periodSeparatorLayer.fillColor = UIColor.clear.cgColor
        addSublayer(periodSeparatorLayer)
    }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 刷新

    struct AxisData {
        /// Y 轴刻度：[(像素Y, 显示文字)]
        let yTicks: [(y: CGFloat, label: String)]
        /// X 轴刻度：[(中心像素X, 显示文字)]
        let xTicks: [(x: CGFloat, label: String)]
        /// 周期分隔线 X 坐标（月/季度/年边界）
        let verticalSeparators: [CGFloat]
        let chartWidth:  CGFloat
        let chartHeight: CGFloat
        let yAxisWidth:  CGFloat
        let xAxisHeight: CGFloat
    }

    func render(data: AxisData, config: KLineConfiguration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        drawGrid(data: data, config: config)
        drawPeriodSeparators(data: data, config: config)
        drawYLabels(data: data, config: config)
        drawXLabels(data: data, config: config)

        CATransaction.commit()
    }

    // MARK: - 网格线（水平）

    private func drawGrid(data: AxisData, config: KLineConfiguration) {
        // 复用或新建 CAShapeLayer
        while gridLayers.count < data.yTicks.count {
            let l = CAShapeLayer()
            l.lineWidth   = 0.5
            l.fillColor   = UIColor.clear.cgColor
            l.lineDashPattern = [4, 4]
            addSublayer(l)
            gridLayers.append(l)
        }

        for (i, tick) in data.yTicks.enumerated() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: tick.y))
            path.addLine(to: CGPoint(x: data.chartWidth - data.yAxisWidth, y: tick.y))
            gridLayers[i].path        = path
            gridLayers[i].strokeColor = config.gridColor.cgColor
            gridLayers[i].isHidden    = false
        }
        // 隐藏多余层
        for i in data.yTicks.count..<gridLayers.count {
            gridLayers[i].isHidden = true
        }
    }

    // MARK: - 周期竖线

    private func drawPeriodSeparators(data: AxisData, config: KLineConfiguration) {
        let contentH = data.chartHeight - data.xAxisHeight
        let contentW = data.chartWidth - data.yAxisWidth
        let path = CGMutablePath()
        for x in data.verticalSeparators where x >= 0 && x <= contentW {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: contentH))
        }
        periodSeparatorLayer.path        = path
        periodSeparatorLayer.strokeColor = config.periodSeparatorColor.cgColor
    }

    // MARK: - Y 轴价格标签

    private func drawYLabels(data: AxisData, config: KLineConfiguration) {
        while yLabelLayers.count < data.yTicks.count {
            let t = makeTextLayer(config: config)
            addSublayer(t)
            yLabelLayers.append(t)
        }

        for (i, tick) in data.yTicks.enumerated() {
            yLabelLayers[i].string   = tick.label
            yLabelLayers[i].frame    = CGRect(
                x: data.chartWidth - data.yAxisWidth + 4,
                y: tick.y - 8,
                width: data.yAxisWidth - 4,
                height: 16
            )
            yLabelLayers[i].isHidden = false
        }
        for i in data.yTicks.count..<yLabelLayers.count {
            yLabelLayers[i].isHidden = true
        }
    }

    // MARK: - X 轴时间标签

    private func drawXLabels(data: AxisData, config: KLineConfiguration) {
        while xLabelLayers.count < data.xTicks.count {
            let t = makeTextLayer(config: config)
            t.alignmentMode = .center
            addSublayer(t)
            xLabelLayers.append(t)
        }

        for (i, tick) in data.xTicks.enumerated() {
            xLabelLayers[i].string   = tick.label
            xLabelLayers[i].frame    = CGRect(
                x: tick.x - 30,
                y: data.chartHeight - data.xAxisHeight,
                width: 60,
                height: data.xAxisHeight
            )
            xLabelLayers[i].isHidden = false
        }
        for i in data.xTicks.count..<xLabelLayers.count {
            xLabelLayers[i].isHidden = true
        }
    }

    // MARK: - 辅助

    private func makeTextLayer(config: KLineConfiguration) -> CATextLayer {
        let t = CATextLayer()
        t.contentsScale     = UIScreen.main.scale
        t.fontSize          = config.axisTextFont.pointSize
        t.foregroundColor   = config.axisTextColor.cgColor
        t.isWrapped         = false
        t.truncationMode    = .end
        return t
    }
}

// MARK: - 轴刻度计算工具

enum AxisCalculator {

    /// 计算 Y 轴刻度（价格）
    static func yTicks(
        maxPrice: Double,
        minPrice: Double,
        count: Int,
        chartHeight: CGFloat,
        mapper: CoordinateMapper,
        scale: Int   // 小数位数
    ) -> [(y: CGFloat, label: String)] {
        guard maxPrice > minPrice, count > 0 else { return [] }
        let step = (maxPrice - minPrice) / Double(count)
        return (0...count).map { i in
            let price = minPrice + Double(i) * step
            let y     = mapper.priceY(price, in: chartHeight)
            let label = String(format: "%.\(scale)f", price)
            return (y, label)
        }
    }

    /// 计算 X 轴刻度（时间标签）
    static func xTicks(
        models: [KLineRenderModel],
        startIndex: Int,
        count: Int,
        mapper: CoordinateMapper
    ) -> [(x: CGFloat, label: String)] {
        guard !models.isEmpty, count > 0 else { return [] }
        let step = max(1, models.count / count)
        var ticks: [(x: CGFloat, label: String)] = []
        var i = 0
        while i < models.count {
            let m = models[i]
            let x = m.centerX
            ticks.append((x, m.xLabel))
            i += step
        }
        return ticks
    }
}
