import XCTest
@testable import LatchCore

final class ShutterLayoutTests: XCTestCase {
    func testIdleIsFullyOpen() {
        let idle = ShutterLayout(phase: .idle)
        XCTAssertEqual(idle.gap, ShutterLayout.maxGap)
        XCTAssertEqual(idle.notchCount, 0)
    }

    func testBracketsCloseMonotonically() {
        let gaps = (0...10).reversed().map { ShutterLayout(phase: .running, remainingFraction: Double($0) / 10).gap }
        XCTAssertEqual(gaps.first, ShutterLayout.maxGap)
        XCTAssertEqual(gaps.last, ShutterLayout.minGap)
        XCTAssertEqual(gaps, gaps.sorted(by: >))
    }

    func testOvertimeNotchesGrowAndCap() {
        XCTAssertEqual(ShutterLayout(phase: .overtime, overtimeSeconds: 5).notchCount, 1)
        XCTAssertEqual(ShutterLayout(phase: .overtime, overtimeSeconds: 125).notchCount, 2)
        XCTAssertEqual(ShutterLayout(phase: .overtime, overtimeSeconds: 3600).notchCount, 3)
        XCTAssertEqual(ShutterLayout(phase: .overtime, overtimeSeconds: 3600).gap, ShutterLayout.minGap)
    }

    func testEverythingStaysInsideTheFixedBox() {
        let box = CGRect(origin: .zero, size: ShutterLayout.size)
        for layout in [ShutterLayout(phase: .idle), ShutterLayout(phase: .overtime, overtimeSeconds: 9999)] {
            let half = ShutterLayout.strokeWidth / 2
            XCTAssertGreaterThanOrEqual(layout.leftStrokeX - half, box.minX)
            XCTAssertLessThanOrEqual(layout.rightStrokeX + half, box.maxX)
            for notch in layout.notchRects { XCTAssertTrue(box.contains(notch)) }
            XCTAssertTrue(box.contains(layout.boltRect))
        }
    }
}
