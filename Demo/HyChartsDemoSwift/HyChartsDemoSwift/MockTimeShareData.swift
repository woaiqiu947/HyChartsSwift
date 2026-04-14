import Foundation
import HyChartsSwift

// MARK: - 分时数据模型

struct MockTimeShare: TimeShareModel {
    let price:     Double
    let average:   Double?
    let volume:    Double
    let xLabel:    String
    let timestamp: Date?
}

// MARK: - 分时数据生成器

enum MockTimeShareData {

    // MARK: - 公共入口

    /// 单日分时（240 个点：9:30-11:30 + 13:00-15:00）
    static func generateIntraday(basePrice: Double = 100.0) -> [MockTimeShare] {
        generateDays(count: 1, basePrice: basePrice, endingAt: Date())
    }

    /// 五日分时（5 × 240 = 1200 个点）
    static func generateFiveDay(basePrice: Double = 100.0) -> [MockTimeShare] {
        generateDays(count: 5, basePrice: basePrice, endingAt: Date())
    }

    // MARK: - 内部：多日生成

    private static func generateDays(count: Int, basePrice: Double, endingAt end: Date) -> [MockTimeShare] {
        var all: [MockTimeShare] = []
        let calendar = Calendar.current
        var price = basePrice

        // 往前推 count-1 个交易日
        for dayOffset in (-(count - 1))...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: end) else { continue }
            let session = generateSession(basePrice: price, date: date)
            price = session.last?.price ?? price
            all.append(contentsOf: session)
        }
        return all
    }

    // MARK: - 内部：单个交易日（上午 9:30-11:30 + 下午 13:00-15:00）

    private static func generateSession(basePrice: Double, date: Date) -> [MockTimeShare] {
        let calendar = Calendar.current
        var comps    = calendar.dateComponents([.year, .month, .day], from: date)
        var result: [MockTimeShare] = []
        var price      = basePrice
        var cumVolume  = 0.0
        var cumAmount  = 0.0

        func addMinute(_ ts: Date, _ label: String) {
            let change = price * Double.random(in: -0.004...0.004)
            price      = max(0.1, price + change)
            let vol    = Double.random(in: 1_000...15_000)
            cumVolume += vol
            cumAmount += price * vol
            let avg   = cumVolume > 0 ? cumAmount / cumVolume : price
            result.append(MockTimeShare(price: price, average: avg, volume: vol,
                                        xLabel: label, timestamp: ts))
        }

        // 上午 9:30 ~ 11:30（120 分钟）
        comps.hour = 9; comps.minute = 30; comps.second = 0
        if let start = calendar.date(from: comps) {
            for m in 0..<120 {
                if let ts = calendar.date(byAdding: .minute, value: m, to: start) {
                    let c = calendar.dateComponents([.hour, .minute], from: ts)
                    addMinute(ts, String(format: "%d:%02d", c.hour!, c.minute!))
                }
            }
        }

        // 下午 13:00 ~ 15:00（120 分钟）
        comps.hour = 13; comps.minute = 0
        if let start = calendar.date(from: comps) {
            for m in 0..<120 {
                if let ts = calendar.date(byAdding: .minute, value: m, to: start) {
                    let c = calendar.dateComponents([.hour, .minute], from: ts)
                    addMinute(ts, String(format: "%d:%02d", c.hour!, c.minute!))
                }
            }
        }

        return result
    }
}
