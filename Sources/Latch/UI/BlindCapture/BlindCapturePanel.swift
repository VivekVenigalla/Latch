import AppKit
import LatchCore
import SwiftUI

/// A floating, non-activating panel. Because it never activates Latch, the app the user was
/// working in stays frontmost; hiding the panel hands keyboard focus straight back to it.
final class BlindCapturePanel: NSPanel {
    static let size = NSSize(width: 480, height: 52)

    var onResignKey: (() -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        level = .floating
        // Appear over fullscreen IDEs/browsers without triggering a Space swipe.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    // Borderless panels refuse key status by default; the text field needs it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class BlindCaptureModel: ObservableObject {
    @Published var text = "" {
        didSet { parsed = BlindCaptureNLPParser.parse(text, knownLists: knownLists) }
    }
    @Published private(set) var parsed = CaptureParse(title: "")
    /// Bumped on every show so the view re-focuses its field.
    @Published private(set) var focusToken = 0
    var knownLists: [String] = []

    func prepareForShow(knownLists: [String]) {
        self.knownLists = knownLists
        text = ""
        focusToken += 1
    }
}

/// Owns the panel lifecycle: ⌘⇧Space → type → ↩ saves to Reminders, Esc / click-away discards.
@MainActor
final class BlindCaptureController {
    private let panel = BlindCapturePanel()
    private let model = BlindCaptureModel()
    private let eventKit: EventKitService

    init(eventKit: EventKitService) {
        self.eventKit = eventKit
        let root = BlindCaptureView(
            model: model,
            onSubmit: { [weak self] in self?.submit() },
            onCancel: { [weak self] in self?.hide() })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: BlindCapturePanel.size)
        panel.contentView = hosting
        panel.onResignKey = { [weak self] in self?.hide() }
        panel.onCancel = { [weak self] in self?.hide() }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        guard eventKit.remindersAuthorized else {
            NSSound.beep()
            return
        }
        model.prepareForShow(knownLists: eventKit.reminderLists().map(\.title))
        position()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        model.text = ""
    }

    private func submit() {
        let capture = BlindCaptureNLPParser.parse(model.text, knownLists: model.knownLists)
        guard !capture.title.isEmpty else {
            NSSound.beep()
            return
        }
        do {
            try eventKit.createReminder(from: capture)
            hide()
        } catch {
            NSLog("Latch: blind capture failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    /// Horizontally centred, upper third of the screen under the mouse (Spotlight-style).
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = BlindCapturePanel.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + frame.height * 0.70 - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}
