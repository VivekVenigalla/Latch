import CoreGraphics
import Foundation

public enum LatchGlyphPhase: Equatable, Sendable {
    case idle, running, clamped, overtime, paused
    /// Drift Guard's off-beat: the bolt goes hollow, alternating with the normal phase.
    case drifting
}

/// Geometry for the "Deadbolt" token: a housing on the left, a keeper (strike plate) on the
/// right, and a bolt that slides out of the housing as focus time is spent. At 00:00 the bolt
/// is seated in the keeper — the task is latched. When idle the bolt rests retracted: an
/// unlocked deadbolt.
///
/// Coordinates are in a fixed 28×16 unit box, y-down, sized for a template image in the macOS
/// menu bar. The box never changes width, so the text beside it never shifts. Both the AppKit
/// status item and the SwiftUI popover glyph draw from this one layout.
public struct DeadboltLayout: Equatable, Sendable {
    public static let size = CGSize(width: 28, height: 16)
    public static let strokeWidth: CGFloat = 1.4

    public static let housingRect = CGRect(x: 1, y: 2, width: 6, height: 12)
    public static let housingCornerRadius: CGFloat = 1.6

    /// The keeper, drawn as an open `]` facing the bolt.
    public static let keeper: [CGPoint] = [
        CGPoint(x: 24, y: 3.5), CGPoint(x: 27, y: 3.5), CGPoint(x: 27, y: 12.5), CGPoint(x: 24, y: 12.5),
    ]

    public static let boltRootX: CGFloat = 6
    public static let boltY: CGFloat = 6
    public static let boltHeight: CGFloat = 4
    public static let boltCornerRadius: CGFloat = 1.2
    /// Bolt tip at the moment of latching: just proud of the housing.
    public static let retractedTipX: CGFloat = 8.5
    /// Bolt tip when seated against the keeper's back wall.
    public static let seatedTipX: CGFloat = 27 - strokeWidth / 2

    public let phase: LatchGlyphPhase
    /// 0 = bolt retracted (session just started), 1 = seated (time is up).
    public let throwFraction: CGFloat

    public init(phase: LatchGlyphPhase, elapsedFraction: Double = 0) {
        self.phase = phase
        switch phase {
        case .idle: throwFraction = 0
        case .overtime: throwFraction = 1
        case .running, .clamped, .paused, .drifting: throwFraction = CGFloat(min(1, max(0, elapsedFraction)))
        }
    }

    /// The same layout with the bolt forced to `fraction` (used by the engage animation).
    public func throwing(to fraction: CGFloat) -> DeadboltLayout {
        DeadboltLayout(phase: phase == .idle ? .running : phase, elapsedFraction: Double(fraction))
    }

    /// Paused and drifting draw the bolt as an outline rather than solid.
    public var isBoltHollow: Bool { phase == .paused || phase == .drifting }

    public var isSeated: Bool { throwFraction >= 1 }

    public var boltTipX: CGFloat {
        Self.retractedTipX + throwFraction * (Self.seatedTipX - Self.retractedTipX)
    }

    public var boltRect: CGRect {
        CGRect(x: Self.boltRootX, y: Self.boltY, width: boltTipX - Self.boltRootX, height: Self.boltHeight)
    }
}
