import Foundation

// MARK: - BrainEngine — the canonical compute layer (automatic, spec-v2).
//
// ONE source of truth. Given the user's baseline (from onboarding) + the
// AUTOMATIC per-day flagged-app usage (from DeviceActivity, via UsageProvider),
// it computes the only things the app cares about now:
//
//   • reclaimed time today / this week (baseline − flagged usage)
//   • what that time REPRESENTS (goal units: chapters, workouts, …)
//   • who the user is becoming (identity)
//   • a light streak of days that returned meaningful time
//
// No score, no macros, no traffic-light logging — those were tracker mechanics
// and are gone (product-spec-v2). Every screen reads from here.

struct BrainEngine {

    enum Constants {
        /// A day "counts" toward the streak once it returns at least this many
        /// minutes vs. baseline — a low, encouraging bar (a real, gentle win).
        static let streakMinReclaimed = 20
    }

    // MARK: - Mind Health weights (spec-v2.2)
    //
    // The daily Mind Health score (0–100) is a weighted composite of five signals,
    // each normalized to 0…1, then summed and scaled. Tunable constants — they
    // are the ONLY place the balance of the score lives.
    //
    // Framing (critical): this is a DAILY ACHIEVEMENT you close, not a grade of
    // the person. It resets every morning (a fresh ring). A low day is never
    // shamed — the qualitative label bottoms out at "Getting there," never "Poor."
    enum MindHealth {
        /// How much a day's reclaimed time contributes (vs. the plan's promise).
        static let wReclaimed = 0.32
        /// Doing a focus session today (or protection simply running).
        static let wFocus = 0.14
        /// Keeping junk share low.
        static let wLowJunk = 0.20
        /// Feeding your mind (nourishing share high).
        static let wNourishing = 0.20
        /// Showing up day after day (streak).
        static let wConsistency = 0.14

        /// A streak of this length maxes the consistency signal (a reachable bar).
        static let streakForFull = 5
        /// Junk share (0…1) at/above which the low-junk signal reads 0.
        static let junkCeiling = 0.60
        /// Nourishing share (0…1) at/above which the nourishing signal reads full.
        static let nourishingTarget = 0.55
    }

    /// Onboarding baseline: the user's typical daily flagged-app minutes. The
    /// reference point everything is measured against.
    let baselineMinutes: Int
    /// Automatic usage, oldest → today (from the UsageProvider). One per day.
    let usage: [DayUsage]
    var calendar = Calendar.current
    var now: Date = .now

    /// True when the numbers are real automatic data (vs. the degraded "not
    /// active yet" state). Drives Home's calm degraded rendering.
    let hasLiveData: Bool

    /// Minutes protected via ProtectSessions, keyed by start-of-day. Set by
    /// EngineContext from the views' @Query'd sessions — the engine never touches
    /// SwiftData itself. Sessions FEED the loop: even with zero usage data, a
    /// protected block moves the ring, floors reclaimed time, and earns the streak.
    var protectedMinutesByDay: [Date: Int] = [:]

    /// Protected (ProtectSession) minutes on a given day.
    func protectedMinutes(on day: Date) -> Int {
        protectedMinutesByDay[calendar.startOfDay(for: day)] ?? 0
    }

    var todayProtectedMinutes: Int { protectedMinutes(on: now) }

    /// True once the user has ever run a Protect session.
    var hasProtectedHistory: Bool { !protectedMinutesByDay.isEmpty }

    // MARK: - Lookup

    private func entry(on day: Date) -> DayUsage? {
        usage.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    func hasData(on day: Date) -> Bool { entry(on: day)?.hasData ?? false }

    /// Reclaimed minutes for a day: max(0, baseline − flagged usage), floored at
    /// the day's PROTECTED session minutes — a deliberately reclaimed block always
    /// counts, even before any automatic usage data exists.
    func reclaimedMinutes(on day: Date) -> Int {
        let protected = protectedMinutes(on: day)
        guard let e = entry(on: day), e.hasData else { return protected }
        return max(protected, max(0, baselineMinutes - e.flaggedMinutes))
    }

    // MARK: - Today

    var todayReclaimedMinutes: Int { reclaimedMinutes(on: now) }
    var hasDataToday: Bool { hasData(on: now) }

    // MARK: - Today's Mental Diet (spec-v2.1) — the automatic nutrition panel

    /// Today's per-nutrition-class share, derived automatically from categorized
    /// app usage. `nil` when there's nothing to show yet (no data / uncategorized)
    /// — Home then simply omits the panel rather than showing an empty one.
    var todayMentalDiet: MentalDiet? { mentalDiet(on: now) }

    /// The Mental Diet for a specific day. Rounds shares to whole percents that
    /// sum to exactly 100 (largest-remainder), so the panel never reads 99% / 101%.
    func mentalDiet(on day: Date) -> MentalDiet? {
        guard let e = entry(on: day), e.hasData else { return nil }
        let raw = e.categoryMinutes.filter { $0.value > 0 }
        let total = raw.values.reduce(0, +)
        guard total > 0 else { return nil }

        // Largest-remainder rounding so percents sum to 100.
        let exact = AppCategory.allCases.compactMap { cat -> (AppCategory, Double)? in
            guard let m = raw[cat], m > 0 else { return nil }
            return (cat, Double(m) / Double(total) * 100)
        }
        var floors = exact.map { ($0.0, Int($0.1), $0.1 - Double(Int($0.1))) }
        let assigned = floors.reduce(0) { $0 + $1.1 }
        var remainder = 100 - assigned
        floors.sort { $0.2 > $1.2 }
        var i = 0
        while remainder > 0, !floors.isEmpty {
            floors[i % floors.count].1 += 1
            remainder -= 1
            i += 1
        }
        let percents = Dictionary(uniqueKeysWithValues: floors.map { ($0.0, $0.1) })
        return MentalDiet(minutes: raw, percents: percents, totalMinutes: total)
    }

    /// Signed delta vs. yesterday's reclaimed time (nil when no yesterday data).
    var reclaimedDeltaVsYesterday: Int? {
        let y = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        guard hasData(on: y) else { return nil }
        return todayReclaimedMinutes - reclaimedMinutes(on: y)
    }

    // MARK: - Mind Health (spec-v2.2) — the daily achievement the ring represents
    //
    // A 0–100 composite of how well you fed your mind TODAY. Behavior you control,
    // reset each morning. Never a permanent grade. `dailyPromise` scales the
    // reclaimed signal (the plan's promise); passed in from the plan so the engine
    // stays plan-agnostic.

    /// Today's Mind Health score (0–100). Returns 0 when there's no data yet — the
    /// UI renders that as a calm, not-yet-started state, never a failing grade.
    func mindHealthToday(dailyPromise: Int) -> Int {
        mindHealth(on: now, dailyPromise: dailyPromise)
    }

    /// Mind Health for a specific day (0–100). The full weighted composite.
    func mindHealth(on day: Date, dailyPromise: Int) -> Int {
        guard hasData(on: day) || protectedMinutes(on: day) > 0 else { return 0 }

        // 1. Reclaimed vs. the daily promise (capped at 1).
        let reclaimed = reclaimedMinutes(on: day)
        let reclaimedSignal = min(1.0, Double(reclaimed) / Double(max(1, dailyPromise)))

        // 2. Focus / protection: ANY Protect session on this day earns it fully —
        //    the deliberate act is the strongest signal. Otherwise a meaningful
        //    reclaimed day implies the block ran.
        let focusSignal: Double = protectedMinutes(on: day) > 0
            ? 1.0
            : (reclaimed >= Constants.streakMinReclaimed ? 1.0 : 0.35)

        // 3 & 4. Diet mix — low junk + high nourishing (from the automatic panel).
        let diet = mentalDiet(on: day)
        let junkShare = Double(diet?.percents[.junk] ?? 0) / 100.0
        let nourishingShare = Double(diet?.percents[.nourishing] ?? 0) / 100.0
        let lowJunkSignal = max(0, 1 - junkShare / MindHealth.junkCeiling)
        let nourishingSignal = min(1, nourishingShare / MindHealth.nourishingTarget)

        // 5. Consistency — the streak up to and including this day.
        let streakHere = streak(asOf: day)
        let consistencySignal = min(1.0, Double(streakHere) / Double(MindHealth.streakForFull))

        let composite =
            reclaimedSignal    * MindHealth.wReclaimed +
            focusSignal        * MindHealth.wFocus +
            lowJunkSignal      * MindHealth.wLowJunk +
            nourishingSignal   * MindHealth.wNourishing +
            consistencySignal  * MindHealth.wConsistency

        return Int((composite * 100).rounded())
    }

    /// Per-day Mind Health over the last `days` (oldest → today) for Becoming's
    /// gentle trend. Days without data carry a nil score (rendered as a gap).
    func mindHealthByDay(lastDays days: Int, dailyPromise: Int) -> [DayScore] {
        (0..<days).reversed().map { ago in
            let day = calendar.date(byAdding: .day, value: -ago, to: now) ?? now
            let has = hasData(on: day)
            return DayScore(
                date: day,
                score: has ? mindHealth(on: day, dailyPromise: dailyPromise) : nil,
                isToday: calendar.isDateInToday(day)
            )
        }
    }

    // MARK: - Reframe (goal-aware) — what the time REPRESENTS

    /// "3 chapters" / "a full workout" — concrete, singular/plural-correct.
    func reframe(forReclaimed minutes: Int, goalID: String?) -> String {
        let unit = GoalCatalog.unit(for: goalID)
        let units = max(0, minutes / max(1, unit.minutesPer))
        if units == 0 {
            return String(localized: "a fresh start")
        }
        return "\(units) \(unit.noun(for: units))"
    }

    func reclaimedDisplay(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    // MARK: - Streak — consecutive days that returned meaningful time

    var streak: Int { streak(asOf: now) }

    /// The streak of consecutive meaningful days ending at `asOf` (inclusive if
    /// that day qualifies, else counting back from the day before).
    func streak(asOf asOf: Date) -> Int {
        var count = 0
        var day = asOf
        if !returnedMeaningfully(on: asOf) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while returnedMeaningfully(on: day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private func returnedMeaningfully(on day: Date) -> Bool {
        // A streak day is earned by returned time OR a protected block — the
        // deliberate session counts even before any automatic usage data exists.
        reclaimedMinutes(on: day) >= Constants.streakMinReclaimed
            || protectedMinutes(on: day) >= Constants.streakMinReclaimed
    }

    // MARK: - Aggregates (Journey)

    /// Total reclaimed minutes across the last `days` (only days with data).
    func reclaimedMinutes(lastDays days: Int) -> Int {
        (0..<days).reduce(0) { sum, ago in
            let day = calendar.date(byAdding: .day, value: -ago, to: now) ?? now
            return sum + reclaimedMinutes(on: day)
        }
    }

    /// Total minutes in a nutrition class across the last `days` — powers
    /// Becoming's identity progress + the weekly diet trend.
    func categoryMinutes(_ category: AppCategory, lastDays days: Int) -> Int {
        (0..<days).reduce(0) { sum, ago in
            let day = calendar.date(byAdding: .day, value: -ago, to: now) ?? now
            guard let diet = mentalDiet(on: day) else { return sum }
            return sum + (diet.minutes[category] ?? 0)
        }
    }

    /// The nutrition-class MIX (whole percents summing to 100) across the last
    /// `days` — Becoming's "how your mental diet is shifting" read. nil when no data.
    func dietMix(lastDays days: Int) -> [AppCategory: Int]? {
        var totals: [AppCategory: Int] = [:]
        for cat in AppCategory.allCases {
            let m = categoryMinutes(cat, lastDays: days)
            if m > 0 { totals[cat] = m }
        }
        let sum = totals.values.reduce(0, +)
        guard sum > 0 else { return nil }
        // Largest-remainder rounding so it reads 100.
        var floors = totals.map { ($0.key, Int(Double($0.value) / Double(sum) * 100),
                                   Double($0.value) / Double(sum) * 100 - Double(Int(Double($0.value) / Double(sum) * 100))) }
        var remainder = 100 - floors.reduce(0) { $0 + $1.1 }
        floors.sort { $0.2 > $1.2 }
        var i = 0
        while remainder > 0, !floors.isEmpty {
            floors[i % floors.count].1 += 1
            remainder -= 1
            i += 1
        }
        return Dictionary(uniqueKeysWithValues: floors.map { ($0.0, $0.1) })
    }

    /// Per-day reclaimed minutes over the last `days` (oldest → today) for the
    /// Journey's minimal week strip.
    func reclaimedByDay(lastDays days: Int) -> [DayReclaimed] {
        (0..<days).reversed().map { ago in
            let day = calendar.date(byAdding: .day, value: -ago, to: now) ?? now
            return DayReclaimed(
                date: day,
                minutes: reclaimedMinutes(on: day),
                hasData: hasData(on: day),
                isToday: calendar.isDateInToday(day)
            )
        }
    }

    /// Best single day (most time returned) in the last `days`.
    func bestDay(lastDays days: Int) -> DayReclaimed? {
        reclaimedByDay(lastDays: days).filter { $0.hasData }.max { $0.minutes < $1.minutes }
    }
}

// MARK: - One day of reclaimed time (Journey's atomic unit)

struct DayReclaimed: Identifiable {
    var id: Date { date }
    let date: Date
    let minutes: Int
    let hasData: Bool
    let isToday: Bool

    var weekdayLetter: String { date.formatted(.dateTime.weekday(.narrow)) }
}

// MARK: - One day of Mind Health (Becoming's trend unit)

struct DayScore: Identifiable {
    var id: Date { date }
    let date: Date
    /// nil when the day has no automatic data yet (rendered as a gap).
    let score: Int?
    let isToday: Bool

    var weekdayLetter: String { date.formatted(.dateTime.weekday(.narrow)) }
}

// MARK: - Mind Health label (spec-v2.2) — the qualitative word under the number.
//
// Scales gently and NEVER shames: high → "Excellent / Well-fed / Nourished";
// mid → "Solid / Good"; low → "Getting there / A quiet day." There is no "Poor,"
// no grade, no judgement of the person — it reads how you fed your mind TODAY,
// and tomorrow is a fresh ring. Deterministic per score band so it's stable.

enum MindHealthLabel {
    /// The qualitative READ for a 0–100 score — phrases that stand alone as the
    /// Home hero headline under the plate (mockup: "Well nourished"). The hero
    /// renders the LAST word sage, preceding words ink. Never shames: low =
    /// "Running low," not "poor."
    static func word(for score: Int) -> String {
        switch score {
        case 85...:   return String(localized: "Well nourished")
        case 70..<85: return String(localized: "Well fed")
        case 55..<70: return String(localized: "Fuelled")
        case 40..<55: return String(localized: "Getting there")
        case 20..<40: return String(localized: "Running low")
        default:      return String(localized: "Depleted")
        }
    }

    /// A one-line, forward, never-shaming read for beneath the ring / in Becoming.
    static func note(for score: Int) -> String {
        switch score {
        case 70...:  return String(localized: "You fed your mind well today.")
        case 40..<70: return String(localized: "A good day for your mind.")
        default:     return String(localized: "A gentle day. Tomorrow's a fresh ring.")
        }
    }
}

// MARK: - MentalDiet — one day's automatic nutrition panel (spec-v2.1)
//
// The data behind "Today's Mental Diet — Nourishing 72% · Leisure 18% · Junk
// 10%." Percents already sum to 100. Ordered nourishing → leisure → junk for the
// panel. Purely derived from categorized Screen Time usage — never logged.

struct MentalDiet: Equatable {
    /// Raw minutes per class (only classes with >0 present).
    let minutes: [AppCategory: Int]
    /// Whole-percent share per class (sums to 100).
    let percents: [AppCategory: Int]
    /// Total monitored minutes today (the panel's denominator).
    let totalMinutes: Int

    /// Classes present today, in nutrition-panel order (nourishing first).
    var slices: [Slice] {
        AppCategory.allCases
            .sorted { $0.panelOrder < $1.panelOrder }
            .compactMap { cat in
                guard let pct = percents[cat], pct > 0 else { return nil }
                return Slice(category: cat, percent: pct, minutes: minutes[cat] ?? 0)
            }
    }

    /// The single dominant class — used for the one-line human read.
    var lead: Slice? { slices.max { $0.percent < $1.percent } }

    /// True when junk dominates the plate (drives the fresh-plate summary; also
    /// lets the label skip a doubled phrase when the junk budget says it too).
    var isJunkHeavy: Bool { (percents[.junk] ?? 0) >= 50 }

    /// A warm, one-line interpretation for the panel footer. Honest but kind.
    var summaryLine: String {
        let nourishing = percents[.nourishing] ?? 0
        let junk = percents[.junk] ?? 0
        if nourishing >= 60 {
            return String(localized: "A well-fed mind today.")
        } else if isJunkHeavy {
            return String(localized: "Heavier on the junk today. Tomorrow starts fresh.")
        } else if nourishing >= junk {
            return String(localized: "A balanced day.")
        } else {
            return String(localized: "Room for more that feeds you.")
        }
    }

    struct Slice: Identifiable, Equatable {
        var id: String { category.rawValue }
        let category: AppCategory
        let percent: Int
        let minutes: Int
    }
}
