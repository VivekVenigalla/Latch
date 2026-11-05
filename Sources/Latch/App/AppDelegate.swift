import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine: LatchEngine
    private var hotkey: GlobalHotkeyManager?
    private var capture: BlindCaptureController?
    private var statusItem: StatusItemController?

    override init() {
        // Demo mode (a launch argument) runs on sample data and an in-memory ledger.
        engine = DemoMode.isActive
            ? LatchEngine(store: DemoTaskStore(), ledger: LedgerStore(defaults: nil))
            : LatchEngine(store: EventKitService(), ledger: LedgerStore())
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this also keeps `swift run` out of the Dock.
        NSApp.setActivationPolicy(.accessory)

        let capture = BlindCaptureController(store: engine.store)
        self.capture = capture
        statusItem = StatusItemController(
            engine: engine,
            autosaveName: DemoMode.isActive ? "LatchDemoStatusItem" : "LatchStatusItem"
        ) { capture.show() }

        if DemoMode.isActive {
            Task { await engine.bootstrap() }
            return
        }

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
