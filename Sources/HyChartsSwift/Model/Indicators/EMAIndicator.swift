import Foundation

// MARK: - EMA 结果

public struct EMAResult: IndicatorResult {
    public let value: Double?
}

// MARK: - EMA 指标

public struct EMAIndicator<Input: KLineModel>: Indicator {
    public let period: Int
    public var parameters: IndicatorParameters { .ema(period: period) }

    private var multiplier: Double { 2.0 / Double(period + 1) }

    public init(period: Int) {
        precondition(period > 0, "EMA period must be > 0")
        self.period = period
    }

    public func calculate(models: [Input]) -> [EMAResult] {
        guard !models.isEmpty else { return [] }
        var results = [EMAResult](repeating: EMAResult(value: nil), count: models.count)
        var prevEMA: Double = 0
        let k = multiplier

        for i in models.indices {
            if i == 0 {
                prevEMA = models[i].close
                results[i] = EMAResult(value: prevEMA)
            } else {
                prevEMA = k * (models[i].close - prevEMA) + prevEMA
                results[i] = EMAResult(value: prevEMA)
            }
        }
        return results
    }

    /// 增量计算：只需上一个 EMA 值即可向后延伸，O(n_new) 而非 O(n_all)
    public func calculateIncremental(existing: [EMAResult], newModels: [Input], allModels: [Input]) -> [EMAResult] {
        guard !newModels.isEmpty else { return existing }
        guard let lastEMAValue = existing.last?.value else {
            return calculate(models: allModels)
        }
        var results = existing
        var prevEMA = lastEMAValue
        let k = multiplier

        for model in newModels {
            prevEMA = k * (model.close - prevEMA) + prevEMA
            results.append(EMAResult(value: prevEMA))
        }
        return results
    }
}
