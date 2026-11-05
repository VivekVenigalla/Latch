import XCTest
@testable import LatchCore

final class DayLedgerTests: XCTestCase {
    func testDayKeyUsesTheLocalCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let lateEvening = ISO8601DateFormatter().date(from: "2026-11-05T06:30:00Z")! // 22:30 on the 4th in LA
        XCTAssertEqual(DayLedger.dayKey(for: lateEvening, calendar: calendar), "2026-11-04")
    }

    func testRecordingSessions() {
        var ledger = DayLedger(day: "2026-11-05")
        ledger.record(sessionSeconds: 1500, driftSeconds: 90, completed: true)
        ledger.record(sessionSeconds: 600, driftSeconds: 0, completed: false)
        XCTAssertEqual(ledger, DayLedger(day: "2026-11-05", focusedSeconds: 2100, driftSeconds: 90, sessions: 2, completed: 1))
    }

    func testDriftNeverExceedsSessionTime() {
        var ledger = DayLedger(day: "d")
        ledger.record(sessionSeconds: 60, driftSeconds: 500, completed: false)
        XCTAssertEqual(ledger.driftSeconds, 60)
        XCTAssertEqual(ledger.driftRatio, 1)
    }

    func testIncludingTheLiveSessionDoesNotMutate() {
        let ledger = DayLedger(day: "d", focusedSeconds: 600, sessions: 1)
        let live = ledger.including(liveSeconds: 300, liveDriftSeconds: 30)
        XCTAssertEqual(live.focusedSeconds, 900)
        XCTAssertEqual(live.driftSeconds, 30)
        XCTAssertEqual(live.sessions, 1)
        XCTAssertEqual(ledger.focusedSeconds, 600)
    }

    func testGoalFractions() {
        let ledger = DayLedger(day: "d", focusedSeconds: 7200, driftSeconds: 720)
        let f = ledger.goalFractions(goalSeconds: 14400)
        XCTAssertEqual(f.onTask, 0.45, accuracy: 0.0001)
        XCTAssertEqual(f.drift, 0.05, accuracy: 0.0001)
        let over = DayLedger(day: "d", focusedSeconds: 99999).goalFractions(goalSeconds: 3600)
        XCTAssertEqual(over.onTask + over.drift, 1, accuracy: 0.0001)
        XCTAssertEqual(DayLedger(day: "d").goalFractions(goalSeconds: 0).onTask, 0)
    }

    func testSummary() {
        XCTAssertEqual(DayLedger(day: "d").summary, "0m")
        XCTAssertEqual(DayLedger(day: "d", focusedSeconds: 8040, driftSeconds: 482, completed: 3).summary, "2h 14m · 3 done · drift 6%")
    }

    func testCodableRoundTrip() throws {
        let ledger = DayLedger(day: "2026-11-05", focusedSeconds: 10, driftSeconds: 2, sessions: 1, completed: 1)
        let data = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(DayLedger.self, from: data), ledger)
    }
}
