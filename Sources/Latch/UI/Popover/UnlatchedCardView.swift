import LatchCore
import SwiftUI

/// State 1: a single candidate card. Never a list.
struct UnlatchedCardView: View {
    @EnvironmentObject private var engine: LatchEngine
    let candidate: TaskCandidate?
    let filterMode: FilterMode

    var body: some View {
        VStack(spacing: 0) {
            if let clamp = engine.clampPreview, candidate != nil {
                ClampBanner(clamp: clamp)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 10) {
                PopoverHeader(label: filterMode == .quick ? "NEXT · QUICK ≤15m" : "NEXT")

                ZStack(alignment: .topLeading) {
                    if let candidate {
                        CandidateCard(candidate: candidate)
                            .id(candidate.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity))
                    } else {
                        EmptyBufferCard(filterMode: filterMode)
                            .transition(.opacity)
                    }
                }
                .animation(Tokens.snap, value: candidate?.id)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Spacer(minLength: 0)
            Hairline()

            HStack(spacing: 6) {
                KeycapButton(title: "Latch", key: "↩", prominent: true) { engine.latch() }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(candidate == nil)
                KeycapButton(title: "Cycle", key: "⇥") { withAnimation(Tokens.snap) { engine.cycle() } }
                    .keyboardShortcut(.tab, modifiers: [])
                    .disabled(candidate == nil)
                Spacer(minLength: 0)
                KeycapButton(title: "Quick 15m", key: "⌘1", active: filterMode == .quick) {
                    withAnimation(Tokens.snap) { engine.toggleQuickFilter() }
                }
                .keyboardShortcut("1", modifiers: .command)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .animation(Tokens.snap, value: engine.clampPreview)
    }
}

private struct CandidateCard: View {
    @EnvironmentObject private var engine: LatchEngine
    let candidate: TaskCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                PriorityDot(band: candidate.priorityBand)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(candidate.title)
                    .font(LatchFont.title)
                    .tracking(-0.2)
                    .foregroundStyle(Tokens.crispWhite)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                DurationStepper()
                if let due = candidate.dueDate {
                    Text(dueLabel(due))
                        .font(LatchFont.meta)
                        .foregroundStyle(due < .now ? Tokens.coral : Tokens.silver)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let list = candidate.listTitle {
                    Text(list)
                        .font(LatchFont.meta)
                        .foregroundStyle(Tokens.keycapText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if let context = candidate.metadata.context {
                RecessedWell {
                    Text("↳ \(context)")
                        .font(LatchFont.meta)
                        .foregroundStyle(Tokens.silver)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .help(context)
            }
        }
    }

    private func dueLabel(_ due: Date) -> String {
        if due < .now { return "overdue" }
        return "due " + due.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

/// `[−] 25m [+]` — adjustable with the keycaps, `-` / `=`, or the scroll wheel, in 5m steps.
private struct DurationStepper: View {
    @EnvironmentObject private var engine: LatchEngine

    var body: some View {
        HStack(spacing: 4) {
            Button { engine.adjustDuration(steps: -1) } label: { KeycapBadge("−") }
                .buttonStyle(.plain)
                .keyboardShortcut("-", modifiers: [])
            Text(TimeFormat.duration(engine.selectedDurationSec))
                .font(LatchFont.timer)
                .foregroundStyle(Tokens.crispWhite)
                .frame(minWidth: 34)
                .overlay(ScrollWheelCatcher { engine.adjustDuration(steps: $0) })
                .help("Scroll to adjust in 5m steps")
            Button { engine.adjustDuration(steps: 1) } label: { KeycapBadge("+") }
                .buttonStyle(.plain)
                .keyboardShortcut("=", modifiers: [])
        }
    }
}

private struct ClampBanner: View {
    let clamp: ClampResult

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Tokens.amber).frame(width: 2, height: 10)
            Text("CLAMPED · \(TimeFormat.duration(clamp.allocatedSeconds)) until \(clamp.event?.title ?? "Event")")
                .font(LatchFont.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.amber)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Tokens.amber.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(Tokens.amber.opacity(0.25)).frame(height: 1) }
    }
}

private struct EmptyBufferCard: View {
    let filterMode: FilterMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(filterMode == .quick ? "No quick tasks." : "Buffer clear.")
                .font(LatchFont.title)
                .tracking(-0.2)
                .foregroundStyle(Tokens.crispWhite)
            Text(filterMode == .quick
                 ? "Nothing ≤15m in Reminders. ⌘1 to widen."
                 : "No incomplete reminders. Capture with ⌘⇧Space.")
                .font(LatchFont.meta)
                .foregroundStyle(Tokens.silver)
                .lineLimit(2)
        }
    }
}
