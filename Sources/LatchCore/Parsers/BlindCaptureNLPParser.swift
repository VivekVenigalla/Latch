import Foundation

public struct CaptureParse: Equatable, Sendable {
    /// Title with all recognised tokens stripped and whitespace collapsed.
    public var title: String
    public var durationSec: Int?

    public init(title: String, durationSec: Int? = nil) {
        self.title = title
        self.durationSec = durationSec
    }
}

/// Extracts inline tokens from a Blind Capture string: `~15m` / `~1h` (duration).
/// Tokens must stand alone (whitespace-delimited), so `email~5m` stays in the title.
public enum BlindCaptureNLPParser {
    private static let durationRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)~(\d+)(m|h)(?!\S)"#, options: [.caseInsensitive])

    /// Upper bound for a single captured duration (12h); larger values are ignored.
    public static let maxDurationSec = 12 * 3600

    public static func parse(_ raw: String) -> CaptureParse {
        let ns = raw as NSString
        let full = NSRange(location: 0, length: ns.length)
        var strip: [NSRange] = []
        var result = CaptureParse(title: "")

        for match in durationRegex.matches(in: raw, range: full) {
            guard let value = Int(ns.substring(with: match.range(at: 1))) else { continue }
            let unit = ns.substring(with: match.range(at: 2)).lowercased()
            guard value > 0, value <= (unit == "h" ? 12 : 12 * 60) else { continue }
            if result.durationSec == nil { result.durationSec = unit == "h" ? value * 3600 : value * 60 }
            strip.append(match.range)
        }

        let cleaned = NSMutableString(string: raw)
        for range in strip.sorted(by: { $0.location > $1.location }) {
            cleaned.replaceCharacters(in: range, with: " ")
        }
        result.title = (cleaned as String)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return result
    }
}
