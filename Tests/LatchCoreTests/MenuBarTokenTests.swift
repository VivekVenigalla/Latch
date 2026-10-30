import XCTest
@testable import LatchCore

final class MenuBarTokenTests: XCTestCase {
    func testMinutesRoundUp() {
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 1500), "25m")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 1081), "19m")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 1080), "18m")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 60), "1m")
    }

    func testHours() {
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 3600), "1h")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 3900), "1h 5m")
    }

    func testFinalMinuteShowsSeconds() {
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 59.2), "60s")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 45), "45s")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 0.3), "1s")
        XCTAssertTrue(MenuBarToken.isFinalMinute(remainingSeconds: 45))
        XCTAssertFalse(MenuBarToken.isFinalMinute(remainingSeconds: 60))
        XCTAssertFalse(MenuBarToken.isFinalMinute(remainingSeconds: 0))
    }

    func testOvertime() {
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: 0), "+0s")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: -12.7), "+12s")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: -134), "+2m")
        XCTAssertEqual(MenuBarToken.timeLabel(remainingSeconds: -3700), "+1h 1m")
    }
}
