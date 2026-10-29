import AppKit
import LatchCore
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

/// The Shutter glyph (`[ · ]` idle, brackets closing while latched) plus the task title.
/// Time is shown as geometry, not digits; the exact clock stays available to VoiceOver.
private struct MenuBarLabel: View {
    @ObservedObject var engine: LatchEngine

    var body: some View {
        Image(nsImage: ShutterRenderer.image(layout: engine.shutter, title: engine.shutterTitle))
            .accessibilityLabel(engine.glanceText)
    }
}

/// Draws the Shutter into an `NSImage` for the status item.
///
/// The image is not a template because the bolt carries the emerald/amber accent. Brackets
/// and title use `labelColor`, resolved inside the drawing handler, so they still follow
/// the menu bar's light/dark appearance.
enum ShutterRenderer {
    private static let titleFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let titleSpacing: CGFloat = 6

    static func image(layout: ShutterLayout, title: String?) -> NSImage {
        let glyph = ShutterLayout.size
        let attributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        let titleSize = title.map { ($0 as NSString).size(withAttributes: attributes) } ?? .zero
        let width = glyph.width + (title == nil ? 0 : titleSpacing + ceil(titleSize.width))

        let image = NSImage(size: NSSize(width: width, height: glyph.height), flipped: true) { _ in
            let ink = NSColor.labelColor
            let accent = NSColor(Tokens.shutterTint(layout.phase))

            let brackets = NSBezierPath()
            for points in [layout.leftBracket, layout.rightBracket] {
                brackets.move(to: points[0])
                points.dropFirst().forEach { brackets.line(to: $0) }
            }
            brackets.lineWidth = ShutterLayout.strokeWidth
            brackets.lineJoinStyle = .miter
            ink.setStroke()
            brackets.stroke()

            switch layout.phase {
            case .idle:
                NSColor.secondaryLabelColor.setFill()
                NSBezierPath(ovalIn: layout.idleDotRect).fill()
            case .paused:
                let bolt = NSBezierPath(roundedRect: layout.boltRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 1, yRadius: 1)
                bolt.lineWidth = 1
                accent.setStroke()
                bolt.stroke()
            case .running, .clamped, .overtime:
                accent.setFill()
                NSBezierPath(roundedRect: layout.boltRect, xRadius: 1, yRadius: 1).fill()
            }

            NSColor(Tokens.amber).setFill()
            layout.notchRects.forEach { NSBezierPath(rect: $0).fill() }

            if let title {
                let origin = NSPoint(x: glyph.width + titleSpacing, y: (glyph.height - titleSize.height) / 2)
                (title as NSString).draw(at: origin, withAttributes: attributes.merging([.foregroundColor: ink]) { $1 })
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
