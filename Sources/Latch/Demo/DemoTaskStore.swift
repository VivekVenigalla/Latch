import Foundation
import LatchCore

/// Launch-argument switches for demo mode:
///
///     open -n build/Latch.app --args -LatchDemoScene latched -LatchDemoReport /tmp/report.json
///
/// Demo mode never touches Reminders, Calendar, the real ledger or the global hotkey.
enum DemoMode {
    static let sceneKey = "LatchDemoScene"
    static let reportKey = "LatchDemoReport"

    static var scene: String? { UserDefaults.standard.string(forKey: sceneKey) }
    static var reportPath: String? { UserDefaults.standard.string(forKey: reportKey) }
    static var isActive: Bool { scene != nil }
}

/// An in-memory `TaskStore` with a small, believable backlog and one upcoming meeting.
@MainActor
final class DemoTaskStore: TaskStore {
    var onChange: (() -> Void)?
    var remindersAuthorized: Bool { true }
    var remindersDenied: Bool { false }

    private var tasks: [TaskCandidate]
    private var completedIDs: Set<String> = []

    init(now: Date = .now) {
        let authWorkspace = Workspace([
            .app(bundleID: "com.apple.dt.Xcode"),
            .app(bundleID: "com.apple.Terminal"),
            .site(url: URL(string: "https://github.com/acme/api/pull/42")!),
        ])
        tasks = [
            TaskCandidate(
                id: "demo-auth", title: "Fix auth token refresh", priority: 1,
                dueDate: now.addingTimeInterval(3 * 3600), listTitle: "Work",
                metadata: LatchMetadata(
                    durationSec: 1500, elapsedSec: 840,
                    context: "Check line 142 in AuthController.swift; exp claim missing",
                    deferredCount: 1, workspace: authWorkspace)),
            TaskCandidate(
                id: "demo-review", title: "Review PR #42", priority: 5,
                dueDate: now.addingTimeInterval(26 * 3600), listTitle: "Work",
                metadata: LatchMetadata(durationSec: 900)),
            TaskCandidate(id: "demo-planning", title: "Draft Q4 planning doc", listTitle: "Work"),
            TaskCandidate(
                id: "demo-dentist", title: "Book dentist appointment", priority: 9, listTitle: "Personal",
                metadata: LatchMetadata(durationSec: 600)),
        ]
    }

    func requestAccess() async -> Bool { true }

    func fetchCandidates() async -> [TaskCandidate] {
        tasks.filter { !completedIDs.contains($0.id) }
    }

    func reminderListTitles() -> [String] { ["Work", "Personal"] }

    func isReminderGone(id: String) -> Bool { completedIDs.contains(id) }

    func updateMetadata(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) throws {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { throw LatchError.reminderMissing }
        mutate(&tasks[index].metadata)
    }

    func completeReminder(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) throws {
        try updateMetadata(id: id, mutate)
        completedIDs.insert(id)
    }

    func createReminder(from capture: CaptureParse) throws {
        tasks.append(TaskCandidate(
            id: "demo-\(UUID().uuidString)", title: capture.title, priority: capture.priority?.ekPriority ?? 0,
            listTitle: capture.listName ?? "Work", metadata: LatchMetadata(durationSec: capture.durationSec)))
    }

    func calendarBlocks(from start: Date, to end: Date) -> [CalendarBlock] {
        let review = CalendarBlock(start: Date.now.addingTimeInterval(2 * 3600), title: "Design review")
        return review.start >= start && review.start <= end ? [review] : []
    }
}
