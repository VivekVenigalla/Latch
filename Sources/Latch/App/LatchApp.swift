import AppKit
import LatchCore
import SwiftUI

@main
struct LatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(GlancePill.idle) {
            RootPopoverView()
                .environmentObject(appDelegate.engine)
        }
        .menuBarExtraStyle(.window)
    }
}
