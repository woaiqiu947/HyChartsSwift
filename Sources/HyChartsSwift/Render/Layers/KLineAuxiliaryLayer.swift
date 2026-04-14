import UIKit

// MARK: - 副图渲染层（MACD / KDJ / RSI）

final class KLineAuxiliaryLayer: CALayer {

    // 成交量（作为副图时）
    private let volUpBar   = CAShapeLayer()
    private let volDownBar = CAShapeLayer()
    private let volFlatBar = CAShapeLayer()

    // MACD
    private let macdUpBar   = CAShapeLayer()
    private let macdDownBar = CAShapeLayer()
    private let difLine     = CAShapeLayer()
    private let demLine     = CAShapeLayer()

    // KDJ / RSI：动态线层，key = 线索引
    private var lineLayers: [Int: CAShapeLayer] = [:]

    private let separatorLayer = CAShapeLayer()

    override init() {
        super.init()
        [volUpBar, volDownBar, volFlatBar,
         macdUpBar, macdDownBar, difLine, demLine].forEach {
            addSublayer($0)
        }
        [volUpBar, volDownBar, volFlatBar].forEach { $0.lineWidth = 0 }
        macdUpBar.lineWidth   = 0
        macdDownBar.lineWidth = 0
        difLine.fillColor     = UIColor.clear.cgColor
        demLine.fillColor     = UIColor.clear.cgColor
        separatorLayer.lineWidth = 0.5
        separatorLayer.fillColor = UIColor.clear.cgColor
        addSublayer(separatorLayer)
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 刷新入口

    func render(results: AuxiliaryRenderData, config: KLineConfiguration, mapper: CoordinateMapper,
                verticalSeparators: [CGFloat] = []) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        hideAll()

        switch results {
        case .volume(let bars):
            drawVolume(bars: bars, config: config, mapper: mapper)
        case .macd(let points):
            drawMACD(points: points, config: config, mapper: mapper)
        case .kdj(let lines):
            drawLines(lines: lines, colors: [config.kdjKColor, config.kdjDColor, config.kdjJColor], config: config, mapper: mapper)
        case .rsi(let lines):
            drawLines(lines: lines, colors: config.rsiColors, config: config, mapper: mapper)
        case .none:
            break
        }

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

    // MARK: - MACD

    private func drawMACD(
        points: [MACDPoint],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        let chartHeight = bounds.height
        let upPath   = CGMutablePath()
        let downPath = CGMutablePath()
        let difPath  = CGMutablePath()
        let demPath  = CGMutablePath()
        var difPen   = false
        var demPen   = false
        let halfWidth = config.candleWidth * mapper.scale / 2

        for p in points {
            let x = p.x
            // MACD 柱
            let zeroY  = mapper.auxiliaryY(0, in: chartHeight)
            let macdY  = mapper.auxiliaryY(p.macd, in: chartHeight)
            let barTop  = min(zeroY, macdY)
            let barH    = max(abs(zeroY - macdY), 1)
            let barRect = CGRect(x: x - halfWidth, y: barTop, width: halfWidth * 2, height: barH)
            if p.macd >= 0 { upPath.addRect(barRect) } else { downPath.addRect(barRect) }

            // DIF 线
            let difY = mapper.auxiliaryY(p.dif, in: chartHeight)
            let pt   = CGPoint(x: x, y: difY)
            if difPen { difPath.addLine(to: pt) } else { difPath.move(to: pt); difPen = true }

            // DEM 线
            let demY = mapper.auxiliaryY(p.dem, in: chartHeight)
            let dp   = CGPoint(x: x, y: demY)
            if demPen { demPath.addLine(to: dp) } else { demPath.move(to: dp); demPen = true }
        }

        macdUpBar.path      = upPath
        macdUpBar.fillColor = config.macdUpColor.cgColor
        macdDownBar.path      = downPath
        macdDownBar.fillColor = config.macdDownColor.cgColor

        difLine.path        = difPath
        difLine.lineWidth   = config.technicalLineWidth
        difLine.strokeColor = config.macdDIFColor.cgColor

        demLine.path        = demPath
        demLine.lineWidth   = config.technicalLineWidth
        demLine.strokeColor = config.macdDEMColor.cgColor
    }

    // MARK: - 多线（KDJ / RSI）

    private func drawLines(
        lines: [[(x: CGFloat, value: Double?)]],
        colors: [UIColor],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        let chartHeight = bounds.height
        for (idx, series) in lines.enumerated() {
            let layer = lineLayer(at: idx)
            let color = colors.indices.contains(idx) ? colors[idx] : .white
            layer.strokeColor = color.cgColor
            layer.lineWidth   = config.technicalLineWidth
            layer.fillColor   = UIColor.clear.cgColor

            let path    = CGMutablePath()
            var penDown = false
            for (x, val) in series {
                guard let v = val else { penDown = false; continue }
                let y  = mapper.auxiliaryY(v, in: chartHeight)
                let pt = CGPoint(x: x, y: y)
                if penDown { path.addLine(to: pt) } else { path.move(to: pt); penDown = true }
            }
            layer.path = path
        }
    }

    // MARK: - 辅助

    // MARK: - 成交量（副图模式）

    private func drawVolume(
        bars: [(x: CGFloat, volume: Double, trend: KLineTrend)],
        config: KLineConfiguration,
        mapper: CoordinateMapper
    ) {
        let chartHeight = bounds.height
        let upPath   = CGMutablePath()
        let downPath = CGMutablePath()
        let flatPath = CGMutablePath()
        let halfWidth = config.candleWidth * mapper.scale / 2

        for bar in bars {
            let y      = mapper.auxiliaryY(bar.volume, in: chartHeight)
            let height = max(chartHeight - y, 1)
            let rect   = CGRect(x: bar.x - halfWidth, y: y, width: halfWidth * 2, height: height)
            switch bar.trend {
            case .up:   upPath.addRect(rect)
            case .down: downPath.addRect(rect)
            case .flat: flatPath.addRect(rect)
            }
        }

        volUpBar.path      = upPath
        volUpBar.fillColor = config.volumeUpColor.cgColor
        volDownBar.path      = downPath
        volDownBar.fillColor = config.volumeDownColor.cgColor
        volFlatBar.path      = flatPath
        volFlatBar.fillColor = config.flatColor.withAlphaComponent(0.7).cgColor
    }

    private func hideAll() {
        volUpBar.path    = nil
        volDownBar.path  = nil
        volFlatBar.path  = nil
        macdUpBar.path   = nil
        macdDownBar.path = nil
        difLine.path     = nil
        demLine.path     = nil
        lineLayers.values.forEach { $0.path = nil }
    }

    private func lineLayer(at index: Int) -> CAShapeLayer {
        if let l = lineLayers[index] { return l }
        let l = CAShapeLayer()
        addSublayer(l)
        lineLayers[index] = l
        return l
    }
}

// MARK: - 副图数据载体（不含 any，传给 Layer 的快照）

struct MACDPoint {
    let x: CGFloat
    let dif, dem, macd: Double
}

enum AuxiliaryRenderData {
    case none
    case volume(bars: [(x: CGFloat, volume: Double, trend: KLineTrend)])
    case macd(points: [MACDPoint])
    /// KDJ 三条线：[(x, k?), (x, d?), (x, j?)]
    case kdj(lines: [[(x: CGFloat, value: Double?)]])
    /// RSI 多条线
    case rsi(lines: [[(x: CGFloat, value: Double?)]])
}
