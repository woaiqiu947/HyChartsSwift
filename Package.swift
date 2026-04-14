// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyChartsSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "HyChartsSwift", targets: ["HyChartsSwift"])
    ],
    targets: [
        .target(
            name: "HyChartsSwift",
            path: "Sources/HyChartsSwift"
        ),
        .testTarget(
            name: "HyChartsSwiftTests",
            dependencies: ["HyChartsSwift"],
            path: "Tests/HyChartsSwiftTests"
        )
    ]
)
