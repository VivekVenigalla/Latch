import AppKit
import SwiftUI

@main
struct LatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            RootPopoverView()
                .environmentObject(appDelegate.engine)
        } label: {
            MenuBarLabel(engine: appDelegate.engine)
        }
        .menuBarExtraStyle(.window)
    }
}

/// `[ · ]` idle, `[▪] 18:42 · Fix auth token` latched, `[▪] +02:14 · …` overtime.
///
/// MenuBarExtra labels ignore most SwiftUI font modifiers, so the pill is rendered to a
/// template image with a monospaced font. That guarantees fixed-width digits (no jitter)
/// and lets the system tint it for light/dark menu bars.
private struct MenuBarLabel: View {
    @ObservedObject var engine: LatchEngine

    var body: some View {
        Image(nsImage: GlanceRenderer.image(for: engine.glanceText))
            .accessibilityLabel(engine.glanceText)
    }
}

enum GlanceRenderer {
    static func image(for text: String) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: LatchFont.menuBarNSFont,
            .foregroundColor: NSColor.black,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let size = NSSize(width: ceil(textSize.width), height: max(16, ceil(textSize.height)))
        let image = NSImage(size: size, flipped: false) { rect in
            string.draw(at: NSPoint(x: 0, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }
}
