import Foundation

public enum FilterMode: Equatable, Sendable {
    case all
    /// Only tasks with `duration_sec <= 900`.
    case quick

    public static let quickLimitSeconds = 900

    public func admits(_ candidate: TaskCandidate) -> Bool {
        switch self {
        case .all: true
        case .quick: candidate.durationSec <= Self.quickLimitSeconds
        }
    }

    public var toggled: FilterMode { self == .all ? .quick : .all }
}

public enum AppState: Equatable, Sendable {
    case permissionsRequired
    case unlatchedSelector(candidate: TaskCandidate?, filterMode: FilterMode)
    case latchedFocus(activeTask: ActiveSession)
    case stateDumpGate(completedSession: ActiveSession)

    public enum Phase: Equatable, Sendable {
        case permissions, selector, focus, gate
    }

    /// Coarse identity used to drive view transitions.
    public var phase: Phase {
        switch self {
        case .permissionsRequired: .permissions
        case .unlatchedSelector: .selector
        case .latchedFocus: .focus
        case .stateDumpGate: .gate
        }
    }
}
