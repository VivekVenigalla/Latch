import XCTest
@testable import LatchCore

final class LatchMetadataParserTests: XCTestCase {
    private let sampleDate = try! Date("2026-10-29T14:30:00Z", strategy: .iso8601)

    // MARK: Empty / absent

    func testNilNotes() {
        let parsed = LatchMetadataParser.parse(nil)
        XCTAssertEqual(parsed.userNotes, "")
        XCTAssertNil(parsed.metadata)
    }

    func testEmptyNotes() {
        let parsed = LatchMetadataParser.parse("")
        XCTAssertEqual(parsed.userNotes, "")
        XCTAssertNil(parsed.metadata)
    }

    func testUserNotesWithoutBlockAreUntouched() {
        let notes = "Call Dana about the contract.\n  - bring numbers\n"
        let parsed = LatchMetadataParser.parse(notes)
        XCTAssertEqual(parsed.userNotes, notes)
        XCTAssertNil(parsed.metadata)
    }

    // MARK: Well-formed

    func testFullBlockWithUserText() {
        let notes = """
        Original user notes.
        Second line.

        ---LATCH---
        duration_sec: 1500
        elapsed_sec: 420
        context: Check line 142 in AuthController.swift; token payload is missing exp claim.
        deferred_count: 1
        last_latched: 2026-10-29T14:30:00Z

        """
        let parsed = LatchMetadataParser.parse(notes)
        XCTAssertEqual(parsed.userNotes, "Original user notes.\nSecond line.")
        XCTAssertEqual(parsed.metadata, LatchMetadata(
            durationSec: 1500,
            elapsedSec: 420,
            context: "Check line 142 in AuthController.swift; token payload is missing exp claim.",
            deferredCount: 1,
            lastLatched: sampleDate))
    }

    func testBlockOnly() {
        let parsed = LatchMetadataParser.parse("---LATCH---\nduration_sec: 900\n")
        XCTAssertEqual(parsed.userNotes, "")
        XCTAssertEqual(parsed.metadata, LatchMetadata(durationSec: 900))
    }

    func testContextMayContainColons() {
        let parsed = LatchMetadataParser.parse("---LATCH---\ncontext: see https://x.dev/a:b at 10:30")
        XCTAssertEqual(parsed.metadata?.context, "see https://x.dev/a:b at 10:30")
    }

    func testCRLFLineEndings() {
        let parsed = LatchMetadataParser.parse("Note\r\n\r\n---LATCH---\r\nduration_sec: 600\r\n")
        XCTAssertEqual(parsed.userNotes, "Note")
        XCTAssertEqual(parsed.metadata?.durationSec, 600)
    }

    // MARK: Malformed

    func testMalformedValuesBecomeNil() {
        let notes = """
        ---LATCH---
        duration_sec: twenty
        elapsed_sec: -5
        deferred_count: 2
        last_latched: yesterday
        context:
        """
        let parsed = LatchMetadataParser.parse(notes)
        XCTAssertEqual(parsed.metadata, LatchMetadata(deferredCount: 2))
    }

    func testUnknownKeysAreIgnored() {
        let parsed = LatchMetadataParser.parse("---LATCH---\nfuture_key: 1\nduration_sec: 300")
        XCTAssertEqual(parsed.metadata, LatchMetadata(durationSec: 300))
    }

    func testMarkerWithNoFields() {
        let parsed = LatchMetadataParser.parse("Hello\n---LATCH---")
        XCTAssertEqual(parsed.userNotes, "Hello")
        XCTAssertEqual(parsed.metadata, LatchMetadata())
    }

    func testFreeTextAfterBlockIsPreservedAsUserNotes() {
        let notes = """
        Top note.

        ---LATCH---
        duration_sec: 1200
        I typed this on my iPhone below the block.
        """
        let parsed = LatchMetadataParser.parse(notes)
        XCTAssertEqual(parsed.metadata, LatchMetadata(durationSec: 1200))
        XCTAssertEqual(parsed.userNotes, "Top note.\n\nI typed this on my iPhone below the block.")
    }

    func testLastMarkerWins() {
        let notes = "---LATCH---\nduration_sec: 100\n\n---LATCH---\nduration_sec: 200"
        XCTAssertEqual(LatchMetadataParser.parse(notes).metadata?.durationSec, 200)
    }

    // MARK: Writing

    func testWriteIntoEmptyNotes() {
        let written = LatchMetadataParser.write(LatchMetadata(durationSec: 900), into: nil)
        XCTAssertEqual(written, "---LATCH---\nduration_sec: 900\n")
    }

    func testWriteAppendsBelowUserText() {
        let written = LatchMetadataParser.write(LatchMetadata(durationSec: 900), into: "Buy milk\n\n")
        XCTAssertEqual(written, "Buy milk\n\n---LATCH---\nduration_sec: 900\n")
    }

    func testWriteUpdatesInPlaceWithoutDuplicatingBlock() {
        let original = "User text.\n\n---LATCH---\nduration_sec: 1500\nelapsed_sec: 60\n"
        var metadata = LatchMetadataParser.parse(original).metadata!
        metadata.elapsedSec = 480
        metadata.context = "Next: run tests"
        let written = LatchMetadataParser.write(metadata, into: original)!
        XCTAssertEqual(written.components(separatedBy: LatchMetadataParser.marker).count, 2)
        XCTAssertEqual(written, "User text.\n\n---LATCH---\nduration_sec: 1500\nelapsed_sec: 480\ncontext: Next: run tests\n")
    }

    func testWriteEmptyMetadataStripsBlock() {
        XCTAssertEqual(LatchMetadataParser.write(LatchMetadata(), into: "Keep me\n\n---LATCH---\nduration_sec: 1"), "Keep me")
        XCTAssertNil(LatchMetadataParser.write(LatchMetadata(), into: "---LATCH---\nduration_sec: 1"))
    }

    func testMultilineContextIsFolded() {
        let block = LatchMetadataParser.serialize(LatchMetadata(context: "line one\n  line two\n"))
        XCTAssertEqual(block, "---LATCH---\ncontext: line one line two")
    }

    func testRoundTrip() {
        let metadata = LatchMetadata(
            durationSec: 1500, elapsedSec: 420, context: "Fix segfault", deferredCount: 3, lastLatched: sampleDate)
        let written = LatchMetadataParser.write(metadata, into: "Some notes")
        let parsed = LatchMetadataParser.parse(written)
        XCTAssertEqual(parsed.userNotes, "Some notes")
        XCTAssertEqual(parsed.metadata, metadata)
    }
}
