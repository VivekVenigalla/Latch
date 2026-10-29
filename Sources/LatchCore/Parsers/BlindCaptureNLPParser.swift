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
    /// Canonical title of the matched Reminders list, or `nil` for the default list.
    public var listName: String?

    public init(title: String, durationSec: Int? = nil, priority: CapturePriority? = nil, listName: String? = nil) {
        self.title = title
        self.durationSec = durationSec
        self.priority = priority
        self.listName = listName
    }
}

/// Extracts inline tokens from a Blind Capture string:
/// `~15m` / `~1h` (duration), `!high` / `!med` / `!low` / `!1`-`!3` (priority), `#list` (routing).
/// Tokens must stand alone (whitespace-delimited), so `email~5m` or `issue#12` stay in the title.
public enum BlindCaptureNLPParser {
    private static let durationRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)~(\d+)(m|h)(?!\S)"#, options: [.caseInsensitive])
    private static let priorityRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)!(high|med|low|1|2|3)(?!\S)"#, options: [.caseInsensitive])
    private static let listRegex = try! NSRegularExpression(
        pattern: #"(?<!\S)#([A-Za-z0-9_-]+)(?!\S)"#)

    /// Upper bound for a single captured duration (12h); larger values are ignored.
    public static let maxDurationSec = 12 * 3600

    /// - Parameter knownLists: Reminders list titles to route against (case-insensitive).
    ///   A `#token` that matches none of them stays in the title. Pass `nil` to accept any token.
    public static func parse(_ raw: String, knownLists: [String]? = nil) -> CaptureParse {
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

        for match in listRegex.matches(in: raw, range: full) where result.listName == nil {
            let token = ns.substring(with: match.range(at: 1))
            if let knownLists {
                guard let hit = knownLists.first(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) else { continue }
                result.listName = hit
            } else {
                result.listName = token
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
