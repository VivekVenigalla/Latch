import Foundation
import LatchCore

/// Keeps today's `DayLedger` on this Mac. It's an aggregate, not task data, so it lives in
/// UserDefaults rather than in Reminders; a new day starts from zero automatically.
/// With `defaults: nil` it is in-memory only (used by demo mode).
@MainActor
final class LedgerStore {
    static let defaultsKey = "LatchTodayLedger"
    /// UserDefaults key: daily focus goal in minutes (default 240).
    static let goalDefaultsKey = "LatchDailyGoalMinutes"

    private let defaults: UserDefaults?
    private var memory: DayLedger?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    var goalSeconds: Int {
        let minutes = (UserDefaults.standard.object(forKey: Self.goalDefaultsKey) as? NSNumber)?.intValue ?? 0
        return minutes > 0 ? minutes * 60 : DayLedger.defaultGoalSeconds
    }

    func today(at now: Date = .now) -> DayLedger {
        let key = DayLedger.dayKey(for: now)
        let stored = memory ?? defaults?.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode(DayLedger.self, from: $0) }
        guard let stored, stored.day == key else { return DayLedger(day: key) }
        return stored
    }

    func record(sessionSeconds: Int, driftSeconds: Int, completed: Bool, at now: Date = .now) {
        var ledger = today(at: now)
        ledger.record(sessionSeconds: sessionSeconds, driftSeconds: driftSeconds, completed: completed)
        save(ledger)
    }

    /// Replaces today's ledger (demo mode seeds it this way).
    func save(_ ledger: DayLedger) {
        if let defaults {
            defaults.set(try? JSONEncoder().encode(ledger), forKey: Self.defaultsKey)
        } else {
            memory = ledger
        }
    }
}
