import SwiftUI

// MARK: - PlanServing — one goal's daily serving line on the meal-plan document.
//
// "[icon] Read a few pages — 35m." A pure value type so the card
// renders the same from persisted Goals (Home / Your Plan sheet) and from the
// onboarding planner's value-type output (plan reveal), and stays
// ImageRenderer-safe.

struct PlanServing: Identifiable, Equatable {
    var id: String { title }
    /// SF Symbol for the goal's domain (never emoji). Retained for
    /// the row's icon tile.
    let symbol: String
    /// The concrete daily action — "Read a few pages", NOT the goal title
    /// "Read more". Locke & Latham (2002): specific goals beat "do your best",
    /// and a vague title IS do-your-best.
    let title: String
    /// The if-then cue — "after you brush your teeth". Empty renders nothing.
    var cue: String = ""
    /// Servings per day — the plan's rhythm is one serving per goal.
    let count: Int
    /// The serving size in minutes (the goal's everyday recurring step).
    let minutes: Int
    /// ⭐ The domain this serving belongs to (2026-07-22). Carries the CATEGORY
    /// through to the card so every row can wear its colour. Optional
    /// only so legacy/mock call sites keep compiling; real plans always set it.
    var domain: ActivityDomain? = nil

    /// "1× 25m" — the legacy printed amount column (accessibility copy).
    var amount: String { "\(count)× \(minutes)m" }
}

extension PlanServing {
    /// From the persisted plan (Reclaim's Goal/GoalStep rows).
    static func from(goals: [Goal]) -> [PlanServing] {
        goals.sorted { $0.sortIndex < $1.sortIndex }.map { goal in
            PlanServing(
                symbol: ActivityDomain(rawValue: goal.domain)?.symbol ?? "sparkles",
                title: everydayStep(goal.orderedSteps.map { ($0.kind, $0.title) }) ?? goal.title,
                cue: everydayCue(goal.orderedSteps.map { ($0.kind, $0.cue) }),
                count: 1,
                minutes: servingMinutes(goal.orderedSteps.map { ($0.kind, $0.suggestedMinutes) }),
                domain: ActivityDomain(rawValue: goal.domain)
            )
        }
    }

    /// From the planner's value-type output (onboarding reveal, pre-persistence).
    static func from(planned: [PlannedGoal]) -> [PlanServing] {
        planned.map { goal in
            PlanServing(
                symbol: goal.domain.symbol,
                title: everydayStep(goal.steps.map { ($0.kind, $0.title) }) ?? goal.title,
                cue: everydayCue(goal.steps.map { ($0.kind, $0.cue) }),
                count: 1,
                minutes: servingMinutes(goal.steps.map { ($0.kind, $0.suggestedMinutes) }),
                domain: goal.domain
            )
        }
    }

    /// The everyday ACTION: the first recurring step's title. This is the row the
    /// card should show — the plan card used to render `goal.title` ("Read more"),
    /// which is a category, not something a person can do today.
    private static func everydayStep(_ steps: [(GoalStepKind, String)]) -> String? {
        let t = steps.first { $0.0 == .recurring }?.1 ?? steps.first?.1
        return (t?.isEmpty == false) ? t : nil
    }

    /// That step's if-then cue, index-matched to the same choice as `everydayStep`.
    private static func everydayCue(_ steps: [(GoalStepKind, String)]) -> String {
        steps.first { $0.0 == .recurring }?.1 ?? steps.first?.1 ?? ""
    }

    /// The everyday serving size: the first RECURRING step's minutes (the habit),
    /// falling back to any step, then a gentle 25m default.
    private static func servingMinutes(_ steps: [(GoalStepKind, Int)]) -> Int {
        steps.first { $0.0 == .recurring }?.1 ?? steps.first?.1 ?? 25
    }
}

// MARK: - PlanCard — the SIGNATURE artifact: "Your BrainDiet", a nutrition label
// you can actually eat.
//
// ⭐ REBUILT 2026-07-22 (spec of record `design/plate-concepts/plan-card-redesign.html`,
// a HYBRID of direction C "Refined Label" + direction B "The Plated Day").
// The nutrition-label CONCEPT was praised and stays; the EXECUTION was the
// problem. What changed and why:
//   • THE FORMAT SURVIVES — serif "Your BrainDiet" title, "Serving size · one
//     day" meta, the hero "Time for you — N hrs/day" line, a DAILY SERVINGS
//     section label, one row per serving. That readability IS the share trigger.
//   • COLOUR RETURNS. This card was the ONE screen in the app with zero colour,
//     in open violation of the CATEGORY-COLOR LAW. Every row's tile now
//     carries its domain tint.
//   • ICON TILES. Each row wears its domain's icon tile (the meal-photo dish
//     art was cut 2026-10-09).
//   • THE HEAVY FDA RULES ARE GONE. Black 8pt/4pt printed rules → the appetite
//     hairline (#EFE7DA) on a warm white card with a soft shadow, Radius.card.
//   • THE CARD CLOSES ON A TOTAL: "A FULL PLATE" + the summed time, on the leaf
//     tint in leaf-deep — the plan adds up to something.
//   • The junk-budget / was→now fact rows and the rest-day footnote were CUT.
//     They are plumbing the tray and the mirror already own, and they were half
//     the reason the card ran off the bottom of the reveal screen.
//
// Reused in the onboarding Plan Reveal, the re-viewable "Your Plan" sheet and
// the share/ad artifact. `animate` drives the count-up + plating assembly
// (Reduce Motion → fade/static). The static path stays fully populated so
// ImageRenderer snapshots are complete.

struct PlanCard: View {
    let plan: BrainPlan
    /// The per-goal daily servings. Empty (e.g. no plan yet) simply omits the section.
    var servings: [PlanServing] = []
    var animate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedPlated = false

    private var doAnimate: Bool { animate && !reduceMotion }

    /// Effective values: the static/non-animated path is always fully populated
    /// (so ImageRenderer snapshots render complete), the animated path uses state.
    private var plated: Bool { doAnimate ? animatedPlated : true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Document title block ──────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text("Your BrainDiet")
                    .font(BDFont.serif(size: 21, relativeTo: .title2))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Serving size · one day")
                    .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption2))
                    .foregroundStyle(Color.bdTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // ⭐ 2026-07-22: the "Time for you · N hrs/day" hero row was DELETED.
            // It duplicated the compact reclaim strip sitting directly above the
            // card on the plan reveal ("2 hours back a day — time to read"), and
            // it sat a few rows above "A FULL PLATE · 1h 45m" — two different
            // quantities in one document, inviting a false comparison (reclaimed
            // time vs. plated time). The reclaim strip keeps stating the hours;
            // the card states what's ON the plate.

            // ── DAILY SERVINGS — one serving of each goal, every day ──
            if !rows.isEmpty {
                hairline
                Text("DAILY SERVINGS")
                    .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                    .kerning(1.35)
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 9)
                    .padding(.bottom, 5)

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    hairline
                    servingRow(row)
                        .modifier(Plate(active: plated, index: i, reduceMotion: reduceMotion))
                }

                // ── The plan adds up to something. ──
                totalRow
                    .modifier(Plate(active: plated, index: rows.count,
                                    reduceMotion: reduceMotion))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.bdSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.Shadow.cardColor, radius: Theme.Shadow.cardRadius, y: Theme.Shadow.cardY)
        .onAppear(perform: runAnimation)
        // `animate` often flips true AFTER first appear (the screen gates it on a
        // reveal phase), so re-run when it turns on.
        .onChange(of: animate) { _, _ in runAnimation() }
    }

    // MARK: Rows — one per serving, wearing the domain's icon tile.
    //
    // Meal photos cut app-wide (Jack, 2026-10-09: "Cut the meal photos and
    // brain vegetables"). The tile is the SAME one Home's focus card uses:
    // domain tint at 30% behind the domain's SF Symbol.

    private struct Row: Identifiable {
        let id: String
        let serving: PlanServing
    }

    private var rows: [Row] {
        servings.enumerated().map { index, serving in
            Row(id: "\(index)-\(serving.id)", serving: serving)
        }
    }

    private func servingRow(_ row: Row) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((row.serving.domain?.tint ?? Color.bdLeafTint).opacity(0.3))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: row.serving.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.bdTextPrimary.opacity(0.75))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(row.serving.title)
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // ⭐ THE CUE LINE — the "if" of the implementation intention. Set in
                // the CATEGORY ink so it reads as part of the serving rather than as
                // metadata, and phrased as the tail of a sentence ("after you brush
                // your teeth") the way 5 Minute Journal writes its prompts — a
                // sentence in the user's voice, never a labelled field.
                if !row.serving.cue.isEmpty {
                    Text(row.serving.cue)
                        .font(BDFont.body(.regular, size: 11, relativeTo: .caption2))
                        .foregroundStyle(Color.bdTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: Theme.Space.sm)

            Text("\(row.serving.minutes)m")
                .font(BDFont.body(.bold, size: 13, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Color.bdTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.serving.title): \(row.serving.minutes) minutes daily"
        )
    }

    // MARK: The close — "A FULL PLATE" on the leaf tint.

    private var totalRow: some View {
        HStack {
            Text("A FULL PLATE")
                .font(BDFont.body(.bold, size: 12.5, relativeTo: .footnote))
                .kerning(0.25)
                .foregroundStyle(Color.bdLeafDeep)
            Spacer(minLength: Theme.Space.sm)
            Text(totalText)
                .font(BDFont.serif(size: 19, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Color.bdLeafDeep)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.bdLeafTint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A full plate: \(totalText) a day")
    }

    /// Honest sum of the printed servings — "2h 00m", or "45m" under an hour.
    private var totalText: String {
        let total = servings.reduce(0) { $0 + $1.minutes }
        guard total >= 60 else { return "\(total)m" }
        return String(format: "%dh %02dm", total / 60, total % 60)
    }

    // MARK: The appetite hairline (replaces the heavy black FDA rules).

    private var hairline: some View {
        Rectangle()
            .fill(Color.bdCardBorder)
            .frame(height: 1)
    }

    // MARK: Animation

    private func runAnimation() {
        guard doAnimate else { return } // static path is already fully populated
        withAnimation(Theme.Motion.plate) { animatedPlated = true }
    }
}

// MARK: - "Plating" entrance for each ingredient row.

private struct Plate: ViewModifier {
    let active: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(active ? 1 : 0).animation(.easeOut(duration: 0.3), value: active)
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 14)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.84).delay(0.35 + 0.09 * Double(index)),
                    value: active
                )
        }
    }
}

#Preview {
    ZStack {
        BDBackground()
        PlanCard(
            plan: .mock(goalNoun: "your book", why: "I want to write my book"),
            servings: [
                PlanServing(symbol: "book.fill", title: "Read more", count: 1,
                            minutes: 35, domain: .reading),
                PlanServing(symbol: "dumbbell.fill", title: "Get stronger", count: 1,
                            minutes: 35, domain: .fitness),
                PlanServing(symbol: "hammer.fill", title: "Build something", count: 1,
                            minutes: 35, domain: .building),
                PlanServing(symbol: "guitars.fill", title: "Play music", count: 1,
                            minutes: 15, domain: .music)
            ],
            animate: true
        )
        .padding(Theme.Space.screenX)
    }
}
