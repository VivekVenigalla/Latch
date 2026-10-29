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

    /// Picks the single highest-scoring candidate admitted by `filter`.
    /// Ties break on earliest due date, then title, then id, so the result is deterministic.
    public static func resolve(
        _ candidates: [TaskCandidate],
        filter: FilterMode,
        skipCounts: [String: Int],
        secondsUntilNextEvent: TimeInterval?,
        now: Date,
        weights: ScoringWeights = .standard
    ) -> TaskCandidate? {
        var best: TaskCandidate?
        for var candidate in candidates where filter.admits(candidate) {
            candidate.score = score(
                candidate,
                skipCount: skipCounts[candidate.id, default: 0],
                secondsUntilNextEvent: secondsUntilNextEvent,
                now: now,
                weights: weights)
            if let current = best, !ranks(candidate, above: current) { continue }
            best = candidate
        }
        return best
    }

    private static func ranks(_ a: TaskCandidate, above b: TaskCandidate) -> Bool {
        if a.score != b.score { return a.score > b.score }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: break
        }
        let byTitle = a.title.localizedCaseInsensitiveCompare(b.title)
        if byTitle != .orderedSame { return byTitle == .orderedAscending }
        return a.id < b.id
    }
}
