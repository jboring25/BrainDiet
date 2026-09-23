import Foundation

// MARK: - DegradedUsageProvider — the no-entitlement automatic-data fallback.
//
// Used whenever the Family Controls / DeviceActivity stack isn't available
// (simulator, un-entitled build). It is NOT manual logging — the app stays
// automatic. In RELEASE it reports no data (`hasLiveData == false`), so Home
// renders the calm "your protection isn't active yet" state.
//
// In DEBUG it synthesizes a realistic "comeback" curve (flagged-app minutes
// falling over ~30 days) so previews, the simulator, and screenshots look alive
// with automatic-style numbers — never hand-logged.

final class DegradedUsageProvider: UsageProvider, @unchecked Sendable {

    #if DEBUG
    // Seeded numbers ONLY when the demo-history env explicitly asks for them —
    // a plain DEBUG run stays honest (matches release behavior).
    var hasLiveData: Bool {
        ProcessInfo.processInfo.environment["BD_SEED_HISTORY"] == "1"
    }
    #else
    var hasLiveData: Bool { false }
    #endif

    func usage(lastDays days: Int, baselineMinutes: Int,
               categories: [String: AppCategory], now: Date) -> [DayUsage] {
        let cal = Calendar.current
        return (0..<days).reversed().map { ago in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -ago, to: now) ?? now)
            #if DEBUG
            if hasLiveData {
                let flagged = seededFlaggedMinutes(daysAgo: ago, baseline: baselineMinutes, now: now, day: day)
                return DayUsage(
                    day: day,
                    flaggedMinutes: flagged,
                    hasData: true,
                    categoryMinutes: seededCategoryMinutes(
                        daysAgo: ago, flagged: flagged, baseline: baselineMinutes,
                        categories: categories, day: day)
                )
            }
            #endif
            // No automatic feed yet → no data. Home shows the honest state.
            return DayUsage.empty(day)
        }
    }

    #if DEBUG
    /// `BD_SLOP_DAY=1` (with BD_SEED_HISTORY=1): TODAY runs junk-heavy so the
    /// slop-voice redirect + the tray's big slop mound are screenshot-able.
    private var isSlopDay: Bool {
        ProcessInfo.processInfo.environment["BD_SLOP_DAY"] == "1"
    }

    /// A deterministic, realistic decline in flagged-app minutes (the comeback
    /// shape): heavy near baseline 30 days ago, settling well under the cap now.
    /// Today is dampened so "reclaimed today" reads like a strong-but-real day.
    private func seededFlaggedMinutes(daysAgo ago: Int, baseline: Int, now: Date, day: Date) -> Int {
        // A slop-day today: flagged well over the cap (baseline 180 → 120m junk
        // vs. a 90m budget) so the slop voice + heavy tray render honestly.
        if ago == 0, isSlopDay { return min(baseline, Int(Double(baseline) * 0.67)) }
        let span = 30.0
        let progress = max(0, min(1, Double(29 - min(ago, 29)) / (span - 1)))  // 0 → 1 over 30d
        // Start ~baseline, trend down to ~35% of baseline, with mild day-to-day noise.
        let floor = Double(baseline) * 0.32
        let base = Double(baseline)
        let trended = base - (base - floor) * progress
        // Deterministic pseudo-noise per day so it's stable across renders — a
        // wider swing so the week strip has real day-to-day shape (some strong
        // days, some gentler ones), not a flat wall of bars.
        let seed = Int(day.timeIntervalSince1970 / 86_400)
        let noise = Double((seed &* 2_654_435_761 >> 8) % 60) - 26   // ~ -26…+33
        var minutes = Int((trended + noise).rounded())
        // Today: a genuinely good day so the hero number feels earned.
        if ago == 0 { minutes = max(10, Int(floor * 0.7)) }
        return max(0, min(baseline, minutes))
    }

    /// Synthesizes a realistic per-nutrition-class split for "Today's Mental Diet."
    /// Junk minutes track the flagged total (the flagged apps ARE the junk); the
    /// comeback shifts weight toward nourishing over the 30-day span, so today
    /// reads healthy (~70% nourishing) while 30 days ago read junk-heavy. Only
    /// classes the user actually has categorized apps for are populated.
    private func seededCategoryMinutes(
        daysAgo ago: Int, flagged: Int, baseline: Int,
        categories: [String: AppCategory], day: Date
    ) -> [AppCategory: Int] {
        guard !categories.isEmpty else { return [:] }
        let present = Set(categories.values)

        // The slop-day split: junk dominates, nourishing/leisure stay modest.
        if ago == 0, isSlopDay {
            var out: [AppCategory: Int] = [:]
            if present.contains(.junk)       { out[.junk] = flagged }
            if present.contains(.nourishing) { out[.nourishing] = Int(Double(baseline) * 0.30) }
            if present.contains(.leisure)    { out[.leisure] = Int(Double(baseline) * 0.28) }
            return out
        }
        // 0 (30d ago) → 1 (today): how far along the comeback we are.
        let progress = max(0, min(1, Double(29 - min(ago, 29)) / 29.0))

        // Junk time = the flagged minutes (already declining over the comeback).
        var out: [AppCategory: Int] = [:]
        if present.contains(.junk) { out[.junk] = max(0, flagged) }

        // Nourishing rises with the comeback; leisure stays a gentle constant.
        // Scale off baseline so heavier users see proportionally larger numbers.
        let seed = Int(day.timeIntervalSince1970 / 86_400)
        let noise = Double((seed &* 40_503 >> 6) % 20) - 10   // ~ -10…+9

        if present.contains(.nourishing) {
            let base = Double(baseline) * (0.35 + 0.85 * progress)   // grows a lot
            out[.nourishing] = max(0, Int((base + noise).rounded()))
        }
        if present.contains(.leisure) {
            let base = Double(baseline) * (0.30 + 0.10 * progress)   // fairly flat
            out[.leisure] = max(0, Int((base + noise * 0.6).rounded()))
        }
        return out
    }
    #endif
}
