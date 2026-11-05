import Foundation

/// What Workspace restore will do: launch assigned apps that aren't running, and open assigned
/// sites that no open tab is already on. Restoring twice never duplicates anything.
public struct RestorePlan: Equatable, Sendable {
    public var appsToLaunch: [String]
    public var sitesToOpen: [URL]

    public init(appsToLaunch: [String] = [], sitesToOpen: [URL] = []) {
        self.appsToLaunch = appsToLaunch
        self.sitesToOpen = sitesToOpen
    }

    public var isEmpty: Bool { appsToLaunch.isEmpty && sitesToOpen.isEmpty }

    public static func make(for workspace: Workspace, runningApps: Set<String>, openTabs: [URL]) -> RestorePlan {
        let openHosts = openTabs.compactMap(Workspace.normalizedHost)
        let sites = workspace.siteURLs.filter { url in
            guard let host = Workspace.normalizedHost(url) else { return false }
            return !openHosts.contains { Workspace.host($0, isWithin: host) }
        }
        return RestorePlan(
            appsToLaunch: workspace.appBundleIDs.filter { !runningApps.contains($0) },
            sitesToOpen: sites)
    }
}
