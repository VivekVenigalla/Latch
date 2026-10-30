import AppKit
import Combine
import LatchCore
import SwiftUI

/// Owns Latch's menu bar presence with AppKit rather than `MenuBarExtra`:
///
/// - the Deadbolt glyph is a template image and the time/title are a native attributed title,
///   so the item looks and tints like the system's own;
/// - `autosaveName` keeps the position the user ⌘-drags it to (for example, away from the notch);
/// - the popover lives in a `PopoverPanel` anchored under the item.
@MainActor
final class StatusItemController: NSObject {
    private let engine: LatchEngine
    private let statusItem: NSStatusItem
    private let hosting: NSHostingController<AnyView>
    private let panel: PopoverPanel
    private var cancellables = Set<AnyCancellable>()
    private var renderedLayout: DeadboltLayout?
    private var renderedTitle: NSAttributedString?
    /// Clicking the item while the panel is open resigns the panel first; this stops that
    /// same click from immediately reopening it.
    private var lastResignClose = Date.distantPast

    init(engine: LatchEngine) {
        self.engine = engine
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

        let title = tokenTitle()
        if title != renderedTitle {
            button.attributedTitle = title
            button.imagePosition = title.length == 0 ? .imageOnly : .imageLeading
            renderedTitle = title
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
        if let title = engine.tokenTitle {
            result.append(NSAttributedString(string: "  " + title, attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        return result
    }

    // MARK: - Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        togglePanel()
    }

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
