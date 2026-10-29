import Foundation

public enum CapturePriority: String, Equatable, Sendable {
    case high, med, low

    /// `EKReminder.priority` value: 1 = high, 5 = medium, 9 = low.
    public var ekPriority: Int {
        switch self {
        case .high: 1
        case .med: 5
        case .low: 9
        }
    }
}

public struct CaptureParse: Equatable, Sendable {
    /// Title with all recognised tokens stripped and whitespace collapsed.
    public var title: String
    public var durationSec: Int?
    public var priority: CapturePriority?

    public init(title: String, durationSec: Int? = nil, priority: CapturePriority? = nil) {
        self.title = title
        self.durationSec = durationSec
        self.priority = priority
    }
}

/// Extracts inline tokens from a Blind Capture string:
/// `~15m` / `~1h` (duration), `!high` / `!med` / `!low` / `!1`-`!3` (priority).
/// Tokens must stand alone (whitespace-delimited), so `email~5m` or `wow!high` stay in the title.
public enum BlindCaptureNLPParser {
    private static let durationRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)~(\d+)(m|h)(?!\S)"#, options: [.caseInsensitive])
    private static let priorityRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)!(high|med|low|1|2|3)(?!\S)"#, options: [.caseInsensitive])

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

        for match in priorityRegex.matches(in: raw, range: full) {
            if result.priority == nil {
                switch ns.substring(with: match.range(at: 1)).lowercased() {
                case "high", "1": result.priority = .high
                case "med", "2": result.priority = .med
                default: result.priority = .low
                }
            }
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
