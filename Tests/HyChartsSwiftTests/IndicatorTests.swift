import XCTest
@testable import HyChartsSwift

// MARK: - 测试用 K 线数据

private struct TestKLine: KLineModel {
    let open, high, low, close, volume: Double
    let xLabel: String
    init(_ close: Double, open: Double? = nil, high: Double? = nil, low: Double? = nil) {
        self.close  = close
        self.open   = open  ?? close
        self.high   = high  ?? close
        self.low    = low   ?? close
        self.volume = 1000
        self.xLabel = ""
    }
}

private func makeModels(_ closes: [Double]) -> [TestKLine] {
    closes.map { TestKLine($0) }
}

// MARK: - SMA Tests

final class SMAIndicatorTests: XCTestCase {

    func test_insufficientData_returnsNil() {
        let models = makeModels([10, 20])
        let sma = SMAIndicator<TestKLine>(period: 3)
        let results = sma.calculate(models: models)
        XCTAssertNil(results[0].value)
        XCTAssertNil(results[1].value)
    }

    func test_exactPeriod() {
        let models = makeModels([10, 20, 30])
        let sma = SMAIndicator<TestKLine>(period: 3)
        let results = sma.calculate(models: models)
        XCTAssertEqual(results[2].value, 20.0, accuracy: 1e-9)
    }

    func test_slidingWindow() {
        let models = makeModels([10, 20, 30, 40])
        let sma = SMAIndicator<TestKLine>(period: 3)
        let results = sma.calculate(models: models)
        XCTAssertNil(results[0].value)
        XCTAssertNil(results[1].value)
        XCTAssertEqual(results[2].value!, 20.0, accuracy: 1e-9)  // (10+20+30)/3
        XCTAssertEqual(results[3].value!, 30.0, accuracy: 1e-9)  // (20+30+40)/3
    }

    func test_incremental_matchesFull() {
        let initial = makeModels([10, 20, 30, 40])
        let added   = makeModels([50, 60])
        let all     = initial + added
        let sma     = SMAIndicator<TestKLine>(period: 3)

        let full        = sma.calculate(models: all)
        let existing    = sma.calculate(models: initial)
        let incremental = sma.calculateIncremental(existing: existing, newModels: added, allModels: all)

        XCTAssertEqual(incremental.count, full.count)
        for i in incremental.indices {
            XCTAssertEqual(incremental[i].value, full[i].value,
                           accuracy: 1e-9, "Mismatch at index \(i)")
        }
    }
}

// MARK: - EMA Tests

final class EMAIndicatorTests: XCTestCase {

    func test_firstValue_equalsFirstClose() {
        let models = makeModels([100])
        let ema = EMAIndicator<TestKLine>(period: 3)
        let results = ema.calculate(models: models)
        XCTAssertEqual(results[0].value!, 100.0, accuracy: 1e-9)
    }

    func test_knownValues() {
        // EMA(3): k = 2/(3+1) = 0.5
        // [10, 20, 30]
        // EMA[0] = 10
        // EMA[1] = 0.5*(20-10)+10 = 15
        // EMA[2] = 0.5*(30-15)+15 = 22.5
        let models = makeModels([10, 20, 30])
        let ema = EMAIndicator<TestKLine>(period: 3)
        let results = ema.calculate(models: models)
        XCTAssertEqual(results[0].value!, 10.0,  accuracy: 1e-9)
        XCTAssertEqual(results[1].value!, 15.0,  accuracy: 1e-9)
        XCTAssertEqual(results[2].value!, 22.5,  accuracy: 1e-9)
    }

    func test_incremental_matchesFull() {
        let initial = makeModels([10, 20, 30, 40, 50])
        let added   = makeModels([60, 70])
        let all     = initial + added
        let ema     = EMAIndicator<TestKLine>(period: 5)

        let full        = ema.calculate(models: all)
        let existing    = ema.calculate(models: initial)
        let incremental = ema.calculateIncremental(existing: existing, newModels: added, allModels: all)

        for i in incremental.indices {
            XCTAssertEqual(incremental[i].value!, full[i].value!, accuracy: 1e-9)
        }
    }
}

// MARK: - BOLL Tests

final class BOLLIndicatorTests: XCTestCase {

    func test_insufficientData_returnsNil() {
        let models = makeModels([10, 20])
        let boll = BOLLIndicator<TestKLine>(period: 3)
        let results = boll.calculate(models: models)
        XCTAssertNil(results[0].value)
        XCTAssertNil(results[1].value)
    }

    func test_uniformPrices_zeroBandwidth() {
        // 所有价格相同，std=0，上下轨等于中轨
        let models = makeModels([50, 50, 50, 50, 50])
        let boll = BOLLIndicator<TestKLine>(period: 5)
        let results = boll.calculate(models: models)
        let last = results.last!!.value!
        XCTAssertEqual(last.mb, 50.0, accuracy: 1e-9)
        XCTAssertEqual(last.upper, 50.0, accuracy: 1e-9)
        XCTAssertEqual(last.lower, 50.0, accuracy: 1e-9)
    }

    func test_upperGreaterThanLower() {
        let models = makeModels([10, 20, 15, 25, 18, 22, 30, 12, 28, 20])
        let boll = BOLLIndicator<TestKLine>(period: 5)
        let results = boll.calculate(models: models)
        for r in results.compactMap({ $0.value }) {
            XCTAssertGreaterThan(r.upper, r.lower)
            XCTAssertGreaterThan(r.mb, r.lower)
            XCTAssertLessThan(r.mb, r.upper)
        }
    }
}

// MARK: - MACD Tests

final class MACDIndicatorTests: XCTestCase {

    func test_resultCount_equalsInput() {
        let models = makeModels(Array(stride(from: 10.0, to: 50.0, by: 1.0)))
        let macd = MACDIndicator<TestKLine>()
        let results = macd.calculate(models: models)
        XCTAssertEqual(results.count, models.count)
    }

    func test_trendingUp_positiveDIF() {
        // 单调递增，EMA(fast) > EMA(slow) → DIF > 0
        let closes = stride(from: 1.0, through: 60.0, by: 1.0).map { $0 }
        let models = makeModels(closes)
        let macd = MACDIndicator<TestKLine>(fast: 12, slow: 26, signal: 9)
        let results = macd.calculate(models: models)
        let last = results.last!!.value!
        XCTAssertGreaterThan(last.dif, 0)
    }
}

// MARK: - KDJ Tests

final class KDJIndicatorTests: XCTestCase {

    func test_resultCount_equalsInput() {
        let models = makeModels(Array(repeating: 100.0, count: 20))
        let kdj = KDJIndicator<TestKLine>()
        let results = kdj.calculate(models: models)
        XCTAssertEqual(results.count, 20)
    }

    func test_uniformPrice_kAndDEqual50() {
        // 价格不变，high=low=close，RSV 无意义取 50，K/D 收敛到 50
        let closes = Array(repeating: 100.0, count: 30)
        var models = [TestKLine]()
        for c in closes {
            models.append(TestKLine(c, open: c, high: c, low: c))
        }
        let kdj = KDJIndicator<TestKLine>(n: 9, m1: 3, m2: 3)
        let results = kdj.calculate(models: models)
        let last = results.last!!.value!
        XCTAssertEqual(last.k, 50.0, accuracy: 1e-6)
        XCTAssertEqual(last.d, 50.0, accuracy: 1e-6)
    }

    func test_kAndD_within0to100() {
        let closes = [10.0, 12, 11, 15, 14, 13, 16, 18, 17, 20, 19, 21]
        let models = closes.map { TestKLine($0, open: $0 * 0.99, high: $0 * 1.01, low: $0 * 0.98) }
        let kdj = KDJIndicator<TestKLine>()
        let results = kdj.calculate(models: models)
        for r in results.compactMap({ $0.value }) {
            XCTAssertGreaterThanOrEqual(r.k, 0)
            XCTAssertLessThanOrEqual(r.k, 100)
            XCTAssertGreaterThanOrEqual(r.d, 0)
            XCTAssertLessThanOrEqual(r.d, 100)
        }
    }
}

// MARK: - RSI Tests

final class RSIIndicatorTests: XCTestCase {

    func test_resultCount_equalsInput() {
        let models = makeModels(Array(1...20).map { Double($0) })
        let rsi = RSIIndicator<TestKLine>(period: 6)
        let results = rsi.calculate(models: models)
        XCTAssertEqual(results.count, 20)
    }

    func test_monotonicallyIncreasing_rsiNear100() {
        // 单调递增，全是上涨，RSI 应趋近 100
        let closes = stride(from: 10.0, through: 60.0, by: 1.0).map { $0 }
        let models = makeModels(closes)
        let rsi = RSIIndicator<TestKLine>(period: 6)
        let results = rsi.calculate(models: models)
        let last = results.last!!.value!
        XCTAssertGreaterThan(last, 90)
    }

    func test_rsi_within0to100() {
        let closes = [10.0, 12, 11, 9, 8, 10, 13, 11, 14, 12, 15]
        let models = makeModels(closes)
        let rsi = RSIIndicator<TestKLine>(period: 6)
        let results = rsi.calculate(models: models)
        for r in results.compactMap({ $0.value }) {
            XCTAssertGreaterThanOrEqual(r, 0)
            XCTAssertLessThanOrEqual(r, 100)
        }
    }
}

// MARK: - ChartDataStore Tests

final class ChartDataStoreTests: XCTestCase {

    func test_load_storesCorrectCount() async {
        let store = ChartDataStore()
        let source = ArrayDataSource(makeModels(Array(1...10).map { Double($0) }))
        await store.load(source)
        let count = await store.models.count
        XCTAssertEqual(count, 10)
    }

    func test_setVisibleRange_clamps() async {
        let store = ChartDataStore()
        let source = ArrayDataSource(makeModels([1, 2, 3, 4, 5]))
        await store.load(source)
        await store.setVisibleRange(0..<100)
        let range = await store.visibleRange
        XCTAssertEqual(range, 0..<5)
    }

    func test_smaSeries_cachedOnSecondCall() async {
        let store = ChartDataStore()
        let source = ArrayDataSource(makeModels(Array(1...20).map { Double($0) }))
        await store.load(source)
        let r1 = await store.smaSeries(period: 5)
        let r2 = await store.smaSeries(period: 5)
        XCTAssertEqual(r1.count, r2.count)
    }
}
