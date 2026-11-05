import LatchCore
import SwiftUI

/// `TODAY ▕██████▆░░░▏ 2h 14m · 3 done · drift 6%` — one bar toward the daily goal: emerald
/// for on-task time, amber for drift. No history, no streaks.
struct TodayStrip: View {
    @EnvironmentObject private var engine: LatchEngine

    var body: some View {
        let today = engine.today
        let goal = engine.ledger.goalSeconds
        let fractions = today.goalFractions(goalSeconds: goal)
        HStack(spacing: 8) {
            SectionLabel("TODAY")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    HStack(spacing: 0) {
                        Rectangle().fill(Tokens.emerald).frame(width: geometry.size.width * fractions.onTask)
                        Rectangle().fill(Tokens.amber).frame(width: geometry.size.width * fractions.drift)
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 3)
            Text(today.summary)
                .font(LatchFont.meta.monospacedDigit())
                .foregroundStyle(Tokens.silver)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .help("Today: \(today.sessions) session\(today.sessions == 1 ? "" : "s") toward a \(TimeFormat.duration(goal)) goal")
        .animation(Tokens.snap, value: today)
    }
}
