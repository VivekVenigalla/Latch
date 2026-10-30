import SwiftUI

/// Latch has no windows of its own: the menu bar item and its popover are owned by
/// `StatusItemController` (AppKit), so the item can be positioned, measured and kept visible.
@main
struct LatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
