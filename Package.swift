// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskMetrics",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DiskMetrics", targets: ["DiskMetrics"])],
    targets: [
        .target(name: "StorageProbe", publicHeadersPath: "include"),
        .executableTarget(name: "DiskMetrics", dependencies: ["StorageProbe"]),
        .testTarget(name: "DiskMetricsTests", dependencies: ["DiskMetrics"])
    ]
)
