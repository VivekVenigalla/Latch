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

    func testResolvePicksHighestAndCycles() {
        let a = TaskCandidate(id: "a", title: "A", priority: 1, dueDate: now)          // 95
        let b = TaskCandidate(id: "b", title: "B", priority: 5, dueDate: now)          // 80
        let c = TaskCandidate(id: "c", title: "C", priority: 0)                        // 40
        let all = [c, b, a]
        var skips: [String: Int] = [:]

        func pick() -> String? {
            CandidateScorer.resolve(all, filter: .all, skipCounts: skips, secondsUntilNextEvent: nil, now: now)?.id
        }
        XCTAssertEqual(pick(), "a")
        skips["a", default: 0] += 1                  // a: 45
        XCTAssertEqual(pick(), "b")
        skips["b", default: 0] += 1                  // b: 30
        XCTAssertEqual(pick(), "a", "a (45) still outranks c (40) after one skip each")
        skips["a", default: 0] += 1                  // a: -5
        XCTAssertEqual(pick(), "c")
        skips["c", default: 0] += 1                  // c: -10
        XCTAssertEqual(pick(), "b", "b (30) is now the best remaining")
    }

    func testQuickFilter() {
        let long = TaskCandidate(id: "long", title: "Long", priority: 1, metadata: LatchMetadata(durationSec: 3600))
        let short = TaskCandidate(id: "short", title: "Short", priority: 9, metadata: LatchMetadata(durationSec: 600))
        let pick = CandidateScorer.resolve([long, short], filter: .quick, skipCounts: [:], secondsUntilNextEvent: nil, now: now)
        XCTAssertEqual(pick?.id, "short")
        XCTAssertNil(CandidateScorer.resolve([long], filter: .quick, skipCounts: [:], secondsUntilNextEvent: nil, now: now))
    }

    func testTieBreakIsDeterministic() {
        let x = TaskCandidate(id: "x", title: "Beta")
        let y = TaskCandidate(id: "y", title: "alpha")
        XCTAssertEqual(CandidateScorer.resolve([x, y], filter: .all, skipCounts: [:], secondsUntilNextEvent: nil, now: now)?.id, "y")
    }
}
