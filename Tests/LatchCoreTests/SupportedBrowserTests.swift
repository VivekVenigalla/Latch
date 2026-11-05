import XCTest
@testable import LatchCore

final class SupportedBrowserTests: XCTestCase {
    func testLookupByBundleID() {
        XCTAssertEqual(SupportedBrowser(bundleID: "com.google.Chrome"), .chrome)
        XCTAssertEqual(SupportedBrowser(bundleID: "company.thebrowser.Browser"), .arc)
        XCTAssertNil(SupportedBrowser(bundleID: "com.apple.dt.Xcode"))
        XCTAssertNil(SupportedBrowser(bundleID: nil))
    }

    func testScriptsTargetTheRightBrowserAndTab() {
        XCTAssertTrue(SupportedBrowser.safari.activeTabURLScript.contains("current tab"))
        XCTAssertTrue(SupportedBrowser.chrome.activeTabURLScript.contains("active tab"))
        for browser in SupportedBrowser.allCases {
            XCTAssertTrue(browser.activeTabURLScript.contains("application id \"\(browser.bundleID)\""))
            XCTAssertTrue(browser.allTabURLsScript.contains("application id \"\(browser.bundleID)\""))
            XCTAssertTrue(browser.activeTabURLScript.contains("with timeout"))
        }
    }

    func testParsingScriptOutput() {
        let output = "https://github.com/a\n\nabout:blank\nfile:///tmp/x\n  https://docs.swift.org  \n"
        XCTAssertEqual(
            SupportedBrowser.urls(fromScriptOutput: output),
            [URL(string: "https://github.com/a")!, URL(string: "https://docs.swift.org")!])
        XCTAssertEqual(SupportedBrowser.urls(fromScriptOutput: ""), [])
    }
}
