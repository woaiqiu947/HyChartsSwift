import UIKit

// MARK: - 成交量渲染层

final class KLineVolumeLayer: CALayer {

    private let upLayer   = CAShapeLayer()
    private let downLayer = CAShapeLayer()
    private let flatLayer = CAShapeLayer()
    private let separatorLayer = CAShapeLayer()

    // 成交量 MA 线
    private var maLineLayers: [Int: CAShapeLayer] = [:]

    override init() {
        super.init()
        [upLayer, downLayer, flatLayer].forEach {
            $0.lineWidth = 0
            addSublayer($0)
        }
        separatorLayer.lineWidth = 0.5
        separatorLayer.fillColor = UIColor.clear.cgColor
        addSublayer(separatorLayer)
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 刷新

    func render(
        models: [KLineRenderModel],
        config: KLineConfiguration,
        mapper: CoordinateMapper,
        maSeries: [[(x: CGFloat, volume: Double?)]],   // 成交量 MA，可为空数组
        verticalSeparators: [CGFloat] = []
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        drawBars(models: models, config: config, mapper: mapper)
        drawMALines(series: maSeries, config: config, mapper: mapper)
        drawSeparators(verticalSeparators, config: config)

        CATransaction.commit()
    }

    private func drawSeparators(_ separators: [CGFloat], config: KLineConfiguration) {
        let h = bounds.height
        let path = CGMutablePath()
        for x in separators {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: h))
        }
        separatorLayer.path        = path
        separatorLayer.strokeColor = config.periodSeparatorColor.cgColor
    }

    // MARK: - 成交量柱

    private func drawBars(
        models: [KLineRenderModel],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        let upPath   = CGMutablePath()
        let downPath = CGMutablePath()
        let flatPath = CGMutablePath()
        let chartHeight = bounds.height
        let halfWidth = config.candleWidth * mapper.scale / 2

        for m in models {
            let path: CGMutablePath
            switch m.trend {
            case .up:   path = upPath
            case .down: path = downPath
            case .flat: path = flatPath
            }
            let barHeight = max(chartHeight - m.volumeY, 1)
            let rect = CGRect(x: m.centerX - halfWidth, y: m.volumeY,
                              width: halfWidth * 2, height: barHeight)
            path.addRect(rect)
        }

        upLayer.path      = upPath
        upLayer.fillColor = config.volumeUpColor.cgColor

        downLayer.path      = downPath
        downLayer.fillColor = config.volumeDownColor.cgColor

        flatLayer.path      = flatPath
        flatLayer.fillColor = config.flatColor.withAlphaComponent(0.7).cgColor
    }

    // MARK: - 成交量 MA 线

    private func drawMALines(
        series: [[(x: CGFloat, volume: Double?)]],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        maLineLayers.values.forEach { $0.path = nil }
        let chartHeight = bounds.height

        for (idx, points) in series.enumerated() {
            let layer = maLineLayer(at: idx, config: config)
            let path  = CGMutablePath()
            var penDown = false
            for (x, vol) in points {
                guard let v = vol else { penDown = false; continue }
                let y = mapper.volumeY(v, in: chartHeight)
                if penDown { path.addLine(to: CGPoint(x: x, y: y)) }
                else       { path.move(to: CGPoint(x: x, y: y)); penDown = true }
            }
            layer.path = path
        }
    }

    private func maLineLayer(at index: Int, config: KLineConfiguration) -> CAShapeLayer {
        if let l = maLineLayers[index] { return l }
        let l = CAShapeLayer()
        l.lineWidth   = config.technicalLineWidth
        l.fillColor   = UIColor.clear.cgColor
        l.strokeColor = (config.technicalColors.indices.contains(index)
            ? config.technicalColors[index] : .white).cgColor
        addSublayer(l)
        maLineLayers[index] = l
        return l
    }
}
