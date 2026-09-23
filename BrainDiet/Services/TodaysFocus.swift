import Foundation

// MARK: - TodaysFocus — the ONE thing, ranked (Jack, 2026-09-13).
//
// ⭐ "Not the biggest in terms of the longest — what gets you the closest to the
// person you want to be." So this does not sort by minutes, and it actively
// PENALISES length: a 45-minute block you will not start moves the identity less
// than a 10-minute one you will. The literature agrees — proximal, achievable
// sub-goals beat distant ones, and an implementation intention with a cue that
// fits the current hour beats the same step at the wrong time of day.
//
// ⭐ THIS IS THE DETERMINISTIC FLOOR, ON PURPOSE. Jack, 2026-07-13: a heuristic
// is good, and not calling a model when one is cheap is leaving value on the
// table. Both are true — this ranks well enough to ship today and it is the
// exact interface a model slots behind: same input (the user's real steps, what
// is already done, the hour), same output (one step and one reason). When the
// call lands, `pick` gets an async sibling and nothing downstream moves.
//
// ⭐ IT NEVER INVENTS. Every candidate is a step the user's own plan already
// contains; the ranking only chooses between them.

struct TodaysFocus {

    let goal: Goal
    let step: GoalStep
    let domain: ActivityDomain
    /// Why this one — shown as a short line, never a paragraph.
    let reason: String

    // MARK: Ranking

    /// Home's single focus. Defined as the first of the Menu's three, so the two
    /// surfaces can never recommend different things at the same moment.
    @MainActor
    static func pick(goals: [Goal],
                     doneToday: Set<UUID>,
                     everDone: Set<UUID> = [],
                     skips: [UUID: Int] = [:],
                     now: Date = .now) -> TodaysFocus? {
        pickThree(goals: goals, doneToday: doneToday, everDone: everDone, skips: skips, now: now).first
    }

    /// ⭐ A ONE-OFF IS DONE FOREVER, NOT FOR TODAY (2026-09-21). Every surface
    /// filtered by `doneToday` only, so "Put Dune where you'll see it" came back
    /// the morning after you did it — a setup step re-prescribed daily. A one-off
    /// also counts as done once any LATER step of its goal has been done: if you
    /// are reading chapters of Dune, you evidently found it.
    static func isRetired(_ step: GoalStep, in goal: Goal, everDone: Set<UUID>) -> Bool {
        guard step.kind == .oneoff else { return false }
        if everDone.contains(step.id) { return true }
        let steps = goal.orderedSteps
        guard let i = steps.firstIndex(where: { $0.id == step.id }) else { return false }
        return steps.dropFirst(i + 1).contains { everDone.contains($0.id) }
    }

    /// ⭐ LAYER 3, THE DAILY THREE (2026-09-21). The Menu used to round-robin
    /// steps in plan order, so Tuesday 8am and Friday 10pm got the same three.
    /// Now the same plan yields a different three by hour, by what is already
    /// done, and by what keeps getting passed over.
    ///
    /// One per goal FIRST, best-scoring goal first, then any remaining slots by
    /// score — three steps of the same goal reads as one chore in three parts,
    /// not a day worth having.
    @MainActor
    static func pickThree(goals: [Goal],
                          doneToday: Set<UUID>,
                          everDone: Set<UUID> = [],
                          skips: [UUID: Int] = [:],
                          now: Date = .now) -> [TodaysFocus] {
        let hour = Calendar.current.component(.hour, from: now)
        var ranked: [(score: Double, focus: TodaysFocus)] = []

        for goal in goals {
            guard let domain = ActivityDomain(rawValue: goal.domain) else { continue }
            for (index, step) in goal.orderedSteps.enumerated()
            where !doneToday.contains(step.id) && !isRetired(step, in: goal, everDone: everDone) {
                let s = score(goal: goal, step: step, index: index, hour: hour,
                              skips: skips[step.id] ?? 0)
                ranked.append((s, TodaysFocus(goal: goal, step: step, domain: domain,
                                              reason: reason(for: goal, step: step, hour: hour))))
            }
        }
        // ⚠️ TIES MUST BREAK DETERMINISTICALLY. Swift's `sort` is NOT stable, so
        // two steps on the same score (two 35-minute steps with anytime cues is
        // the common case) could swap places on every single render — a menu
        // that reshuffles while you are looking at it. Plan order settles it.
        ranked.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            let a = $0.focus, b = $1.focus
            if a.goal.isPrimary != b.goal.isPrimary { return a.goal.isPrimary }
            if a.goal.sortIndex != b.goal.sortIndex { return a.goal.sortIndex < b.goal.sortIndex }
            return a.step.sortIndex < b.step.sortIndex
        }

        var picked: [TodaysFocus] = []
        var usedGoals = Set<UUID>()
        for entry in ranked where picked.count < 3 && !usedGoals.contains(entry.focus.goal.id) {
            picked.append(entry.focus)
            usedGoals.insert(entry.focus.goal.id)
        }
        for entry in ranked where picked.count < 3
            && !picked.contains(where: { $0.step.id == entry.focus.step.id }) {
            picked.append(entry.focus)
        }
        return picked
    }

    private static func score(goal: Goal, step: GoalStep, index: Int, hour: Int, skips: Int) -> Double {
        var score = 0.0

        // The identity anchor. The primary goal IS the person they said they
        // were becoming, so its steps start well ahead.
        if goal.isPrimary { score += 100 }

        // Foundational first. The step a plan opens with is the one the rest of
        // the plan leans on.
        score += max(0, 30 - Double(index) * 10)

        // The cue has to fit the hour it is offered in. A step cued to the
        // evening is the wrong answer at 8am even if it scores well on
        // everything else — friction has to fit the context.
        score += cueFit(step.cue, hour: hour)

        // Short enough to actually start. Explicitly NOT "the biggest".
        score -= Double(step.suggestedMinutes) / 6.0

        // A step that names their actual thing knows something about this user
        // that a catalog default does not.
        if step.isPersonalised { score += 12 }

        // ⭐ LAYER 4. Each day it was offered and passed over costs it ground,
        // capped at three so one bad week cannot bury a step forever. At −54 a
        // skipped step on the PRIMARY goal still outranks nothing on a secondary
        // one — it steps aside for its own siblings first, which is the point:
        // try a different way into the same goal before abandoning the goal.
        score -= Double(min(skips, 3)) * 18

        return score
    }

    /// 0…25. Rewards a cue whose time-of-day words match now, and quietly
    /// punishes one that clearly does not.
    private static func cueFit(_ cue: String, hour: Int) -> Double {
        let c = cue.lowercased()
        guard !c.isEmpty else { return 0 }
        let morning = c.contains("morning") || c.contains("wake") || c.contains("breakfast")
                   || c.contains("alarm") || c.contains("coffee")
        let evening = c.contains("night") || c.contains("tonight") || c.contains("evening")
                   || c.contains("bed") || c.contains("dinner") || c.contains("shower")
        switch (morning, evening) {
        case (true, false):  return hour < 12 ? 25 : -12
        case (false, true):  return hour >= 17 ? 25 : -12
        default:             return 6            // an anytime cue is still a cue
        }
    }

    /// One short line naming what this moves. The identity sentence is the
    /// user's own words, so the reason never sounds like the app talking.
    private static func reason(for goal: Goal, step: GoalStep, hour: Int) -> String {
        // ⭐ The identity line ends in a full stop ("Reading every night."), so
        // splicing it mid-sentence produced "Moves reading more. further than…".
        // Strip the terminal punctuation before it becomes a clause.
        let identity = goal.identityLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
        if !identity.isEmpty {
            return String(localized: "Moves \(identity.lowercasedFirst) further than anything else today")
        }
        return String(localized: "The one that moves \(goal.title.lowercased()) furthest today")
    }
}

private extension String {
    /// "Reading every night." → "reading every night." — so it reads inside a
    /// sentence instead of starting a new one mid-line.
    var lowercasedFirst: String {
        guard let f = first else { return self }
        return f.lowercased() + dropFirst()
    }
}
