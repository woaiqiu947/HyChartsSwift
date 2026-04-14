import Foundation

// MARK: - KDJ 结果

public struct KDJIndicatorResult: IndicatorResult {
    public let value: KDJResult?
}

// MARK: - KDJ 指标

public struct KDJIndicator<Input: KLineModel>: Indicator {
    /// RSV 回望周期，默认 9
    public let n: Int
    /// K 平滑因子，默认 3（即 1/3 权重）
    public let m1: Int
    /// D 平滑因子，默认 3
    public let m2: Int
    public var parameters: IndicatorParameters { .kdj(n: n, m1: m1, m2: m2) }

    public init(n: Int = 9, m1: Int = 3, m2: Int = 3) {
        precondition(n > 0 && m1 > 0 && m2 > 0, "Invalid KDJ parameters")
        self.n = n
        self.m1 = m1
        self.m2 = m2
    }

    public func calculate(models: [Input]) -> [KDJIndicatorResult] {
        guard !models.isEmpty else { return [] }
        var results = [KDJIndicatorResult](repeating: KDJIndicatorResult(value: nil), count: models.count)

        var prevK: Double = 50
        var prevD: Double = 50

        for i in models.indices {
            // 取最近 n 根的最高最低
            let windowStart = max(0, i - n + 1)
            var highest = models[windowStart].high
            var lowest  = models[windowStart].low
            if windowStart < i {
                for j in (windowStart + 1)...i {
                    highest = max(highest, models[j].high)
                    lowest  = min(lowest, models[j].low)
                }
            }

            let rsv: Double
            if highest == lowest {
                rsv = 50
            } else {
                rsv = (models[i].close - lowest) / (highest - lowest) * 100
            }

            // K = (m1-1)/m1 * prevK + 1/m1 * RSV
            let k = (Double(m1 - 1) * prevK + rsv) / Double(m1)
            // D = (m2-1)/m2 * prevD + 1/m2 * K
            let d = (Double(m2 - 1) * prevD + k) / Double(m2)
            let j = 3 * k - 2 * d

            results[i] = KDJIndicatorResult(value: KDJResult(k: k, d: d, j: j))
            prevK = k
            prevD = d
        }
        return results
    }
}
