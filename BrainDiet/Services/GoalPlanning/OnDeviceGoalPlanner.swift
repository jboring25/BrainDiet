import Foundation

// MARK: - OnDeviceGoalPlanner — Apple Foundation Models personalisation (spec-v2.6).
//
// Compiled ONLY where the framework exists (iOS 26 SDK) and used ONLY when the
// on-device model is genuinely available on this hardware (Apple Intelligence).
// It personalises the plan: a warm identity line + refined, personal step wording
// that interprets the user's free-text aspiration — via guided generation
// (@Generable). It NEVER crashes or blocks on unsupported hardware: every path
// falls back to the deterministic HeuristicGoalPlanner floor.
//
// Design for robustness: we START from the heuristic plan (structure, domains, and
// minutes are deterministic) and ask the model ONLY to rewrite the identity line
// and the step titles (same count, same order). If the model is unavailable, errors,
// or returns a mismatched shape, we keep the heuristic result verbatim.

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct OnDeviceGoalPlanner: GoalPlanner {

    /// The floor we refine (and fall back to).
    private let base = HeuristicGoalPlanner()

    /// Whether the on-device model is usable on THIS device right now.
    @MainActor
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: Guided-generation shape

    @Generable
    struct Refinement {
        @Guide(description: "A short, warm, second-person identity line — who the user is becoming. One sentence, no more than 12 words. Present tense.")
        var identityLine: String

        @Guide(description: "Refined titles for the plan's steps, in the SAME order and SAME count as provided. Each: a concrete, tiny, encouraging action. Under 6 words. No numbering.")
        var stepTitles: [String]

        @Guide(description: "A cue for each step, in the SAME order and SAME count. Each names a moment that already happens in the person's day, phrased to follow it — for example 'once the dishes are done' or 'before you open your laptop'. Lowercase, under 8 words, no 'you should'.")
        var stepCues: [String]
    }

    func makePlan(from answers: OnboardingAnswers) async -> GoalPlan {
        // Always compute the deterministic floor first.
        let floor = await base.makePlan(from: answers)

        guard await Self.isAvailable else { return floor }

        // Flatten the floor's step titles to feed + realign the model's output.
        let originalTitles = floor.goals.flatMap { $0.steps.map(\.title) }
        guard !originalTitles.isEmpty else { return floor }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt = Self.prompt(answers: answers, originalTitles: originalTitles)
            let response = try await session.respond(to: prompt, generating: Refinement.self)
            return Self.merge(floor: floor, refinement: response.content, originalCount: originalTitles.count)
        } catch {
            Log.onboarding.error("OnDeviceGoalPlanner failed, using heuristic floor: \(error.localizedDescription, privacy: .public)")
            return floor
        }
    }

    // MARK: Prompt

    private static let instructions = String(localized: """
    You help someone reclaim time from doomscrolling and pour it into a life they \
    actually want. You write in a warm, direct, encouraging voice. You never shame. \
    You keep everything short and concrete.
    """)

    private static func prompt(answers: OnboardingAnswers, originalTitles: [String]) -> String {
        let domains = answers.domains.map(\.label).joined(separator: ", ")
        // ⭐ THE ANCHORS ARE THE POINT (2026-09-15). Without them the model
        // invents a moment, which is the same failure as the fixed table: a cue
        // whose anchor does not exist in the person's day never fires.
        let anchorBlock: String = {
            let anchors = answers.dailyAnchors.compactMap(DayAnchor.init(rawValue:))
            guard !anchors.isEmpty else { return "" }
            let list = anchors.map { "- \($0.phrase)" }.joined(separator: "\n")
            return String(localized: """


            Things that already happen in their day:
            \(list)

            Attach every cue to one of these. Do not invent a moment that is not on \
            this list. If two steps would land on the same moment, move one.
            """)
        }()
        let steps = originalTitles.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        // ⭐ 2026-08-06 — the bounded "in your own words" block. Present ONLY
        // when the user actually filled the Adjust-plan surface; the vast
        // majority of prompts never carry it, and the model must not be told
        // to honour detail that isn't there. Instruction is deliberately
        // NAME-THE-THING: without it a model hands back a warmer restatement of
        // the same generic step, which is precisely the "read more / do your
        // best" failure the plan card was rebuilt to escape (Locke & Latham
        // 2002 — specific goals beat "do your best").
        let detailBlock: String = {
            let details = DreamDetails.normalise(answers.dreamDetails)
            guard !details.isEmpty else { return "" }
            let lines = details.map { "- \($0)" }.joined(separator: "\n")
            return String(localized: """


            In their own words, what they actually want:
            \(lines)

            Use these specifics. Where a step can name their actual thing instead of a \
            generic one, name it. Do not quote them back at themselves.
            """)
        }()

        return String(localized: """
        The person wants to become: "\(answers.aspiration)"
        Their focus areas: \(domains). Most important: \(answers.primaryDomain.label).
        What's stopped them before: \(answers.blocker.label).\(detailBlock)\(anchorBlock)

        Rewrite the identity line to reflect who they said they want to become.
        Then rewrite these \(originalTitles.count) step titles — keep the same order \
        and the same count, keep each tiny and doable. Where you can name their \
        actual thing instead of a generic one, name it:
        \(steps)

        Then write one cue for each step, in the same order.
        """)
    }

    // MARK: Merge — apply refined wording back onto the deterministic structure.

    private static func merge(floor: GoalPlan, refinement: Refinement, originalCount: Int) -> GoalPlan {
        var plan = floor

        let identity = refinement.identityLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !identity.isEmpty { plan.identityLine = identity }

        // Only realign step titles if the model honoured the count. Cues are
        // applied independently for the same reason — a model that got the
        // titles right and the cues short should not lose both.
        guard refinement.stepTitles.count == originalCount else { return plan }
        let cues = refinement.stepCues.count == originalCount ? refinement.stepCues : nil
        var cursor = 0
        plan.goals = plan.goals.map { goal in
            var g = goal
            g.steps = goal.steps.map { step in
                var s = step
                let refined = refinement.stepTitles[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
                if !refined.isEmpty { s.title = refined }
                if let cue = cues?[cursor].trimmingCharacters(in: .whitespacesAndNewlines), !cue.isEmpty {
                    s.cue = cue
                }
                cursor += 1
                return s
            }
            return g
        }
        return plan
    }
}
#endif
