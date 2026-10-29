import AppKit
import LatchCore
import SwiftUI

@main
struct LatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(GlancePill.idle) {
            Text("Latch")
                .padding()
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}
