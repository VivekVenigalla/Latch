import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = LatchEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this also keeps `swift run` out of the Dock.
        NSApp.setActivationPolicy(.accessory)

        Task { await engine.bootstrap() }
    }
}
