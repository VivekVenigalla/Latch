import CoreGraphics
import Foundation

public enum ShutterPhase: Equatable, Sendable {
    case idle, running, clamped, overtime, paused
}

/// Geometry for the "Shutter" glyph: two square brackets that close inward as focus time
/// runs out, with a bolt between them. At 00:00 the brackets are shut; overtime stacks amber
/// notches outside the right bracket.
///
/// Coordinates are in a fixed 48×16 unit box, y-down. The box width never changes, so the
/// task title beside it in the menu bar never shifts. Both the AppKit menu bar renderer and
/// the SwiftUI popover glyph draw from this one layout.
public struct ShutterLayout: Equatable, Sendable {
    public static let size = CGSize(width: 48, height: 16)
    public static let centerX: CGFloat = 24
    public static let clearance: CGFloat = 3
    public static let serif: CGFloat = 4
    public static let strokeWidth: CGFloat = 1.6
    public static let boltHeight: CGFloat = 4
    public static let minGap: CGFloat = 3
    public static let maxGap: CGFloat = 30
    public static let maxNotches = 3
    public static let secondsPerNotch: TimeInterval = 120

    public let phase: ShutterPhase
    /// Width of the bolt (the space between the brackets, less clearance).
    public let gap: CGFloat
    public let notchCount: Int

    public init(phase: ShutterPhase, remainingFraction: Double = 1, overtimeSeconds: TimeInterval = 0) {
        self.phase = phase
        switch phase {
        case .idle:
            gap = Self.maxGap
            notchCount = 0
        case .overtime:
            gap = Self.minGap
            notchCount = min(Self.maxNotches, 1 + Int(max(0, overtimeSeconds) / Self.secondsPerNotch))
        case .running, .clamped, .paused:
            let fraction = CGFloat(min(1, max(0, remainingFraction)))
            gap = Self.minGap + fraction * (Self.maxGap - Self.minGap)
            notchCount = 0
        }
    }

    private static let top: CGFloat = 1
    private static let bottom: CGFloat = 15

    /// x of the left bracket's vertical stroke.
    public var leftStrokeX: CGFloat { Self.centerX - gap / 2 - Self.clearance - Self.serif }
    /// x of the right bracket's vertical stroke.
    public var rightStrokeX: CGFloat { Self.centerX + gap / 2 + Self.clearance + Self.serif }

    /// `[` — serifs point inward.
    public var leftBracket: [CGPoint] {
        [CGPoint(x: leftStrokeX + Self.serif, y: Self.top),
         CGPoint(x: leftStrokeX, y: Self.top),
         CGPoint(x: leftStrokeX, y: Self.bottom),
         CGPoint(x: leftStrokeX + Self.serif, y: Self.bottom)]
    }

    /// `]`
    public var rightBracket: [CGPoint] {
        [CGPoint(x: rightStrokeX - Self.serif, y: Self.top),
         CGPoint(x: rightStrokeX, y: Self.top),
         CGPoint(x: rightStrokeX, y: Self.bottom),
         CGPoint(x: rightStrokeX - Self.serif, y: Self.bottom)]
    }

    public var boltRect: CGRect {
        CGRect(x: Self.centerX - gap / 2, y: (Self.size.height - Self.boltHeight) / 2, width: gap, height: Self.boltHeight)
    }

    /// Idle shows a centred dot instead of a bolt: `[ · ]`.
    public var idleDotRect: CGRect {
        CGRect(x: Self.centerX - 1.3, y: Self.size.height / 2 - 1.3, width: 2.6, height: 2.6)
    }

    public var notchRects: [CGRect] {
        (0..<notchCount).map { i in
            CGRect(x: rightStrokeX + 3 + CGFloat(i) * 4, y: 5, width: 2, height: 6)
        }
    }
}
