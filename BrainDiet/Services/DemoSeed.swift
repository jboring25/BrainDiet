import Foundation
import SwiftData

// MARK: - DemoSeed — optional profile + plan seeding for demos/screenshots (DEBUG).
//
// OFF by default. Enable with the launch arg / env `BD_SEED_HISTORY=1`. Seeds a
// UserProfile + a derived GoalPlan (primary = reading, plus fitness + building) so
// the app skips onboarding and Reclaim/Becoming render populated. ProtectSessions
// are tagged to those goal/step IDs, so invested time is attributable to goals.
// The AUTOMATIC reclaimed-time numbers come from the DegradedUsageProvider's DEBUG
// comeback curve — nothing hand-logged. NEVER runs in release.

enum DemoSeed {
    #if DEBUG
    /// Full 30-day demo history (profile + plan + tagged sessions + the
    /// DegradedUsageProvider's seeded comeback curve).
    static var isHistoryRequested: Bool {
        ProcessInfo.processInfo.environment["BD_SEED_HISTORY"] == "1"
    }

    /// Honest-Home screenshot state: profile + plan + ONE real session today —
    /// NO seeded usage curve, so Home renders the protected (un-entitled) hero.
    static var isTodaySessionRequested: Bool {
        ProcessInfo.processInfo.environment["BD_SEED_SESSION_TODAY"] == "1"
    }

    /// Zero-state screenshot state: profile + plan, NO sessions and NO usage —
    /// Home renders the degraded "ready when you are" hero (brain at low ember).
    static var isZeroStateRequested: Bool {
        ProcessInfo.processInfo.environment["BD_SEED_ZERO"] == "1"
    }

    static var isRequested: Bool {
        isHistoryRequested || isTodaySessionRequested || isZeroStateRequested
    }

    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard isRequested else { return }

        // Wipe + reseed a single deterministic profile + plan + history.
        if let ps = try? context.fetch(FetchDescriptor<UserProfile>()) { ps.forEach(context.delete) }
        if let ss = try? context.fetch(FetchDescriptor<ProtectSession>()) { ss.forEach(context.delete) }
        if let gs = try? context.fetch(FetchDescriptor<Goal>()) { gs.forEach(context.delete) }
        if let gt = try? context.fetch(FetchDescriptor<GoalStep>()) { gt.forEach(context.delete) }

        // The judged answers → a genuinely good deterministic plan.
        //
        // ⭐ BD_SEED_PERSONA=builder switches the primary domain, so two real
        // users can be put side by side without running onboarding twice. Added
        // 2026-09-15 to audit how much of the app is actually personalised.
        let builder = ProcessInfo.processInfo.environment["BD_SEED_PERSONA"] == "builder"
        let answers = builder
            ? OnboardingAnswers(
                hijackers: [.shortVideo, .social, .news],
                timeLost: .twoToFour,
                domains: [.building, .learning, .writing],
                primaryDomain: .building,
                aspiration: "Building something people use.",
                blocker: .noTime)
            : OnboardingAnswers(
                hijackers: [.shortVideo, .social, .youtube],
                timeLost: .twoToFour,
                domains: [.reading, .fitness, .building],
                primaryDomain: .reading,
                aspiration: "Reading every night.",
                blocker: .distracted
        )
        // A real user names their thing in onboarding now (PlanPersonaliser), so the
        // seed does too — the Menu screenshots must review the plan people get.
        let objects: [ActivityDomain: String] = builder
            ? [.building: "your app", .learning: "Swift", .writing: "your blog"]
            : [.reading: "Dune", .fitness: "lifting", .building: "your app"]
        let plan = PlanPersonaliser.apply(HeuristicGoalPlanner.plan(from: answers), objects: objects)

        let profile = UserProfile(
            goalIDs: builder ? ["business", "skill", "create"] : ["read", "fitness", "business"],
            why: answers.aspiration,
            baselineJunkMinutes: 180,
            // Zero state means NOTHING is set up, apps included — otherwise the
            // Menu's first-run branch (the "Choose the apps to rest" CTA) has no
            // fixture and can only be reviewed by imagining it.
            junkAppIDs: isZeroStateRequested ? [] : ["tiktok", "instagram", "youtube"],
            appCategories: [
                "tiktok":    .junk,
                "instagram": .junk,
                "reddit":    .junk,
                "youtube":   .leisure,
                "spotify":   .leisure,
                "kindle":    .nourishing,
                "duolingo":  .nourishing
            ],
            hijackers: answers.hijackers,
            domains: answers.domains,
            primaryDomain: answers.primaryDomain,
            blocker: answers.blocker,
            planIdentityLine: plan.identityLine,
            // ⭐ BACKDATE THE PROFILE TO MATCH THE HISTORY. `daysIn` counts from
            // createdAt, so a profile made right now beside 30 days of seeded
            // sessions rendered "1 DAY IN · 14/16 days you showed up" — two
            // numbers on one screen contradicting each other. A seed that
            // disagrees with itself makes every screenshot review a guess.
            createdAt: isHistoryRequested
                ? (Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now)
                : .now
        )
        context.insert(profile)
        for (domain, object) in objects { profile.rememberStepObject(object, for: domain) }

        let goals = plan.persist(into: context)
        if isHistoryRequested {
            seedProtectSessions(into: context, goals: goals)
            // BD_SEED_SKIPS=1 — the primary goal's DEEP step was offered on the
            // last three days and done on none of them.
            //
            // ⚠️ Skips only count SINCE a step's last completion, so the fixture
            // has to remove that step's recent sessions or it seeds zero skips —
            // which is exactly what the first version of this did, and the
            // screenshots came back identical. A fixture that cannot produce the
            // state it claims to test proves nothing.
            if ProcessInfo.processInfo.environment["BD_SEED_SKIPS"] == "1",
               let primary = goals.first(where: \.isPrimary),
               primary.orderedSteps.count > 2 {
                let stepID = primary.orderedSteps[2].id
                let cutoff = Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
                for s in (try? context.fetch(FetchDescriptor<ProtectSession>())) ?? []
                where s.stepID == stepID && s.startedAt >= cutoff {
                    context.delete(s)
                }
                MenuExposure.debugSeed(stepID, daysAgo: [1, 2, 3])
            }
        } else if isZeroStateRequested {
            // Zero-state: no sessions at all → Home's degraded hero.
        } else {
            // Today-only: one real 25m reading block, an hour ago.
            let readingGoal = goals.first { $0.domain == ActivityDomain.reading.rawValue }
            context.insert(ProtectSession(
                activityID: "read",
                minutes: 25,
                startedAt: Date.now.addingTimeInterval(-3600),
                goalID: readingGoal?.id,
                stepID: readingGoal?.orderedSteps.first?.id
            ))
        }

        try? context.save()
        Log.app.info("DemoSeed: seeded profile + \(goals.count, privacy: .public)-goal plan (history=\(isHistoryRequested, privacy: .public)).")
    }

    /// Deterministic Protect sessions across the past ~30 days, tagged to plan
    /// goals/steps where they map (reading/fitness/building). Reading leads.
    @MainActor
    private static func seedProtectSessions(into context: ModelContext, goals: [Goal]) {
        let cal = Calendar.current
        let now = Date.now

        // domain → its persisted goal (for tagging).
        func goal(_ domain: ActivityDomain) -> Goal? { goals.first { $0.domain == domain.rawValue } }
        // A goal's Nth recurring step id (falls back to any step / nil).
        func stepID(_ g: Goal?, _ index: Int) -> UUID? {
            let steps = g?.orderedSteps ?? []
            guard !steps.isEmpty else { return nil }
            return steps[min(index, steps.count - 1)].id
        }

        let readingGoal = goal(.reading)
        let fitnessGoal = goal(.fitness)
        let buildingGoal = goal(.building)

        // (activityID, daysAgo, minutes, taggedGoal, stepIndex). nil goal = off-plan.
        let sessions: [(String, Int, Int, Goal?, Int)] = [
            ("read", 1, 50, readingGoal, 2), ("read", 2, 50, readingGoal, 1), ("read", 3, 90, readingGoal, 2),
            ("read", 5, 50, readingGoal, 1), ("read", 6, 50, readingGoal, 2), ("read", 8, 90, readingGoal, 2),
            ("read", 9, 50, readingGoal, 1), ("read", 12, 50, readingGoal, 2), ("read", 14, 90, readingGoal, 2),
            ("read", 17, 50, readingGoal, 1), ("read", 20, 50, readingGoal, 2), ("read", 24, 90, readingGoal, 2),
            ("lift", 2, 50, fitnessGoal, 1), ("lift", 4, 50, fitnessGoal, 2), ("lift", 7, 50, fitnessGoal, 1),
            ("lift", 11, 50, fitnessGoal, 2), ("lift", 15, 50, fitnessGoal, 1), ("lift", 19, 50, fitnessGoal, 2),
            ("lift", 23, 50, fitnessGoal, 1),
            ("build", 4, 90, buildingGoal, 2), ("build", 13, 90, buildingGoal, 2), ("build", 21, 90, buildingGoal, 2),
            ("study", 3, 25, nil, 0), ("study", 6, 50, nil, 0), ("study", 16, 50, nil, 0),
            ("guitar", 7, 25, nil, 0), ("guitar", 18, 25, nil, 0),
        ]
        // ⭐ SOME OF THE HISTORY IS SELF-REPORTED, because real history is.
        // Becoming's hero counts measured and reported minutes together (the
        // latter capped per day) and then prints the split underneath. That
        // line can only be reviewed in a screenshot if the seed actually
        // contains both kinds — a seed of pure measured time made the app look
        // like it had no self-report path at all.
        let selfReported: Set<String> = ["read-5", "read-12", "study-6", "guitar-18"]

        for (activityID, daysAgo, minutes, g, stepIndex) in sessions {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let started = cal.date(bySettingHour: 19, minute: 0, second: 0, of: day) ?? day
            context.insert(ProtectSession(
                activityID: activityID,
                minutes: minutes,
                startedAt: started,
                goalID: g?.id,
                stepID: stepID(g, stepIndex),
                source: selfReported.contains("\(activityID)-\(daysAgo)") ? .reported : .protected
            ))
        }
    }
    #else
    @MainActor static func seedIfRequested(_ context: ModelContext) {}
    #endif
}
