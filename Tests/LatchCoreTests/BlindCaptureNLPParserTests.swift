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

    func testDurationTokenMustStandAlone() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("email~5m"), CaptureParse(title: "email~5m"))
    }

    func testOnlyTokensYieldsEmptyTitle() {
        XCTAssertEqual(BlindCaptureNLPParser.parse("~15m").title, "")
    }
}
