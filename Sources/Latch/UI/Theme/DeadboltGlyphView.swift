import LatchCore
import SwiftUI

/// SwiftUI twin of the menu bar Deadbolt, drawn from the same `DeadboltLayout`. Built from
/// animatable shapes so the bolt glides between timer ticks instead of stepping.
struct DeadboltGlyphView: View {
    let layout: DeadboltLayout
    var scale: CGFloat = 1
    /// Plays the engage animation when this changes, or on appear if it happened within 1s.
    var engagedAt: Date?
    @State private var throwOverride: CGFloat?

    private var size: CGSize { DeadboltLayout.size }

    var body: some View {
        let tint = Tokens.latchTint(layout.phase)
        let layout = throwOverride.map { self.layout.throwing(to: $0) } ?? self.layout
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
        .transaction { transaction in
            // Glide between ticks, unless an explicit animation (the engage spring) is running.
            if transaction.animation == nil { transaction.animation = .linear(duration: 0.5) }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
        .accessibilityHidden(true)
        .task(id: engagedAt) { await engage() }
    }

    /// The bolt throws home into the keeper, then springs back to where the session stands.
    private func engage() async {
        guard let engagedAt, Date.now.timeIntervalSince(engagedAt) < 1 else { return }
        withAnimation(.spring(response: 0.16, dampingFraction: 0.75)) { throwOverride = 1 }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { throwOverride = layout.throwFraction }
        try? await Task.sleep(for: .milliseconds(450))
        throwOverride = nil
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
