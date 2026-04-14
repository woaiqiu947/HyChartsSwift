import SwiftUI
import HyChartsSwift

// MARK: - SwiftUI 包装

struct TimeShareChartViewRepresentable: UIViewRepresentable {

    let models:   [MockTimeShare]
    let dayCount: Int

    func makeUIView(context: Context) -> TimeShareChartView {
        let view = TimeShareChartView()
        view.load(models, dayCount: dayCount)
        return view
    }

    func updateUIView(_ uiView: TimeShareChartView, context: Context) {
        uiView.load(models, dayCount: dayCount)
    }
}
