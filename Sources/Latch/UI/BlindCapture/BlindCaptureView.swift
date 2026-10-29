import LatchCore
import SwiftUI

/// Spotlight-style single-line input with live token badges. Shows nothing from the backlog.
struct BlindCaptureView: View {
    @ObservedObject var model: BlindCaptureModel
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("[+]")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Tokens.emerald)

            TextField(
                "",
                text: $model.text,
                prompt: Text("Capture a thought…  ~15m  !high  #list")
                    .foregroundStyle(Tokens.keycapText))
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Tokens.crispWhite)
                .focused($focused)
                .onSubmit(onSubmit)
                .onExitCommand(perform: onCancel)

            TokenBadges(parsed: model.parsed)

            KeycapBadge("↩")
        }
        .padding(.horizontal, 16)
        .frame(width: BlindCapturePanel.size.width, height: BlindCapturePanel.size.height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Tokens.obsidian.opacity(0.65))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Tokens.perimeter, lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .onAppear { focused = true }
        .onChange(of: model.focusToken) {
            DispatchQueue.main.async { focused = true }
        }
    }
}

private struct TokenBadges: View {
    let parsed: CaptureParse

    var body: some View {
        HStack(spacing: 6) {
            if let duration = parsed.durationSec {
                Text("⏱ \(TimeFormat.duration(duration))")
                    .font(LatchFont.keycap)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.crispWhite)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            if let priority = parsed.priority {
                Circle()
                    .fill(color(for: priority))
                    .frame(width: 7, height: 7)
                    .help("Priority: \(priority.rawValue)")
            }
            if let list = parsed.listName {
                Text("#\(list)")
                    .font(LatchFont.keycap)
                    .foregroundStyle(Tokens.silver)
                    .lineLimit(1)
                    .frame(maxWidth: 90)
            }
        }
        .animation(Tokens.snap, value: parsed)
    }

    private func color(for priority: CapturePriority) -> Color {
        switch priority {
        case .high: Tokens.coral
        case .med: Tokens.amber
        case .low: Tokens.silver
        }
    }
}
