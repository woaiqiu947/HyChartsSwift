import Foundation

// MARK: - 基础图表数据协议

/// 所有图表数据模型的基础协议
public protocol ChartModel: Sendable {
    /// X 轴显示文本（时间标签等）
    var xLabel: String { get }
}

// MARK: - K 线数据协议

/// K 线数据模型协议，外部实现此协议喂给图表
public protocol KLineModel: ChartModel {
    var open: Double { get }
    var high: Double { get }
    var low: Double { get }
    var close: Double { get }
    var volume: Double { get }
    /// 成交额，可选
    var amount: Double? { get }
    /// 换手率，可选
    var turnoverRate: Double? { get }
    /// 时间戳，用于周期分隔线检测（月/季度/年边界），可选
    var timestamp: Date? { get }
}

public extension KLineModel {
    var amount: Double? { nil }
    var turnoverRate: Double? { nil }
    var timestamp: Date? { nil }

    /// 涨跌方向
    var trend: KLineTrend {
        if close > open { return .up }
        if close < open { return .down }
        return .flat
    }

    /// 涨跌幅（百分比）
    var changePercent: Double {
        guard open != 0 else { return 0 }
        return (close - open) / open * 100
    }
}

// MARK: - 枚举

public enum KLineTrend: Sendable {
    case up, down, flat
}

// MARK: - 折线图数据协议

public protocol LineModel: ChartModel {
    /// 支持多条线，每条对应一个 Double?（nil 表示断点）
    var values: [Double?] { get }
}

// MARK: - 柱状图数据协议

public protocol BarModel: ChartModel {
    var value: Double { get }
    /// 用于区分颜色的分组（如涨/跌）
    var group: Int { get }
}
