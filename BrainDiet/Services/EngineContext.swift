import Foundation

// MARK: - EngineContext — resolves the canonical plan + engine from persisted
// profile + AUTOMATIC usage (spec-v2).
//
// Screens build one of these from their @Query'd profile + the injected
// UsageProvider, then read everything off `engine` / `plan`. Falls back to a
// coherent day-zero state when no profile exists yet (previews / edge cases).

struct EngineContext {
    let profile: UserProfile?
    let plan: BrainPlan
    let engine: BrainEngine
    let goalID: String?
    /// Whether the user has categorized their apps (drives the Mental Diet card).
    let hasCategorized: Bool
    /// Whether the engine is on real automatic data (vs. the degraded state).
    var hasLiveData: Bool { engine.hasLiveData }

    /// How many days of usage the engine pulls (covers the Journey month view).
    static let lookbackDays = 30

    /// `sessions` = the view's @Query'd ProtectSessions. They feed the engine's
    /// protected-minutes loop (ring, streak, reclaimed floor) — pass them wherever
    /// they're available so a session moves Home even with zero usage data.
    init(profile: UserProfile?, usage provider: UsageProvider,
         sessions: [ProtectSession] = [], now: Date = .now) {
        self.profile = profile
        self.goalID = profile?.headlineGoalID
        self.hasCategorized = profile?.hasCategorized ?? false

        let plan: BrainPlan
        if let profile {
            plan = BrainPlan.generate(from: profile)
        } else {
            plan = BrainPlan.generate(
                goalID: nil,
                goalNoun: GoalCatalog.noun(for: nil),
                why: "",
                baselineJunkMinutes: 90
            )
        }
        self.plan = plan

        let days = provider.usage(
            lastDays: Self.lookbackDays,
            baselineMinutes: plan.baselineMinutes,
            categories: profile?.appCategories ?? [:],
            now: now
        )
        var engine = BrainEngine(
            baselineMinutes: plan.baselineMinutes,
            usage: days,
            hasLiveData: provider.hasLiveData
        )
        engine.now = now

        // Fold the sessions into per-day protected minutes (start-of-day keyed).
        let cal = Calendar.current
        var byDay: [Date: Int] = [:]
        for s in sessions {
            byDay[cal.startOfDay(for: s.startedAt), default: 0] += s.minutes
        }
        engine.protectedMinutesByDay = byDay

        self.engine = engine
    }
}
