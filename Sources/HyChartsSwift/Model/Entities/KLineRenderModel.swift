import CoreGraphics
import Foundation

// MARK: - 渲染用内部值类型

/// 渲染层唯一使用的数据结构，完全避开 any Protocol 开销
/// 由 ChartDataStore 从外部 KLineModel 转换而来，包含：
/// - 原始 OHLCV 数据
/// - 已计算好的像素坐标（由 CoordinateMapper 填充）
/// - 各技术指标结果（按需填充）
public struct KLineRenderModel: Sendable {

    // MARK: 原始数据
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double
    public let amount: Double?
    public let turnoverRate: Double?
    public let xLabel: String
    public let timestamp: Date?
    public let trend: KLineTrend

    // MARK: 像素坐标（由 CoordinateMapper 填充）
    /// K 线中心 X 坐标（绝对位置，未减去滚动偏移）
    public var centerX: CGFloat = 0
    /// 最高价对应 Y
    public var highY: CGFloat = 0
    /// 最低价对应 Y
    public var lowY: CGFloat = 0
    /// 开盘价对应 Y
    public var openY: CGFloat = 0
    /// 收盘价对应 Y
    public var closeY: CGFloat = 0
    /// 成交量柱顶 Y
    public var volumeY: CGFloat = 0

    // MARK: 主图技术指标结果
    public var sma: [Int: Double] = [:]       // key: period
    public var ema: [Int: Double] = [:]       // key: period
    public var boll: BOLLResult? = nil

    // MARK: 副图技术指标结果
    public var macd: MACDResult? = nil
    public var kdj: KDJResult? = nil
    public var rsi: [Int: Double] = [:]       // key: period

    // MARK: - 初始化（从外部 KLineModel 转换）
    public init<M: KLineModel>(_ model: M) {
        open = model.open
        high = model.high
        low = model.low
        close = model.close
        volume = model.volume
        amount = model.amount
        turnoverRate = model.turnoverRate
        xLabel = model.xLabel
        timestamp = model.timestamp
        trend = model.trend
    }
}

// MARK: - 指标结果结构体

public struct BOLLResult: Sendable {
    public let mb: Double       // 中轨
    public let upper: Double    // 上轨
    public let lower: Double    // 下轨
}

public struct MACDResult: Sendable {
    public let dif: Double
    public let dem: Double      // signal line
    public let macd: Double     // histogram = 2 * (dif - dem)
}

public struct KDJResult: Sendable {
    public let k: Double
    public let d: Double
    public let j: Double
}

// MARK: - 极值信息（用于 Y 轴范围计算）

public struct KLineExtremes: Sendable {
    public let maxPrice: Double
    public let minPrice: Double
    public let maxVolume: Double
    public let minVolume: Double
    /// 副图指标的最大值（MACD/KDJ/RSI 各自不同）
    public let maxAuxiliary: Double
    public let minAuxiliary: Double

    public static let zero = KLineExtremes(
        maxPrice: 0, minPrice: 0,
        maxVolume: 0, minVolume: 0,
        maxAuxiliary: 0, minAuxiliary: 0
    )
}
