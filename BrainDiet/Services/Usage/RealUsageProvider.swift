import Foundation

// MARK: - RealUsageProvider — automatic reclaimed-time from DeviceActivity.
//
// Compiled ONLY when BRAINDIET_FAMILY_CONTROLS is defined (entitlement present).
// Reads the per-day flagged-app minute totals that the DeviceActivityMonitor
// extension records into the shared App Group. The extension is scheduled with
// DeviceActivityEvent thresholds and updates the running daily total as usage
// accrues; this provider simply reads those totals — it does no monitoring
// itself, keeping all the privileged work out-of-process.
//
// REAL-DATA LIMITS (flagged for Athena / the deliverable):
//   • DeviceActivity does not hand the app a live "minutes used" number on
//     demand. It fires threshold callbacks (e.g. every 5 min) into the
//     extension. So today's total has the granularity of the thresholds we
//     schedule, and it lags reality by up to one threshold window. Historical
//     days are exact once their interval has ended.
//   • Totals only exist from the day monitoring was first armed onward; there is
//     no backfill of usage from before the user granted access.

#if canImport(DeviceActivity) && BRAINDIET_FAMILY_CONTROLS
import DeviceActivity

final class RealUsageProvider: UsageProvider, @unchecked Sendable {

    private let appGroup: String
    init(appGroup: String) { self.appGroup = appGroup }

    /// ⭐ FIXED 2026-08-09 — this used to return `true` unconditionally.
    ///
    /// THE BUG: being ENTITLED is not the same as HAVING DATA. The moment the
    /// user grants Family Controls this provider existed and claimed live data,
    /// but the DeviceActivity extension only starts accruing totals from the
    /// day monitoring is armed (see the REAL-DATA LIMITS note above) — so for
    /// the whole first day the app believed it had a mirror and had nothing to
    /// show in it. Every surface that branches on `hasLiveData` was reasoning
    /// from a claim the data didn't support.
    ///
    /// Now it answers the question it is actually asked: is there at least one
    /// recorded day? Scans the same lookback window the engine uses.
    var hasLiveData: Bool {
        guard let store = defaults else { return false }
        let cal = Calendar.current
        let now = Date()
        for ago in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -ago, to: now) else { continue }
            if store.object(forKey: BlockingConfig.dailyUsageKey(for: cal.startOfDay(for: day))) != nil {
                return true
            }
        }
        return false
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    func usage(lastDays days: Int, baselineMinutes: Int,
               categories: [String: AppCategory], now: Date) -> [DayUsage] {
        let cal = Calendar.current
        let store = defaults
        return (0..<days).reversed().map { ago in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -ago, to: now) ?? now)
            let key = BlockingConfig.dailyUsageKey(for: day)
            if let store, store.object(forKey: key) != nil {
                return DayUsage(
                    day: day,
                    flaggedMinutes: max(0, store.integer(forKey: key)),
                    hasData: true,
                    categoryMinutes: readCategoryMinutes(store: store, day: day, categories: categories)
                )
            }
            return DayUsage.empty(day)
        }
    }

    /// Reads the per-nutrition-class daily totals the DeviceActivityMonitor
    /// extension accrues into the App Group (one key per class per day). Only
    /// classes the user has categorized apps for are populated.
    private func readCategoryMinutes(
        store: UserDefaults, day: Date, categories: [String: AppCategory]
    ) -> [AppCategory: Int] {
        guard !categories.isEmpty else { return [:] }
        var out: [AppCategory: Int] = [:]
        for category in Set(categories.values) {
            let key = BlockingConfig.dailyCategoryUsageKey(for: day, category: category.rawValue)
            if store.object(forKey: key) != nil {
                out[category] = max(0, store.integer(forKey: key))
            }
        }
        return out
    }
}
#endif
