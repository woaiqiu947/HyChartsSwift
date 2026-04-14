import Foundation

// MARK: - RSI 结果

public struct RSIIndicatorResult: IndicatorResult {
    public let value: Double?
}

// MARK: - RSI 指标

public struct RSIIndicator<Input: KLineModel>: Indicator {
    public let period: Int
    public var parameters: IndicatorParameters { .rsi(period: period) }

    public init(period: Int) {
        precondition(period > 1, "RSI period must be > 1")
        self.period = period
    }

    public func calculate(models: [Input]) -> [RSIIndicatorResult] {
        guard models.count > 1 else {
            return Array(repeating: RSIIndicatorResult(value: nil), count: models.count)
        }

        var results = [RSIIndicatorResult](repeating: RSIIndicatorResult(value: nil), count: models.count)
        // 使用指数平滑（Wilder 平滑法，与主流行情软件一致）
        // 初始值：首个 period 段的简单平均
        var avgUp: Double = 0
        var avgDown: Double = 0

        for i in 1..<models.count {
            let change = models[i].close - models[i - 1].close
            let up   = max(change, 0)
            let down = max(-change, 0)

            if i < period {
                // 积累初始段
                avgUp   += up
                avgDown += down
                if i == period - 1 {
                    avgUp   /= Double(period)
                    avgDown /= Double(period)
                    let rsi = avgDown == 0 ? 100 : avgUp / (avgUp + avgDown) * 100
                    results[i] = RSIIndicatorResult(value: rsi)
                }
            } else {
                // Wilder 平滑：(prevAvg * (n-1) + current) / n
                avgUp   = (avgUp   * Double(period - 1) + up)   / Double(period)
                avgDown = (avgDown * Double(period - 1) + down) / Double(period)
                let rsi = avgDown == 0 ? 100 : avgUp / (avgUp + avgDown) * 100
                results[i] = RSIIndicatorResult(value: rsi)
            }
        }
        return results
    }

    /// 增量计算：持有 avgUp/avgDown 状态即可 O(1) 延伸
    public func calculateIncremental(existing: [RSIIndicatorResult], newModels: [Input], allModels: [Input]) -> [RSIIndicatorResult] {
        guard !newModels.isEmpty, existing.count >= period else {
            return calculate(models: allModels)
        }
        // 反推 avgUp/avgDown 需要额外状态，此处回退全量
        // 实际项目中可将状态持久化到 RSIIncrementalState
        return calculate(models: allModels)
    }
}
