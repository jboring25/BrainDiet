import Foundation

// MARK: - MenuExposure — which steps were offered, and which were passed over.
//
// ⭐ LAYER 4, SKIP-AWARE RE-RANKING (2026-09-21). `ProtectSession.stepID` has been
// recorded for weeks and never read per-step, so a step someone ignored eleven
// days running was still offered unchanged on day twelve. The plan could not
// learn, which made it a list, not a coach.
//
// A SKIP is defined narrowly and honestly: the step was one of the Menu's three
// on a past day, and no session was logged against it that day. Nothing is
// inferred from a step that was never shown — not doing something you were never
// offered is not a verdict on it.
//
// It only ever LOWERS a step's rank, and a single completion wipes its slate.
// Nothing is deleted from the plan: a skipped step steps aside, it does not leave.

enum MenuExposure {

    private static let key = "bd.menuExposure.v1"
    /// Days of history kept per step. Two weeks is enough to see a pattern and
    /// short enough that last month's bad fortnight stops counting against you.
    private static let window = 14

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormat.string(from: date) }

    private static func load() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return map
    }

    private static func save(_ map: [String: [String]]) {
        if let data = try? JSONEncoder().encode(map) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Note that these steps were offered today. Idempotent — the Menu can call
    /// it on every appearance without inflating anything.
    static func recordShown(_ stepIDs: [UUID], now: Date = .now) {
        guard !stepIDs.isEmpty else { return }
        var map = load()
        let today = dayKey(now)
        let cutoff = dayKey(Calendar.current.date(byAdding: .day, value: -window, to: now) ?? now)
        for id in stepIDs {
            var days = map[id.uuidString] ?? []
            if !days.contains(today) { days.append(today) }
            map[id.uuidString] = days.filter { $0 >= cutoff }
        }
        save(map)
    }

    #if DEBUG
    /// Screenshot/verification seam: pretend these steps were offered on those
    /// past days. Used by `BD_SEED_SKIPS=1` to prove the re-rank actually fires,
    /// since there is no test target and reasoning about it is not evidence.
    static func debugSeed(_ stepID: UUID, daysAgo: [Int], now: Date = .now) {
        var map = load()
        var days = map[stepID.uuidString] ?? []
        for d in daysAgo {
            guard let date = Calendar.current.date(byAdding: .day, value: -d, to: now) else { continue }
            let key = dayKey(date)
            if !days.contains(key) { days.append(key) }
        }
        map[stepID.uuidString] = days
        save(map)
    }
    #endif

    /// Skips per step: past days it was shown with no session on it that day,
    /// counted only since its most recent completion.
    static func skips(sessions: [ProtectSession], now: Date = .now) -> [UUID: Int] {
        let map = load()
        let today = dayKey(now)
        var doneDays: [UUID: Set<String>] = [:]
        var lastDone: [UUID: String] = [:]
        for s in sessions {
            guard let id = s.stepID else { continue }
            let d = dayKey(s.startedAt)
            doneDays[id, default: []].insert(d)
            if d > (lastDone[id] ?? "") { lastDone[id] = d }
        }
        var out: [UUID: Int] = [:]
        for (raw, days) in map {
            guard let id = UUID(uuidString: raw) else { continue }
            let since = lastDone[id] ?? ""
            let n = days.filter { $0 < today && $0 > since && !(doneDays[id]?.contains($0) ?? false) }.count
            if n > 0 { out[id] = n }
        }
        return out
    }
}
