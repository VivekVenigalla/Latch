import Foundation

/// The app the user was working in when they latched, so they can snap back to it.
public struct PinnedApp: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var name: String
    public var processIdentifier: Int32

    public init(bundleIdentifier: String?, name: String, processIdentifier: Int32) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.processIdentifier = processIdentifier
    }
}

/// A locked focus session. Time is tracked as wall-clock timestamps, never as a decremented
/// counter, so App Nap and sleep/wake cannot cause drift.
public struct ActiveSession: Equatable, Sendable {
    public var task: TaskCandidate
    public var requestedSeconds: Int
    public var allocatedSeconds: Int
    public var startedAt: Date
    public var targetEndDate: Date
    public var clampReason: String?
    public var pinnedApp: PinnedApp?
    /// Set when the session is unlatched; freezes elapsed time for the state-dump gate.
    public var pausedAt: Date?

    public init(
        task: TaskCandidate,
        requestedSeconds: Int,
        allocatedSeconds: Int,
        clampReason: String? = nil,
        pinnedApp: PinnedApp? = nil,
        now: Date = .now
    ) {
        self.task = task
        self.requestedSeconds = requestedSeconds
        self.allocatedSeconds = allocatedSeconds
        self.startedAt = now
        self.targetEndDate = now.addingTimeInterval(TimeInterval(allocatedSeconds))
        self.clampReason = clampReason
        self.pinnedApp = pinnedApp
    }

    public var isClamped: Bool { clampReason != nil }

    /// Seconds spent in this session (frozen once paused).
    public func sessionElapsedSeconds(at now: Date = .now) -> Int {
        Int(max(0, (pausedAt ?? now).timeIntervalSince(startedAt)))
    }

    /// Lifetime elapsed: previously logged `elapsed_sec` plus this session.
    public func totalElapsedSeconds(at now: Date = .now) -> Int {
        (task.metadata.elapsedSec ?? 0) + sessionElapsedSeconds(at: now)
    }

    /// 1.0 at latch, 0.0 at expiry.
    public func progressRemaining(remainingSeconds: TimeInterval) -> Double {
        guard allocatedSeconds > 0 else { return 0 }
        return min(1, max(0, remainingSeconds / TimeInterval(allocatedSeconds)))
    }
}
