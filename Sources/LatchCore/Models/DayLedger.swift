import Foundation

/// Today's focus at a glance: time latched, how much of it drifted, sessions and completions.
/// Deliberately one day only — no history, no streaks.
public struct DayLedger: Codable, Equatable, Sendable {
    public static let defaultGoalSeconds = 4 * 3600

    /// Local calendar day, `yyyy-MM-dd`.
    public var day: String
    public var focusedSeconds = 0
    public var driftSeconds = 0
    public var sessions = 0
    public var completed = 0

    public init(day: String, focusedSeconds: Int = 0, driftSeconds: Int = 0, sessions: Int = 0, completed: Int = 0) {
        self.day = day
        self.focusedSeconds = focusedSeconds
        self.driftSeconds = driftSeconds
        self.sessions = sessions
        self.completed = completed
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Adds one finished session.
    public mutating func record(sessionSeconds: Int, driftSeconds: Int, completed: Bool) {
        focusedSeconds += max(0, sessionSeconds)
        self.driftSeconds += max(0, min(driftSeconds, sessionSeconds))
        sessions += 1
        if completed { self.completed += 1 }
    }

    /// The ledger as it would read if the session in progress ended now.
    public func including(liveSeconds: Int, liveDriftSeconds: Int) -> DayLedger {
        var copy = self
        copy.focusedSeconds += max(0, liveSeconds)
        copy.driftSeconds += max(0, min(liveDriftSeconds, liveSeconds))
        return copy
    }

    /// Share of focused time spent drifting, 0…1.
    public var driftRatio: Double {
        focusedSeconds > 0 ? min(1, Double(driftSeconds) / Double(focusedSeconds)) : 0
    }

    /// On-task and drift time as fractions of the daily goal, together capped at 1.
    public func goalFractions(goalSeconds: Int) -> (onTask: Double, drift: Double) {
        guard goalSeconds > 0 else { return (0, 0) }
        let total = min(1, Double(focusedSeconds) / Double(goalSeconds))
        let drift = total * driftRatio
        return (total - drift, drift)
    }

    /// `2h 14m · 3 done · drift 6%`
    public var summary: String {
        var parts = [TimeFormat.duration(focusedSeconds)]
        if completed > 0 { parts.append("\(completed) done") }
        if driftSeconds > 0 { parts.append("drift \(Int((driftRatio * 100).rounded()))%") }
        return parts.joined(separator: " · ")
    }
}
