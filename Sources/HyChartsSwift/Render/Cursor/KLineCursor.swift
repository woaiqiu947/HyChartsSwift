import UIKit

// MARK: - 十字线光标
//
// 纯 CALayer 实现，不持有 UIView 引用。
// 由 KLineChartView 在 tap/longpress 时调用 show/hide。

final class KLineCursor: CALayer {

    // MARK: - 子层

    private let verticalLine   = CAShapeLayer()
    private let horizontalLine = CAShapeLayer()
    private let dotLayer       = CAShapeLayer()
    private let xLabelBg       = CALayer()
    private let xLabelText     = CATextLayer()
    private let yLabelBg       = CALayer()
    private let yLabelText     = CATextLayer()

    // MARK: - 初始化

    override init() {
        super.init()
        setupSublayers()
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    private func setupSublayers() {
        [verticalLine, horizontalLine, dotLayer,
         xLabelBg, yLabelBg].forEach { addSublayer($0) }
        xLabelBg.addSublayer(xLabelText)
        yLabelBg.addSublayer(yLabelText)

        [verticalLine, horizontalLine].forEach {
            $0.fillColor = UIColor.clear.cgColor
        }
        dotLayer.fillColor   = UIColor.white.cgColor
        dotLayer.strokeColor = UIColor.clear.cgColor

        [xLabelText, yLabelText].forEach {
            $0.contentsScale  = UIScreen.main.scale
            $0.alignmentMode  = .center
            $0.isWrapped      = false
        }
        isHidden = true
    }

    // MARK: - 显示

    struct CursorInfo {
        let centerX: CGFloat        // K 线中心 X（视图坐标）
        let priceY:  CGFloat        // 价格对应 Y（视图坐标）
        let xLabel:  String         // 时间文字
        let yLabel:  String         // 价格文字
        let chartSize: CGSize       // 图表区域尺寸（不含轴标签）
        let xAxisHeight: CGFloat
        let yAxisWidth:  CGFloat
    }

    func show(info: CursorInfo, config: KLineConfiguration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        isHidden = false
        applyStyle(config: config)

        let chartW = info.chartSize.width - info.yAxisWidth
        let chartH = info.chartSize.height - info.xAxisHeight

        // 竖线
        let vPath = CGMutablePath()
        vPath.move(to: CGPoint(x: info.centerX, y: 0))
        vPath.addLine(to: CGPoint(x: info.centerX, y: chartH))
        verticalLine.path = vPath

        // 横线
        let hPath = CGMutablePath()
        hPath.move(to: CGPoint(x: 0, y: info.priceY))
        hPath.addLine(to: CGPoint(x: chartW, y: info.priceY))
        horizontalLine.path = hPath

        // 圆点
        let r = config.cursorDotRadius
        dotLayer.path  = CGPath(ellipseIn: CGRect(x: info.centerX - r, y: info.priceY - r,
                                                   width: r * 2, height: r * 2), transform: nil)

        // X 标签（时间，居中在 centerX 下方）
        let xBgW: CGFloat = 70
        let xBgH: CGFloat = info.xAxisHeight
        var xBgX = info.centerX - xBgW / 2
        xBgX = max(0, min(chartW - xBgW, xBgX))
        xLabelBg.frame   = CGRect(x: xBgX, y: chartH, width: xBgW, height: xBgH)
        xLabelText.frame = xLabelBg.bounds
        xLabelText.string = info.xLabel

        // Y 标签（价格，在右侧 Y 轴区域）
        let yBgH: CGFloat = 18
        var yBgY = info.priceY - yBgH / 2
        yBgY = max(0, min(chartH - yBgH, yBgY))
        yLabelBg.frame   = CGRect(x: chartW, y: yBgY, width: info.yAxisWidth, height: yBgH)
        yLabelText.frame = yLabelBg.bounds
        yLabelText.string = info.yLabel

        CATransaction.commit()
    }

    func hide() {
        isHidden = true
    }

    // MARK: - 样式

    private func applyStyle(config: KLineConfiguration) {
        let lc = config.cursorLineColor.cgColor
        verticalLine.strokeColor   = lc
        horizontalLine.strokeColor = lc
        verticalLine.lineWidth     = config.cursorLineWidth
        horizontalLine.lineWidth   = config.cursorLineWidth

        dotLayer.fillColor = config.cursorLineColor.cgColor

        [xLabelBg, yLabelBg].forEach {
            $0.backgroundColor   = config.cursorBgColor.cgColor
            $0.cornerRadius      = 3
            $0.borderWidth       = 0.5
            $0.borderColor       = config.cursorLineColor.cgColor
        }
        [xLabelText, yLabelText].forEach {
            $0.fontSize          = config.cursorLabelFont.pointSize
            $0.foregroundColor   = config.cursorLabelColor.cgColor
        }
    }
}
