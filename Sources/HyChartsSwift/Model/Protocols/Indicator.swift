import Foundation

// MARK: - 指标协议

/// 技术指标计算协议
/// - associatedtype Input：接受的模型类型
/// - associatedtype Result：每根 K 线对应的指标结果
public protocol Indicator<Input, Result>: Sendable {
    associatedtype Input: KLineModel
    associatedtype Result: IndicatorResult

    /// 参数描述，用于缓存 key（类型安全，不再用字符串）
    var parameters: IndicatorParameters { get }

    /// 全量计算，返回与输入等长的结果数组
    func calculate(models: [Input]) -> [Result]

    /// 增量计算：在已有结果末尾追加 newModels 的结果
    /// - 默认实现回退到全量计算，子类可覆写以提升性能
    func calculateIncremental(existing: [Result], newModels: [Input], allModels: [Input]) -> [Result]
}

public extension Indicator {
    func calculateIncremental(existing: [Result], newModels: [Input], allModels: [Input]) -> [Result] {
        // 默认：全量重算（子类覆写可做增量）
        calculate(models: allModels)
    }
}

// MARK: - 指标结果标记协议

public protocol IndicatorResult: Sendable {}

// MARK: - 指标参数（类型安全替代字符串 key）

public enum IndicatorParameters: Hashable, Sendable {
    case sma(period: Int)
    case ema(period: Int)
    case boll(period: Int, multiplier: Double)
    case macd(fast: Int, slow: Int, signal: Int)
    case kdj(n: Int, m1: Int, m2: Int)
    case rsi(period: Int)
    case volumeSMA(period: Int)
    case volumeEMA(period: Int)
}

// MARK: - K 线时间周期

public enum ChartPeriod: Sendable {
    case minute(Int)    // 1 / 5 / 15 / 30 / 60 分钟K：竖线 = 每个交易日
    case daily          // 日K：竖线 = 每月第一个交易日
    case weekly         // 周K：竖线 = 每季度第一周
    case monthly        // 月K：竖线 = 每年 1 月
    case yearly         // 年K：竖线 = 每 5 年
}

// MARK: - 主图技术线类型

public enum MainTechnicalType: Sendable {
    case none
    case sma(periods: [Int])
    case ema(periods: [Int])
    case boll(period: Int, multiplier: Double = 2.0)
}

// MARK: - 副图指标类型

public enum AuxiliaryType: Sendable {
    case volume                                               // 成交量柱
    case macd(fast: Int = 12, slow: Int = 26, signal: Int = 9)
    case kdj(n: Int = 9, m1: Int = 3, m2: Int = 3)
    case rsi(periods: [Int] = [6, 12, 24])
}
