import XCTest
@testable import LatchCore

final class BlindCaptureNLPParserTests: XCTestCase {
    func testPlainTitle() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("  Fix   auth token  "), CaptureParse(title: "Fix auth token"))
    }

    func testDurationMinutesAndHours() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("Write spec ~15m").durationSec, 900)
        XCTAssertEqual(BlindCaptureNLPParser.parse("Write spec ~1h").durationSec, 3600)
        XCTAssertEqual(BlindCaptureNLPParser.parse("Write spec ~2H").durationSec, 7200)
        XCTAssertEqual(BlindCaptureNLPParser.parse("~45m Write spec").title, "Write spec")
    }

    func testInvalidDurationsAreIgnored() {
        XCTAssertNil(BlindCaptureNLPParser.parse("Thing ~0m").durationSec)
        XCTAssertNil(BlindCaptureNLPParser.parse("Thing ~99999999999999999999m").durationSec)
        XCTAssertNil(BlindCaptureNLPParser.parse("Thing ~13h").durationSec)
    }

    func testPriorityMapping() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !high").priority, .high)
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !1").priority, .high)
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !med").priority, .med)
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !2").priority, .med)
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !low").priority, .low)
        XCTAssertEqual(BlindCaptureNLPParser.parse("a !3").priority, .low)
        XCTAssertEqual(CapturePriority.high.ekPriority, 1)
        XCTAssertEqual(CapturePriority.med.ekPriority, 5)
        XCTAssertEqual(CapturePriority.low.ekPriority, 9)
    }

    func testAllTokensStripped() {
        let parsed = BlindCaptureNLPParser.parse("Fix auth token ~15m !high #work", knownLists: ["Work", "Home"])
        XCTAssertEqual(parsed, CaptureParse(title: "Fix auth token", durationSec: 900, priority: .high, listName: "Work"))
    }

    func testUnknownListStaysInTitle() {
        let parsed = BlindCaptureNLPParser.parse("Ship #123 fix", knownLists: ["Work"])
        XCTAssertNil(parsed.listName)
        XCTAssertEqual(parsed.title, "Ship #123 fix")
    }

    func testAnyListAcceptedWithoutKnownLists() {
        let parsed = BlindCaptureNLPParser.parse("Call mom #home")
        XCTAssertEqual(parsed.listName, "home")
        XCTAssertEqual(parsed.title, "Call mom")
    }

    func testTokensMustStandAlone() {
        let parsed = BlindCaptureNLPParser.parse("email~5m wow!high issue#12", knownLists: ["12"])
        XCTAssertEqual(parsed, CaptureParse(title: "email~5m wow!high issue#12"))
    }

    func testFirstTokenWinsDuplicatesStripped() {
        let parsed = BlindCaptureNLPParser.parse("Task ~10m ~20m !low !high")
        XCTAssertEqual(parsed.durationSec, 600)
        XCTAssertEqual(parsed.priority, .low)
        XCTAssertEqual(parsed.title, "Task")
    }

    func testOnlyTokensYieldsEmptyTitle() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("~15m !high").title, "")
    }
}
