import UIKit

// MARK: - 分时主图层（价格折线 + 填充 + 均价线）

final class TimeShareMainLayer: CALayer {

    private let fillLayer = CAShapeLayer()   // 价格线下方填充
    private let priceLine = CAShapeLayer()   // 价格折线
    private let avgLine   = CAShapeLayer()   // 均价线
    private let sepLayer  = CAShapeLayer()   // 日期分隔线（五日线）

    override init() {
        super.init()
        fillLayer.lineWidth   = 0
        priceLine.fillColor   = UIColor.clear.cgColor
        avgLine.fillColor     = UIColor.clear.cgColor
        avgLine.lineDashPattern = [4, 2]
        sepLayer.fillColor    = UIColor.clear.cgColor
        sepLayer.lineWidth    = 0.5
        [fillLayer, priceLine, avgLine, sepLayer].forEach { addSublayer($0) }
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 刷新

    func render(
        points: [TSRenderPoint],
        dayBoundaries: [CGFloat],
        config: KLineConfiguration
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let contentH = bounds.height - config.xAxisHeight

        // 价格折线
        let linePath = CGMutablePath()
        for (i, p) in points.enumerated() {
            if i == 0 { linePath.move(to: CGPoint(x: p.x, y: p.priceY)) }
            else       { linePath.addLine(to: CGPoint(x: p.x, y: p.priceY)) }
        }
        priceLine.path        = linePath
        priceLine.lineWidth   = 1.5
        priceLine.strokeColor = config.timeShareLineColor.cgColor

        // 填充区域（价格线 → 底部 → 封闭）
        if let first = points.first, let last = points.last {
            let fillPath = CGMutablePath()
            fillPath.addPath(linePath)
            fillPath.addLine(to: CGPoint(x: last.x,  y: contentH))
            fillPath.addLine(to: CGPoint(x: first.x, y: contentH))
            fillPath.closeSubpath()
            fillLayer.path      = fillPath
            fillLayer.fillColor = config.timeShareLineColor.withAlphaComponent(0.15).cgColor
        }

        // 均价线
        let avgPath = CGMutablePath()
        var avgPen  = false
        for p in points {
            guard p.average != nil else { avgPen = false; continue }
            if avgPen { avgPath.addLine(to: CGPoint(x: p.x, y: p.avgY)) }
            else       { avgPath.move(to:  CGPoint(x: p.x, y: p.avgY)); avgPen = true }
        }
        avgLine.path        = avgPath
        avgLine.lineWidth   = 1.0
        avgLine.strokeColor = config.timeShareAvgLineColor.cgColor

        // 日期分隔线（五日线专用）
        let sepPath = CGMutablePath()
        for x in dayBoundaries {
            sepPath.move(to:    CGPoint(x: x, y: 0))
            sepPath.addLine(to: CGPoint(x: x, y: contentH))
        }
        sepLayer.path        = sepPath
        sepLayer.strokeColor = config.periodSeparatorColor.cgColor

        CATransaction.commit()
    }
}

// MARK: - 分时渲染点（内部值类型）

struct TSRenderPoint: Sendable {
    let price:   Double
    let average: Double?
    let volume:  Double
    let xLabel:  String
    let timestamp: Date?
    let trend:   KLineTrend

    var x:         CGFloat = 0
    var priceY:    CGFloat = 0
    var avgY:      CGFloat = 0
    var volumeTopY: CGFloat = 0
}
