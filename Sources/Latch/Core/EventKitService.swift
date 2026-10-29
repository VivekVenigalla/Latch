import EventKit
import Foundation
import LatchCore

enum LatchError: LocalizedError {
    case reminderMissing
    case noDefaultList

    var errorDescription: String? {
        switch self {
        case .reminderMissing: "That reminder no longer exists."
        case .noDefaultList: "No default Reminders list is configured."
        }
    }
}

/// Thin wrapper over `EKEventStore`. Native EventKit only — never AppleScript/JXA.
@MainActor
final class EventKitService {
    /// Optional UserDefaults key: restrict the candidate queue to one Reminders list by title.
    static let targetListDefaultsKey = "LatchTargetList"

    let store = EKEventStore()

    // MARK: Authorization

    var remindersAuthorized: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    var eventsAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    var remindersDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return status == .denied || status == .restricted
    }

    /// Requests Reminders (required) and Calendar (optional, enables clamping) access.
    /// Returns whether Reminders access was granted.
    func requestAccess() async -> Bool {
        let reminders = (try? await store.requestFullAccessToReminders()) ?? false
        _ = try? await store.requestFullAccessToEvents()
        store.refreshSourcesIfNecessary()
        return reminders
    }

    // MARK: Reminders

    func reminderLists() -> [EKCalendar] {
        guard remindersAuthorized else { return [] }
        return store.calendars(for: .reminder)
    }

    private func list(named title: String?) -> EKCalendar? {
        guard let title else { return nil }
        return reminderLists().first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    /// `nil` means all lists.
    private func targetCalendars() -> [EKCalendar]? {
        guard let title = UserDefaults.standard.string(forKey: Self.targetListDefaultsKey),
              let calendar = list(named: title) else { return nil }
        return [calendar]
    }

    func fetchCandidates() async -> [TaskCandidate] {
        guard remindersAuthorized else { return [] }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: targetCalendars())
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                // Convert to value types on EventKit's queue; EKReminder must not cross actors.
                continuation.resume(returning: (reminders ?? []).map(TaskCandidate.init(reminder:)))
            }
        }
    }

    func reminder(id: String) -> EKReminder? {
        store.calendarItem(withIdentifier: id) as? EKReminder
    }

    /// `true` when the reminder was completed or deleted outside Latch.
    func isReminderGone(id: String) -> Bool {
        guard let reminder = reminder(id: id) else { return true }
        return reminder.isCompleted
    }

    /// Fetches the reminder fresh from the store, applies `mutate`, and commits.
    func updateReminder(id: String, _ mutate: (EKReminder) -> Void) throws {
        guard let reminder = reminder(id: id) else { throw LatchError.reminderMissing }
        mutate(reminder)
        try store.save(reminder, commit: true)
    }

    /// Updates only the `---LATCH---` block, leaving the user's notes untouched.
    func updateMetadata(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) throws {
        try updateReminder(id: id) { reminder in
            var metadata = LatchMetadataParser.parse(reminder.notes).metadata ?? LatchMetadata()
            mutate(&metadata)
            reminder.notes = LatchMetadataParser.write(metadata, into: reminder.notes)
        }
    }

    func createReminder(from capture: CaptureParse) throws {
        let reminder = EKReminder(eventStore: store)
        reminder.title = capture.title
        guard let calendar = list(named: capture.listName) ?? store.defaultCalendarForNewReminders() else {
            throw LatchError.noDefaultList
        }
        reminder.calendar = calendar
        if let priority = capture.priority { reminder.priority = priority.ekPriority }
        if let duration = capture.durationSec {
            reminder.notes = LatchMetadataParser.write(LatchMetadata(durationSec: duration), into: nil)
        }
        try store.save(reminder, commit: true)
    }
}
