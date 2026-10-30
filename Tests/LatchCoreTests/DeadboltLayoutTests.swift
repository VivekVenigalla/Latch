import XCTest
@testable import LatchCore

final class DeadboltLayoutTests: XCTestCase {
    func testIdleIsAnOpenLatch() {
        let idle = DeadboltLayout(phase: .idle, elapsedFraction: 0.7)
        XCTAssertFalse(idle.showsBolt)
        XCTAssertEqual(idle.throwFraction, 0)
    }

    func testBoltSlidesTowardTheKeeperAsTimeIsSpent() {
        let tips = (0...10).map { DeadboltLayout(phase: .running, elapsedFraction: Double($0) / 10).boltTipX }
        XCTAssertEqual(tips.first, DeadboltLayout.retractedTipX)
        XCTAssertEqual(tips.last, DeadboltLayout.seatedTipX)
        XCTAssertEqual(tips, tips.sorted())
    }

    func testOvertimeIsSeated() {
        let overtime = DeadboltLayout(phase: .overtime, elapsedFraction: 0.2)
        XCTAssertTrue(overtime.isSeated)
        XCTAssertEqual(overtime.boltTipX, DeadboltLayout.seatedTipX)
    }

    func testFractionIsClamped() {
        XCTAssertEqual(DeadboltLayout(phase: .running, elapsedFraction: -3).throwFraction, 0)
        XCTAssertEqual(DeadboltLayout(phase: .running, elapsedFraction: 9).throwFraction, 1)
    }

    func testHollowBoltForPausedAndDrifting() {
        XCTAssertTrue(DeadboltLayout(phase: .paused).isBoltHollow)
        XCTAssertTrue(DeadboltLayout(phase: .drifting).isBoltHollow)
        XCTAssertFalse(DeadboltLayout(phase: .running).isBoltHollow)
        XCTAssertFalse(DeadboltLayout(phase: .clamped).isBoltHollow)
    }

    func testThrowingOverridesTheBolt() {
        let base = DeadboltLayout(phase: .clamped, elapsedFraction: 0)
        let thrown = base.throwing(to: 1)
        XCTAssertEqual(thrown.phase, .clamped)
        XCTAssertTrue(thrown.isSeated)
        XCTAssertTrue(DeadboltLayout(phase: .idle).throwing(to: 0.5).showsBolt)
    }

    func testEverythingStaysInsideTheFixedBox() {
        let box = CGRect(origin: .zero, size: DeadboltLayout.size)
        let half = DeadboltLayout.strokeWidth / 2
        XCTAssertTrue(box.contains(DeadboltLayout.housingRect.insetBy(dx: -half, dy: -half)))
        for point in DeadboltLayout.keeper {
            XCTAssertTrue(box.insetBy(dx: half, dy: half).contains(point))
        }
        for fraction in [0.0, 0.5, 1.0] {
            XCTAssertTrue(box.contains(DeadboltLayout(phase: .running, elapsedFraction: fraction).boltRect))
        }
    }

    func testSeatedBoltStopsAtTheKeeperWall() {
        let seated = DeadboltLayout(phase: .overtime)
        XCTAssertLessThanOrEqual(seated.boltRect.maxX, 27 - DeadboltLayout.strokeWidth / 2)
        XCTAssertGreaterThan(seated.boltRect.maxX, DeadboltLayout.keeper[0].x, "the bolt sits inside the keeper")
    }
}
