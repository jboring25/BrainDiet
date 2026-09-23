import Foundation

// MARK: - OnDeviceStepRefiner — Apple Foundation Models phrasing (2026-08-07).
//
// Same contract and same robustness rules as `OnDeviceGoalPlanner`: compiled
// only where the framework exists, used only when the model is genuinely
// available on this hardware, and it NEVER blocks or fails the feature —
// every path falls through to `HeuristicStepRefiner`.
//
// ⭐ WHAT IT IS AND IS NOT ALLOWED TO DO. It rewrites PHRASING. The specificity
// is supplied by the user (their object, their moment) and must survive intact,
// so the model is constrained hard:
//   • it must keep the user's object verbatim — a model that helpfully swaps
//     "Dune" for "your book" has undone the entire feature
//   • it must not invent quantities the user didn't give
//   • it never touches the cue; that is the user's pick and it is copied through
//
// Anything it returns that violates the shape is discarded in favour of the
// floor, because a wrong-but-fluent step is worse than a plain correct one.

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct OnDeviceStepRefiner: StepRefiner {

    @MainActor
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    @Generable
    struct Phrasings {
        @Guide(description: "Exactly 3 rewrites of one tiny action, each under 7 words, each naming the user's specific thing verbatim. Vary the SHAPE: one countable amount, one natural unit (a chapter, a set, a section), one time box. Warm, plain, second person. No numbering, no punctuation at the end, never a quantity the user did not give.")
        var titles: [String]
    }

    private static let instructions = String(localized: """
    You rewrite one small action so it names the person's actual thing instead of \
    a category. You are warm, plain and extremely brief. You never shame, never \
    add motivation, and never invent facts about them.
    """)

    func candidates(for request: StepRefinementRequest) async -> [StepCandidate] {
        let floor = HeuristicStepRefiner.build(request)

        let object = request.object.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !object.isEmpty, await Self.isAvailable else { return floor }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(request, object: object),
                                                     generating: Phrasings.self)
            let titles = response.content.titles
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                // ⭐ THE OBJECT GUARD. Drop any line that lost the user's actual
                // thing. That line is the entire point of the interaction, and a
                // fluent rewrite that says "your book" is a regression to exactly
                // the generic phrasing this feature exists to remove.
                .filter { !$0.isEmpty && $0.localizedCaseInsensitiveContains(object) }

            guard titles.count >= 2 else { return floor }
            // The user's cue is copied through untouched — the model is never
            // given the chance to reword the anchor it didn't choose.
            return titles.prefix(3).map { StepCandidate(title: $0, cue: request.cue) }
        } catch {
            Log.onboarding.error("OnDeviceStepRefiner failed, using floor: \(error.localizedDescription, privacy: .public)")
            return floor
        }
    }

    private static func prompt(_ r: StepRefinementRequest, object: String) -> String {
        String(localized: """
        Their focus area: \(r.domain.label).
        The generic step right now: "\(r.action)"
        Their actual thing: "\(object)"
        They have about \(r.minutes) minutes.

        Write 3 rewrites of that step. Every one must contain "\(object)" exactly \
        as written. Keep each under 7 words.
        """)
    }
}
#endif
