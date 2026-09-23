import Foundation
import SwiftData

// MARK: - AdMode — DEBUG-only launch environment for AD-READY screen capture.
//
// `BD_AD_MODE=1` puts the app in a pristine, cinematic state for the hero ad's
// Shot 13 (pass-through-the-screen → the signature open as the calm payoff):
//
//   • A seeded ad profile: primary goal biking ("Ride more"), Mind Health 96,
//     reclaimed today exactly 2h 20m, streak 22, plate ~70% nourishing.
//   • CINEMATIC pacing: the open choreography runs ~1.6× longer beats than
//     production so the camera has air.
//   • Ad-only reframe copy: "Enough time for a bike ride." (shooting script).
//
// `BD_AD_SHOT` selects the capture:
//   open       — the full Home reveal (default)
//   unspin     — the Home surface lands from a 260%/70° spin, THEN the reveal
//                (the pass-through-the-screen transition workhorse; warm grade ON)
//   brain-loop — the brain alone, centered, radiant, breathing (loopable)
//   commit     — the hold-to-commit glow ramp + gold pulse, auto-playing
//   plan       — the "Your Brain Diet" card with biking servings + slow gold flare
//   tray       — the meal tray, chrome-free: portions plate in (slop plops matte,
//                nourishing glows on), then holds
//   intercept  — the ATTRACTION intercept (the real InterceptPreviewView on
//                the ad seed's live engine state), rising in after a cream beat
//   green      — full-screen chroma green (#00FF00), no chrome (tracking clip)
//   endtag     — the quiet closing lockup (brain + wordmark + tagline glint)
//
// `BD_AD_GRADE=warm` layers a golden-hour grade over the capture surface
// (amber temperature shift, lifted blacks, gentle highlight bloom).
//
// Everything here is DEBUG-only; release builds compile the inert stubs below
// (isEnabled == false, pace == 1.0) so call sites stay branch-free.

enum AdMode {
    #if DEBUG
    enum Shot: String {
        case open
        case unspin
        case brainLoop = "brain-loop"
        case commit
        case plan
        case tray       // the meal tray, chrome-free: portions plate in, then hold
        case intercept  // the attraction intercept (real InterceptPreviewView), auto-plays
        case green
        case endtag
    }

    static let isEnabled: Bool =
        ProcessInfo.processInfo.environment["BD_AD_MODE"] == "1"

    /// The requested capture (defaults to the full open reveal).
    static let shot: Shot =
        Shot(rawValue: ProcessInfo.processInfo.environment["BD_AD_SHOT"] ?? "") ?? .open

    /// Cinematic pacing multiplier for the open choreography (~1.6× longer beats).
    static var pace: Double { isEnabled ? 1.6 : 1.0 }

    /// Whether the golden-hour grade layers over the surface. Explicit via
    /// `BD_AD_GRADE=warm`; always ON for the unspin transition; NEVER on the
    /// chroma-green tracking clip.
    static var appliesWarmGrade: Bool {
        guard isEnabled, shot != .green else { return false }
        return shot == .unspin
            || ProcessInfo.processInfo.environment["BD_AD_GRADE"] == "warm"
    }

    /// Home's open-choreography pre-roll. The unspin shot waits for the surface
    /// to land (plus a beat of stillness) before the reveal begins.
    static var openPrerollMilliseconds: Int {
        guard isEnabled else { return 180 }
        return shot == .unspin ? 2400 : 1500
    }
    #else
    static let isEnabled = false
    static let pace = 1.0
    static let openPrerollMilliseconds = 180
    #endif
}

#if DEBUG

// MARK: - AdUsageProvider — deterministic usage that lands the ad numbers exactly.
//
// Baseline 180m/day (seeded by AdSeed). Today: 40m flagged → 140m reclaimed
// ("2h 20m"), plate 40/233/60 → 12% junk / 70% nourishing / 18% leisure.
// Yesterday: 53m flagged → 127m reclaimed → the "13m more than yesterday" whisper.
// Days 1–21 ago all reclaim ≥ 20m; day 22+ reclaims 0 → streak reads exactly 22.
// With the plan promise of 90m/day, Mind Health composes to exactly 96.

final class AdUsageProvider: UsageProvider, @unchecked Sendable {

    var hasLiveData: Bool { true }

    func usage(lastDays days: Int, baselineMinutes: Int,
               categories: [String: AppCategory], now: Date) -> [DayUsage] {
        let cal = Calendar.current
        return (0..<days).reversed().map { ago in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -ago, to: now) ?? now)
            switch ago {
            case 0:
                // Today — the hero frame: reclaimed = 180 − 40 = 140m ("2h 20m").
                return DayUsage(
                    day: day,
                    flaggedMinutes: max(0, baselineMinutes - 140),
                    hasData: true,
                    categoryMinutes: [.junk: 40, .nourishing: 233, .leisure: 60]
                )
            case 1:
                // Yesterday: 127m reclaimed → "13m more than yesterday".
                return DayUsage(
                    day: day,
                    flaggedMinutes: 53,
                    hasData: true,
                    categoryMinutes: [.junk: 53, .nourishing: 205, .leisure: 58]
                )
            case 2...21:
                // The streak body — a gentle deterministic wave, every day
                // reclaiming well over the 20m streak bar (flagged 45…145).
                let flagged = 95 + Int((50 * sin(Double(ago) * 1.1)).rounded())
                return DayUsage(
                    day: day,
                    flaggedMinutes: flagged,
                    hasData: true,
                    categoryMinutes: [.junk: flagged,
                                      .nourishing: max(40, 210 - 6 * ago),
                                      .leisure: 55]
                )
            default:
                // 22+ days ago: the "before" — full baseline, nothing returned.
                // Ends the streak at exactly 22.
                return DayUsage(
                    day: day,
                    flaggedMinutes: baselineMinutes,
                    hasData: true,
                    categoryMinutes: [.junk: baselineMinutes, .nourishing: 25, .leisure: 70]
                )
            }
        }
    }
}

// MARK: - AdSeed — the pristine ad profile (Nate's goal = BIKING).

enum AdSeed {

    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard AdMode.isEnabled else { return }

        // Wipe → one deterministic profile + biking-first plan + today's ride.
        if let ps = try? context.fetch(FetchDescriptor<UserProfile>()) { ps.forEach(context.delete) }
        if let ss = try? context.fetch(FetchDescriptor<ProtectSession>()) { ss.forEach(context.delete) }
        if let gs = try? context.fetch(FetchDescriptor<Goal>()) { gs.forEach(context.delete) }
        if let gt = try? context.fetch(FetchDescriptor<GoalStep>()) { gt.forEach(context.delete) }

        let profile = UserProfile(
            goalIDs: ["fitness", "read"],
            why: "Riding every morning.",
            baselineJunkMinutes: 180,
            junkAppIDs: ["tiktok", "instagram", "reddit"],
            appCategories: [
                "tiktok":    .junk,
                "instagram": .junk,
                "reddit":    .junk,
                "youtube":   .leisure,
                "spotify":   .leisure,
                "kindle":    .nourishing,
                "duolingo":  .nourishing
            ],
            hijackers: [.shortVideo, .social, .news],
            domains: [.fitness, .reading, .outdoors],
            primaryDomain: .fitness,
            blocker: .distracted,
            planIdentityLine: "Riding every morning."
        )
        context.insert(profile)

        // The plan — Ride first. (Custom rows, not the planner: the ad's goal
        // is biking, which isn't a stock domain seed.)
        let ride = makeGoal(
            title: "Ride more", identity: "Riding every morning.",
            domain: .fitness, isPrimary: true, sortIndex: 0,
            steps: [("Pump up your tires", 10, .oneoff),
                    ("Ride your loop", 45, .recurring),
                    ("Go for a long ride", 90, .recurring)],
            into: context
        )
        makeGoal(
            title: "Read more", identity: "Reading every night.",
            domain: .reading, isPrimary: false, sortIndex: 1,
            steps: [("Read a few pages", 25, .recurring)],
            into: context
        )
        makeGoal(
            title: "Get outside", identity: "Getting outside every day.",
            domain: .outdoors, isPrimary: false, sortIndex: 2,
            steps: [("Take a short walk", 25, .recurring)],
            into: context
        )

        // This morning's ride — protection is visibly, calmly working.
        let cal = Calendar.current
        let morning = cal.date(bySettingHour: 7, minute: 30, second: 0, of: .now) ?? .now
        context.insert(ProtectSession(
            activityID: "ride",
            minutes: 45,
            startedAt: morning,
            goalID: ride.id,
            stepID: ride.orderedSteps.first { $0.kind == .recurring }?.id
        ))

        try? context.save()
        Log.app.info("AdSeed: seeded the ad profile (biking-first, streak 22).")
    }

    @MainActor
    @discardableResult
    private static func makeGoal(
        title: String, identity: String, domain: ActivityDomain,
        isPrimary: Bool, sortIndex: Int,
        steps: [(String, Int, GoalStepKind)],
        into context: ModelContext
    ) -> Goal {
        let goal = Goal(title: title, identityLine: identity, domain: domain.rawValue,
                        isPrimary: isPrimary, sortIndex: sortIndex)
        context.insert(goal)
        for (i, s) in steps.enumerated() {
            let step = GoalStep(goalID: goal.id, title: s.0, suggestedMinutes: s.1,
                                kind: s.2, sortIndex: i)
            context.insert(step)
            goal.steps.append(step)
        }
        return goal
    }
}

#endif
