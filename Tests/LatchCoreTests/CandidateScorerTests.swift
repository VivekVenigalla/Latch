import XCTest
@testable import LatchCore

final class CandidateScorerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testPriorityPoints() {
        XCTAssertEqual(CandidateScorer.priorityPoints(1), 30)
        XCTAssertEqual(CandidateScorer.priorityPoints(4), 30)
        XCTAssertEqual(CandidateScorer.priorityPoints(5), 15)
        XCTAssertEqual(CandidateScorer.priorityPoints(9), 5)
        XCTAssertEqual(CandidateScorer.priorityPoints(0), 10)
    }

    func testDueDatePoints() {
        XCTAssertEqual(CandidateScorer.dueDatePoints(now.addingTimeInterval(-60), now: now), 40)
        XCTAssertEqual(CandidateScorer.dueDatePoints(now.addingTimeInterval(23 * 3600), now: now), 40)
        XCTAssertEqual(CandidateScorer.dueDatePoints(now.addingTimeInterval(48 * 3600), now: now), 20)
        XCTAssertEqual(CandidateScorer.dueDatePoints(now.addingTimeInterval(100 * 3600), now: now), 10)
        XCTAssertEqual(CandidateScorer.dueDatePoints(nil, now: now), 5)
    }

    func testCalendarFit() {
        XCTAssertEqual(CandidateScorer.calendarFitPoints(allocatedSeconds: 1500, secondsUntilNextEvent: nil), 25)
        XCTAssertEqual(CandidateScorer.calendarFitPoints(allocatedSeconds: 1500, secondsUntilNextEvent: 3600), 25)
        XCTAssertEqual(CandidateScorer.calendarFitPoints(allocatedSeconds: 1500, secondsUntilNextEvent: 600), 0)
    }

    func testFormula() {
        let c = TaskCandidate(id: "a", title: "A", priority: 1, dueDate: now.addingTimeInterval(3600))
        // 30 + 40 + 25 - 50
        XCTAssertEqual(CandidateScorer.score(c, skipCount: 1, secondsUntilNextEvent: nil, now: now), 45)
    }
}
