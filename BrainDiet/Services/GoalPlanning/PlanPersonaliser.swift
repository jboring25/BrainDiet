import Foundation

// MARK: - PlanPersonaliser — the plan names their actual thing (2026-09-21).
//
// ⭐ PERSONALISATION LIVES IN THE FLOOR, NOT THE CEILING. Until now every reader
// alive got "Pick your next book · Read a few pages · Finish a chapter", because
// the only code that could name the user's book (`HeuristicStepRefiner`) ran
// only when someone opened "Make it yours" — personalisation you could REACH,
// not personalisation you were GIVEN. And the only thing that ran at plan time,
// the on-device model, exists on a minority of phones.
//
// This runs on every device, with no model, at the moment the plan is made. It
// substitutes the one fact the app could not know — the thing itself — into a
// template written for the step's ROLE:
//
//     setup  — the one-off that removes the barrier   "Put Dune where you'll see it tonight"
//     short  — the everyday version                   "Read 10 pages of Dune"
//     deep   — the finishable unit                    "Finish a chapter of Dune"
//
// ⚠️ It never invents a fact. No object → the step stays generic and keeps its
// "Make it yours" affordance. Minutes come from the step. The generic original
// is carried alongside, so every step it touches reverts in one tap.

enum PlanPersonaliser {

    enum Role { case setup, short, deep }

    /// Step order is `ActivityDomain.stepSeeds`: one-off, short, deep.
    static func role(forIndex index: Int, kind: GoalStepKind) -> Role {
        if index == 0 && kind == .oneoff { return .setup }
        return index >= 2 ? .deep : .short
    }

    // MARK: Value-type plan (onboarding: runs BEFORE the reveal renders)

    /// Name each domain's object in its steps. Steps whose title already names
    /// the object (the on-device model got there first) are left alone.
    static func apply(_ plan: GoalPlan, objects: [ActivityDomain: String]) -> GoalPlan {
        var out = plan
        out.goals = plan.goals.map { goal in
            guard let object = clean(objects[goal.domain]) else { return goal }
            var g = goal
            g.steps = goal.steps.enumerated().map { index, step in
                guard step.originalTitle.isEmpty,
                      !step.title.localizedCaseInsensitiveContains(object) else { return step }
                var s = step
                s.originalTitle = step.title
                s.originalCue = step.cue
                s.title = goal.domain.planTemplate(role(forIndex: index, kind: step.kind),
                                                   object: object, minutes: step.suggestedMinutes)
                return s
            }
            return g
        }
        return out
    }

    // MARK: Persisted plan (a thing named later, in "Make it yours" or Adjust)

    /// Name `object` in every still-generic step of `domain`. Called when the
    /// user names their thing on ONE step, so naming the book once makes the
    /// whole reading plan about that book instead of one line of it.
    static func apply(object raw: String, domain: ActivityDomain, to goals: [Goal]) {
        guard let object = clean(raw) else { return }
        for goal in goals where goal.domain == domain.rawValue {
            for (index, step) in goal.orderedSteps.enumerated()
            where !step.isPersonalised && !step.title.localizedCaseInsensitiveContains(object) {
                let title = domain.planTemplate(role(forIndex: index, kind: step.kind),
                                                object: object, minutes: step.suggestedMinutes)
                step.personalise(title: title, cue: step.cue, keepKind: true)
            }
        }
    }

    private static func clean(_ raw: String?) -> String? {
        let t = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Templates and suggestions, per domain

extension ActivityDomain {

    /// A step written for its role, naming the user's thing. Chips are stored in
    /// their mid-sentence form ("your app", "Spanish") so these read as written.
    func planTemplate(_ role: PlanPersonaliser.Role, object o: String, minutes m: Int) -> String {
        switch (self, role) {
        case (.reading, .setup):  return String(localized: "Put \(o) where you'll see it tonight")
        case (.reading, .short):  return String(localized: "Read 10 pages of \(o)")
        case (.reading, .deep):   return String(localized: "Finish a chapter of \(o)")

        case (.fitness, .setup):  return String(localized: "Lay out what you need for \(o)")
        case (.fitness, .short):  return String(localized: "\(m) minutes of \(o)")
        case (.fitness, .deep):   return String(localized: "A full session of \(o)")

        case (.music, .setup):    return String(localized: "Leave your \(o) out where you can see it")
        case (.music, .short):    return String(localized: "\(m) minutes on \(o)")
        case (.music, .deep):     return String(localized: "Learn a new part on \(o)")

        case (.building, .setup): return String(localized: "Write down the next piece of \(o)")
        case (.building, .short): return String(localized: "\(m) minutes on \(o)")
        case (.building, .deep):  return String(localized: "Ship one piece of \(o)")

        case (.writing, .setup):  return String(localized: "Open \(o) to where you left off")
        case (.writing, .short):  return String(localized: "Write 200 words of \(o)")
        case (.writing, .deep):   return String(localized: "\(m) minutes on \(o)")

        case (.learning, .setup): return String(localized: "Line up the next lesson of \(o)")
        case (.learning, .short): return String(localized: "One lesson of \(o)")
        case (.learning, .deep):  return String(localized: "\(m) minutes of \(o)")

        case (.outdoors, .setup): return String(localized: "Pick a time to get to \(o)")
        case (.outdoors, .short): return String(localized: "\(m) minutes at \(o)")
        case (.outdoors, .deep):  return String(localized: "A real stretch of time at \(o)")

        case (.creating, .setup): return String(localized: "Set out what you need for \(o)")
        case (.creating, .short): return String(localized: "\(m) minutes of \(o)")
        case (.creating, .deep):  return String(localized: "Finish one piece of \(o)")
        }
    }

    /// The example in the type-your-own field — specific enough to show that a
    /// real title is welcome, which is the register the plan gets better on.
    var objectPlaceholder: String {
        switch self {
        case .reading:  return String(localized: "Dune")
        case .fitness:  return String(localized: "leg day")
        case .music:    return String(localized: "ukulele")
        case .building: return String(localized: "a landing page")
        case .writing:  return String(localized: "my screenplay")
        case .learning: return String(localized: "Japanese")
        case .outdoors: return String(localized: "the river path")
        case .creating: return String(localized: "pottery")
        }
    }

    /// One-tap answers for the object question, so a tap is always enough and
    /// typing is only for people who want their exact thing ("Dune"). Stored in
    /// mid-sentence form; the chip displays them capitalised.
    var objectSuggestions: [String] {
        switch self {
        case .reading:  return [String(localized: "a novel"), String(localized: "a non-fiction book"),
                                String(localized: "a classic"), String(localized: "a book you started")]
        case .fitness:  return [String(localized: "lifting"), String(localized: "running"),
                                String(localized: "yoga"), String(localized: "home workouts")]
        case .music:    return [String(localized: "guitar"), String(localized: "piano"),
                                String(localized: "drums"), String(localized: "bass")]
        case .building: return [String(localized: "your app"), String(localized: "your business"),
                                String(localized: "your website"), String(localized: "your side project")]
        case .writing:  return [String(localized: "your novel"), String(localized: "a journal"),
                                String(localized: "your blog"), String(localized: "your essays")]
        case .learning: return [String(localized: "Spanish"), String(localized: "coding"),
                                String(localized: "math"), String(localized: "chess")]
        case .outdoors: return [String(localized: "the park"), String(localized: "a trail"),
                                String(localized: "the beach"), String(localized: "the gym track")]
        case .creating: return [String(localized: "drawing"), String(localized: "painting"),
                                String(localized: "photography"), String(localized: "video")]
        }
    }
}
