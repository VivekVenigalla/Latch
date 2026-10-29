import SwiftUI

/// A segmented hairline that retracts from right to left as `progress` falls from 1.0 to 0.0.
/// Twelve segments with 1pt gaps give it the look of a machined scale.
struct FilamentShape: Shape {
    var progress: Double
    var segments = 12
    var gap: CGFloat = 1

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segmentWidth = rect.width / CGFloat(segments)
        let litEdge = rect.minX + rect.width * min(1, max(0, progress))
        for i in 0..<segments {
            let start = rect.minX + CGFloat(i) * segmentWidth
            let end = min(start + segmentWidth - gap, litEdge)
            guard end > start else { break }
            path.addRect(CGRect(x: start, y: rect.minY, width: end - start, height: rect.height))
        }
        return path
    }
}

/// Graduation marks under the filament: a tick every quarter of the session.
private struct FilamentTicks: Shape {
    var segments = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segmentWidth = rect.width / CGFloat(segments)
        for i in stride(from: 3, to: segments, by: 3) {
            let x = rect.minX + CGFloat(i) * segmentWidth - 1
            path.addRect(CGRect(x: x, y: rect.minY, width: 1, height: rect.height))
        }
        return path
    }
}

/// Edge-lit perimeter progress along the top inner edge of the popover. No rings, ever.
struct EdgeProgressFilament: View {
    var progress: Double
    var tint: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                FilamentShape(progress: 1).fill(Color.white.opacity(0.05))
                FilamentShape(progress: progress)
                    .fill(tint)
                    .shadow(color: tint.opacity(0.7), radius: 3, y: 0)
            }
            .frame(height: 2)
            FilamentTicks()
                .fill(Color.white.opacity(0.10))
                .frame(height: 3)
        }
        // Linear between 0.5s ticks so the filament glides instead of stepping.
        .animation(.linear(duration: 0.5), value: progress)
    }
}
