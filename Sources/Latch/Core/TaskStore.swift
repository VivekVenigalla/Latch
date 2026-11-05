import Foundation
import LatchCore

/// Where Latch's tasks live. `EventKitService` is the real store (Apple Reminders and Calendar);
/// the engine and Blind Capture only ever talk to this protocol, so an in-memory store can
/// stand in for demos and screenshots without touching the user's data.
@MainActor
protocol TaskStore: AnyObject {
    var remindersAuthorized: Bool { get }
    var remindersDenied: Bool { get }
    /// Called on the main queue when tasks change outside Latch (for example, on iPhone).
    var onChange: (() -> Void)? { get set }

    func requestAccess() async -> Bool
    func fetchCandidates() async -> [TaskCandidate]
    func reminderListTitles() -> [String]
    /// `true` when the task was completed or deleted outside Latch.
    func isReminderGone(id: String) -> Bool
    /// Rewrites only the task's `---LATCH---` block.
    func updateMetadata(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) throws
    /// Applies a final metadata update and marks the task complete.
    func completeReminder(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) throws
    func createReminder(from capture: CaptureParse) throws
    /// Upcoming events overlapping `[start, end]`; empty without Calendar access.
    func calendarBlocks(from start: Date, to end: Date) -> [CalendarBlock]
}
