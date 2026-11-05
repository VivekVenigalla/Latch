import LatchCore
import SwiftUI

/// State 2: the single-threaded execution lock.
struct LatchedFocusView: View {
    @EnvironmentObject private var engine: LatchEngine
    let session: ActiveSession

    private var tint: Color {
        engine.isOvertime || engine.isDrifting || session.isClamped ? Tokens.amber : Tokens.emerald
    }

    private var statusLabel: String {
        if engine.isOvertime { return "OVERTIME" }
        if engine.isDrifting { return "DRIFTING" }
        if session.isClamped { return "CLAMPED" }
        return "LATCHED"
    }

    var body: some View {
        VStack(spacing: 0) {
            EdgeProgressFilament(
                progress: engine.isOvertime ? 1 : session.progressRemaining(remainingSeconds: engine.remainingSeconds),
                tint: tint)

            if engine.isDrifting, let target = engine.driftTarget {
                DriftBanner(target: target)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    DeadboltGlyphView(layout: engine.deadbolt, scale: 2, engagedAt: engine.engagedAt)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimeFormat.clock(engine.remainingSeconds))
                            .font(LatchFont.timer)
                            .foregroundStyle(engine.isOvertime ? Tokens.amber : Tokens.crispWhite)
                        HStack(spacing: 5) {
                            SectionLabel(statusLabel, color: tint)
                                .help(session.clampReason ?? "")
                            if engine.isDrifting {
                                Text(TimeFormat.clock(-engine.driftExcursionSeconds))
                                    .font(LatchFont.label.monospacedDigit())
                                    .foregroundStyle(Tokens.amber)
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    if let pinned = session.pinnedApp {
                        RefocusPill(pinned: pinned, urgent: engine.isDrifting)
                    }
                }

                Text(session.task.title)
                    .font(LatchFont.title)
                    .tracking(-0.2)
                    .foregroundStyle(Tokens.crispWhite)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // While drifting, the OFF TASK banner takes this space so the popover stays ≤ 220pt.
                if let context = session.task.metadata.context, !engine.isDrifting {
                    RecessedWell {
                        Text("↳ \(context)")
                            .font(LatchFont.meta)
                            .foregroundStyle(Tokens.silver)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(context)
                }

                MicroStepScratchpad()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Spacer(minLength: 0)
            Hairline()

            HStack(spacing: 6) {
                KeycapButton(title: "Complete", key: "⌘↩", prominent: true) { engine.complete() }
                    .keyboardShortcut(.return, modifiers: .command)
                KeycapButton(title: "Unlatch", key: "⌘.") { engine.unlatch() }
                    .keyboardShortcut(".", modifiers: .command)
                Spacer(minLength: 0)
                WorkspaceStrip(workspace: session.scope.workspace)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .animation(Tokens.snap, value: engine.isDrifting)
    }
}

/// `[App Icon] Refocus <AppName> [⌘G]` — becomes an amber `[App Icon] Return [⌘G]` while
/// drifting (the icon says where; the full name is in the tooltip).
private struct RefocusPill: View {
    @EnvironmentObject private var engine: LatchEngine
    let pinned: PinnedApp
    var urgent = false

    var body: some View {
        Button { engine.refocusPinnedApp() } label: {
            HStack(spacing: 5) {
                if let icon = engine.anchor.icon(for: pinned) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 13, height: 13)
                }
                Text(urgent ? "Return" : "Refocus \(pinned.name)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(urgent ? Tokens.amber : Tokens.silver)
                    .lineLimit(1)
                    .truncationMode(.tail)
                KeycapBadge("⌘G")
            }
            .padding(.leading, 5)
            .padding(.trailing, 3)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Color.white.opacity(0.04)))
            .overlay(Capsule().strokeBorder(urgent ? Tokens.amber.opacity(0.6) : Tokens.perimeter, lineWidth: 1))
            .animation(Tokens.snap, value: urgent)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("g", modifiers: .command)
        .help("Return to \(pinned.name)")
    }
}

/// Up to three ephemeral micro-steps; never persisted.
private struct MicroStepScratchpad: View {
    @EnvironmentObject private var engine: LatchEngine
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(engine.microSteps.enumerated()), id: \.element.id) { index, step in
                Button { engine.toggleMicroStep(step.id) } label: {
                    HStack(spacing: 6) {
                        Text(step.isDone ? "▪" : "▫")
                            .foregroundStyle(step.isDone ? Tokens.emerald : Tokens.keycapText)
                        Text("\(index + 1). \(step.text)")
                            .strikethrough(step.isDone, color: Tokens.keycapText)
                            .foregroundStyle(step.isDone ? Tokens.keycapText : Tokens.silver)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .font(LatchFont.meta)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if engine.microSteps.count < LatchEngine.maxMicroSteps {
                HStack(spacing: 6) {
                    Text("+")
                        .font(LatchFont.meta)
                        .foregroundStyle(Tokens.keycapText)
                    TextField(
                        "",
                        text: $draft,
                        prompt: Text("micro-step \(engine.microSteps.count + 1)/\(LatchEngine.maxMicroSteps)")
                            .foregroundStyle(Tokens.keycapText.opacity(0.7)))
                        .textFieldStyle(.plain)
                        .font(LatchFont.meta)
                        .foregroundStyle(Tokens.crispWhite)
                        .onSubmit {
                            engine.addMicroStep(draft)
                            draft = ""
                        }
                }
            }
        }
        .animation(Tokens.snap, value: engine.microSteps)
    }
}
