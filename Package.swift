// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Latch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Latch", targets: ["Latch"]),
    ],
    targets: [
        // Pure logic: parsers, models, scoring, clamping. No UI, fully unit-testable.
        .target(name: "LatchCore"),
        // The menu bar app: EventKit service, FSM engine, SwiftUI/AppKit UI.
        .executableTarget(name: "Latch", dependencies: ["LatchCore"]),
        .testTarget(name: "LatchCoreTests", dependencies: ["LatchCore"]),
    ]
)
