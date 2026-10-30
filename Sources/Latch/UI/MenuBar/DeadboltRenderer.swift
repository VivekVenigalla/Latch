import AppKit
import LatchCore

/// Draws the Deadbolt glyph as a template image for the status item, so macOS tints it for
/// light, dark and accent-tinted menu bars exactly like its own icons.
enum DeadboltRenderer {
    static func image(for layout: DeadboltLayout) -> NSImage {
        let image = NSImage(size: DeadboltLayout.size, flipped: true) { _ in
            NSColor.black.set()

            let housing = NSBezierPath(
                roundedRect: DeadboltLayout.housingRect,
                xRadius: DeadboltLayout.housingCornerRadius,
                yRadius: DeadboltLayout.housingCornerRadius)
            housing.lineWidth = DeadboltLayout.strokeWidth
            housing.stroke()

            let keeper = NSBezierPath()
            keeper.move(to: DeadboltLayout.keeper[0])
            DeadboltLayout.keeper.dropFirst().forEach { keeper.line(to: $0) }
            keeper.lineWidth = DeadboltLayout.strokeWidth
            keeper.lineJoinStyle = .miter
            keeper.stroke()

            drawBolt(layout)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Latch"
        return image
    }

    private static func drawBolt(_ layout: DeadboltLayout) {
        let radius = DeadboltLayout.boltCornerRadius
        if layout.isBoltHollow {
            // Outline only the part outside the housing, so it never doubles the housing stroke.
            var rect = layout.boltRect
            let housingEdge = DeadboltLayout.housingRect.maxX
            rect.size.width = max(0, rect.maxX - housingEdge)
            rect.origin.x = housingEdge
            let bolt = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
            bolt.lineWidth = 1
            bolt.stroke()
        } else {
            NSBezierPath(roundedRect: layout.boltRect, xRadius: radius, yRadius: radius).fill()
        }
    }
}
