import XCTest
@testable import LatchCore

final class CalendarClampTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoEventsNoClamp() {
        let result = CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: [])
        XCTAssertFalse(result.isClamped)
        XCTAssertEqual(result.allocatedSeconds, 1500)
    }

    func testClampsWithFiveMinuteBuffer() {
        let standup = CalendarBlock(start: now.addingTimeInterval(23 * 60), title: "Standup")
        let result = CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: [standup])
        XCTAssertTrue(result.isClamped)
        XCTAssertEqual(result.allocatedSeconds, 18 * 60)
        XCTAssertEqual(result.reason, "Clamped for Standup")
    }

    func testIgnoresAllDayAndFreeEvents() {
        let events = [
            CalendarBlock(start: now.addingTimeInterval(600), title: "Holiday", isAllDay: true),
            CalendarBlock(start: now.addingTimeInterval(600), title: "Focus hold", isFree: true),
        ]
        XCTAssertFalse(CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: events).isClamped)
    }

    func testTooShortWindowIsNotClamped() {
        let soon = CalendarBlock(start: now.addingTimeInterval(9 * 60), title: "Soon")
        XCTAssertFalse(CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: [soon]).isClamped)
    }

    func testEventAfterSessionIsNotClamped() {
        let later = CalendarBlock(start: now.addingTimeInterval(40 * 60), title: "Later")
        XCTAssertFalse(CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: [later]).isClamped)
    }

    func testOngoingEventIsIgnoredAndEarliestUpcomingWins() {
        let events = [
            CalendarBlock(start: now.addingTimeInterval(-600), title: "Ongoing"),
            CalendarBlock(start: now.addingTimeInterval(20 * 60), title: "Second"),
            CalendarBlock(start: now.addingTimeInterval(15 * 60), title: "First"),
        ]
        let result = CalendarClamp.clamp(requestedSeconds: 1500, now: now, events: events)
        XCTAssertEqual(result.event?.title, "First")
        XCTAssertEqual(result.allocatedSeconds, 10 * 60)
    }
}
