import AppKit
import LatchCore

/// Tracks the last app the user worked in (excluding Latch) so a session can pin it and the
/// user can snap back with ⌘G. Opening the menu bar popover activates Latch itself, so
/// `frontmostApplication` alone is not enough — we remember the previous activation.
@MainActor
final class WindowAnchorService {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var lastExternalApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    /// Called on every activation of an app other than Latch (Drift Guard listens here).
    var onExternalActivation: (@MainActor (NSRunningApplication) -> Void)?

    init() {
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            lastExternalApp = front
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app, !self.isSelf(app) else { return }
                self.lastExternalApp = app
                self.onExternalActivation?(app)
            }
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func captureFrontmost() -> PinnedApp? {
        let front = NSWorkspace.shared.frontmostApplication
        let candidate = (front.map { !isSelf($0) } ?? false) ? front : lastExternalApp
        guard let app = candidate, !app.isTerminated else { return nil }
        return PinnedApp(
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? "App",
            processIdentifier: app.processIdentifier)
    }

    func icon(for pinned: PinnedApp) -> NSImage? {
        if let app = runningApp(for: pinned) { return app.icon }
        guard let id = pinned.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func refocus(_ pinned: PinnedApp) {
        if let app = runningApp(for: pinned) {
            app.activate(options: [.activateAllWindows])
        } else if let id = pinned.bundleIdentifier,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// `true` when `app` is the pinned app, matched by process, or by bundle id after a relaunch.
    func matches(_ app: NSRunningApplication, _ pinned: PinnedApp) -> Bool {
        if app.processIdentifier == pinned.processIdentifier { return true }
        guard let id = pinned.bundleIdentifier else { return false }
        return app.bundleIdentifier == id
    }

    private func runningApp(for pinned: PinnedApp) -> NSRunningApplication? {
        if let app = NSRunningApplication(processIdentifier: pinned.processIdentifier), !app.isTerminated {
            return app
        }
        guard let id = pinned.bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ownPID
    }
}
