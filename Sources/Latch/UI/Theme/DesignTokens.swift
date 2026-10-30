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

    static func latchTint(_ phase: LatchGlyphPhase) -> Color {
        switch phase {
        case .running: emerald
        case .clamped, .overtime, .paused, .drifting: amber
        case .idle: silver
        }
    }

    static func shutterTint(_ phase: ShutterPhase) -> Color {
        switch phase {
        case .running: emerald
        case .clamped, .overtime, .paused, .drifting: amber
        case .idle: silver
        }
    }

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

// MARK: - Components

private struct KeycapPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by `KeycapButtonStyle` so nested keycaps travel down when their button is pressed.
    var keycapPressed: Bool {
        get { self[KeycapPressedKey.self] }
        set { self[KeycapPressedKey.self] = newValue }
    }
}

/// A raised physical key: lit top edge, dark skirt underneath, and 1pt of travel when pressed.
struct KeycapBadge: View {
    let key: String
    @Environment(\.keycapPressed) private var pressed

    init(_ key: String) { self.key = key }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 4, style: .continuous) }

    var body: some View {
        Text(key)
            .font(LatchFont.keycap)
            .foregroundStyle(pressed ? Tokens.silver : Tokens.keycapText)
            .frame(minWidth: 10)
            .padding(.horizontal, 4)
            .padding(.top, 1)
            .padding(.bottom, 1.5)
            .background {
                ZStack {
                    shape.fill(Tokens.keycapFill)
                    shape.fill(LinearGradient(
                        colors: [Color.white.opacity(0.07), .clear], startPoint: .top, endPoint: .bottom))
                    shape.strokeBorder(LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                }
            }
            .background {
                // The skirt: visible below the cap at rest, hidden when the key is down.
                shape.fill(Color.black.opacity(0.55)).offset(y: pressed ? 0 : 1)
            }
            .offset(y: pressed ? 1 : 0)
            .animation(.spring(response: 0.12, dampingFraction: 0.9), value: pressed)
    }
}

/// Small-caps section label, e.g. `NEXT`, `LATCHED`.
struct SectionLabel: View {
    let text: String
    var color: Color = Tokens.silver

    init(_ text: String, color: Color = Tokens.silver) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(LatchFont.label)
            .kerning(1.1)
            .foregroundStyle(color)
    }
}

/// A "machined slot" container for secondary metadata.
struct RecessedWell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.wellCornerRadius, style: .continuous)
                    .fill(Tokens.wellFill))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.wellCornerRadius, style: .continuous)
                    .strokeBorder(Tokens.wellBorder, lineWidth: 1))
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Tokens.divider).frame(height: 1)
    }
}

struct PriorityDot: View {
    let band: PriorityBand

    var body: some View {
        Circle()
            .fill(Tokens.color(for: band))
            .frame(width: 6, height: 6)
    }
}

/// Every action shows its hotkey as a trailing keycap: `Latch [↩]`.
struct KeycapButtonStyle: ButtonStyle {
    var prominent = false
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LatchFont.button)
            .foregroundStyle(prominent || active ? Tokens.crispWhite : Tokens.silver)
            .padding(.leading, 9)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed)))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(active ? Tokens.emerald.opacity(0.5) : Tokens.perimeter, lineWidth: 1))
            .contentShape(Rectangle())
            .environment(\.keycapPressed, configuration.isPressed)
    }

    private func fill(pressed: Bool) -> Color {
        let base = prominent ? 0.10 : 0.03
        return Color.white.opacity(pressed ? base + 0.06 : base)
    }
}

struct KeycapButton: View {
    let title: String
    let key: String
    var prominent = false
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).lineLimit(1)
                KeycapBadge(key)
            }
        }
        .buttonStyle(KeycapButtonStyle(prominent: prominent, active: active))
    }
}
