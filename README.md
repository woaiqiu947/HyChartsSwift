# HyChartsSwift

A high-performance, protocol-oriented Swift K-line & time-sharing chart library for iOS.  
Rewritten from [HyCharts](https://github.com/hydreamit/HyCharts) (OC version), drawing on real trading app experience.

English | [中文](README_CN.md)

---

<img src="Screenshots/kline_daily_kdj.png" alt="K-line chart" width="320" />　<img src="Screenshots/timeshare.png" alt="Time-sharing chart" width="320" />

---

## Features

- **K-line chart** — candlesticks with pan & pinch-zoom, period separator lines
- **Time-sharing chart** — filled area chart with average-price line, 5-day view
- **Main-chart overlays** — SMA, EMA, Bollinger Bands (switchable)
- **Auxiliary panel** — Volume / MACD / KDJ / RSI (switchable)
- **Period support** — minute / daily / weekly / monthly / yearly K-lines
- **Protocol-oriented** — implement `KLineModel` or `TimeShareModel` on your own data struct
- **60 fps rendering** — CALayer pipeline, merged CGPath per color group
- **Thread-safe** — indicator computation via Swift `actor`

---

## Requirements

| | Minimum |
|---|---|
| iOS | 15.0 |
| Swift | 5.9 |
| Xcode | 15.0 |

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yuanshipei/HyChartsSwift.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the repo URL.

### CocoaPods

```ruby
pod 'HyChartsSwift', '~> 1.0'
```

Then run:

```bash
pod install
```

---

## Quick Start

### 1. Implement the data protocol

```swift
import HyChartsSwift

struct MyKLine: KLineModel {
    var open:      Double
    var high:      Double
    var low:       Double
    var close:     Double
    var volume:    Double
    var xLabel:    String   // e.g. "01-05"
    var timestamp: Date?    // for period separator lines
}
```

### 2. Add the chart view

```swift
import HyChartsSwift

let chart = KLineChartView()
view.addSubview(chart)
chart.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 460)

// Configure
var config = KLineConfiguration()
config.mainTechnical = .ema(periods: [5, 10, 30])
config.auxiliaryType = .macd()
config.chartPeriod   = .daily
chart.configuration  = config

// Load data
chart.load(ArrayDataSource(myKLines))
```

### 3. Time-sharing chart

```swift
struct MyTick: TimeShareModel {
    var price:     Double
    var average:   Double?  // average price line
    var volume:    Double
    var xLabel:    String   // e.g. "9:30"
    var timestamp: Date?
}

let tsChart = TimeShareChartView()
tsChart.load(myTicks, dayCount: 1)   // dayCount: 5 for 5-day view
```

---

## Configuration

`KLineConfiguration` is a value type — mutate it and assign back to trigger a redraw.

```swift
var config = KLineConfiguration()

// Colors
config.upColor   = UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1)
config.downColor = UIColor(red: 0.13, green: 0.69, blue: 0.30, alpha: 1)

// Layout
config.yAxisWidth           = 60
config.volumeHeightRatio    = 0.20
config.auxiliaryHeightRatio = 0.25

// Indicators
config.mainTechnical = .boll(period: 20, multiplier: 2.0)
config.auxiliaryType = .kdj()
config.chartPeriod   = .weekly

// Time-sharing colors
config.timeShareLineColor    = .systemBlue
config.timeShareAvgLineColor = .systemYellow
```

### MainTechnicalType

```swift
.none
.sma(periods: [5, 10, 30])
.ema(periods: [5, 10, 30])
.boll(period: 20, multiplier: 2.0)
```

### AuxiliaryType

```swift
.volume
.macd(fast: 12, slow: 26, signal: 9)
.kdj(n: 9, m1: 3, m2: 3)
.rsi(periods: [6, 12, 24])
```

### ChartPeriod

```swift
.minute(1)   // intraday — separator = each trading day
.daily       // separator = first trading day of each month
.weekly      // separator = first week of each quarter
.monthly     // separator = January of each year
.yearly      // separator = every 5 years
```

---

## Real-time Updates

```swift
// Append new candles (e.g. after a REST poll)
chart.appendModels(newCandles)

// Tick update — update the last candle in place
chart.updateLastModel(latestCandle)
```

---

## Architecture

### Data Flow

```
Your Model (KLineModel / TimeShareModel)
    ↓  ArrayDataSource / custom ChartDataSource
ChartDataStore (actor)         — thread-safe storage & incremental indicator cache
    ↓  async/await
CoordinateMapper (value type)  — price / volume / index ↔ pixel, zero side effects
    ↓
CALayer rendering pipeline
    ├── KLineMainLayer         — candles + SMA / EMA / BOLL overlay lines
    ├── KLineVolumeLayer       — volume bars (main-chart inline or auxiliary slot)
    ├── KLineAuxiliaryLayer    — MACD / KDJ / RSI / Volume (switchable panel)
    ├── AxisLayer              — horizontal grid, Y-axis price labels, X-axis time labels
    └── KLineCursor            — crosshair overlay (tap / long-press)
```

### Class Reference

#### Protocols & Enums

| Type | Description |
|---|---|
| `KLineModel` | Data protocol for K-line candles. Requires OHLCV + `xLabel`. `timestamp` optional, used for period separator lines. |
| `TimeShareModel` | Data protocol for intraday ticks. Requires `price`, `volume`, `xLabel`. `average` and `timestamp` optional. |
| `ChartDataSource` | Generic data-feeding protocol. `ArrayDataSource<M>` is the built-in convenience wrapper. |
| `Indicator` | Protocol for technical indicator calculators. Supports both full and incremental computation. |
| `KLineConfiguration` | Value-type config struct. Assign to `chart.configuration` to trigger a redraw. |
| `MainTechnicalType` | Enum selecting the main-chart overlay: `.none` / `.sma` / `.ema` / `.boll`. |
| `AuxiliaryType` | Enum selecting the auxiliary panel: `.volume` / `.macd` / `.kdj` / `.rsi`. |
| `ChartPeriod` | Enum controlling vertical separator line rules: `.minute` / `.daily` / `.weekly` / `.monthly` / `.yearly`. |

#### Data & Computation

| Type | Description |
|---|---|
| `ChartDataStore` | Swift `actor`. Holds the full `[KLineRenderModel]` array and all indicator caches. All reads/writes are serialised. Exposes async methods: `smaSeries`, `emaSeries`, `bollSeries`, `macdSeries`, `kdjSeries`, `rsiSeries`. |
| `KLineRenderModel` | Internal value type. Mirrors `KLineModel` fields plus pixel coordinates (`centerX`, `highY`, `lowY`, `openY`, `closeY`, `volumeY`) filled in by `CoordinateMapper`. |
| `CoordinateMapper` | Pure `Sendable` value type. Holds chart size, scale, scroll offset, and price/volume extremes. Provides bidirectional transforms and `fillCoordinates(into:startIndex:)`. |
| `SMAIndicator` | Simple Moving Average. O(n) sliding-window incremental update. |
| `EMAIndicator` | Exponential Moving Average. O(k) true incremental update for new bars. |
| `BOLLIndicator` | Bollinger Bands (mid / upper / lower). Based on SMA + standard deviation. |
| `MACDIndicator` | MACD histogram + DIF + DEM signal line. |
| `KDJIndicator` | KDJ stochastic oscillator (K / D / J lines). |
| `RSIIndicator` | Relative Strength Index, supports multiple periods simultaneously. |

#### Rendering Layers

| Type | Description |
|---|---|
| `KLineMainLayer` | `CALayer` subclass. Draws all up-candles as a single merged `CGPath`, down-candles as another — one `CAShapeLayer` fill per color group for maximum performance. Also draws the latest-price dashed line and SMA/EMA/BOLL overlay lines. |
| `KLineVolumeLayer` | `CALayer` subclass. Renders volume bars in the volume sub-panel with the same merged-path strategy. Supports an optional MA line series. |
| `KLineAuxiliaryLayer` | `CALayer` subclass. Renders whichever `AuxiliaryRenderData` is active: MACD bars + DIF/DEM lines, KDJ three-line, RSI multi-line, or volume bars. Includes a period-separator sub-layer. |
| `AxisLayer` | `CALayer` subclass. Draws horizontal grid lines (dashed), Y-axis price labels, X-axis time labels, and vertical period-separator lines. Driven purely by `AxisData` — no Store dependency. |
| `TimeShareMainLayer` | `CALayer` subclass. Draws the filled price-area, price line, average-price dashed line, and day-boundary separator lines for the 5-day view. |
| `TimeShareVolumeLayer` | `CALayer` subclass. Draws per-tick volume bars coloured by price direction (up / down / flat). |
| `KLineCursor` | `CALayer` subclass. Crosshair overlay activated by tap or long-press. Renders a vertical line, horizontal price line, and label bubbles for the selected candle. |

#### Views

| Type | Description |
|---|---|
| `KLineChartView` | Main public `UIView`. Three sub-panels: main chart (candles + overlays), volume, auxiliary. Handles `UIPanGestureRecognizer` (scroll), `UIPinchGestureRecognizer` (zoom with anchor-index preservation), tap/long-press (crosshair). Drives the full async render pipeline via `rebuildRenderModels()`. |
| `TimeShareChartView` | Public `UIView` for intraday / 5-day charts. Two sub-panels: price area + volume. No scroll/zoom — all ticks are laid out proportionally across the full width. `load(_:dayCount:)` accepts any `TimeShareModel` conformance. |

---

## Demo

Open `Demo/HyChartsDemoSwift.xcodeproj` and run on a simulator or device.  
The demo covers all chart types (分时 / 五日 / 日K / 周K / 月K / 年K) with switchable overlays and indicators.

---

## License

MIT © 2025 yuanshipei  
See [LICENSE](LICENSE) for details.

---

## Acknowledgements

This library is a Swift rewrite of [HyCharts](https://github.com/hydreamit/HyCharts)  
by [@hydreamit](https://github.com/hydreamit), with additional features and architecture  
improvements based on real-world trading app experience for HK & US markets.

Architecture design, Swift rewrite, and documentation assisted by [Claude Code](https://claude.ai/code) (Anthropic).
