# HyChartsSwift

高性能、面向协议的 Swift K 线 & 分时图表库，适用于 iOS。  
基于 [HyCharts](https://github.com/hydreamit/HyCharts)（OC 版本）重写，融入了实际炒股项目中的开发经验。

[English](README.md) | 中文

---

<img src="Screenshots/kline_daily_kdj.png" alt="K线图+KDJ" width="320" />　<img src="Screenshots/timeshare.png" alt="分时图" width="320" />

---

## 功能特性

- **K 线图** — 蜡烛图，支持平移 & 双指缩放，周期分隔竖线
- **分时图** — 价格填充折线图 + 均价线，支持五日线模式
- **主图技术线** — SMA、EMA、布林带（可切换）
- **副图指标** — 成交量 / MACD / KDJ / RSI（可切换）
- **多周期支持** — 分时 / 日 K / 周 K / 月 K / 年 K
- **面向协议** — 实现 `KLineModel` 或 `TimeShareModel` 即可接入自己的数据模型
- **60 fps 渲染** — CALayer 管线，同色蜡烛合并为单条 CGPath
- **线程安全** — 技术指标计算通过 Swift `actor` 异步执行

---

## 运行环境

| | 最低要求 |
|---|---|
| iOS | 15.0 |
| Swift | 5.9 |
| Xcode | 15.0 |

---

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/yuanshipei/HyChartsSwift.git", from: "1.0.0")
]
```

或在 Xcode 中：**File → Add Package Dependencies** → 粘贴仓库地址。

### CocoaPods

```ruby
pod 'HyChartsSwift', '~> 1.0'
```

然后执行：

```bash
pod install
```

---

## 快速上手

### 1. 实现数据协议

```swift
import HyChartsSwift

struct MyKLine: KLineModel {
    var open:      Double
    var high:      Double
    var low:       Double
    var close:     Double
    var volume:    Double
    var xLabel:    String   // 显示在 X 轴的时间标签，如 "01-05"
    var timestamp: Date?    // 用于绘制周期分隔竖线，可选
}
```

### 2. 添加 K 线图

```swift
import HyChartsSwift

let chart = KLineChartView()
view.addSubview(chart)
chart.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 460)

// 配置
var config = KLineConfiguration()
config.mainTechnical = .ema(periods: [5, 10, 30])
config.auxiliaryType = .macd()
config.chartPeriod   = .daily
chart.configuration  = config

// 加载数据
chart.load(ArrayDataSource(myKLines))
```

### 3. 添加分时图

```swift
struct MyTick: TimeShareModel {
    var price:     Double
    var average:   Double?  // 均价线，可选
    var volume:    Double
    var xLabel:    String   // 如 "9:30"
    var timestamp: Date?
}

let tsChart = TimeShareChartView()
tsChart.load(myTicks, dayCount: 1)   // dayCount: 5 → 五日线
```

---

## 配置项说明

`KLineConfiguration` 是值类型，修改后重新赋给 `chart.configuration` 即可触发重绘。

```swift
var config = KLineConfiguration()

// 涨跌颜色
config.upColor   = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1) // 红涨
config.downColor = UIColor(red: 0.13, green: 0.69, blue: 0.30, alpha: 1) // 绿跌

// 布局比例
config.yAxisWidth           = 60    // Y 轴标签宽度
config.volumeHeightRatio    = 0.20  // 成交量区占总高比例
config.auxiliaryHeightRatio = 0.25  // 副图区占总高比例

// 指标选择
config.mainTechnical = .boll(period: 20, multiplier: 2.0)
config.auxiliaryType = .kdj()
config.chartPeriod   = .weekly

// 分时图颜色
config.timeShareLineColor    = .systemBlue
config.timeShareAvgLineColor = .systemYellow
```

### 主图技术线（MainTechnicalType）

```swift
.none
.sma(periods: [5, 10, 30])           // 简单移动平均
.ema(periods: [5, 10, 30])           // 指数移动平均
.boll(period: 20, multiplier: 2.0)   // 布林带
```

### 副图指标（AuxiliaryType）

```swift
.volume                              // 成交量
.macd(fast: 12, slow: 26, signal: 9) // MACD
.kdj(n: 9, m1: 3, m2: 3)            // KDJ
.rsi(periods: [6, 12, 24])           // RSI
```

### K 线周期（ChartPeriod）

```swift
.minute(1)   // 分时 / 五日线 — 竖线 = 每个交易日
.daily       // 日 K — 竖线 = 每月第一个交易日
.weekly      // 周 K — 竖线 = 每季度第一周
.monthly     // 月 K — 竖线 = 每年 1 月
.yearly      // 年 K — 竖线 = 每 5 年
```

---

## 实时行情更新

```swift
// 追加新 K 线（如 REST 轮询后追加）
chart.appendModels(newCandles)

// Tick 刷新 — 更新最后一根 K 线
chart.updateLastModel(latestCandle)
```

---

## 架构说明

```
KLineModel（你的数据）
    ↓  ArrayDataSource / 自定义 ChartDataSource
ChartDataStore (actor)         — 线程安全的数据存储 & 指标缓存
    ↓  async
CoordinateMapper（值类型）     — 价格 / 成交量 / 索引 ↔ 像素，无副作用
    ↓
CALayer 渲染管线
    ├── KLineMainLayer         — 蜡烛图 + SMA/EMA/BOLL 技术线
    ├── KLineVolumeLayer       — 成交量柱
    ├── KLineAuxiliaryLayer    — MACD / KDJ / RSI
    └── AxisLayer              — 网格线、价格标签、时间标签
```

---

## Demo

打开 `Demo/HyChartsDemoSwift.xcodeproj`，在模拟器或真机上运行即可查看全部功能演示。

---

## License

MIT © 2025 yuanshipei  
详见 [LICENSE](LICENSE)。

---

## 致谢

本库基于 [@hydreamit](https://github.com/hydreamit) 的 [HyCharts](https://github.com/hydreamit/HyCharts)（OC 版本）进行 Swift 重写，  
并结合港股 & 美股实际交易 App 开发经验进行了架构优化与功能扩展。
