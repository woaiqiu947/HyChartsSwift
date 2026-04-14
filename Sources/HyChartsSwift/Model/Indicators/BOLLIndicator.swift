import Foundation

// MARK: - BOLL 结果

public struct BOLLIndicatorResult: IndicatorResult {
    /// nil 表示数据不足
    public let value: BOLLResult?
}

// MARK: - BOLL 指标

public struct BOLLIndicator<Input: KLineModel>: Indicator {
    public let period: Int
    public let multiplier: Double
    public var parameters: IndicatorParameters { .boll(period: period, multiplier: multiplier) }

    public init(period: Int = 20, multiplier: Double = 2.0) {
        precondition(period > 1, "BOLL period must be > 1")
        self.period = period
        self.multiplier = multiplier
    }

    public func calculate(models: [Input]) -> [BOLLIndicatorResult] {
        guard !models.isEmpty else { return [] }
        var results = [BOLLIndicatorResult](repeating: BOLLIndicatorResult(value: nil), count: models.count)
        var windowSum: Double = 0
        // 滑动窗口内的值，用于方差计算
        var window = [Double]()
        window.reserveCapacity(period)

        for i in models.indices {
            let close = models[i].close
            window.append(close)
            windowSum += close

            if window.count > period {
                windowSum -= window.removeFirst()
            }

            guard window.count == period else { continue }

            let mb = windowSum / Double(period)
            // 总体标准差（与主流行情软件一致）
            let variance = window.reduce(0.0) { $0 + ($1 - mb) * ($1 - mb) } / Double(period)
            let md = variance.squareRoot()

            results[i] = BOLLIndicatorResult(value: BOLLResult(
                mb: mb,
                upper: mb + multiplier * md,
                lower: mb - multiplier * md
            ))
        }
        return results
    }
}
