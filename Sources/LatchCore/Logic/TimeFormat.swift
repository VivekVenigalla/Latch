import Foundation

public enum TimeFormat {
    /// Countdown clock. Positive values count down (`18:42`), negative values are overtime
    /// and count up with a plus prefix (`+02:14`). Hours appear only when needed (`1:05:00`).
    public static func clock(_ remainingSeconds: TimeInterval) -> String {
        let overtime = remainingSeconds < 0
        // Round toward the deadline: show 00:01 until the last fraction elapses, 00:00 exactly at expiry.
        let total = overtime ? Int((-remainingSeconds).rounded(.down)) : Int(remainingSeconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        let body = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
        return overtime ? "+" + body : body
    }

    /// Compact duration badge: `25m`, `1h`, `1h 30m`.
    public static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
