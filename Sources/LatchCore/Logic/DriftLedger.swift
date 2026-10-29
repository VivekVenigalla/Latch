import Foundation

/// Drift Guard bookkeeping: how long the user has been away from the app they pinned when
/// they latched. A quick glance elsewhere (up to `graceSeconds`) is forgiven; an excursion
/// longer than that counts in full.
///
/// Activating Latch itself is neutral — the engine reports neither a leave nor a return —
/// so opening the popover never starts or ends an excursion.
public struct DriftLedger: Equatable, Sendable {
    public static let defaultGraceSeconds: TimeInterval = 20

    public var graceSeconds: TimeInterval
    /// Drift from excursions that have already ended.
    public private(set) var settledSeconds: TimeInterval = 0
    /// Number of ended excursions that went past the grace period.
    public private(set) var episodes = 0
    /// Start of the current excursion, or `nil` while on the pinned app.
    public private(set) var awaySince: Date?

    public init(graceSeconds: TimeInterval = DriftLedger.defaultGraceSeconds) {
        self.graceSeconds = max(0, graceSeconds)
    }

    public var isAway: Bool { awaySince != nil }

    /// The user activated an app other than the pinned one. Repeated leaves keep the first start.
    public mutating func leave(at date: Date) {
        if awaySince == nil { awaySince = date }
    }

    /// The user came back to the pinned app, or the session stopped.
    public mutating func returnToAnchor(at date: Date) {
        guard let since = awaySince else { return }
        awaySince = nil
        let away = max(0, date.timeIntervalSince(since))
        guard away > graceSeconds else { return }
        settledSeconds += away
        episodes += 1
    }

    /// Length of the current excursion; 0 while on the pinned app.
    public func currentExcursion(at now: Date) -> TimeInterval {
        awaySince.map { max(0, now.timeIntervalSince($0)) } ?? 0
    }

    /// `true` once the current excursion has outlasted the grace period.
    public func isDrifting(at now: Date) -> Bool {
        currentExcursion(at: now) > graceSeconds
    }

    /// Settled drift plus the current excursion, if it has passed the grace period.
    public func totalDriftSeconds(at now: Date) -> TimeInterval {
        let current = currentExcursion(at: now)
        return settledSeconds + (current > graceSeconds ? current : 0)
    }

    /// Episodes including the current one, if it has passed the grace period.
    public func totalEpisodes(at now: Date) -> Int {
        episodes + (isDrifting(at: now) ? 1 : 0)
    }
}
