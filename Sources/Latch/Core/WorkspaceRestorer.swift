import AppKit
import LatchCore

/// Reopens a task's workspace: launches assigned apps that aren't running (in the background),
/// opens assigned sites no tab is already on, then brings the first assigned app forward.
@MainActor
final class WorkspaceRestorer {
    private let browsers: BrowserBridge

    init(browsers: BrowserBridge) {
        self.browsers = browsers
    }

    @discardableResult
    func restore(_ workspace: Workspace) async -> RestorePlan {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let openTabs = workspace.hasSites ? await browsers.openTabURLs(in: SupportedBrowser.allCases) : []
        let plan = RestorePlan.make(for: workspace, runningApps: running, openTabs: openTabs)

        let background = NSWorkspace.OpenConfiguration()
        background.activates = false
        for id in plan.appsToLaunch {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: background)
        }
        for site in plan.sitesToOpen {
            NSWorkspace.shared.open(site)
        }

        // Land in the first assigned app. LaunchServices activates it even if Latch lost focus.
        if let first = workspace.appBundleIDs.first,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: first) {
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        return plan
    }

    /// The app a restored session should be pinned to: the first assigned app, if any.
    static func pinnedApp(for workspace: Workspace) -> PinnedApp? {
        guard let id = workspace.appBundleIDs.first else { return nil }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first
        let name = running?.localizedName ?? WorkspaceItemIcon.name(.app(bundleID: id))
        // An app that isn't running yet has no pid; refocus falls back to the bundle id.
        return PinnedApp(bundleIdentifier: id, name: name, processIdentifier: running?.processIdentifier ?? 0)
    }
}
