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
