import Foundation

// MARK: - GoalPlanner — the boundary around goal-plan generation (spec-v2.6).
//
// Same protocol-gated pattern as ScreenTimeGateway: the app depends only on this
// protocol, never on a specific engine. Implementations:
//
//   • HeuristicGoalPlanner  — the DEFAULT. Deterministic, no LLM, ships everywhere.
//     This is the FLOOR and it must produce a genuinely good plan on its own.
//   • OnDeviceGoalPlanner   — Apple Foundation Models (iOS 26, Apple-Intelligence
//     hardware), behind #if canImport(FoundationModels) + a runtime availability
//     check. Personalises the identity line + step wording via guided generation.
//     Falls back to the heuristic when unavailable. Never crashes on unsupported
//     hardware.
//
// SEAM: a future RemoteGoalPlanner (server-backed) would conform here too — inject
// it the same way. Do NOT build it yet.

protocol GoalPlanner: Sendable {
    /// Turn the judged onboarding answers into an actionable, persistable plan.
    func makePlan(from answers: OnboardingAnswers) async -> GoalPlan
}

// MARK: - Factory — pick the best available planner at runtime.

enum GoalPlannerFactory {
    /// The default planner used at onboarding. Prefers the on-device model when it
    /// is genuinely available on this device; otherwise the heuristic floor.
    @MainActor
    static func make() -> GoalPlanner {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), OnDeviceGoalPlanner.isAvailable {
            return OnDeviceGoalPlanner()
        }
        #endif
        return HeuristicGoalPlanner()
    }
}

// MARK: - HeuristicGoalPlanner — the deterministic floor (no LLM).
//
// Maps the chip answers → 2–3 seeded goals (primary first), each with ~3 small,
// concrete first steps. Step MINUTES are sized by "time available" (timeLost) and
// "what stopped you" (blocker); the free-text aspiration becomes the plan's identity
// line verbatim (lightly cleaned). This alone is a good plan — it's what ships when
// no on-device model exists.

struct HeuristicGoalPlanner: GoalPlanner {

    func makePlan(from answers: OnboardingAnswers) async -> GoalPlan {
        Self.plan(from: answers)
    }

    /// Synchronous entry point — the deterministic floor, usable without awaiting
    /// (e.g. a persist-time fallback when async generation didn't run).
    static func plan(from answers: OnboardingAnswers) -> GoalPlan {
        GoalPlan(
            identityLine: identityLine(from: answers),
            goals: goals(from: answers)
        )
    }

    // MARK: Identity line — the free text, lightly cleaned, else a domain fallback.

    static func identityLine(from answers: OnboardingAnswers) -> String {
        let raw = answers.aspiration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return answers.primaryDomain.identityLine }
        // Light clean: collapse whitespace, cap length, uppercase first letter.
        var cleaned = raw.replacingOccurrences(of: "\n", with: " ")
        while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
        if cleaned.count > 120 { cleaned = String(cleaned.prefix(120)).trimmingCharacters(in: .whitespaces) + "…" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    // MARK: Goals — primary first, then up to two supporting domains.

    static func goals(from answers: OnboardingAnswers) -> [PlannedGoal] {
        // Order: primary anchor first, then the rest of the chosen domains, deduped.
        var ordered: [ActivityDomain] = [answers.primaryDomain]
        for d in answers.domains where !ordered.contains(d) { ordered.append(d) }
        // 2–3 goals total is the sweet spot — a plan you can actually hold.
        let chosen = Array(ordered.prefix(3))

        return chosen.enumerated().map { index, domain in
            PlannedGoal(
                title: domain.goalTitle,
                identityLine: domain.identityLine,
                domain: domain,
                isPrimary: index == 0,
                steps: steps(for: domain, answers: answers)
            )
        }
    }

    // MARK: Steps — ~3 per goal, sized by time available + blocker.

    static func steps(for domain: ActivityDomain, answers: OnboardingAnswers) -> [PlannedStep] {
        let seeds = domain.stepSeeds
        let cues = domain.stepCues
        return seeds.enumerated().map { index, seed in
            PlannedStep(
                title: seed.kind == .oneoff ? opener(seed.title, blocker: answers.blocker) : seed.title,
                // Pair the step with its if-then cue. Index-matched by construction;
                // guarded so a future seed list that outgrows the cue list degrades
                // to "no cue" rather than crashing.
                cue: index < cues.count ? cues[index] : "",
                suggestedMinutes: minutes(forStepIndex: index, kind: seed.kind, answers: answers),
                kind: seed.kind
            )
        }
    }

    /// The concrete first action. When the blocker is "don't know where to start",
    /// lean harder into the do-it-once opener; otherwise keep the seed as written.
    private static func opener(_ title: String, blocker: Blocker) -> String {
        switch blocker {
        case .dontKnowStart: return String(localized: "Just this once: \(title.lowercased())")
        default:             return title
        }
    }

    /// Step length in minutes. One-offs are tiny wins. Recurring steps scale with
    /// how much time the user is reclaiming, then get clamped by the blocker so we
    /// never prescribe more than they can sustain.
    private static func minutes(forStepIndex index: Int, kind: GoalStepKind, answers: OnboardingAnswers) -> Int {
        if kind == .oneoff { return 10 }

        // Base by time available (more reclaimed time → room for longer blocks).
        let base: Int
        switch answers.timeLost {
        case .under1:    base = 15
        case .oneToTwo:  base = 25
        case .twoToFour: base = 35
        case .fourPlus:  base = 45
        }
        // The second recurring step is the deeper block.
        let scaled = index >= 2 ? base + 15 : base

        // Blocker clamp: low-time / low-energy → tiny 10–15m steps regardless.
        switch answers.blocker {
        case .noTime, .noEnergy: return min(scaled, 15)
        case .distracted:        return min(scaled, 50)
        case .dontKnowStart:     return min(scaled, 40)
        }
    }
}
