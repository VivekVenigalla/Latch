import AppKit
import Combine
import EventKit
import LatchCore

struct MicroStep: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isDone = false
}

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
    /// UserDefaults key: when `true`, hitting 00:00 goes straight to the state-dump gate
    /// instead of counting up in amber overtime ("Soft Box", the default).
    static let hardStopDefaultsKey = "LatchHardStop"
    /// UserDefaults key: Drift Guard grace period in seconds (default 20).
    static let driftGraceDefaultsKey = "LatchDriftGraceSeconds"
    /// UserDefaults key: when `true`, Drift Guard ignores app switches entirely.
    static let driftGuardDisabledDefaultsKey = "LatchDriftGuardDisabled"

    static let durationStepSeconds = 300
    static let minDurationSeconds = 300
    static let maxDurationSeconds = 3 * 3600
    static let maxMicroSteps = 3

    @Published private(set) var state: AppState = .permissionsRequired
    /// `targetEndDate.timeIntervalSinceNow`, refreshed every 0.5s while latched. Negative = overtime.
    @Published private(set) var remainingSeconds: TimeInterval = 0
    @Published private(set) var selectedDurationSec = TaskCandidate.defaultDurationSec
    /// Preview of the calendar clamp for the current candidate and selected duration.
    @Published private(set) var clampPreview: ClampResult?
    @Published private(set) var microSteps: [MicroStep] = []
    /// Drift Guard: away from the pinned app for longer than the grace period.
    @Published private(set) var isDrifting = false
    /// Length of the current excursion away from the pinned app (0 when on it).
    @Published private(set) var driftExcursionSeconds: TimeInterval = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var lastError: String?

    let eventKit: EventKitService
    let anchor: WindowAnchorService

    private var candidates: [TaskCandidate] = []
    /// In-memory deferral counts for `Cycle [⇥]`; cleared each time a task is latched.
    private var sessionSkipCounts: [String: Int] = [:]
    private var upcomingBlocks: [CalendarBlock] = []
    private var ticker: Timer?
    private var timerActivity: NSObjectProtocol?
    private var hasChimed = false
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
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        })
        anchor.onExternalActivation = { [weak self] app in
            self?.appDidActivate(app)
        }
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

    /// Current Shutter glyph geometry, shared by the menu bar and the popover.
    var shutter: ShutterLayout {
        switch state {
        case let .latchedFocus(session):
            if remainingSeconds < 0 {
                return ShutterLayout(phase: .overtime, overtimeSeconds: -remainingSeconds)
            }
            // Drifting blinks the bolt hollow on alternate seconds: a peripheral nudge, not an alarm.
            let blinkOff = isDrifting && Int(Date.now.timeIntervalSince1970) % 2 == 0
            return ShutterLayout(
                phase: blinkOff ? .drifting : (session.isClamped ? .clamped : .running),
                remainingFraction: session.progressRemaining(remainingSeconds: remainingSeconds))
        case let .stateDumpGate(session):
            let remainingAtPause = session.targetEndDate.timeIntervalSince(session.pausedAt ?? .now)
            return ShutterLayout(phase: .paused, remainingFraction: session.progressRemaining(remainingSeconds: remainingAtPause))
        case .permissionsRequired, .unlatchedSelector:
            return ShutterLayout(phase: .idle)
        }
    }

    /// Truncated task title shown beside the menu bar glyph, if any.
    var shutterTitle: String? {
        switch state {
        case let .latchedFocus(session), let .stateDumpGate(session):
            GlancePill.truncate(session.task.title)
        case .permissionsRequired, .unlatchedSelector:
            nil
        }
    }

    /// Text equivalent of the glyph, including the exact time (used for accessibility).
    var glanceText: String {
        switch state {
        case let .latchedFocus(session):
            GlancePill.latched(remainingSeconds: remainingSeconds, title: session.task.title)
                + (isDrifting ? " · drifting" : "")
        case let .stateDumpGate(session):
            GlancePill.paused(title: session.task.title)
        case .permissionsRequired, .unlatchedSelector:
            GlancePill.idle
        }
    }

    private var hardStopOnExpiry: Bool { UserDefaults.standard.bool(forKey: Self.hardStopDefaultsKey) }

    private var driftGraceSeconds: TimeInterval {
        (UserDefaults.standard.object(forKey: Self.driftGraceDefaultsKey) as? NSNumber)?.doubleValue
            ?? DriftLedger.defaultGraceSeconds
    }

    private var driftGuardEnabled: Bool { !UserDefaults.standard.bool(forKey: Self.driftGuardDisabledDefaultsKey) }

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
        case .latchedFocus where isOvertime:
            // Soft Box overtime ends the moment the user looks at Latch.
            unlatch()
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

    // MARK: - State 2: latchedFocus

    func latch() {
        guard let candidate = currentCandidate else { return }
        latch(onto: candidate)
    }

    func latch(onto candidate: TaskCandidate) {
        let now = Date.now
        let requested = selectedDurationSec
        let blocks = eventKit.calendarBlocks(
            from: now, to: now.addingTimeInterval(TimeInterval(requested) + CalendarClamp.bufferSeconds))
        let clamp = CalendarClamp.clamp(requestedSeconds: requested, now: now, events: blocks)

        let session = ActiveSession(
            task: candidate,
            requestedSeconds: requested,
            allocatedSeconds: clamp.allocatedSeconds,
            clampReason: clamp.reason,
            pinnedApp: anchor.captureFrontmost(),
            driftGraceSeconds: driftGraceSeconds,
            now: now)

        sessionSkipCounts.removeAll()
        microSteps.removeAll()
        hasChimed = false
        state = .latchedFocus(activeTask: session)
        startTicker()

        persist(id: candidate.id) { metadata in
            metadata.durationSec = requested
            metadata.lastLatched = now
        }
    }

    /// Drift Guard: every app switch while latched either starts or ends an excursion.
    private func appDidActivate(_ app: NSRunningApplication) {
        guard driftGuardEnabled, case var .latchedFocus(session) = state, let pinned = session.pinnedApp else { return }
        let now = Date.now
        if anchor.matches(app, pinned) {
            session.drift.returnToAnchor(at: now)
        } else {
            session.drift.leave(at: now)
        }
        state = .latchedFocus(activeTask: session)
        tick()
    }

    func refocusPinnedApp() {
        guard case let .latchedFocus(session) = state, let pinned = session.pinnedApp else { return }
        anchor.refocus(pinned)
    }

    func addMicroStep(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, microSteps.count < Self.maxMicroSteps else { return }
        microSteps.append(MicroStep(text: trimmed))
    }

    func toggleMicroStep(_ id: MicroStep.ID) {
        guard let index = microSteps.firstIndex(where: { $0.id == id }) else { return }
        microSteps[index].isDone.toggle()
    }

    /// `Complete [⌘↩]` — valid from focus and from the state-dump gate.
    func complete() {
        let session: ActiveSession
        switch state {
        case let .latchedFocus(s), let .stateDumpGate(s): session = s
        default: return
        }
        stopTicker()

        do {
            try eventKit.updateReminder(id: session.task.id) { reminder in
                var metadata = LatchMetadataParser.parse(reminder.notes).metadata ?? LatchMetadata()
                metadata.elapsedSec = session.totalElapsedSeconds()
                Self.accrueDrift(of: session, into: &metadata)
                reminder.notes = LatchMetadataParser.write(metadata, into: reminder.notes)
                reminder.isCompleted = true
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        if let tick = NSSound(named: "Pop") {
            tick.volume = 0.35
            tick.play()
        }
        returnToSelector(removing: session.task.id)
    }

    /// `Unlatch [⌘.]` — pauses the clock and forces the state-dump gate.
    func unlatch() {
        guard case var .latchedFocus(session) = state else { return }
        stopTicker()
        let now = Date.now
        session.pausedAt = now
        session.drift.returnToAnchor(at: now)
        clearDriftReadout()
        state = .stateDumpGate(completedSession: session)
    }

    private func startTicker() {
        stopTicker()
        // Keep the 0.5s cadence honest while the app is backgrounded; the math is wall-clock anyway.
        timerActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "Latch focus timer")
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        if let timerActivity { ProcessInfo.processInfo.endActivity(timerActivity) }
        timerActivity = nil
    }

    private func tick() {
        guard case let .latchedFocus(session) = state else { return }
        remainingSeconds = session.targetEndDate.timeIntervalSinceNow
        isDrifting = session.drift.isDrifting(at: .now)
        driftExcursionSeconds = session.drift.currentExcursion(at: .now)
        if remainingSeconds <= 0, !hasChimed {
            hasChimed = true
            NSSound(named: "Tink")?.play()
            if hardStopOnExpiry { unlatch() }
        }
    }

    // MARK: - State 3: stateDumpGate

    /// Logs the next physical action and releases the lock. Returns `false` if `note` is blank.
    @discardableResult
    func commitContext(_ note: String) -> Bool {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, case let .stateDumpGate(session) = state else { return false }

        persist(id: session.task.id) { metadata in
            metadata.context = trimmed
            metadata.elapsedSec = session.totalElapsedSeconds()
            metadata.deferredCount = (metadata.deferredCount ?? 0) + 1
            Self.accrueDrift(of: session, into: &metadata)
        }
        if let index = candidates.firstIndex(where: { $0.id == session.task.id }) {
            candidates[index].metadata.context = trimmed
            candidates[index].metadata.elapsedSec = session.totalElapsedSeconds()
            Self.accrueDrift(of: session, into: &candidates[index].metadata)
        }
        // Surface something else first; the deferred task comes back on the next cycle.
        sessionSkipCounts[session.task.id, default: 0] += 1
        returnToSelector(removing: nil)
        return true
    }

    // MARK: - Helpers

    private func returnToSelector(removing completedID: String?) {
        if let completedID { candidates.removeAll { $0.id == completedID } }
        microSteps.removeAll()
        remainingSeconds = 0
        clearDriftReadout()
        state = .unlatchedSelector(candidate: nil, filterMode: .all)
        resolve(filter: .all)
        scheduleRefresh(delayNanoseconds: 0)
    }

    /// Adds this session's drift to the lifetime `drift_sec`; writes nothing for a clean session.
    private static func accrueDrift(of session: ActiveSession, into metadata: inout LatchMetadata) {
        let drift = session.driftSeconds()
        guard drift > 0 else { return }
        metadata.driftSec = (metadata.driftSec ?? 0) + drift
    }

    private func clearDriftReadout() {
        isDrifting = false
        driftExcursionSeconds = 0
    }

    private func persist(id: String, _ mutate: @escaping (inout LatchMetadata) -> Void) {
        do {
            try eventKit.updateMetadata(id: id, mutate)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func storeDidChange() {
        switch state {
        case let .latchedFocus(session):
            // Completed on another device (e.g. iPhone): release the lock without a state dump.
            if eventKit.isReminderGone(id: session.task.id) {
                stopTicker()
                returnToSelector(removing: session.task.id)
            }
        case .stateDumpGate:
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
