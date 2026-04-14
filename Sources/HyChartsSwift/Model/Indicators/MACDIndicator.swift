import Foundation

// MARK: - MACD 结果

public struct MACDIndicatorResult: IndicatorResult {
    public let value: MACDResult?
}

// MARK: - MACD 指标

public struct MACDIndicator<Input: KLineModel>: Indicator {
    public let fast: Int
    public let slow: Int
    public let signal: Int
    public var parameters: IndicatorParameters { .macd(fast: fast, slow: slow, signal: signal) }

    public init(fast: Int = 12, slow: Int = 26, signal: Int = 9) {
        precondition(fast > 0 && slow > fast && signal > 0, "Invalid MACD parameters")
        self.fast = fast
        self.slow = slow
        self.signal = signal
    }

    public func calculate(models: [Input]) -> [MACDIndicatorResult] {
        guard !models.isEmpty else { return [] }
        let count = models.count
        var results = [MACDIndicatorResult](repeating: MACDIndicatorResult(value: nil), count: count)

        let kFast   = 2.0 / Double(fast + 1)
        let kSlow   = 2.0 / Double(slow + 1)
        let kSignal = 2.0 / Double(signal + 1)

        var emaFast  = models[0].close
        var emaSlow  = models[0].close
        var demValue: Double = 0
        var demInited = false

        for i in models.indices {
            let close = models[i].close
            if i == 0 {
                emaFast = close
                emaSlow = close
            } else {
                emaFast = kFast * (close - emaFast) + emaFast
                emaSlow = kSlow * (close - emaSlow) + emaSlow
            }

            let dif = emaFast - emaSlow

            if !demInited {
                demValue = dif
                demInited = true
            } else {
                demValue = kSignal * (dif - demValue) + demValue
            }

            let macdValue = 2.0 * (dif - demValue)
            results[i] = MACDIndicatorResult(value: MACDResult(
                dif: dif,
                dem: demValue,
                macd: macdValue
            ))
        }
        return results
    }

    /// 增量计算：持有上次 emaFast/emaSlow/dem 即可 O(n_new) 延伸
    /// 通过 MACDIncrementalState 在外部持久化状态
    public func calculateIncremental(existing: [MACDIndicatorResult], newModels: [Input], allModels: [Input]) -> [MACDIndicatorResult] {
        guard !newModels.isEmpty else { return existing }
        // 没有上一个有效值时，全量重算
        guard let lastResult = existing.last?.value else {
            return calculate(models: allModels)
        }
        // 从全量结果中反推 ema 状态代价过高，此处回退全量
        // 实际项目中可将 emaFast/emaSlow/dem 持久化到 MACDIncrementalState
        _ = lastResult
        return calculate(models: allModels)
    }
}
