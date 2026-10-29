import Foundation

/// Latch-specific state persisted inside `EKReminder.notes` so it syncs via iCloud
/// without a local database. Every field is optional: absent keys are simply not written.
public struct LatchMetadata: Equatable, Sendable {
    public var durationSec: Int?
    public var elapsedSec: Int?
    public var context: String?
    public var deferredCount: Int?
    public var lastLatched: Date?

    public init(
        durationSec: Int? = nil,
        elapsedSec: Int? = nil,
        context: String? = nil,
        deferredCount: Int? = nil,
        lastLatched: Date? = nil
    ) {
        self.durationSec = durationSec
        self.elapsedSec = elapsedSec
        self.context = context
        self.deferredCount = deferredCount
        self.lastLatched = lastLatched
    }

    public var isEmpty: Bool {
        durationSec == nil && elapsedSec == nil && context == nil && deferredCount == nil && lastLatched == nil
    }
}

public struct ParsedNotes: Equatable, Sendable {
    /// The user's own notes with the `---LATCH---` block removed.
    public var userNotes: String
    /// `nil` when the notes contain no `---LATCH---` marker at all.
    public var metadata: LatchMetadata?

    public init(userNotes: String, metadata: LatchMetadata?) {
        self.userNotes = userNotes
        self.metadata = metadata
    }
}

/// Reads and writes the human-readable metadata block at the bottom of `EKReminder.notes`:
///
///     <user notes>
///
///     ---LATCH---
///     duration_sec: 1500
///     elapsed_sec: 420
///     context: Check line 142 in AuthController.swift
///     deferred_count: 1
///     last_latched: 2026-10-29T14:30:00Z
///
/// Parsing is forgiving: unknown keys are ignored, unparseable values become `nil`, and the
/// block ends at the first line that is not `key: value`, so any text the user typed below
/// the block is preserved as user notes rather than silently dropped.
public enum LatchMetadataParser {
    public static let marker = "---LATCH---"

    private enum Key: String {
        case durationSec = "duration_sec"
        case elapsedSec = "elapsed_sec"
        case context
        case deferredCount = "deferred_count"
        case lastLatched = "last_latched"
    }

    public static func parse(_ notes: String?) -> ParsedNotes {
        guard let notes, !notes.isEmpty else { return ParsedNotes(userNotes: "", metadata: nil) }

        // "\r\n" is a single Character in Swift, so normalise before splitting.
        let lines = notes
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let markerIndex = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces) == marker }) else {
            return ParsedNotes(userNotes: notes, metadata: nil)
        }

        var metadata = LatchMetadata()
        var cursor = markerIndex + 1
        while cursor < lines.count {
            let line = lines[cursor].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                cursor += 1
                continue
            }
            guard let (key, value) = splitKeyValue(line) else { break }
            apply(key: key, value: value, to: &metadata)
            cursor += 1
        }

        let before = trimTrailing(lines[..<markerIndex].joined(separator: "\n"))
        let after = lines[cursor...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let userNotes = [before, after].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return ParsedNotes(userNotes: userNotes, metadata: metadata)
    }

    /// Returns `notes` with its metadata block replaced by `metadata` (or appended if absent).
    /// User text is never modified apart from trailing whitespace. Returns `nil` when both the
    /// user text and the metadata are empty, so the reminder's notes can be cleared.
    public static func write(_ metadata: LatchMetadata, into notes: String?) -> String? {
        let userNotes = trimTrailing(parse(notes).userNotes)
        guard !metadata.isEmpty else { return userNotes.isEmpty ? nil : userNotes }
        let block = serialize(metadata)
        return userNotes.isEmpty ? block + "\n" : userNotes + "\n\n" + block + "\n"
    }

    /// The `---LATCH---` block alone, without user notes.
    public static func serialize(_ metadata: LatchMetadata) -> String {
        var lines = [marker]
        if let v = metadata.durationSec { lines.append("\(Key.durationSec.rawValue): \(v)") }
        if let v = metadata.elapsedSec { lines.append("\(Key.elapsedSec.rawValue): \(v)") }
        if let v = metadata.context { lines.append("\(Key.context.rawValue): \(singleLine(v))") }
        if let v = metadata.deferredCount { lines.append("\(Key.deferredCount.rawValue): \(v)") }
        if let v = metadata.lastLatched { lines.append("\(Key.lastLatched.rawValue): \(v.formatted(.iso8601))") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func splitKeyValue(_ line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon])
        guard !key.isEmpty, key.allSatisfy({ $0.isLowercase || $0 == "_" }) else { return nil }
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private static func apply(key: String, value: String, to metadata: inout LatchMetadata) {
        guard let key = Key(rawValue: key) else { return }
        switch key {
        case .durationSec: metadata.durationSec = nonNegativeInt(value)
        case .elapsedSec: metadata.elapsedSec = nonNegativeInt(value)
        case .deferredCount: metadata.deferredCount = nonNegativeInt(value)
        case .context: metadata.context = value.isEmpty ? nil : value
        case .lastLatched: metadata.lastLatched = try? Date(value, strategy: .iso8601)
        }
    }

    private static func nonNegativeInt(_ value: String) -> Int? {
        guard let n = Int(value), n >= 0 else { return nil }
        return n
    }

    /// The block is line-oriented, so a multi-line context note is folded onto one line.
    private static func singleLine(_ s: String) -> String {
        s.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func trimTrailing(_ s: String) -> String {
        var s = s
        while let last = s.last, last.isWhitespace { s.removeLast() }
        return s
    }
}
