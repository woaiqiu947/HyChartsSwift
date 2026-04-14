import Foundation

// MARK: - 数据供给协议

/// 图表数据源，外部实现，泛型在边界处消除 any 开销
public protocol ChartDataSource<Model>: AnyObject {
    associatedtype Model: ChartModel
    var count: Int { get }
    func model(at index: Int) -> Model
}

// MARK: - K 线数据源协议

public protocol KLineDataSource: ChartDataSource where Model: KLineModel {
    /// 价格小数位数
    var priceScale: Int { get }
    /// 成交量小数位数
    var volumeScale: Int { get }
}

public extension KLineDataSource {
    var priceScale: Int { 2 }
    var volumeScale: Int { 0 }
}

// MARK: - 便捷包装：数组直接作为数据源

public final class ArrayDataSource<M: KLineModel>: KLineDataSource {
    public typealias Model = M
    private let items: [M]
    public let priceScale: Int
    public let volumeScale: Int

    public init(_ items: [M], priceScale: Int = 2, volumeScale: Int = 0) {
        self.items = items
        self.priceScale = priceScale
        self.volumeScale = volumeScale
    }

    public var count: Int { items.count }
    public func model(at index: Int) -> M { items[index] }
}
