import SwiftUI
import HyChartsSwift

// MARK: - SwiftUI 包装

struct KLineChartViewRepresentable: UIViewRepresentable {

    let models: [MockKLine]
    let configuration: KLineConfiguration

    // MARK: Coordinator（检测数据是否真正变化，避免不必要的 reload）

    final class Coordinator {
        var loadedCount: Int = 0
        var loadedFirstLabel: String = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> KLineChartView {
        let view = KLineChartView()
        view.configuration = configuration
        view.load(ArrayDataSource(models))
        context.coordinator.loadedCount      = models.count
        context.coordinator.loadedFirstLabel = models.first?.xLabel ?? ""
        return view
    }

    func updateUIView(_ uiView: KLineChartView, context: Context) {
        uiView.configuration = configuration

        // 只有数据真正变化时才重新 load（避免配置切换时重置滚动位置）
        let coord = context.coordinator
        if models.count != coord.loadedCount ||
           (models.first?.xLabel ?? "") != coord.loadedFirstLabel {
            uiView.load(ArrayDataSource(models))
            coord.loadedCount      = models.count
            coord.loadedFirstLabel = models.first?.xLabel ?? ""
        }
    }
}
