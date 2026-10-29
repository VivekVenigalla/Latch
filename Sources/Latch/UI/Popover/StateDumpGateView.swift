import AppKit
import LatchCore
import SwiftUI

/// State 3: the mandatory context-serialization gate. There is deliberately no cancel path:
/// the only ways out are logging a next action (↩) or marking the task done (⌘↩).
struct StateDumpGateView: View {
    @EnvironmentObject private var engine: LatchEngine
    let session: ActiveSession
    @State private var note = ""
    @FocusState private var fieldFocused: Bool

    private var canCommit: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Tokens.amber).frame(height: 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ShutterGlyphView(layout: engine.shutter, scale: 0.75)
                    SectionLabel("STATE DUMP", color: Tokens.amber)
                    Spacer()
                    Text("\(TimeFormat.clock(TimeInterval(session.sessionElapsedSeconds()))) logged")
                        .font(LatchFont.timer)
                        .foregroundStyle(Tokens.keycapText)
                }

                Text(session.task.title)
                    .font(LatchFont.title)
                    .tracking(-0.2)
                    .foregroundStyle(Tokens.crispWhite)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if session.driftSeconds() > 0 {
                    Text(driftSummary)
                        .font(LatchFont.meta.monospacedDigit())
                        .foregroundStyle(Tokens.amber)
                        .lineLimit(1)
                }

                Text("Task incomplete. Log exact next physical action to unlatch:")
                    .font(LatchFont.meta)
                    .foregroundStyle(Tokens.silver)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                RecessedWell {
                    TextField(
                        "",
                        text: $note,
                        prompt: Text(session.task.metadata.context ?? "e.g. Run test suite on MockOrderBook")
                            .foregroundStyle(Tokens.keycapText.opacity(0.7)))
                        .textFieldStyle(.plain)
                        .font(LatchFont.meta)
                        .foregroundStyle(Tokens.crispWhite)
                        .focused($fieldFocused)
                        .onSubmit(commit)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Spacer(minLength: 0)
            Hairline()

            HStack(spacing: 6) {
                KeycapButton(title: "Log & Unlatch", key: "↩", prominent: true, action: commit)
                    .disabled(!canCommit)
                KeycapButton(title: "Done", key: "⌘↩") { engine.complete() }
                    .keyboardShortcut(.return, modifiers: .command)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .onAppear {
            // The window may not be key yet on the same runloop pass.
            DispatchQueue.main.async { fieldFocused = true }
        }
    }

    /// `Drifted 03:12 across 2 excursions`
    private var driftSummary: String {
        let episodes = session.drift.episodes
        let clock = TimeFormat.clock(TimeInterval(session.driftSeconds()))
        return "Drifted \(clock) across \(episodes) excursion\(episodes == 1 ? "" : "s")"
    }

    private func commit() {
        if !engine.commitContext(note) { NSSound.beep() }
    }
}
