import Foundation

public struct ScoringWeights: Equatable, Sendable {
    public var priority: Double
    public var dueDate: Double
    public var calendarFit: Double
    public var skip: Double

    public init(priority: Double = 1, dueDate: Double = 1, calendarFit: Double = 1, skip: Double = 1) {
        self.priority = priority
        self.dueDate = dueDate
        self.calendarFit = calendarFit
        self.skip = skip
    }

    public static let standard = ScoringWeights()
}

/// Auto-Resolver: `Score = Wp·P + Wd·D + Wf·F − Ws·S`.
public enum CandidateScorer {
    public static let skipPenalty = 50
    public static let calendarFitBonus = 25

    /// P: 1-4 high = 30, 5 medium = 15, 6-9 low = 5, 0 none = 10.
    public static func priorityPoints(_ ekPriority: Int) -> Int {
        switch PriorityBand(ekPriority: ekPriority) {
        case .high: 30
        case .medium: 15
        case .low: 5
        case .none: 10
        }
    }

    /// D: overdue or due within 24h = 40, within 72h = 20, later = 10, no due date = 5.
    public static func dueDatePoints(_ dueDate: Date?, now: Date) -> Int {
        guard let dueDate else { return 5 }
        let delta = dueDate.timeIntervalSince(now)
        if delta <= 24 * 3600 { return 40 }
        if delta <= 72 * 3600 { return 20 }
        return 10
    }

    /// F: +25 if the task fits before the next blocking calendar event (or there is none).
    public static func calendarFitPoints(allocatedSeconds: Int, secondsUntilNextEvent: TimeInterval?) -> Int {
        guard let secondsUntilNextEvent else { return calendarFitBonus }
        return TimeInterval(allocatedSeconds) < secondsUntilNextEvent ? calendarFitBonus : 0
    }

    public static func score(
        _ candidate: TaskCandidate,
        skipCount: Int,
        secondsUntilNextEvent: TimeInterval?,
        now: Date,
        weights: ScoringWeights = .standard
    ) -> Double {
        let p = Double(priorityPoints(candidate.priority))
        let d = Double(dueDatePoints(candidate.dueDate, now: now))
        let f = Double(calendarFitPoints(allocatedSeconds: candidate.durationSec, secondsUntilNextEvent: secondsUntilNextEvent))
        let s = Double(skipCount * skipPenalty)
        return weights.priority * p + weights.dueDate * d + weights.calendarFit * f - weights.skip * s
    }
}
