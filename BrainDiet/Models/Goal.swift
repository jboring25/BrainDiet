import Foundation
import SwiftData

// MARK: - Goal / GoalStep — the derived, actionable plan (spec-v2.6).
//
// Goals are no longer picked live in the tab. They're derived ONCE at onboarding
// from the user's judged answers (see GoalPlanner) and persisted as an actionable
// plan the Reclaim tab lists. Each Goal carries an identity line ("You're becoming
// a reader") and a small set of concrete first STEPS. A step is the unit of action:
// tapping one starts a tagged ProtectSession aimed at that exact step.
//
// Local-first (SwiftData), alongside UserProfile + ProtectSession.

/// Whether a step is a one-time push or an ongoing habit.
enum GoalStepKind: String, Codable, Sendable {
    case oneoff       // "Pick your next book" — do it once
    case recurring    // "Read 15 minutes" — repeatable
}

@Model
final class Goal {
    /// Stable identifier (also stamped onto ProtectSession for attribution).
    var id: UUID
    /// "Read more", "Get stronger" — the plan-row title.
    var title: String
    /// "You're becoming a reader." — the identity this goal grows.
    var identityLine: String
    /// The seeding domain (ActivityDomain.rawValue) — maps to the Activity catalog.
    var domain: String
    /// The one goal that matters most right now (rendered first, emphasised).
    var isPrimary: Bool
    /// Display order within the plan (primary first).
    var sortIndex: Int
    /// The actionable first steps. Cascade-deleted with the goal.
    @Relationship(deleteRule: .cascade) var steps: [GoalStep]

    init(
        id: UUID = UUID(),
        title: String,
        identityLine: String,
        domain: String,
        isPrimary: Bool,
        sortIndex: Int,
        steps: [GoalStep] = []
    ) {
        self.id = id
        self.title = title
        self.identityLine = identityLine
        self.domain = domain
        self.isPrimary = isPrimary
        self.sortIndex = sortIndex
        self.steps = steps
    }

    /// Steps in their intended order.
    var orderedSteps: [GoalStep] { steps.sorted { $0.sortIndex < $1.sortIndex } }
}

@Model
final class GoalStep {
    var id: UUID
    /// The owning goal's id (denormalised so ProtectSession can tag by step).
    var goalID: UUID
    /// "Read 15 minutes tonight" — a concrete, small action.
    var title: String
    /// The if-then cue — the existing daily event this action rides on
    /// ("after you brush your teeth"). Gollwitzer & Sheeran (2006), d = 0.65.
    /// Default "" keeps older persisted plans decodable.
    var cue: String = ""
    /// A sensible default block length for this step, in minutes.
    var suggestedMinutes: Int
    /// oneoff vs. recurring.
    var kindRaw: String
    var sortIndex: Int

    // MARK: ⭐ "Make it mine" (2026-08-07) — the personalised rewrite.
    //
    // When the user sharpens a step ("Read a few pages" → "Read 10 pages of
    // Dune"), the ORIGINAL is stashed here rather than lost. Two reasons, and
    // the second is the load-bearing one:
    //   1 · revert is one tap, so committing to a rewrite is never a gamble
    //   2 · a plan rebuild (Adjust plan) regenerates generic titles, and without
    //       the original there would be no way to tell an untouched step from a
    //       personalised one — the user's own words would be silently wiped.
    // Both default to "" so every previously persisted plan stays decodable
    // (lightweight SwiftData migration).

    /// The generic title this step had before the user personalised it.
    /// Empty = never personalised.
    var originalTitle: String = ""
    /// The cue it had before personalisation.
    var originalCue: String = ""
    /// The kind it had before personalisation (see `personalise`). Empty = the
    /// kind never changed.
    var originalKindRaw: String = ""

    /// True once the user has made this step their own.
    var isPersonalised: Bool { !originalTitle.isEmpty }

    /// Apply a chosen candidate, stashing the generic version exactly once —
    /// re-personalising an already-personalised step must not overwrite the
    /// original with the previous rewrite, or revert would stop reaching home.
    ///
    /// ⭐ A PERSONALISED ONE-OFF BECOMES RECURRING (Jack, 2026-08-08: "go with
    /// the more user friendly feature"). The openers are setup tasks — "Pick
    /// your next book" — and naming the actual thing COMPLETES them: once you've
    /// said you're reading Dune, being told to pick a book is the app arguing
    /// with an answer you already gave. So the rewrite is allowed to turn it
    /// into the ongoing action it now describes.
    ///
    /// The `kind` has to move with the title or the model starts lying about
    /// itself: a step reading "Read 10 pages of Dune" while still flagged
    /// `.oneoff` is a daily action the plan believes is a one-time chore, and
    /// everything that selects on kind (the everyday-serving pick) would reason
    /// from that. Stashed so revert restores the opener exactly.
    ///
    /// `keepKind` is for `PlanPersonaliser`, whose one-off template is still a
    /// one-off ("Put Dune where you'll see it tonight") — the setup survives
    /// being named, so it must not be promoted to a daily action.
    func personalise(title newTitle: String, cue newCue: String, keepKind: Bool = false) {
        if originalTitle.isEmpty {
            originalTitle = title
            originalCue = cue
            if kind == .oneoff && !keepKind {
                originalKindRaw = kindRaw
                kindRaw = GoalStepKind.recurring.rawValue
            }
        }
        title = newTitle
        cue = newCue
    }

    /// Put the generic step back and forget the rewrite.
    func revertPersonalisation() {
        guard isPersonalised else { return }
        title = originalTitle
        cue = originalCue
        if !originalKindRaw.isEmpty {
            kindRaw = originalKindRaw
            originalKindRaw = ""
        }
        originalTitle = ""
        originalCue = ""
    }

    init(
        id: UUID = UUID(),
        goalID: UUID,
        title: String,
        cue: String = "",
        suggestedMinutes: Int,
        kind: GoalStepKind,
        sortIndex: Int
    ) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.cue = cue
        self.suggestedMinutes = suggestedMinutes
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
    }

    var kind: GoalStepKind { GoalStepKind(rawValue: kindRaw) ?? .recurring }
}

// MARK: - GoalPlan — the planner's value-type output (persisted as Goal/GoalStep).
//
// GoalPlanner implementations return this pure, Sendable plan; the app then
// materialises it into @Model Goal/GoalStep rows in the ModelContainer. Keeping
// the plan a value type keeps the planners testable and lets the on-device model
// produce one via guided generation without touching SwiftData.

struct GoalPlan: Sendable, Equatable {
    /// The overarching identity line for the whole plan (the header on Reclaim).
    var identityLine: String
    var goals: [PlannedGoal]

    var isEmpty: Bool { goals.isEmpty }
}

struct PlannedGoal: Identifiable, Sendable, Equatable {
    var id = UUID()
    var title: String
    var identityLine: String
    var domain: ActivityDomain
    var isPrimary: Bool
    var steps: [PlannedStep]
}

struct PlannedStep: Identifiable, Sendable, Equatable {
    var id = UUID()
    var title: String
    /// The "if" of the implementation intention — an existing daily event this
    /// action rides on ("after you brush your teeth"). Empty is tolerated (older
    /// plans, model failure) and simply renders no cue line. See
    /// `ActivityDomain.stepCues` for why this exists.
    var cue: String = ""
    var suggestedMinutes: Int
    var kind: GoalStepKind
    /// The generic title/cue this step had before `PlanPersonaliser` named the
    /// user's actual thing in it. Empty = not personalised. Carried into
    /// `GoalStep.originalTitle` on persist, so "✦ yours" and one-tap revert work
    /// on a step the app personalised exactly as on one the user did by hand.
    var originalTitle: String = ""
    var originalCue: String = ""
}

extension GoalPlan {
    /// Materialise the value-type plan into persisted Goal/GoalStep rows.
    /// Caller is responsible for wiping any prior plan first.
    @discardableResult
    func persist(into context: ModelContext) -> [Goal] {
        var inserted: [Goal] = []
        for (gIndex, pg) in goals.enumerated() {
            let goal = Goal(
                id: pg.id,
                title: pg.title,
                identityLine: pg.identityLine,
                domain: pg.domain.rawValue,
                isPrimary: pg.isPrimary,
                sortIndex: gIndex
            )
            context.insert(goal)
            for (sIndex, ps) in pg.steps.enumerated() {
                let step = GoalStep(
                    id: ps.id,
                    goalID: pg.id,
                    title: ps.title,
                    cue: ps.cue,
                    suggestedMinutes: ps.suggestedMinutes,
                    kind: ps.kind,
                    sortIndex: sIndex
                )
                step.originalTitle = ps.originalTitle
                step.originalCue = ps.originalCue
                context.insert(step)
                goal.steps.append(step)
            }
            inserted.append(goal)
        }
        return inserted
    }
}
