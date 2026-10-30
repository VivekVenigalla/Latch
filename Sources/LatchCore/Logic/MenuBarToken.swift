import Foundation

/// Text for the menu bar token beside the Deadbolt glyph.
///
/// Time is deliberately coarse — `18m` rather than `18:42` — so the menu bar changes once a
/// minute instead of every second. In the final minute it switches to seconds (`45s`) so the
/// ending is never a surprise. Overtime counts up with a plus prefix (`+2m`).
public enum MenuBarToken {
    public static let pausedLabel = "paused"

    public static func timeLabel(remainingSeconds: TimeInterval) -> String {
        if remainingSeconds <= 0 {
            let over = -remainingSeconds
            return over < 60 ? "+\(Int(over))s" : "+" + minutes(Int(over / 60))
        }
        if remainingSeconds < 60 {
            return "\(Int(remainingSeconds.rounded(.up)))s"
        }
        // Round up, like any countdown: 18:01 left still reads as 19m.
        return minutes(Int((remainingSeconds / 60).rounded(.up)))
    }

    /// `true` during the last minute before expiry, when the label shows seconds.
    public static func isFinalMinute(remainingSeconds: TimeInterval) -> Bool {
        remainingSeconds > 0 && remainingSeconds < 60
    }

    /// `18m`, `1h`, `1h 5m`.
    static func minutes(_ total: Int) -> String {
        let h = total / 60
        let m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
