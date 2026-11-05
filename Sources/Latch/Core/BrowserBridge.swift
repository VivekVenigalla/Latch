import AppKit
import LatchCore

/// Reads browser tabs over Apple Events. macOS asks once per browser for Automation permission
/// (System Settings → Privacy & Security → Automation). Scripts run on a private serial queue so
/// a slow browser can never stall the UI, and only against browsers that are already running.
final class BrowserBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.latch.browser-bridge", qos: .userInitiated)

    /// The active tab's URL in the front window, or `nil` (not running, no window, no permission).
    func activeTabURL(of browser: SupportedBrowser) async -> URL? {
        guard await Self.isRunning(browser) else { return nil }
        let output = await run(browser.activeTabURLScript)
        return output.flatMap { SupportedBrowser.urls(fromScriptOutput: $0).first }
    }

    /// Every open tab's URL across the given browsers that are running.
    func openTabURLs(in browsers: [SupportedBrowser]) async -> [URL] {
        var urls: [URL] = []
        for browser in browsers where await Self.isRunning(browser) {
            if let output = await run(browser.allTabURLsScript) {
                urls += SupportedBrowser.urls(fromScriptOutput: output)
            }
        }
        return urls
    }

    @MainActor
    private static func isRunning(_ browser: SupportedBrowser) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID).isEmpty
    }

    private func run(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    NSLog("Latch: browser script failed: \(error[NSAppleScript.errorMessage] ?? error)")
                }
                continuation.resume(returning: result?.stringValue)
            }
        }
    }
}
