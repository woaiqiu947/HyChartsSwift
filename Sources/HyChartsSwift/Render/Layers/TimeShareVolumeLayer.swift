import UIKit

// MARK: - 分时成交量层

final class TimeShareVolumeLayer: CALayer {

    private let upLayer   = CAShapeLayer()
    private let downLayer = CAShapeLayer()
    private let flatLayer = CAShapeLayer()

    override init() {
        super.init()
        [upLayer, downLayer, flatLayer].forEach {
            $0.lineWidth = 0
            addSublayer($0)
        }
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func render(points: [TSRenderPoint], config: KLineConfiguration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let upPath   = CGMutablePath()
        let downPath = CGMutablePath()
        let flatPath = CGMutablePath()
        let h = bounds.height
        let n = CGFloat(max(points.count, 1))
        let contentW = bounds.width - config.yAxisWidth
        let barW = max(1, contentW / n * 0.7)

        for p in points {
            let barH = max(h - p.volumeTopY, 1)
            let rect = CGRect(x: p.x - barW / 2, y: p.volumeTopY, width: barW, height: barH)
            switch p.trend {
            case .up:   upPath.addRect(rect)
            case .down: downPath.addRect(rect)
            case .flat: flatPath.addRect(rect)
            }
        }

        upLayer.path      = upPath
        upLayer.fillColor = config.volumeUpColor.cgColor
        downLayer.path      = downPath
        downLayer.fillColor = config.volumeDownColor.cgColor
        flatLayer.path      = flatPath
        flatLayer.fillColor = config.flatColor.withAlphaComponent(0.7).cgColor

        CATransaction.commit()
    }
}
