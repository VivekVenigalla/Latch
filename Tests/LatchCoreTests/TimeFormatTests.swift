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
}
