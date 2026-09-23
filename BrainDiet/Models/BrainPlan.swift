import Foundation

// MARK: - BrainPlan — the one-time "your protection" setup (spec-v2).
//
// Built once from onboarding. It is NOT a daily loop anymore — it holds the
// personal reference points the automatic engine + blocking use:
//   • baseline flagged-app minutes (what reclaimed time is measured against)
//   • the daily cap the out-of-process DeviceActivity schedule enforces
//   • the reclaimed-time promise + the goal it's for
//
// A plain value type: the same contract a future AI Edge Function would return.

struct BrainPlan {

    let goalNoun: String
    let why: String

    /// The user's onboarding baseline (flagged-app minutes/day). The reference
    /// point the automatic reclaimed-time engine measures against.
    let baselineMinutes: Int
    /// The daily cap the out-of-process schedule enforces (minutes).
    let junkCapMinutes: Int
    /// Reclaimed minutes/day the plan aims to return vs. baseline (the promise).
    let reclaimedMinutes: Int

    let restDay: String            // e.g. "Sundays — rest, no shame"

    var hook: String { "Made to bring you closer to \(goalNoun)." }

    /// Reclaimed promise rounded to whole hours for the hero figure.
    var reclaimedHours: Int { Int((Double(reclaimedMinutes) / 60).rounded()) }
}

// MARK: - Deterministic generator (rule-based — NO AI)

extension BrainPlan {

    enum Rules {
        /// Cap = baseline × this factor (roughly halve it)…
        static let junkCapFactor = 0.5
        /// …floored so the cap is never punishingly low.
        static let junkCapFloorMinutes = 15
        /// Default weekly rest day (1 = Sunday in Calendar).
        static let restWeekday = 1
    }

    static func generate(from profile: UserProfile) -> BrainPlan {
        generate(
            goalID: profile.headlineGoalID,
            goalNoun: profile.goalNoun,
            why: profile.why,
            baselineJunkMinutes: profile.baselineJunkMinutes
        )
    }

    static func generate(
        goalID: String?,
        goalNoun: String,
        why: String,
        baselineJunkMinutes: Int
    ) -> BrainPlan {
        let cap = max(
            Rules.junkCapFloorMinutes,
            Int((Double(baselineJunkMinutes) * Rules.junkCapFactor).rounded())
        )
        let reclaimed = max(0, baselineJunkMinutes - cap)
        let cleanWhy = why.trimmingCharacters(in: .whitespacesAndNewlines)

        return BrainPlan(
            goalNoun: goalNoun,
            why: cleanWhy,
            baselineMinutes: baselineJunkMinutes,
            junkCapMinutes: cap,
            reclaimedMinutes: reclaimed,
            restDay: restDayLabel(weekday: Rules.restWeekday)
        )
    }

    private static func restDayLabel(weekday: Int) -> String {
        var cal = Calendar.current
        cal.locale = .current
        let name = cal.weekdaySymbols[(weekday - 1) % 7]
        return "\(name)s: rest, no shame"
    }

    /// Preview/demo convenience.
    static func mock(goalNoun: String = "your reading list", why: String = "") -> BrainPlan {
        generate(goalID: "read", goalNoun: goalNoun, why: why, baselineJunkMinutes: 180)
    }
}
