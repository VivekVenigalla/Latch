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
