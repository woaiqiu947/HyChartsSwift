import CoreGraphics

// MARK: - 坐标映射器
//
// 纯值类型，无副作用。
// 持有当前视图尺寸、滚动偏移、缩放比、Y 轴极值，
// 提供价格/成交量/索引 ↔ 像素 的双向转换。
//
// 渲染层（CALayer）和手势层只依赖这个 struct，
// 不直接持有 Store 或 View，彻底解耦。

public struct CoordinateMapper: Sendable {

    // MARK: - 布局参数

    /// 图表可视区域尺寸（不含轴标签）
    public let chartSize: CGSize

    /// 单根 K 线实体宽度（已含 scale）
    public let itemWidth: CGFloat

    /// K 线间距（已含 scale）
    public let itemSpacing: CGFloat

    /// 当前缩放倍数（1.0 = 默认）
    public let scale: CGFloat

    /// 滚动偏移（content offset x）
    public let offsetX: CGFloat

    /// 当前可见切片在全量 models 中的起始全局索引
    /// 用于将全局 absoluteX → 局部 renderModels 索引
    public let startIndex: Int

    // MARK: - Y 轴极值

    public let maxPrice:  Double
    public let minPrice:  Double
    public let maxVolume: Double
    public let minVolume: Double
    public let maxAuxiliary: Double
    public let minAuxiliary: Double

    // MARK: - 初始化

    public init(
        chartSize: CGSize,
        itemWidth: CGFloat,
        itemSpacing: CGFloat,
        scale: CGFloat,
        offsetX: CGFloat,
        startIndex: Int = 0,
        extremes: KLineExtremes
    ) {
        self.chartSize    = chartSize
        self.itemWidth    = itemWidth
        self.itemSpacing  = itemSpacing
        self.scale        = scale
        self.offsetX      = offsetX
        self.startIndex   = startIndex
        self.maxPrice     = extremes.maxPrice
        self.minPrice     = extremes.minPrice
        self.maxVolume    = extremes.maxVolume
        self.minVolume    = extremes.minVolume
        self.maxAuxiliary = extremes.maxAuxiliary
        self.minAuxiliary = extremes.minAuxiliary
    }

    // MARK: - 单根 K 线总占宽

    public var itemStride: CGFloat { itemWidth + itemSpacing }

    // MARK: - 内容总宽度（所有 K 线）

    public func contentWidth(count: Int) -> CGFloat {
        CGFloat(count) * itemStride
    }

    // MARK: - X 轴：索引 → 像素

    /// 返回第 index 根 K 线中心的绝对 X 坐标（content 坐标系）
    public func centerX(at index: Int) -> CGFloat {
        CGFloat(index) * itemStride + itemWidth * 0.5
    }

    /// 返回第 index 根 K 线中心在当前视图内的可见 X（已减去 offsetX）
    public func visibleCenterX(at index: Int) -> CGFloat {
        centerX(at: index) - offsetX
    }

    // MARK: - X 轴：像素 → 索引

    /// 将视图内像素 x（可见坐标）转换为 renderModels 中的局部索引
    /// - Returns: clamp 到 [0, count-1]
    public func index(forVisibleX x: CGFloat, count: Int) -> Int {
        let absoluteX = x + offsetX
        let globalRaw = Int(absoluteX / itemStride)
        let localRaw  = globalRaw - startIndex
        return max(0, min(count - 1, localRaw))
    }

    // MARK: - 可见区间

    /// 当前可见的 index 区间（两端各扩 1 根避免裁切）
    public func visibleRange(totalCount: Int) -> Range<Int> {
        let first = max(0, Int(offsetX / itemStride) - 1)
        let last  = min(totalCount, Int((offsetX + chartSize.width) / itemStride) + 2)
        return first..<last
    }

    // MARK: - Y 轴：价格 → 像素（主图）

    /// 价格映射到主图 Y（上=高价=小Y）
    public func priceY(_ price: Double, in chartHeight: CGFloat) -> CGFloat {
        guard maxPrice > minPrice else { return chartHeight * 0.5 }
        let ratio = CGFloat((price - minPrice) / (maxPrice - minPrice))
        return chartHeight * (1 - ratio)
    }

    // MARK: - Y 轴：像素 → 价格（手势反算）

    public func price(forY y: CGFloat, in chartHeight: CGFloat) -> Double {
        guard maxPrice > minPrice, chartHeight > 0 else { return minPrice }
        let ratio = Double(1 - y / chartHeight)
        return minPrice + ratio * (maxPrice - minPrice)
    }

    // MARK: - Y 轴：成交量 → 像素（成交量图）

    public func volumeY(_ volume: Double, in chartHeight: CGFloat) -> CGFloat {
        guard maxVolume > 0 else { return chartHeight }
        let ratio = CGFloat(volume / maxVolume)
        return chartHeight * (1 - ratio)
    }

    // MARK: - Y 轴：副图指标值 → 像素

    public func auxiliaryY(_ value: Double, in chartHeight: CGFloat) -> CGFloat {
        let range = maxAuxiliary - minAuxiliary
        guard range > 0 else { return chartHeight * 0.5 }
        let ratio = CGFloat((value - minAuxiliary) / range)
        return chartHeight * (1 - ratio)
    }

    // MARK: - 填充像素坐标到 KLineRenderModel

    /// 将可见 models 数组的像素坐标一次性写入（主图高度）
    public func fillCoordinates(
        into models: inout [KLineRenderModel],
        startIndex: Int,
        mainHeight: CGFloat,
        volumeHeight: CGFloat
    ) {
        for i in models.indices {
            let idx = startIndex + i
            models[i].centerX  = visibleCenterX(at: idx)
            models[i].highY    = priceY(models[i].high,   in: mainHeight)
            models[i].lowY     = priceY(models[i].low,    in: mainHeight)
            models[i].openY    = priceY(models[i].open,   in: mainHeight)
            models[i].closeY   = priceY(models[i].close,  in: mainHeight)
            models[i].volumeY  = volumeY(models[i].volume, in: volumeHeight)
        }
    }
}
