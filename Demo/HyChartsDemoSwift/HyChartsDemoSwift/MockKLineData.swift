import Foundation
import HyChartsSwift

// MARK: - Mock K 线数据模型

struct MockKLine: KLineModel {
    let open:      Double
    let high:      Double
    let low:       Double
    let close:     Double
    let volume:    Double
    let xLabel:    String
    let timestamp: Date?
}

// MARK: - K 线数据生成器

enum MockKLineData {

    // MARK: - 公共入口

    /// 日 K（每根 = 1 天）
    static func generate(count: Int = 500) -> [MockKLine] {
        make(count: count, advanceDays: 1, labelFormat: "MM-dd", startPrice: 100)
    }

    /// 周 K（每根 = 7 天）
    static func generateWeekly(count: Int = 260) -> [MockKLine] {
        make(count: count, advanceDays: 7, labelFormat: "yy/MM/dd", startPrice: 100)
    }

    /// 月 K（每根 = 30 天）
    static func generateMonthly(count: Int = 120) -> [MockKLine] {
        make(count: count, advanceDays: 30, labelFormat: "yy/MM", startPrice: 100)
    }

    /// 年 K（每根 = 365 天）
    static func generateYearly(count: Int = 30) -> [MockKLine] {
        make(count: count, advanceDays: 365, labelFormat: "yyyy", startPrice: 100)
    }

    // MARK: - 内部通用生成

    private static func make(
        count: Int,
        advanceDays: Int,
        labelFormat: String,
        startPrice: Double
    ) -> [MockKLine] {
        var result: [MockKLine] = []
        var basePrice = startPrice
        let calendar  = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = labelFormat

        // 从 count 个周期前开始，以便最后一根对应"当前"
        var date = calendar.date(
            byAdding: .day,
            value: -(count * advanceDays),
            to: Date()
        ) ?? Date()

        for _ in 0..<count {
            let change   = basePrice * Double.random(in: -0.03...0.03)
            let open     = basePrice
            let close    = max(1, basePrice + change)
            let highDiff = abs(open - close) * Double.random(in: 0.1...0.6) + Double.random(in: 0...1)
            let lowDiff  = abs(open - close) * Double.random(in: 0.1...0.6) + Double.random(in: 0...1)
            let high     = max(open, close) + highDiff
            let low      = min(open, close) - lowDiff
            let volume   = Double.random(in: 50_000...500_000)

            result.append(MockKLine(
                open: open, high: high, low: max(0.1, low),
                close: close, volume: volume,
                xLabel: formatter.string(from: date),
                timestamp: date
            ))

            basePrice = close
            date = calendar.date(byAdding: .day, value: advanceDays, to: date) ?? date
        }
        return result
    }
}
