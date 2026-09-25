// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Fnord",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Fnord", path: "Sources", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
