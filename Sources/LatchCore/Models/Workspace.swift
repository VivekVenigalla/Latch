import Foundation

/// Something a task may use without Drift Guard counting it as drift.
public enum WorkspaceItem: Hashable, Sendable {
    /// A whole app, by bundle identifier. Every window and tab in it counts.
    case app(bundleID: String)
    /// A website, kept as the page it was assigned from (so restore can reopen it) and matched
    /// by host, including subdomains.
    case site(url: URL)

    public var host: String? {
        if case let .site(url) = self { return Workspace.normalizedHost(url) }
        return nil
    }
}

/// The set of apps and sites assigned to one task.
public struct Workspace: Equatable, Sendable {
    public private(set) var items: [WorkspaceItem] = []

    public init(_ items: [WorkspaceItem] = []) {
        items.forEach { add($0) }
    }

    public var isEmpty: Bool { items.isEmpty }

    public var appBundleIDs: [String] {
        items.compactMap { if case let .app(id) = $0 { return id } else { return nil } }
    }

    public var siteURLs: [URL] {
        items.compactMap { if case let .site(url) = $0 { return url } else { return nil } }
    }

    /// Adds `item` unless it is already covered (same app, or a site on the same host).
    /// Returns `true` if the workspace changed.
    @discardableResult
    public mutating func add(_ item: WorkspaceItem) -> Bool {
        switch item {
        case let .app(id):
            guard !id.isEmpty, !containsApp(id) else { return false }
        case let .site(url):
            guard let host = Self.normalizedHost(url), !items.contains(where: { $0.host == host }) else { return false }
        }
        items.append(item)
        return true
    }

    /// Removes `item`; a site is removed by host. Returns `true` if the workspace changed.
    @discardableResult
    public mutating func remove(_ item: WorkspaceItem) -> Bool {
        let before = items.count
        switch item {
        case let .app(id): items.removeAll { $0 == .app(bundleID: id) }
        case .site: items.removeAll { $0.host != nil && $0.host == item.host }
        }
        return items.count != before
    }

    public func containsApp(_ bundleID: String) -> Bool {
        items.contains(.app(bundleID: bundleID))
    }

    /// `true` if `host` is an assigned site or one of its subdomains (`docs.github.com` ⊂ `github.com`).
    public func containsSite(host: String) -> Bool {
        let host = Self.normalized(host)
        return items.contains { item in
            guard let assigned = item.host else { return false }
            return Self.host(host, isWithin: assigned)
        }
    }

    public var hasSites: Bool { items.contains { $0.host != nil } }

    // MARK: - Hosts

    /// Lowercased host without a leading `www.`; `nil` for URLs without a host.
    public static func normalizedHost(_ url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return normalized(host)
    }

    /// `true` when `host` equals `domain` or is a subdomain of it.
    public static func host(_ host: String, isWithin domain: String) -> Bool {
        let host = normalized(host)
        let domain = normalized(domain)
        return host == domain || host.hasSuffix("." + domain)
    }

    static func normalized(_ host: String) -> String {
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }
}

/// What the user is looking at right now: the frontmost app and, for a supported browser,
/// the URL of its active tab (when it could be read).
public struct FocusTarget: Equatable, Sendable {
    public var bundleID: String?
    public var appName: String
    public var isBrowser: Bool
    public var url: URL?

    public init(bundleID: String?, appName: String, isBrowser: Bool = false, url: URL? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.isBrowser = isBrowser
        self.url = url
    }

    public var host: String? { url.flatMap(Workspace.normalizedHost) }

    /// The workspace item that would cover this target: the site for a browser tab, else the app.
    public var suggestedItem: WorkspaceItem? {
        if isBrowser, let url, host != nil { return .site(url: url) }
        return bundleID.map { .app(bundleID: $0) }
    }

    /// `Xcode`, or `Chrome · github.com` for a browser tab.
    public var displayName: String {
        guard isBrowser, let host else { return appName }
        return "\(appName) · \(host)"
    }
}

/// Decides whether a focus target is on-task for the current session: the task's workspace
/// plus the app the session was latched from.
public struct FocusScope: Equatable, Sendable {
    public var workspace: Workspace
    /// The app the session started in; always on-task for this session.
    public var pinnedBundleID: String?
    /// When the pinned app is a browser, the site it was on; only that site counts.
    public var pinnedHost: String?

    public init(workspace: Workspace = Workspace(), pinnedBundleID: String? = nil, pinnedHost: String? = nil) {
        self.workspace = workspace
        self.pinnedBundleID = pinnedBundleID
        self.pinnedHost = pinnedHost
    }

    public func isOnTask(_ target: FocusTarget) -> Bool {
        if let id = target.bundleID, workspace.containsApp(id) { return true }
        let isPinnedApp = target.bundleID != nil && target.bundleID == pinnedBundleID
        guard target.isBrowser else { return isPinnedApp }

        guard let host = target.host else {
            // The tab couldn't be read (no Automation permission, or a blank tab). Don't accuse
            // the user of drifting when the task does involve this browser.
            return isPinnedApp || workspace.hasSites
        }
        if workspace.containsSite(host: host) { return true }
        if isPinnedApp {
            guard let pinnedHost else { return true }
            return Workspace.host(host, isWithin: pinnedHost)
        }
        return false
    }
}
