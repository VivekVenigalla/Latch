import AppKit
import LatchCore
import SwiftUI

extension Color {
    /// `Color(hex: "#0D0E11")`
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1)
    }
}

/// "Tactile Utility" design system: 95% monochrome, whisper-quiet semantic accents.
enum Tokens {
    // Canvas
    static let obsidian = Color(hex: "#0D0E11")
    static let slate = Color(hex: "#16181D")
    static let silver = Color(hex: "#9CA3AF")
    static let crispWhite = Color(hex: "#F3F4F6")
    static let keycapText = Color(hex: "#6B7280")

    // Semantic accents
    static let emerald = Color(hex: "#10B981").opacity(0.85)
    static let amber = Color(hex: "#F59E0B").opacity(0.85)
    static let coral = Color(hex: "#EF4444").opacity(0.85)

    // Structure
    static let perimeter = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.06)
    static let wellFill = Color.black.opacity(0.35)
    static let wellBorder = Color.white.opacity(0.04)
    static let keycapFill = Color.white.opacity(0.06)

    // Geometry
    static let popoverWidth: CGFloat = 320
    static let popoverMinHeight: CGFloat = 168
    static let popoverMaxHeight: CGFloat = 220
    static let windowCornerRadius: CGFloat = 10
    static let wellCornerRadius: CGFloat = 6

    /// The only transition curve in the popover: snappy, non-oscillating.
    static let snap = Animation.spring(response: 0.20, dampingFraction: 0.90)

    static func color(for band: PriorityBand) -> Color {
        switch band {
        case .high: coral
        case .medium: amber
        case .low: silver.opacity(0.6)
        case .none: Color.white.opacity(0.18)
        }
    }
}

enum LatchFont {
    /// Menu bar pill & all countdowns. Monospaced digits prevent horizontal jitter.
    static let timer = Font.system(size: 12, weight: .medium, design: .monospaced).monospacedDigit()
    static let title = Font.system(size: 15, weight: .semibold, design: .default)
    static let meta = Font.system(size: 11.5, weight: .regular, design: .monospaced)
    static let keycap = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let label = Font.system(size: 9.5, weight: .semibold, design: .monospaced)
    static let button = Font.system(size: 12, weight: .medium, design: .default)

    /// AppKit twin of `timer`, for the rendered menu bar glyph.
    static let menuBarNSFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
}
