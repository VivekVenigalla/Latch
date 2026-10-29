import LatchCore
import SwiftUI

/// SwiftUI twin of the menu bar Shutter, drawn from the same `ShutterLayout`.
struct ShutterGlyphView: View {
    let layout: ShutterLayout
    var scale: CGFloat = 1

    var body: some View {
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            let tint = Tokens.shutterTint(layout.phase)

            var brackets = Path()
            brackets.addLines(layout.leftBracket)
            brackets.addLines(layout.rightBracket)
            context.stroke(
                brackets,
                with: .color(Tokens.crispWhite),
                style: StrokeStyle(lineWidth: ShutterLayout.strokeWidth, lineCap: .butt, lineJoin: .miter))

            switch layout.phase {
            case .idle:
                context.fill(Path(ellipseIn: layout.idleDotRect), with: .color(Tokens.silver))
            case .paused, .drifting:
                context.stroke(
                    Path(roundedRect: layout.boltRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 1),
                    with: .color(tint), lineWidth: 1)
            case .running, .clamped, .overtime:
                context.fill(Path(roundedRect: layout.boltRect, cornerRadius: 1), with: .color(tint))
            }

            for notch in layout.notchRects {
                context.fill(Path(notch), with: .color(Tokens.amber))
            }
        }
        .frame(width: ShutterLayout.size.width * scale, height: ShutterLayout.size.height * scale)
        .accessibilityHidden(true)
    }
}
