import Foundation

// MARK: - 图表数据仓库

/// 线程安全的数据中心，所有读写均在 actor 内部串行执行
/// 负责：
/// 1. 持有原始 KLineRenderModel 数组
/// 2. 管理可见区间（滚动/缩放时更新）
/// 3. 协调技术指标的（增量）计算
/// 4. 计算极值（Y 轴范围）
public actor ChartDataStore {

    // MARK: - 存储

    /// 所有已加载的渲染模型
    private(set) var models: [KLineRenderModel] = []

    /// 当前可见区间（index 范围）
    private(set) var visibleRange: Range<Int> = 0..<0

    /// 极值，由 recalculateExtremes 更新
    private(set) var extremes: KLineExtremes = .zero

    // MARK: - 指标缓存
    // 每种指标参数对应一个结果数组，与 models 等长

    private var smaCache:  [Int:    [SMAResult]]            = [:]   // key: period
    private var emaCache:  [Int:    [EMAResult]]            = [:]
    private var bollCache: [Int:    [BOLLIndicatorResult]]  = [:]
    private var macdCache: MACDKey? = nil
    private var macdResult:[MACDIndicatorResult]            = []
    private var kdjCache:  KDJKey?  = nil
    private var kdjResult: [KDJIndicatorResult]             = []
    private var rsiCache:  [Int:    [RSIIndicatorResult]]   = [:]

    private struct MACDKey: Equatable { let fast, slow, signal: Int }
    private struct KDJKey:  Equatable { let n, m1, m2: Int }

    // MARK: - 数据加载

    /// 全量加载（替换全部数据）
    public func load<M: KLineModel>(_ source: some ChartDataSource<M>) {
        models = (0..<source.count).map { KLineRenderModel(source.model(at: $0)) }
        clearIndicatorCache()
    }

    /// 追加新数据（实时行情推送）
    public func append<M: KLineModel>(newModels: [M]) {
        let newRender = newModels.map { KLineRenderModel($0) }
        models.append(contentsOf: newRender)
        // 指标增量计算由各指标方法按需触发，此处只标记 cache 失效
        // 已有缓存保留，incremental 路径延伸
    }

    /// 更新最后一根 K 线（tick 刷新）
    public func updateLast<M: KLineModel>(_ model: M) {
        guard !models.isEmpty else { return }
        models[models.count - 1] = KLineRenderModel(model)
        invalidateLastIndicators()
    }

    // MARK: - 可见区间

    public func setVisibleRange(_ range: Range<Int>) {
        let clamped = range.clamped(to: 0..<max(models.count, 1))
        visibleRange = clamped
        recalculateExtremes()
    }

    public var visibleModels: [KLineRenderModel] {
        guard !visibleRange.isEmpty, visibleRange.upperBound <= models.count else { return [] }
        return Array(models[visibleRange])
    }

    // MARK: - 技术指标（主图）

    public func smaSeries(period: Int) -> [SMAResult] {
        if let cached = smaCache[period] { return cached }
        let indicator = SMAIndicator<_AnyKLineModel>(period: period)
        let result = indicator.calculate(models: _proxies())
        smaCache[period] = result
        return result
    }

    public func emaSeries(period: Int) -> [EMAResult] {
        if let cached = emaCache[period] { return cached }
        let indicator = EMAIndicator<_AnyKLineModel>(period: period)
        let result = indicator.calculate(models: _proxies())
        emaCache[period] = result
        return result
    }

    public func bollSeries(period: Int, multiplier: Double = 2.0) -> [BOLLIndicatorResult] {
        if let cached = bollCache[period] { return cached }
        let indicator = BOLLIndicator<_AnyKLineModel>(period: period, multiplier: multiplier)
        let result = indicator.calculate(models: _proxies())
        bollCache[period] = result
        return result
    }

    // MARK: - 技术指标（副图）

    public func macdSeries(fast: Int = 12, slow: Int = 26, signal: Int = 9) -> [MACDIndicatorResult] {
        let key = MACDKey(fast: fast, slow: slow, signal: signal)
        if macdCache == key { return macdResult }
        let indicator = MACDIndicator<_AnyKLineModel>(fast: fast, slow: slow, signal: signal)
        macdResult = indicator.calculate(models: _proxies())
        macdCache = key
        return macdResult
    }

    public func kdjSeries(n: Int = 9, m1: Int = 3, m2: Int = 3) -> [KDJIndicatorResult] {
        let key = KDJKey(n: n, m1: m1, m2: m2)
        if kdjCache == key { return kdjResult }
        let indicator = KDJIndicator<_AnyKLineModel>(n: n, m1: m1, m2: m2)
        kdjResult = indicator.calculate(models: _proxies())
        kdjCache = key
        return kdjResult
    }

    public func rsiSeries(period: Int) -> [RSIIndicatorResult] {
        if let cached = rsiCache[period] { return cached }
        let indicator = RSIIndicator<_AnyKLineModel>(period: period)
        let result = indicator.calculate(models: _proxies())
        rsiCache[period] = result
        return result
    }

    // MARK: - 极值计算

    private func recalculateExtremes() {
        guard !visibleRange.isEmpty, visibleRange.upperBound <= models.count else {
            extremes = .zero
            return
        }
        let visible = models[visibleRange]
        let maxPrice  = visible.map(\.high).max() ?? 0
        let minPrice  = visible.map(\.low).min() ?? 0
        let maxVolume = visible.map(\.volume).max() ?? 0
        let minVolume: Double = 0
        // 副图极值需根据当前指标类型来定，暂用 0
        extremes = KLineExtremes(
            maxPrice: maxPrice, minPrice: minPrice,
            maxVolume: maxVolume, minVolume: minVolume,
            maxAuxiliary: 0, minAuxiliary: 0
        )
    }

    // MARK: - 缓存管理

    private func clearIndicatorCache() {
        smaCache.removeAll()
        emaCache.removeAll()
        bollCache.removeAll()
        macdCache = nil
        macdResult = []
        kdjCache = nil
        kdjResult = []
        rsiCache.removeAll()
    }

    private func invalidateLastIndicators() {
        // tick 刷新只影响最后一根，重置全量 cache，下次按需重算
        // 后续可优化为只回退最后一个元素
        clearIndicatorCache()
    }

    // MARK: - 内部代理（避免 any 进入指标计算热路径）

    /// 用轻量值类型包装 KLineRenderModel，满足 KLineModel 协议供指标使用
    private func _proxies() -> [_AnyKLineModel] {
        models.map { _AnyKLineModel($0) }
    }
}

// MARK: - 内部协议代理（仅用于指标计算，不对外暴露）

struct _AnyKLineModel: KLineModel {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let xLabel: String

    init(_ m: KLineRenderModel) {
        open = m.open; high = m.high; low = m.low
        close = m.close; volume = m.volume; xLabel = m.xLabel
    }
}
