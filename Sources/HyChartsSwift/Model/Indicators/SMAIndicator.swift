import Foundation

// MARK: - SMA 结果

public struct SMAResult: IndicatorResult {
    /// nil 表示数据不足（不足 period 根）
    public let value: Double?
}

// MARK: - SMA 指标

public struct SMAIndicator<Input: KLineModel>: Indicator {
    public let period: Int
    public var parameters: IndicatorParameters { .sma(period: period) }

    public init(period: Int) {
        precondition(period > 0, "SMA period must be > 0")
        self.period = period
    }

    public func calculate(models: [Input]) -> [SMAResult] {
        guard !models.isEmpty else { return [] }
        var results = [SMAResult](repeating: SMAResult(value: nil), count: models.count)
        var windowSum: Double = 0

        for i in models.indices {
            windowSum += models[i].close
            if i >= period {
                windowSum -= models[i - period].close
            }
            if i >= period - 1 {
                results[i] = SMAResult(value: windowSum / Double(period))
            }
        }
        return results
    }

    /// 增量计算：新增 newModels 时，只需更新末尾部分
    public func calculateIncremental(existing: [SMAResult], newModels: [Input], allModels: [Input]) -> [SMAResult] {
        guard !newModels.isEmpty else { return existing }
        // 从新增起始点往前取 period 个做窗口，直接复用 calculate 末尾段
        let startIndex = existing.count
        var results = existing
        var windowSum: Double = 0

        // 重建起点窗口
        let windowStart = max(0, startIndex - period + 1)
        for i in windowStart..<startIndex {
            windowSum += allModels[i].close
        }

        for i in startIndex..<allModels.count {
            windowSum += allModels[i].close
            if i >= period {
                windowSum -= allModels[i - period].close
            }
            let result = i >= period - 1
                ? SMAResult(value: windowSum / Double(period))
                : SMAResult(value: nil)
            results.append(result)
        }
        return results
    }
}
