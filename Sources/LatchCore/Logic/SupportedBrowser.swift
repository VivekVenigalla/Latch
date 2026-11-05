import Foundation

/// Browsers whose tabs Latch can read over Apple Events, keyed by bundle identifier.
///
/// The scripts only query; they never navigate or change anything. They must only be run
/// against a browser that is already running, because `tell application` would launch it.
public enum SupportedBrowser: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case safariTechnologyPreview = "com.apple.SafariTechnologyPreview"
    case chrome = "com.google.Chrome"
    case arc = "company.thebrowser.Browser"
    case edge = "com.microsoft.edgemac"
    case brave = "com.brave.Browser"
    case vivaldi = "com.vivaldi.Vivaldi"

    public init?(bundleID: String?) {
        guard let bundleID, let browser = SupportedBrowser(rawValue: bundleID) else { return nil }
        self = browser
    }

    public var bundleID: String { rawValue }

    /// Safari calls it `current tab`; Chromium-based browsers and Arc call it `active tab`.
    private var activeTabTerm: String {
        switch self {
        case .safari, .safariTechnologyPreview: "current tab"
        case .chrome, .arc, .edge, .brave, .vivaldi: "active tab"
        }
    }

    /// Returns the front window's active tab URL, or an empty string when there is none.
    public var activeTabURLScript: String {
        """
        with timeout of 2 seconds
            tell application id "\(rawValue)"
                if (count of windows) is 0 then return ""
                return URL of \(activeTabTerm) of front window
            end tell
        end timeout
        """
    }

    /// Returns every open tab's URL, one per line.
    public var allTabURLsScript: String {
        """
        with timeout of 3 seconds
            tell application id "\(rawValue)"
                set out to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        set out to out & (URL of t) & linefeed
                    end repeat
                end repeat
                return out
            end tell
        end timeout
        """
    }

    /// Parses script output into URLs, skipping blanks and pages without a web host.
    public static func urls(fromScriptOutput output: String) -> [URL] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { URL(string: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") && $0.host != nil }
    }
}
