// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Latch",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: parsers, models, scoring, clamping. No UI, fully unit-testable.
        .target(name: "LatchCore"),
        .testTarget(name: "LatchCoreTests", dependencies: ["LatchCore"]),
    ]
)
