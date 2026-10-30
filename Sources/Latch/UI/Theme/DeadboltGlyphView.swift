import LatchCore
import SwiftUI

/// SwiftUI twin of the menu bar Deadbolt, drawn from the same `DeadboltLayout`. Built from
/// animatable shapes so the bolt glides between timer ticks instead of stepping.
struct DeadboltGlyphView: View {
    let layout: DeadboltLayout
    var scale: CGFloat = 1

    private var size: CGSize { DeadboltLayout.size }

    var body: some View {
        let tint = Tokens.latchTint(layout.phase)
        ZStack(alignment: .topLeading) {
            DeadboltHousing()
                .stroke(Tokens.crispWhite, lineWidth: DeadboltLayout.strokeWidth)
            DeadboltKeeper()
                .stroke(Tokens.crispWhite, style: StrokeStyle(lineWidth: DeadboltLayout.strokeWidth, lineJoin: .miter))
            if layout.isBoltHollow {
                DeadboltBolt(tipX: layout.boltTipX, hollow: true).stroke(tint, lineWidth: 1)
            } else {
                DeadboltBolt(tipX: layout.boltTipX, hollow: false).fill(tint)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.linear(duration: 0.5), value: layout.boltTipX)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

private struct DeadboltHousing: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: DeadboltLayout.housingRect, cornerRadius: DeadboltLayout.housingCornerRadius)
    }
}

private struct DeadboltKeeper: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(DeadboltLayout.keeper)
        return path
    }
}

private struct DeadboltBolt: Shape {
    var tipX: CGFloat
    var hollow: Bool

    var animatableData: CGFloat {
        get { tipX }
        set { tipX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // A hollow bolt is outlined only outside the housing, so it never doubles its stroke.
        let rootX = hollow ? DeadboltLayout.housingRect.maxX : DeadboltLayout.boltRootX
        var bolt = CGRect(
            x: rootX, y: DeadboltLayout.boltY,
            width: max(0, tipX - rootX), height: DeadboltLayout.boltHeight)
        if hollow { bolt = bolt.insetBy(dx: 0.5, dy: 0.5) }
        return Path(roundedRect: bolt, cornerRadius: DeadboltLayout.boltCornerRadius)
    }
}
