import AppKit
import Combine
import LatchCore
import SwiftUI

/// Owns Latch's menu bar presence with AppKit rather than `MenuBarExtra`:
///
/// - the Deadbolt glyph is a template image and the time/title are a native attributed title,
///   so the item looks and tints like the system's own;
/// - `autosaveName` keeps the position the user ⌘-drags it to (for example, away from the notch);
/// - the popover lives in a `PopoverPanel` anchored under the item;
/// - right-click (or control-click) opens a native menu of the current state's actions;
/// - when macOS hides the item (behind the notch, or crowded out), it collapses to the glyph and
///   time, then periodically retries the full width.
@MainActor
final class StatusItemController: NSObject {
    private let engine: LatchEngine
    private let onCapture: () -> Void
    private let statusItem: NSStatusItem
    private let hosting: NSHostingController<AnyView>
    private let panel: PopoverPanel
    private var cancellables = Set<AnyCancellable>()
    private var renderedLayout: DeadboltLayout?
    private var renderedTitle: NSAttributedString?
    /// Clicking the item while the panel is open resigns the panel first; this stops that
    /// same click from immediately reopening it.
    private var lastResignClose = Date.distantPast
    /// Title dropped because the full-width item was hidden.
    private var isCompact = false
    private var retryTimer: Timer?
    private static let compactRetryInterval: TimeInterval = 300

    init(engine: LatchEngine, onCapture: @escaping () -> Void) {
        self.engine = engine
        self.onCapture = onCapture
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hosting = NSHostingController(rootView: AnyView(RootPopoverView().environmentObject(engine)))
        panel = PopoverPanel(content: hosting)
        super.init()

        statusItem.autosaveName = "LatchStatusItem"
        statusItem.behavior = []
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageHugsTitle = true
        }

        panel.onResignKey = { [weak self] in self?.closePanel(returningFocus: false) }
        panel.onCancel = { [weak self] in self?.closePanel(returningFocus: true) }

        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)
            .filter { [weak self] note in (note.object as? NSWindow) === self?.statusItem.button?.window }
            .sink { [weak self] _ in self?.checkVisibility() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.retryFullWidth() }
            .store(in: &cancellables)
        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        guard let button = statusItem.button else { return }

        let layout = engine.deadbolt
        if layout != renderedLayout {
            button.image = DeadboltRenderer.image(for: layout)
            renderedLayout = layout
        }

        if engine.tokenTime == nil { setCompact(false) }
        let title = tokenTitle()
        if title != renderedTitle {
            button.attributedTitle = title
            button.imagePosition = title.length == 0 ? .imageOnly : .imageLeading
            renderedTitle = title
            // Measure after the status bar has laid out the new width.
            DispatchQueue.main.async { [weak self] in self?.checkVisibility() }
        }

        button.setAccessibilityLabel(engine.glanceText)
        if panel.isVisible { fitPanel() }
    }

    /// ` 18m  Fix auth token` — semibold tabular time, regular title.
    private func tokenTitle() -> NSAttributedString {
        guard let time = engine.tokenTime else { return NSAttributedString() }
        let result = NSMutableAttributedString(string: " " + time, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ])
        if !isCompact, let title = engine.tokenTitle {
            result.append(NSAttributedString(string: "  " + title, attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        return result
    }

    // MARK: - Staying visible

    /// `false` when macOS isn't showing the item: occluded, or outside the usable menu bar
    /// area on a notched display (items that don't fit are parked behind the notch).
    private var isItemVisible: Bool {
        guard let window = statusItem.button?.window, let screen = window.screen else { return false }
        guard window.occlusionState.contains(.visible) else { return false }
        guard let rightOfNotch = screen.auxiliaryTopRightArea else { return true }
        // The auxiliary areas may be screen-local; shift them into global space if so.
        let offset = rightOfNotch.maxX <= screen.frame.width + 0.5 ? screen.frame.minX : 0
        let frame = window.frame
        return frame.minX >= rightOfNotch.minX + offset - 1 && frame.maxX <= rightOfNotch.maxX + offset + 1
    }

    private func checkVisibility() {
        guard engine.tokenTitle != nil, !isCompact, !isItemVisible else { return }
        setCompact(true)
        refresh()
    }

    /// Try the full title again; `checkVisibility` collapses it straight back if it doesn't fit.
    private func retryFullWidth() {
        guard isCompact else { return }
        setCompact(false)
        refresh()
    }

    private func setCompact(_ compact: Bool) {
        guard compact != isCompact else { return }
        isCompact = compact
        retryTimer?.invalidate()
        retryTimer = nil
        guard compact else { return }
        let timer = Timer(timeInterval: Self.compactRetryInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryFullWidth() }
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
    }

    // MARK: - Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePanel()
        }
    }

    // MARK: - Menu

    private var session: ActiveSession? {
        switch engine.state {
        case let .latchedFocus(session), let .stateDumpGate(session): session
        case .permissionsRequired, .unlatchedSelector: nil
        }
    }

    private func showMenu() {
        closePanel(returningFocus: false)
        // Attach the menu only for this click, so a left click still opens the popover.
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(item("Open Latch", #selector(openFromMenu)))
        let isLatched: Bool
        if case .latchedFocus = engine.state { isLatched = true } else { isLatched = false }
        menu.addItem(item("Complete", #selector(completeFromMenu), key: "\r", enabled: session != nil))
        menu.addItem(item("Unlatch", #selector(unlatchFromMenu), key: ".", enabled: isLatched))
        if let pinned = session?.pinnedApp {
            menu.addItem(item("Refocus \(pinned.name)", #selector(refocusFromMenu), key: "g", enabled: isLatched))
        }
        menu.addItem(.separator())
        menu.addItem(item("Capture…", #selector(captureFromMenu), key: " ", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Quit Latch", #selector(quitFromMenu), key: "q"))
        return menu
    }

    private func item(
        _ title: String,
        _ action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        item.target = self
        item.isEnabled = enabled
        return item
    }

    /// `Latched · 18m left`, `Paused · log your next step`, or `Not latched`.
    private func statusLine() -> String {
        switch engine.state {
        case .latchedFocus:
            if engine.isOvertime { return "Overtime · " + MenuBarToken.timeLabel(remainingSeconds: engine.remainingSeconds) }
            return "Latched · " + MenuBarToken.timeLabel(remainingSeconds: engine.remainingSeconds) + " left"
        case .stateDumpGate: return "Paused · log your next step"
        case .permissionsRequired: return "Reminders access needed"
        case .unlatchedSelector: return "Not latched"
        }
    }

    @objc private func openFromMenu() { if !panel.isVisible { openPanel() } }
    @objc private func completeFromMenu() { engine.complete() }
    @objc private func unlatchFromMenu() {
        engine.unlatch()
        openPanel() // the state dump needs an answer
    }
    @objc private func refocusFromMenu() { engine.refocusPinnedApp() }
    @objc private func captureFromMenu() { onCapture() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }

    func togglePanel() {
        if panel.isVisible {
            closePanel(returningFocus: true)
            return
        }
        guard Date.now.timeIntervalSince(lastResignClose) > 0.25 else { return }
        openPanel()
    }

    private func openPanel() {
        fitPanel()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
    }

    private func closePanel(returningFocus: Bool) {
        guard panel.isVisible else { return }
        if !returningFocus { lastResignClose = .now }
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        // Hand the keyboard back to the app the user was in (Esc or a second click).
        if returningFocus, NSApp.isActive { NSApp.hide(nil) }
    }

    private func fitPanel() {
        let fitting = hosting.view.fittingSize
        let size = NSSize(
            width: Tokens.popoverWidth,
            height: min(max(fitting.height, Tokens.popoverMinHeight), Tokens.popoverMaxHeight))
        panel.setFrame(NSRect(origin: anchorOrigin(for: size), size: size), display: true)
    }

    /// Centred under the item, kept on screen; top-centre of the screen if the item isn't placed.
    private func anchorOrigin(for size: NSSize) -> NSPoint {
        if let button = statusItem.button, let window = button.window, let screen = window.screen {
            let itemRect = window.convertToScreen(button.convert(button.bounds, to: nil))
            let visible = screen.visibleFrame
            let x = min(max(itemRect.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
            return NSPoint(x: x, y: itemRect.minY - size.height - 5)
        }
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8)
    }
}
