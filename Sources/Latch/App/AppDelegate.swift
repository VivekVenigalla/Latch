import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this also keeps `swift run` out of the Dock.
        NSApp.setActivationPolicy(.accessory)
    }
}
