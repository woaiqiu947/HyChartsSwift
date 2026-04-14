Pod::Spec.new do |s|

  s.name         = 'HyChartsSwift'
  s.version      = '1.0.0'
  s.summary      = 'A high-performance Swift K-line & time-sharing chart library for iOS.'

  s.description  = <<-DESC
    HyChartsSwift is a Swift rewrite of the HyCharts OC library(https://github.com/hydreamit/HyCharts), featuring:
    - Candlestick (K-line) chart with pan & pinch-zoom gestures
    - Time-sharing (分时) chart with average-price line
    - Main-chart overlays: SMA, EMA, Bollinger Bands
    - Auxiliary panel (switchable): Volume, MACD, KDJ, RSI
    - Period separators for daily / weekly / monthly / yearly K-lines
    - Protocol-oriented data layer — bring your own model
    - CALayer rendering pipeline for smooth 60 fps performance
    - Thread-safe indicator computation via Swift actor
  DESC

  s.homepage     = 'https://github.com/woaiqiu947/HyChartsSwift'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'woaiqiu947' => '' }

  s.source       = {
    :git => 'https://github.com/woaiqiu947/HyChartsSwift.git',
    :tag => s.version.to_s
  }

  s.ios.deployment_target = '15.0'
  s.swift_version         = '5.9'

  s.source_files = 'Sources/HyChartsSwift/**/*.swift'

  # 无第三方依赖
end
