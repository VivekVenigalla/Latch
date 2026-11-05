import XCTest
@testable import LatchCore

final class WorkspaceTests: XCTestCase {
    private let xcode = "com.apple.dt.Xcode"
    private let chrome = "com.google.Chrome"
    private func url(_ s: String) -> URL { URL(string: s)! }

    func testHostNormalisation() {
        XCTAssertEqual(Workspace.normalizedHost(url("https://WWW.GitHub.com/a/b")), "github.com")
        XCTAssertEqual(Workspace.normalizedHost(url("https://docs.swift.org")), "docs.swift.org")
        XCTAssertNil(Workspace.normalizedHost(url("about:blank")))
        XCTAssertTrue(Workspace.host("api.github.com", isWithin: "github.com"))
        XCTAssertTrue(Workspace.host("www.github.com", isWithin: "github.com"))
        XCTAssertFalse(Workspace.host("notgithub.com", isWithin: "github.com"))
    }

    func testAddDeduplicatesAppsAndHosts() {
        var workspace = Workspace()
        XCTAssertTrue(workspace.add(.app(bundleID: xcode)))
        XCTAssertFalse(workspace.add(.app(bundleID: xcode)))
        XCTAssertTrue(workspace.add(.site(url: url("https://github.com/org/repo/pull/1"))))
        XCTAssertFalse(workspace.add(.site(url: url("https://www.github.com/other"))), "same host")
        XCTAssertFalse(workspace.add(.site(url: url("about:blank"))), "no host")
        XCTAssertFalse(workspace.add(.app(bundleID: "")))
        XCTAssertEqual(workspace.items.count, 2)
        XCTAssertEqual(workspace.appBundleIDs, [xcode])
        XCTAssertEqual(workspace.siteURLs, [url("https://github.com/org/repo/pull/1")])
    }

    func testInitDeduplicates() {
        let workspace = Workspace([.app(bundleID: xcode), .app(bundleID: xcode)])
        XCTAssertEqual(workspace.items, [.app(bundleID: xcode)])
    }

    func testRemoveSiteByHost() {
        var workspace = Workspace([.site(url: url("https://github.com/a")), .app(bundleID: xcode)])
        XCTAssertTrue(workspace.remove(.site(url: url("https://github.com/zzz"))))
        XCTAssertFalse(workspace.hasSites)
        XCTAssertTrue(workspace.remove(.app(bundleID: xcode)))
        XCTAssertTrue(workspace.isEmpty)
        XCTAssertFalse(workspace.remove(.app(bundleID: xcode)))
    }

    func testContainsSiteIncludesSubdomains() {
        let workspace = Workspace([.site(url: url("https://github.com"))])
        XCTAssertTrue(workspace.containsSite(host: "gist.github.com"))
        XCTAssertTrue(workspace.containsSite(host: "GitHub.com"))
        XCTAssertFalse(workspace.containsSite(host: "gitlab.com"))
    }

    func testFocusTargetSuggestion() {
        let tab = FocusTarget(bundleID: chrome, appName: "Chrome", isBrowser: true, url: url("https://www.youtube.com/watch"))
        XCTAssertEqual(tab.suggestedItem, .site(url: url("https://www.youtube.com/watch")))
        XCTAssertEqual(tab.displayName, "Chrome · youtube.com")
        let blank = FocusTarget(bundleID: chrome, appName: "Chrome", isBrowser: true)
        XCTAssertEqual(blank.suggestedItem, .app(bundleID: chrome))
        XCTAssertEqual(FocusTarget(bundleID: xcode, appName: "Xcode").displayName, "Xcode")
    }
}

final class FocusScopeTests: XCTestCase {
    private let xcode = "com.apple.dt.Xcode"
    private let terminal = "com.apple.Terminal"
    private let chrome = "com.google.Chrome"
    private let slack = "com.tinyspeck.slackmacgap"

    private func app(_ id: String) -> FocusTarget { FocusTarget(bundleID: id, appName: id) }
    private func tab(_ host: String?) -> FocusTarget {
        FocusTarget(bundleID: chrome, appName: "Chrome", isBrowser: true, url: host.map { URL(string: "https://\($0)/x")! })
    }

    func testPinnedAppAndAssignedAppsAreOnTask() {
        let scope = FocusScope(workspace: Workspace([.app(bundleID: terminal)]), pinnedBundleID: xcode)
        XCTAssertTrue(scope.isOnTask(app(xcode)))
        XCTAssertTrue(scope.isOnTask(app(terminal)))
        XCTAssertFalse(scope.isOnTask(app(slack)))
        XCTAssertFalse(scope.isOnTask(FocusTarget(bundleID: nil, appName: "?")))
    }

    func testAssignedSitesInAnyBrowser() {
        let scope = FocusScope(workspace: Workspace([.site(url: URL(string: "https://github.com")!)]), pinnedBundleID: xcode)
        XCTAssertTrue(scope.isOnTask(tab("github.com")))
        XCTAssertTrue(scope.isOnTask(tab("api.github.com")))
        XCTAssertFalse(scope.isOnTask(tab("youtube.com")))
    }

    func testWholeBrowserAppCoversEveryTab() {
        let scope = FocusScope(workspace: Workspace([.app(bundleID: chrome)]))
        XCTAssertTrue(scope.isOnTask(tab("youtube.com")))
    }

    func testPinnedBrowserCountsOnlyItsSite() {
        let scope = FocusScope(pinnedBundleID: chrome, pinnedHost: "docs.swift.org")
        XCTAssertTrue(scope.isOnTask(tab("docs.swift.org")))
        XCTAssertFalse(scope.isOnTask(tab("youtube.com")))
        let unknownSite = FocusScope(pinnedBundleID: chrome, pinnedHost: nil)
        XCTAssertTrue(unknownSite.isOnTask(tab("youtube.com")), "no site captured at latch: the whole browser counts")
    }

    func testUnreadableTabGetsTheBenefitOfTheDoubt() {
        XCTAssertTrue(FocusScope(pinnedBundleID: chrome).isOnTask(tab(nil)))
        XCTAssertTrue(FocusScope(workspace: Workspace([.site(url: URL(string: "https://github.com")!)])).isOnTask(tab(nil)))
        XCTAssertFalse(FocusScope(pinnedBundleID: xcode).isOnTask(tab(nil)), "the task never involved a browser")
    }
}
