import SwiftUI
import HyChartsSwift

// MARK: - 图表类型

enum ChartDisplayType: String, CaseIterable, Equatable {
    case timeShare = "分时"
    case fiveDay   = "五日"
    case daily     = "日K"
    case weekly    = "周K"
    case monthly   = "月K"
    case yearly    = "年K"

    var isKLine: Bool {
        switch self {
        case .daily, .weekly, .monthly, .yearly: return true
        default: return false
        }
    }

    var chartPeriod: ChartPeriod {
        switch self {
        case .timeShare, .fiveDay: return .minute(1)
        case .daily:               return .daily
        case .weekly:              return .weekly
        case .monthly:             return .monthly
        case .yearly:              return .yearly
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    // MARK: 图表类型状态
    @State private var chartType: ChartDisplayType = .daily

    // MARK: K 线数据（各周期独立存储）
    @State private var dailyModels   = MockKLineData.generate(count: 500)
    @State private var weeklyModels  = MockKLineData.generateWeekly()
    @State private var monthlyModels = MockKLineData.generateMonthly()
    @State private var yearlyModels  = MockKLineData.generateYearly()

    // MARK: 分时数据
    @State private var intradayModels = MockTimeShareData.generateIntraday()
    @State private var fiveDayModels  = MockTimeShareData.generateFiveDay()

    // MARK: 主图技术线
    @State private var mainTag: String = "SMA"
    @State private var mainTechnical: MainTechnicalType = .sma(periods: [5, 10, 30])

    // MARK: 副图指标
    @State private var auxiliaryTag: String = "VOL"
    @State private var auxiliaryType: AuxiliaryType = .volume

    // MARK: - 计算属性

    private var klineConfig: KLineConfiguration {
        var c = KLineConfiguration()
        c.mainTechnical = mainTechnical
        c.auxiliaryType = auxiliaryType
        c.chartPeriod   = chartType.chartPeriod
        return c
    }

    private var currentKLineModels: [MockKLine] {
        switch chartType {
        case .daily:   return dailyModels
        case .weekly:  return weeklyModels
        case .monthly: return monthlyModels
        case .yearly:  return yearlyModels
        default:       return dailyModels
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ── 周期选择栏 ──
                HStack(spacing: 0) {
                    ForEach(ChartDisplayType.allCases, id: \.rawValue) { type in
                        SelectButton(title: type.rawValue, tag: type.rawValue,
                                     selected: chartType.rawValue) {
                            chartType = type
                        }
                    }
                    Spacer()
                }
                .frame(height: 36)
                .padding(.horizontal, 8)
                .background(Color(UIColor.systemGroupedBackground))

                Divider()

                // ── 图表主体 ──
                Group {
                    if chartType.isKLine {
                        KLineChartViewRepresentable(
                            models: currentKLineModels,
                            configuration: klineConfig
                        )
                    } else if chartType == .fiveDay {
                        TimeShareChartViewRepresentable(
                            models: fiveDayModels, dayCount: 5
                        )
                    } else {
                        TimeShareChartViewRepresentable(
                            models: intradayModels, dayCount: 1
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 460)
                .background(Color.white)
                // 切换图表类型时强制重建 UIView
                .id(chartType)

                Divider()

                // ── 主图技术线（仅 K 线模式）──
                if chartType.isKLine {
                    HStack(spacing: 0) {
                        SelectButton(title: "SMA",  tag: "SMA",  selected: mainTag) {
                            mainTag = "SMA"; mainTechnical = .sma(periods: [5, 10, 30])
                        }
                        SelectButton(title: "EMA",  tag: "EMA",  selected: mainTag) {
                            mainTag = "EMA"; mainTechnical = .ema(periods: [5, 10, 30])
                        }
                        SelectButton(title: "BOLL", tag: "BOLL", selected: mainTag) {
                            mainTag = "BOLL"; mainTechnical = .boll(period: 20, multiplier: 2.0)
                        }
                        SelectButton(title: "无",   tag: "NONE", selected: mainTag) {
                            mainTag = "NONE"; mainTechnical = .none
                        }
                        Spacer()
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 8)
                    .background(Color(UIColor.systemGroupedBackground))

                    Divider()

                    // ── 副图指标（仅 K 线模式）──
                    HStack(spacing: 0) {
                        SelectButton(title: "VOL",  tag: "VOL",  selected: auxiliaryTag) {
                            auxiliaryTag = "VOL";  auxiliaryType = .volume
                        }
                        SelectButton(title: "MACD", tag: "MACD", selected: auxiliaryTag) {
                            auxiliaryTag = "MACD"; auxiliaryType = .macd()
                        }
                        SelectButton(title: "KDJ",  tag: "KDJ",  selected: auxiliaryTag) {
                            auxiliaryTag = "KDJ";  auxiliaryType = .kdj()
                        }
                        SelectButton(title: "RSI",  tag: "RSI",  selected: auxiliaryTag) {
                            auxiliaryTag = "RSI";  auxiliaryType = .rsi(periods: [6, 12, 24])
                        }
                        Spacer()
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 8)
                    .background(Color(UIColor.systemGroupedBackground))

                    Divider()
                }

                Spacer()
            }
            .navigationTitle("HyChartsSwift Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        switch chartType {
                        case .daily:     dailyModels   = MockKLineData.generate(count: 500)
                        case .weekly:    weeklyModels  = MockKLineData.generateWeekly()
                        case .monthly:   monthlyModels = MockKLineData.generateMonthly()
                        case .yearly:    yearlyModels  = MockKLineData.generateYearly()
                        case .timeShare: intradayModels = MockTimeShareData.generateIntraday()
                        case .fiveDay:   fiveDayModels  = MockTimeShareData.generateFiveDay()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 带选中状态的切换按钮

private struct SelectButton: View {
    let title: String
    let tag: String
    let selected: String
    let action: () -> Void

    private var isSelected: Bool { tag == selected }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .accentColor : Color(UIColor.secondaryLabel))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(isSelected ? .accentColor : .clear),
                    alignment: .bottom
                )
        }
        .animation(.none, value: isSelected)
    }
}

#Preview {
    ContentView()
}
