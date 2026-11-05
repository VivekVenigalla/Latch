import XCTest
@testable import LatchCore

final class RestorePlanTests: XCTestCase {
    private let workspace = Workspace([
        .app(bundleID: "com.apple.dt.Xcode"),
        .app(bundleID: "com.apple.Terminal"),
        .site(url: URL(string: "https://github.com/acme/api/pull/42")!),
        .site(url: URL(string: "https://docs.swift.org/swift-book")!),
    ])

    func testLaunchesOnlyAppsThatAreNotRunning() {
        let plan = RestorePlan.make(for: workspace, runningApps: ["com.apple.Terminal"], openTabs: [])
        XCTAssertEqual(plan.appsToLaunch, ["com.apple.dt.Xcode"])
    }

    func testSkipsSitesAlreadyOpenOnTheSameHost() {
        let tabs = [URL(string: "https://www.github.com/acme/other")!, URL(string: "https://news.ycombinator.com")!]
        let plan = RestorePlan.make(for: workspace, runningApps: [], openTabs: tabs)
        XCTAssertEqual(plan.sitesToOpen, [URL(string: "https://docs.swift.org/swift-book")!])
    }

    func testSubdomainTabCountsAsOpen() {
        let plan = RestorePlan.make(
            for: Workspace([.site(url: URL(string: "https://github.com")!)]),
            runningApps: [], openTabs: [URL(string: "https://gist.github.com/x")!])
        XCTAssertTrue(plan.sitesToOpen.isEmpty)
    }

    func testNothingToDo() {
        let plan = RestorePlan.make(
            for: workspace,
            runningApps: ["com.apple.dt.Xcode", "com.apple.Terminal"],
            openTabs: [URL(string: "https://github.com")!, URL(string: "https://docs.swift.org")!])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(RestorePlan.make(for: Workspace(), runningApps: [], openTabs: []).isEmpty)
    }
}
