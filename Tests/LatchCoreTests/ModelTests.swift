import XCTest
@testable import LatchCore

final class TaskCandidateTests: XCTestCase {
    func testPriorityBands() {
        XCTAssertEqual(PriorityBand(ekPriority: 0), .none)
        XCTAssertEqual(PriorityBand(ekPriority: 1), .high)
        XCTAssertEqual(PriorityBand(ekPriority: 4), .high)
        XCTAssertEqual(PriorityBand(ekPriority: 5), .medium)
        XCTAssertEqual(PriorityBand(ekPriority: 6), .low)
        XCTAssertEqual(PriorityBand(ekPriority: 9), .low)
        XCTAssertEqual(PriorityBand(ekPriority: 42), .none)
    }

    func testDurationDefaultsToTwentyFiveMinutes() {
        XCTAssertEqual(TaskCandidate(id: "a", title: "A").durationSec, 1500)
        XCTAssertEqual(TaskCandidate(id: "b", title: "B", metadata: LatchMetadata(durationSec: 600)).durationSec, 600)
    }
}

final class ActiveSessionTests: XCTestCase {
    func testWallClockSession() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = ActiveSession(
            task: TaskCandidate(id: "t", title: "T", metadata: LatchMetadata(elapsedSec: 100)),
            requestedSeconds: 1500, allocatedSeconds: 1500, now: start)
        XCTAssertEqual(session.targetEndDate, start.addingTimeInterval(1500))
        // Simulate a 10-minute sleep: elapsed comes from the wall clock, not a counter.
        let afterSleep = start.addingTimeInterval(600)
        XCTAssertEqual(session.sessionElapsedSeconds(at: afterSleep), 600)
        XCTAssertEqual(session.totalElapsedSeconds(at: afterSleep), 700)
        session.pausedAt = afterSleep
        XCTAssertEqual(session.sessionElapsedSeconds(at: afterSleep.addingTimeInterval(9_999)), 600)
    }

    func testProgressRemaining() {
        let session = ActiveSession(task: TaskCandidate(id: "t", title: "T"), requestedSeconds: 1000, allocatedSeconds: 1000)
        XCTAssertEqual(session.progressRemaining(remainingSeconds: 1000), 1)
        XCTAssertEqual(session.progressRemaining(remainingSeconds: 250), 0.25)
        XCTAssertEqual(session.progressRemaining(remainingSeconds: -30), 0)
    }
}

final class AppStateTests: XCTestCase {
    func testQuickFilterAdmitsOnlyShortTasks() {
        let short = TaskCandidate(id: "s", title: "S", metadata: LatchMetadata(durationSec: 900))
        let long = TaskCandidate(id: "l", title: "L", metadata: LatchMetadata(durationSec: 901))
        XCTAssertTrue(FilterMode.quick.admits(short))
        XCTAssertFalse(FilterMode.quick.admits(long))
        XCTAssertTrue(FilterMode.all.admits(long))
        XCTAssertEqual(FilterMode.all.toggled, .quick)
        XCTAssertEqual(FilterMode.quick.toggled, .all)
    }

    func testPhases() {
        let session = ActiveSession(task: TaskCandidate(id: "t", title: "T"), requestedSeconds: 60, allocatedSeconds: 60)
        XCTAssertEqual(AppState.permissionsRequired.phase, .permissions)
        XCTAssertEqual(AppState.unlatchedSelector(candidate: nil, filterMode: .all).phase, .selector)
        XCTAssertEqual(AppState.latchedFocus(activeTask: session).phase, .focus)
        XCTAssertEqual(AppState.stateDumpGate(completedSession: session).phase, .gate)
    }
}
