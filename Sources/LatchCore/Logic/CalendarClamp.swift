import Foundation

/// A value-type snapshot of an `EKEvent`, enough to decide whether it blocks a focus session.
public struct CalendarBlock: Equatable, Sendable {
    public var start: Date
    public var title: String?
    public var isAllDay: Bool
    /// `EKEvent.availability == .free`.
    public var isFree: Bool

    public init(start: Date, title: String?, isAllDay: Bool = false, isFree: Bool = false) {
        self.start = start
        self.title = title
        self.isAllDay = isAllDay
        self.isFree = isFree
    }

    public var blocksFocus: Bool { !isAllDay && !isFree }
}

public struct ClampResult: Equatable, Sendable {
    public var requestedSeconds: Int
    public var allocatedSeconds: Int
    /// Present only when the session was clamped.
    public var event: CalendarBlock?

    public var isClamped: Bool { event != nil }

    public var reason: String? {
        event.map { "Clamped for \($0.title ?? "Event")" }
    }
}

/// Calendar-aware time compression: never let a focus session run into a meeting.
public enum CalendarClamp {
    /// Reserved before every meeting.
    public static let bufferSeconds: TimeInterval = 300
    /// Minimum workable window; anything shorter is not clamped.
    public static let minimumWindowSeconds: TimeInterval = 300

    public static func nextBlockingEvent(_ events: [CalendarBlock], after now: Date) -> CalendarBlock? {
        events
            .filter { $0.blocksFocus && $0.start > now }
            .min { $0.start < $1.start }
    }

    public static func clamp(requestedSeconds: Int, now: Date, events: [CalendarBlock]) -> ClampResult {
        let unclamped = ClampResult(requestedSeconds: requestedSeconds, allocatedSeconds: requestedSeconds, event: nil)
        guard let event = nextBlockingEvent(events, after: now) else { return unclamped }

        let availableWindow = event.start.timeIntervalSince(now) - bufferSeconds
        guard availableWindow > minimumWindowSeconds, availableWindow < TimeInterval(requestedSeconds) else {
            return unclamped
        }
        return ClampResult(
            requestedSeconds: requestedSeconds,
            allocatedSeconds: Int(availableWindow.rounded(.down)),
            event: event)
    }
}
