import EventKit
import Foundation

/// A value-type snapshot of an `EKReminder` plus its parsed Latch metadata.
/// The engine never holds `EKReminder` objects across state transitions; it re-fetches by `id`.
public struct TaskCandidate: Identifiable, Equatable, Sendable {
    public static let defaultDurationSec = 1500

    /// `EKReminder.calendarItemIdentifier`.
    public let id: String
    public var title: String
    /// Raw `EKReminder.priority` (0 = none, 1-4 high, 5 medium, 6-9 low).
    public var priority: Int
    public var dueDate: Date?
    public var listTitle: String?
    public var userNotes: String
    public var metadata: LatchMetadata
    /// Last score assigned by `CandidateScorer.resolve`.
    public var score: Double

    public init(
        id: String,
        title: String,
        priority: Int = 0,
        dueDate: Date? = nil,
        listTitle: String? = nil,
        userNotes: String = "",
        metadata: LatchMetadata = LatchMetadata(),
        score: Double = 0
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.listTitle = listTitle
        self.userNotes = userNotes
        self.metadata = metadata
        self.score = score
    }

    public init(reminder: EKReminder) {
        let parsed = LatchMetadataParser.parse(reminder.notes)
        self.init(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "Untitled",
            priority: reminder.priority,
            dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
            listTitle: reminder.calendar?.title,
            userNotes: parsed.userNotes,
            metadata: parsed.metadata ?? LatchMetadata()
        )
    }

    public var durationSec: Int { metadata.durationSec ?? Self.defaultDurationSec }

    public var priorityBand: PriorityBand { PriorityBand(ekPriority: priority) }
}

public enum PriorityBand: Equatable, Sendable {
    case high, medium, low, none

    public init(ekPriority: Int) {
        switch ekPriority {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }
}
