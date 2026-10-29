import XCTest
@testable import LatchCore

final class DriftLedgerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 10_000)

    func testStartsOnAnchor() {
        let ledger = DriftLedger()
        XCTAssertFalse(ledger.isAway)
        XCTAssertFalse(ledger.isDrifting(at: t0))
        XCTAssertEqual(ledger.totalDriftSeconds(at: t0), 0)
        XCTAssertEqual(ledger.graceSeconds, DriftLedger.defaultGraceSeconds)
    }

    func testShortGlanceIsForgiven() {
        var ledger = DriftLedger(graceSeconds: 20)
        ledger.leave(at: t0)
        XCTAssertFalse(ledger.isDrifting(at: t0.addingTimeInterval(20)))
        ledger.returnToAnchor(at: t0.addingTimeInterval(20))
        XCTAssertEqual(ledger.totalDriftSeconds(at: t0.addingTimeInterval(60)), 0)
        XCTAssertEqual(ledger.episodes, 0)
    }

    func testLongExcursionCountsInFull() {
        var ledger = DriftLedger(graceSeconds: 20)
        ledger.leave(at: t0)
        let during = t0.addingTimeInterval(45)
        XCTAssertTrue(ledger.isDrifting(at: during))
        XCTAssertEqual(ledger.currentExcursion(at: during), 45)
        XCTAssertEqual(ledger.totalDriftSeconds(at: during), 45, "the grace period is not subtracted")
        XCTAssertEqual(ledger.totalEpisodes(at: during), 1)

        ledger.returnToAnchor(at: t0.addingTimeInterval(90))
        XCTAssertFalse(ledger.isAway)
        XCTAssertEqual(ledger.settledSeconds, 90)
        XCTAssertEqual(ledger.episodes, 1)
        XCTAssertEqual(ledger.totalDriftSeconds(at: t0.addingTimeInterval(500)), 90)
    }

    func testRepeatedLeavesKeepFirstStart() {
        var ledger = DriftLedger(graceSeconds: 0)
        ledger.leave(at: t0)
        ledger.leave(at: t0.addingTimeInterval(30))
        XCTAssertEqual(ledger.currentExcursion(at: t0.addingTimeInterval(40)), 40)
    }

    func testReturnWithoutLeaveIsNoOp() {
        var ledger = DriftLedger()
        ledger.returnToAnchor(at: t0)
        XCTAssertEqual(ledger, DriftLedger())
    }

    func testEpisodesAccumulate() {
        var ledger = DriftLedger(graceSeconds: 10)
        ledger.leave(at: t0)
        ledger.returnToAnchor(at: t0.addingTimeInterval(30))
        ledger.leave(at: t0.addingTimeInterval(100))
        ledger.returnToAnchor(at: t0.addingTimeInterval(105))   // forgiven
        ledger.leave(at: t0.addingTimeInterval(200))
        ledger.returnToAnchor(at: t0.addingTimeInterval(260))
        XCTAssertEqual(ledger.episodes, 2)
        XCTAssertEqual(ledger.settledSeconds, 90)
    }

    func testNegativeGraceClampsToZero() {
        XCTAssertEqual(DriftLedger(graceSeconds: -5).graceSeconds, 0)
    }

    func testClockSkewNeverProducesNegativeDrift() {
        var ledger = DriftLedger(graceSeconds: 0)
        ledger.leave(at: t0)
        XCTAssertEqual(ledger.currentExcursion(at: t0.addingTimeInterval(-50)), 0)
        ledger.returnToAnchor(at: t0.addingTimeInterval(-50))
        XCTAssertEqual(ledger.settledSeconds, 0)
    }
}
