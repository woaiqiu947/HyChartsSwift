import UIKit

// MARK: - 全局渲染配置
//
// 值类型，外部修改后重新赋给 KLineChartView 即可触发重绘。
// 颜色使用 UIColor（iOS），后续适配 macOS 时替换为 NSColor 即可。

public struct KLineConfiguration: Sendable {

    // MARK: - 默认颜色常量

    public struct Colors {
        // 涨跌平
        public static let up:   UIColor = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1)
        public static let down: UIColor = UIColor(red: 0.13, green: 0.69, blue: 0.30, alpha: 1)
        public static let flat: UIColor = UIColor.lightGray

        // 技术指标线：黄、蓝、紫
        public static let yellow: UIColor = UIColor(red: 0.90, green: 0.75, blue: 0.10, alpha: 1)
        public static let blue:   UIColor = UIColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 1)
        public static let purple: UIColor = UIColor(red: 0.80, green: 0.30, blue: 0.80, alpha: 1)

        // 背景
        public static let chartBg:     UIColor = UIColor.white
        public static let auxiliaryBg: UIColor = UIColor.white

        // 轴 & 网格
        public static let grid:            UIColor = UIColor(white: 0.90, alpha: 1)
        public static let periodSeparator: UIColor = UIColor(white: 0.75, alpha: 1)

        // 分时图
        public static let timeShareLine:    UIColor = UIColor(red: 0.20, green: 0.60, blue: 0.90, alpha: 1)
        public static let timeShareAvgLine: UIColor = UIColor(red: 0.90, green: 0.75, blue: 0.10, alpha: 1)
        public static let axisText:   UIColor = UIColor(white: 0.40, alpha: 1)
        public static let latestPrice:UIColor = UIColor.systemOrange.withAlphaComponent(0.8)

        // 十字线
        public static let cursor:    UIColor = UIColor.label.withAlphaComponent(0.6)
        public static let cursorBg:  UIColor = UIColor.systemBackground.withAlphaComponent(0.9)
        public static let cursorLabel: UIColor = UIColor.label
    }

    // MARK: - K 线尺寸

    public var candleWidth:   CGFloat = 6
    public var candleSpacing: CGFloat = 2
    public var minScale:      CGFloat = 0.3
    public var maxScale:      CGFloat = 3.0

    // MARK: - 涨跌颜色

    public var upColor:   UIColor = Colors.up
    public var downColor: UIColor = Colors.down
    public var flatColor: UIColor = Colors.flat

    // MARK: - 背景色

    /// 主图 + 成交量区域背景色
    public var chartBackgroundColor:     UIColor = Colors.chartBg
    /// 副图（MACD/KDJ/RSI）背景色
    public var auxiliaryBackgroundColor: UIColor = Colors.auxiliaryBg

    // MARK: - 轴 & 网格

    public var latestPriceLineColor: UIColor = Colors.latestPrice
    public var gridColor:                UIColor = Colors.grid
    public var periodSeparatorColor:     UIColor = Colors.periodSeparator

    // MARK: - 分时图颜色

    public var timeShareLineColor:    UIColor = Colors.timeShareLine
    public var timeShareAvgLineColor: UIColor = Colors.timeShareAvgLine
    public var axisTextColor:            UIColor = Colors.axisText
    public var axisTextFont:         UIFont  = .systemFont(ofSize: 10)

    // MARK: - 主图技术指标颜色

    public var technicalColors: [UIColor] = [Colors.yellow, Colors.blue, Colors.purple]
    public var bollMidColor:    UIColor   = Colors.yellow
    public var bollUpperColor:  UIColor   = Colors.blue
    public var bollLowerColor:  UIColor   = Colors.purple

    // MARK: - 副图颜色

    public var macdDIFColor:  UIColor = Colors.blue
    public var macdDEMColor:  UIColor = Colors.yellow
    public var macdUpColor:   UIColor = Colors.up
    public var macdDownColor: UIColor = Colors.down

    public var kdjKColor: UIColor = Colors.blue
    public var kdjDColor: UIColor = Colors.yellow
    public var kdjJColor: UIColor = Colors.purple

    public var rsiColors: [UIColor] = [Colors.blue, Colors.yellow, Colors.purple]

    // MARK: - 成交量颜色

    public var volumeUpColor:   UIColor = Colors.up
    public var volumeDownColor: UIColor = Colors.down

    // MARK: - 轴布局

    public var yAxisWidth:           CGFloat = 60
    public var xAxisHeight:          CGFloat = 20
    public var volumeHeightRatio:    CGFloat = 0.2
    public var auxiliaryHeightRatio: CGFloat = 0.25
    public var yGridLines:           Int     = 4
    public var xGridLines:           Int     = 4

    // MARK: - 十字线

    public var cursorLineColor:  UIColor = Colors.cursor
    public var cursorLineWidth:  CGFloat = 0.5
    public var cursorDotRadius:  CGFloat = 4
    public var cursorLabelFont:  UIFont  = .systemFont(ofSize: 10)
    public var cursorLabelColor: UIColor = Colors.cursorLabel
    public var cursorBgColor:    UIColor = Colors.cursorBg

    // MARK: - 技术指标选择

    public var mainTechnical: MainTechnicalType = .sma(periods: [5, 10, 30])
    public var auxiliaryType: AuxiliaryType     = .macd()

    // MARK: - 周期分隔线

    /// K 线时间周期，决定竖向分隔线的边界规则
    public var chartPeriod: ChartPeriod = .daily

    // MARK: - 线宽

    public var technicalLineWidth: CGFloat = 1.0
    public var wickLineWidth:      CGFloat = 1.0

    // MARK: - 默认配置

    public static let `default` = KLineConfiguration()
    public init() {}
}
