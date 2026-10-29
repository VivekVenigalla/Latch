import SwiftUI

/// A hairline that retracts from right to left as `progress` falls from 1.0 to 0.0.
struct FilamentShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width * min(1, max(0, progress))
        return Path(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
    }
}

/// Edge-lit perimeter progress along the top inner edge of the popover. No rings, ever.
struct EdgeProgressFilament: View {
    var progress: Double
    var tint: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.04))
            FilamentShape(progress: progress)
                .fill(tint)
                .shadow(color: tint.opacity(0.7), radius: 3, y: 0)
        }
        .frame(height: 2)
        // Linear between 0.5s ticks so the filament glides instead of stepping.
        .animation(.linear(duration: 0.5), value: progress)
    }
}
