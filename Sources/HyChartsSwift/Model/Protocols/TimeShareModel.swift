import Foundation

// MARK: - 分时数据协议

/// 分时图 / 五日线 数据模型协议
public protocol TimeShareModel: ChartModel, Sendable {
    /// 当前价格
    var price: Double { get }
    /// 均价（可选，nil 时不绘制均价线）
    var average: Double? { get }
    /// 成交量
    var volume: Double { get }
    /// 时间戳（用于五日线的日期分隔线检测）
    var timestamp: Date? { get }
}

public extension TimeShareModel {
    var average: Double? { nil }
    var timestamp: Date? { nil }
}
