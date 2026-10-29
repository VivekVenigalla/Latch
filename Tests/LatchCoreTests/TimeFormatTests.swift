import XCTest
@testable import LatchCore

final class TimeFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(TimeFormat.clock(1122), "18:42")
        XCTAssertEqual(TimeFormat.clock(0.4), "00:01")
        XCTAssertEqual(TimeFormat.clock(0), "00:00")
        XCTAssertEqual(TimeFormat.clock(-134.6), "+02:14")
        XCTAssertEqual(TimeFormat.clock(3900), "1:05:00")
    }

    func testDuration() {
        XCTAssertEqual(TimeFormat.duration(1500), "25m")
        XCTAssertEqual(TimeFormat.duration(3600), "1h")
        XCTAssertEqual(TimeFormat.duration(5400), "1h 30m")
    }

    func testGlancePill() {
        XCTAssertEqual(GlancePill.idle, "[ · ]")
        XCTAssertEqual(GlancePill.latched(remainingSeconds: 1122, title: "Fix auth token"), "[▪] 18:42 · Fix auth token")
        XCTAssertEqual(GlancePill.latched(remainingSeconds: -134, title: "Fix auth token"), "[▪] +02:14 · Fix auth token")
        let truncated = GlancePill.truncate("Refactor the entire payments module")
        XCTAssertEqual(truncated.count, 22)
        XCTAssertTrue(truncated.hasSuffix("…"))
    }
}
