import Foundation

// MARK: - StepRefiner — "Make it mine" (2026-08-07).
//
// ⭐ THE PROBLEM THIS EXISTS FOR. The plan can only ever say what KIND of thing
// to do — "Read a few pages", "Do a short workout" — because nothing in the app
// has ever known what the user's actual thing is. Locke & Latham (2002,
// American Psychologist 57(9)) is unambiguous that specific goals outperform
// "do your best", and a category is a sophisticated way of saying "do your
// best". This turns a category into the user's actual next action.
//
// ⭐ THE ARCHITECTURE, AND WHY THE FLOOR MATTERS MOST. Apple's on-device model
// exists only on iPhone 15 Pro and newer. If specificity depended on the model,
// most of the install base would get none of it. So the split is deliberate:
//
//     the USER supplies the specificity  (which book, which moment)
//     the MODEL supplies the phrasing    (and only that)
//
// `HeuristicStepRefiner` therefore produces genuinely specific candidates on
// EVERY device with no model at all — "Read 10 pages of Dune · on the train
// home" is already the thing Locke & Latham are talking about. The on-device
// refiner makes those lines read like a person wrote them. Losing the model is
// a loss of polish, never a loss of the feature.
//
// The engine is behind a protocol + factory (mirroring `GoalPlannerFactory`) so
// a server-side engine is a drop-in swap if that call ever changes. Nothing
// above this layer knows which engine answered.

/// One proposed rewrite of a step: the concrete action, plus the anchoring cue.
///
/// ⭐ THE CUE IS NOT OPTIONAL. A candidate is always action + moment, never a
/// bare action. The whole documented effect (Gollwitzer & Sheeran 2006, d =
/// 0.65 across 94 tests) comes from naming WHEN and WHERE — so handing back a
/// sharper action that had dropped its cue would be a downgrade wearing the
/// costume of an upgrade.
struct StepCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let cue: String

    init(id: UUID = UUID(), title: String, cue: String) {
        self.id = id
        self.title = title
        self.cue = cue
    }
}

/// What the refiner is given. Everything here is either already on the plan or
/// was just picked by the user — the refiner never invents facts about them.
struct StepRefinementRequest: Sendable {
    /// The step's current generic title ("Read a few pages").
    let action: String
    /// The user's actual thing ("Dune"). The one fact the app could not know.
    let object: String
    /// The anchoring moment, defaulted to the step's existing cue.
    let cue: String
    let domain: ActivityDomain
    let minutes: Int
}

protocol StepRefiner: Sendable {
    func candidates(for request: StepRefinementRequest) async -> [StepCandidate]
}

enum StepRefinerFactory {
    /// Prefers the on-device model where it genuinely exists; otherwise the
    /// deterministic floor. Same shape as `GoalPlannerFactory.make()`.
    @MainActor
    static func make() -> StepRefiner {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), OnDeviceStepRefiner.isAvailable {
            return OnDeviceStepRefiner()
        }
        #endif
        return HeuristicStepRefiner()
    }
}

// MARK: - The deterministic floor

struct HeuristicStepRefiner: StepRefiner {

    func candidates(for request: StepRefinementRequest) async -> [StepCandidate] {
        Self.build(request)
    }

    /// Synchronous entry point — also the on-device refiner's fallback, so both
    /// paths return the identical shape and the UI never branches on engine.
    static func build(_ r: StepRefinementRequest) -> [StepCandidate] {
        let object = r.object.trimmingCharacters(in: .whitespacesAndNewlines)
        // With no object there is nothing to be specific ABOUT, so the honest
        // answer is the step unchanged rather than three reworded guesses.
        guard !object.isEmpty else {
            return [StepCandidate(title: r.action, cue: r.cue)]
        }
        return r.domain.refinementTemplates(object: object, minutes: r.minutes)
            .map { StepCandidate(title: $0, cue: r.cue) }
    }
}

// MARK: - Per-domain phrasings
//
// Three shapes per domain, deliberately different in KIND rather than in
// wording, because they have to survive being the only three a user ever sees:
//   [0] a countable amount   — the classic specific-and-measurable form
//   [1] a natural unit       — a chapter, a set, a section: finishable
//   [2] a time box           — the lowest-commitment version, for bad days
// Every one names the user's object. None of them invents a number the user
// didn't supply (minutes comes from the step itself).

extension ActivityDomain {
    func refinementTemplates(object o: String, minutes m: Int) -> [String] {
        switch self {
        case .reading:
            return [String(localized: "Read 10 pages of \(o)"),
                    String(localized: "One chapter of \(o)"),
                    String(localized: "\(m) minutes of \(o)")]
        case .fitness:
            return [String(localized: "\(o) — \(m) minutes"),
                    String(localized: "The first set of \(o)"),
                    String(localized: "Start \(o), stop whenever")]
        case .music:
            return [String(localized: "\(m) minutes on \(o)"),
                    String(localized: "Play \(o) once through"),
                    String(localized: "Just the hard part of \(o)")]
        case .building:
            return [String(localized: "Ship \(o)"),
                    String(localized: "One small piece of \(o)"),
                    String(localized: "\(m) minutes on \(o)")]
        case .writing:
            return [String(localized: "Write 200 words of \(o)"),
                    String(localized: "One paragraph of \(o)"),
                    String(localized: "\(m) minutes on \(o)")]
        case .learning:
            return [String(localized: "One lesson of \(o)"),
                    String(localized: "The next section of \(o)"),
                    String(localized: "\(m) minutes of \(o)")]
        case .outdoors:
            return [String(localized: "\(m) minutes at \(o)"),
                    String(localized: "Walk to \(o) and back"),
                    String(localized: "Just get to \(o)")]
        case .creating:
            return [String(localized: "\(m) minutes on \(o)"),
                    String(localized: "One piece of \(o)"),
                    String(localized: "Just start \(o)")]
        case .social:
            return [String(localized: "Talk to \(o) today"),
                    String(localized: "\(m) minutes with \(o)"),
                    String(localized: "Just say hi to \(o)")]
        case .mindful:
            return [String(localized: "\(m) minutes of \(o)"),
                    String(localized: "One round of \(o)"),
                    String(localized: "Just start \(o)")]
        }
    }

    /// The prompt shown above the object field, per domain. Asking the concrete
    /// question ("What are you reading?") rather than a generic one gets a
    /// concrete answer — the same reason the aspiration step became buttons.
    var objectPrompt: String {
        switch self {
        case .reading:  return String(localized: "What are you reading?")
        case .fitness:  return String(localized: "What's today's session?")
        case .music:    return String(localized: "What are you playing?")
        case .building: return String(localized: "What are you building?")
        case .writing:  return String(localized: "What are you writing?")
        case .learning: return String(localized: "What are you learning?")
        case .outdoors: return String(localized: "Where do you go?")
        case .creating: return String(localized: "What are you making?")
        case .social:   return String(localized: "Who do you want to talk to?")
        case .mindful:  return String(localized: "How do you slow down?")
        }
    }
}
