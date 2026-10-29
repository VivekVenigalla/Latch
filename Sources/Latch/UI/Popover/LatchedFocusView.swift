import LatchCore
import SwiftUI

/// State 2: the single-threaded execution lock.
struct LatchedFocusView: View {
    @EnvironmentObject private var engine: LatchEngine
    let session: ActiveSession

    private var tint: Color {
        engine.isOvertime || session.isClamped ? Tokens.amber : Tokens.emerald
    }

    private var statusLabel: String {
        if engine.isOvertime { return "OVERTIME" }
        if session.isClamped { return "CLAMPED" }
        return "LATCHED"
    }

    var body: some View {
        VStack(spacing: 0) {
            EdgeProgressFilament(
                progress: engine.isOvertime ? 1 : session.progressRemaining(remainingSeconds: engine.remainingSeconds),
                tint: tint)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(TimeFormat.clock(engine.remainingSeconds))
                        .font(LatchFont.timer)
                        .foregroundStyle(engine.isOvertime ? Tokens.amber : Tokens.crispWhite)
                    SectionLabel(statusLabel, color: tint)
                        .help(session.clampReason ?? "")
                    Spacer(minLength: 4)
                }

                Text(session.task.title)
                    .font(LatchFont.title)
                    .tracking(-0.2)
                    .foregroundStyle(Tokens.crispWhite)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let context = session.task.metadata.context {
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
                if let reason = session.clampReason {
                    Text(reason)
                        .font(LatchFont.keycap)
                        .foregroundStyle(Tokens.amber)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
