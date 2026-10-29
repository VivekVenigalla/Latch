import AppKit
import Combine
import EventKit
import LatchCore

/// Deterministic finite-state machine for Latch:
///
///     permissionsRequired ─grant─▶ unlatchedSelector ─latch─▶ latchedFocus
///                                        ▲    ▲                 │      │
///                                        │    └──── complete ───┘      │ unlatch / expiry
///                                        └─ log context / complete ─ stateDumpGate
///
/// The user can never leave an incomplete task without passing through `stateDumpGate`.
@MainActor
final class LatchEngine: ObservableObject {
    static let durationStepSeconds = 300
    static let minDurationSeconds = 300
    static let maxDurationSeconds = 3 * 3600

    @Published private(set) var state: AppState = .permissionsRequired
    /// `targetEndDate.timeIntervalSinceNow`, refreshed every 0.5s while latched. Negative = overtime.
    @Published private(set) var remainingSeconds: TimeInterval = 0
    @Published private(set) var selectedDurationSec = TaskCandidate.defaultDurationSec
    /// Preview of the calendar clamp for the current candidate and selected duration.
    @Published private(set) var clampPreview: ClampResult?
    @Published private(set) var permissionDenied = false
    @Published private(set) var lastError: String?

    let eventKit: EventKitService
    let anchor: WindowAnchorService

    private var candidates: [TaskCandidate] = []
    /// In-memory deferral counts for `Cycle [⇥]`; cleared each time a task is latched.
    private var sessionSkipCounts: [String: Int] = [:]
    private var upcomingBlocks: [CalendarBlock] = []
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        eventKit = EventKitService()
        anchor = WindowAnchorService()

        observers.append(NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventKit.store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.storeDidChange() }
        })
    }

    // MARK: - Derived state

    var currentCandidate: TaskCandidate? {
        if case let .unlatchedSelector(candidate, _) = state { return candidate }
        return nil
    }

    var filterMode: FilterMode {
        if case let .unlatchedSelector(_, mode) = state { return mode }
        return .all
    }

    var isOvertime: Bool {
        if case .latchedFocus = state { return remainingSeconds < 0 }
        return false
    }

    var glanceText: String {
        switch state {
        case let .latchedFocus(session):
            GlancePill.latched(remainingSeconds: remainingSeconds, title: session.task.title)
        case let .stateDumpGate(session):
            GlancePill.paused(title: session.task.title)
        case .permissionsRequired, .unlatchedSelector:
            GlancePill.idle
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        if eventKit.remindersAuthorized {
            await refreshCandidates()
        } else {
            permissionDenied = eventKit.remindersDenied
            state = .permissionsRequired
        }
    }

    func requestPermissions() async {
        if await eventKit.requestAccess() {
            permissionDenied = false
            await refreshCandidates()
        } else {
            permissionDenied = true
        }
    }

    /// Called whenever the menu bar popover becomes key.
    func popoverDidOpen() {
        switch state {
        case .unlatchedSelector, .permissionsRequired:
            scheduleRefresh(delayNanoseconds: 0)
        case .latchedFocus, .stateDumpGate:
            break
        }
    }

    // MARK: - State 1: unlatchedSelector

    func refreshCandidates() async {
        guard eventKit.remindersAuthorized else {
            permissionDenied = eventKit.remindersDenied
            state = .permissionsRequired
            return
        }
        let fetched = await eventKit.fetchCandidates()
        let now = Date.now
        candidates = fetched
        upcomingBlocks = eventKit.calendarBlocks(from: now, to: now.addingTimeInterval(24 * 3600))

        // The user may have latched while EventKit was fetching; never clobber an active session.
        switch state {
        case .permissionsRequired: resolve(filter: .all)
        case let .unlatchedSelector(_, mode): resolve(filter: mode)
        case .latchedFocus, .stateDumpGate: break
        }
    }

    func cycle() {
        guard case let .unlatchedSelector(candidate?, mode) = state else { return }
        sessionSkipCounts[candidate.id, default: 0] += 1
        resolve(filter: mode)
    }

    func toggleQuickFilter() {
        guard case let .unlatchedSelector(_, mode) = state else { return }
        resolve(filter: mode.toggled)
    }

    /// Adjusts the selected duration in 5-minute steps.
    func adjustDuration(steps: Int) {
        guard currentCandidate != nil else { return }
        let next = selectedDurationSec + steps * Self.durationStepSeconds
        selectedDurationSec = min(Self.maxDurationSeconds, max(Self.minDurationSeconds, next))
        updateClampPreview()
    }

    private func resolve(filter: FilterMode) {
        let now = Date.now
        let nextEvent = CalendarClamp.nextBlockingEvent(upcomingBlocks, after: now)
        let previousID = currentCandidate?.id
        let pick = CandidateScorer.resolve(
            candidates,
            filter: filter,
            skipCounts: sessionSkipCounts,
            secondsUntilNextEvent: nextEvent.map { $0.start.timeIntervalSince(now) },
            now: now)
        state = .unlatchedSelector(candidate: pick, filterMode: filter)
        if pick?.id != previousID {
            selectedDurationSec = pick?.durationSec ?? TaskCandidate.defaultDurationSec
        }
        updateClampPreview()
    }

    private func updateClampPreview() {
        guard currentCandidate != nil else {
            clampPreview = nil
            return
        }
        let result = CalendarClamp.clamp(requestedSeconds: selectedDurationSec, now: .now, events: upcomingBlocks)
        clampPreview = result.isClamped ? result : nil
    }

    // MARK: - Helpers

    private func storeDidChange() {
        switch state {
        case .latchedFocus, .stateDumpGate:
            break
        case .unlatchedSelector, .permissionsRequired:
            scheduleRefresh()
        }
    }

    /// Coalesces bursts of `.EKEventStoreChanged` into one fetch.
    private func scheduleRefresh(delayNanoseconds: UInt64 = 300_000_000) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            guard !Task.isCancelled else { return }
            await self?.refreshCandidates()
        }
    }
}
