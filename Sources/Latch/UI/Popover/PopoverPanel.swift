import AppKit

/// The borderless panel that hosts the popover under the status item. It can become key (for
/// text fields and keyboard shortcuts), floats over fullscreen spaces, and closes when it loses
/// focus or on Esc — the same contract as a menu bar extra window.
final class PopoverPanel: NSPanel {
    var onResignKey: (() -> Void)?
    var onCancel: (() -> Void)?

    init(content: NSViewController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true)
        contentViewController = content
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

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
