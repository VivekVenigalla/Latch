import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = LatchEngine()
    private var hotkey: GlobalHotkeyManager?
    private var capture: BlindCaptureController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this also keeps `swift run` out of the Dock.
        NSApp.setActivationPolicy(.accessory)

        statusItem = StatusItemController(engine: engine)

        let capture = BlindCaptureController(eventKit: engine.eventKit)
        self.capture = capture

        let hotkey = GlobalHotkeyManager(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)) {
            MainActor.assumeIsolated { capture.toggle() }
        }
        if !hotkey.register() {
            NSLog("Latch: could not register ⌘⇧Space; another app may own it.")
        }
        self.hotkey = hotkey

        Task { await engine.bootstrap() }
    }
}
