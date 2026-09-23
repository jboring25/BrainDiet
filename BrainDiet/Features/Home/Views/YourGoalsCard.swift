import SwiftUI

// MARK: - YOUR GOALS — the dream, the one action, and the rest of the dreams.
//
// ⭐ ADDED 2026-08-11 for Jack's Screen 1 criterion, which Home was failing
// outright: "the feature of having your actionable steps to the future you want
// right there on the first screen you see. Always reminded of your goals." Home
// showed ONE engine-picked serving and none of the user's goals, so the screen
// they open twenty times a day never mentioned what any of it was for. The
// serving card answered "what now"; nothing answered "toward what".
//
// ⭐ AND IT ABSORBED THE SERVING CARD, rather than sitting under it. The first
// build kept both, and the screenshot settled it immediately: `TodaysServingCard`
// and the first goal row rendered the SAME step ("Pick your next book") 200pt
// apart, because the engine's suggestion is by definition one of these steps.
// Two cards, one fact, and a screen whose whole promise is simplicity. So the
// suggested step is now the highlighted row INSIDE this card and carries the
// app's single primary CTA. One card: the dream, the next bite, and every other
// dream one tap away.
//
// SHAPE. References studied before designing (Mobbin):
//   • Quicken's savings goal — the dream is a NAMED thing with its target ABOVE
//     the progress, so the number is always read in the light of the ambition.
//     That ordering is copied exactly: the sentence the user committed to at
//     onboarding sits above every row.
//     https://mobbin.com/screens/01eb82a0-9c38-43ba-b6e7-1c71edc9e252
//   • Bloom's "Your Program" — a named commitment followed by ONE next item, not
//     a backlog. Each goal gets exactly one row for the same reason.
//     https://mobbin.com/screens/1b17c919-dc12-4e39-ad3d-5da1d854bf69
//
// ⛔️ THE ANTI-REFERENCE IS THE WHOLE CATEGORY. Finch, QUITTR, Life Reset and
// Tiimo all render this idea as a column of unchecked boxes. We removed the
// streak on purpose — Jack: "having no streak is better because it incentivizes
// no pressure, and that's what I want my users to feel" — and a stack of empty
// checkboxes is that same pressure wearing a different control. So: no
// checkboxes, no counts, no "0/3 today", no red. A row is an OFFER (tap it and
// it starts), never a debt. Measurement is Becoming's job, not this card's.

struct YourGoalsCard: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Row: Identifiable {
        let goal: Goal
        let domain: ActivityDomain
        /// The next step for this goal, or nil when today's are all done.
        let step: GoalStep?
        var id: UUID { goal.id }
    }

    /// The user's own committed sentence ("Reading every night.").
    let identityLine: String
    let rows: [Row]
    /// The engine's suggestion, when it is one of these steps — that row becomes
    /// the primary one. Nil (dessert, defaults) leaves every row equal and the
    /// serving card stays on screen above instead.
    var suggestedStepID: UUID?
    /// "Feed my brain" — the engine's own verb for the suggested category.
    var ctaTitle: String = ""
    // ⭐ SELF-REPORT PLATING (2026-08-20). The controller is shared with Home so
    // the plate rect and the drag translation share one coordinate space.
    var drop: PlateDropController?
    /// Called when a row is dropped on the plate — it already happened.
    var onReport: ((PlateDraggable) -> Void)?
    /// Opens the off-plan report sheet.
    var onAddSomething: (() -> Void)?
    /// Start this goal's next step.
    var onStart: (Row) -> Void
    /// The primary CTA and its quiet re-roll (only used when a row is primary).
    var onFeed: () -> Void = {}
    var onNotNow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WHAT YOU'RE BUILDING")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)

            // The dream in the user's own words — serif, because this is the one
            // line on Home that is about them rather than about today.
            Text(identityLine)
                .font(BDFont.serif(size: 19, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            Rectangle()
                .fill(Color.bdCardBorder)
                .frame(height: 1)
                .padding(.top, 12)
                .padding(.bottom, 4)

            VStack(spacing: 6) {
                ForEach(rows) { row in
                    if isPrimary(row) {
                        primaryRow(row)
                    } else {
                        goalRow(row)
                    }
                }
            }
            .padding(.top, 4)

            // ⭐ The off-plan escape hatch. A marginal text action, not another
            // card — the same grammar as the Menu's approved "Make this one
            // mine". Anything that isn't a plan step lives behind this.
            if let onAddSomething {
                Button(action: onAddSomething) {
                    Text("+ Add something you did")
                        .font(BDFont.body(.bold, size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdGoldText)
                        .underline()
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Report something you did away from the app")
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                )
        )
    }

    private func isPrimary(_ row: Row) -> Bool {
        guard let suggestedStepID, let step = row.step else { return false }
        return step.id == suggestedStepID
    }

    // MARK: The suggested step — the same row, raised, carrying the one CTA.

    private func primaryRow(_ row: Row) -> some View {
        VStack(spacing: 0) {
            // `raised` = the chip sits ON the leaf tint, so it needs the surface
            // fill or its own leaf wash disappears into the background and the
            // primary row is the only one without a visible chip.
            rowBody(row, step: row.step, raised: true)

            Button(action: onFeed) {
                Text(ctaTitle)
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.bdLeafDeep))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Button(action: onNotNow) {
                Text("Not now")
                    .font(BDFont.body(.semiBold, size: 13, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.bdLeafTint)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.bdLeaf.opacity(0.45), lineWidth: 1.5)
                )
        )
    }

    // MARK: Every other goal — one row, one tap, no checkbox.

    @ViewBuilder
    private func goalRow(_ row: Row) -> some View {
        if row.step != nil {
            ZStack {
                // The slot the row vacated. Opaque, never a tint — a translucent
                // ghost leaves the original readable and the lifted card then
                // reads as a duplicate instead of a thing you picked up.
                if drop?.liftedRowID == row.id { VacatedSlot() }

                Button { onStart(row) } label: { rowBody(row, step: row.step) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Starts this step")
                    .opacity(drop?.liftedRowID == row.id ? 0 : 1)
                    .modifier(PlateDragModifier(row: row, drop: drop, onReport: onReport,
                                                reduceMotion: reduceMotion))
            }
            .accessibilityAction(named: "I already did this") { reportRow(row) }
        } else {
            rowBody(row, step: nil)
        }
    }

    /// The a11y + Reduce Motion path. NEVER drag-only — the same law the
    /// onboarding plating moment ships under.
    private func reportRow(_ row: Row) {
        guard let item = Self.draggable(from: row) else { return }
        onReport?(item)
    }

    /// A row, as something that can be plated.
    static func draggable(from row: Row) -> PlateDraggable? {
        guard let step = row.step else { return nil }
        return PlateDraggable(
            title: step.title,
            subtitle: step.cue.isEmpty ? "\(step.suggestedMinutes) minutes" : step.cue,
            activityID: row.domain.activityID,
            goalID: row.goal.id,
            stepID: step.id,
            minutes: step.suggestedMinutes,
            icon: row.domain.phIcon,
            tint: row.domain.categoryTint,
            ink: row.domain.categoryColor
        )
    }

    private func rowBody(_ row: Row, step: GoalStep?, raised: Bool = false) -> some View {
        HStack(spacing: 11) {
            // ⛔️ NOT PlateCategoryChip. Three domains collapse onto one plate
            // CATEGORY (fitness and building are both protein), so the category
            // chip drew a dumbbell next to "Write the idea down". The Menu
            // already solved this — icon and tint come from the DOMAIN, food
            // language from the category. Same treatment here so a step looks
            // identical on both screens.
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(raised ? Color.bdSurface : row.domain.categoryTint)
                .frame(width: 34, height: 34)
                .overlay(BDPhIcon(icon: row.domain.phIcon, size: 16,
                                  color: row.domain.categoryColor))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(step?.title ?? row.goal.title)
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(step == nil ? Color.bdTextSecondary : Color.bdTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // The cue is the whole reason the step works (Gollwitzer &
                // Sheeran, d = 0.65 — the effect comes from naming WHEN), so it
                // rides with the step everywhere the step appears.
                Text(secondary(row, step: step))
                    .font(BDFont.body(.medium, size: 11.5, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.sm)

            if let step {
                Text("\(step.suggestedMinutes)m")
                    .font(BDFont.body(.bold, size: 12.5, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Color.bdTextSecondary)
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "after your coffee" · "done today" · the goal title as a last resort.
    private func secondary(_ row: Row, step: GoalStep?) -> String {
        guard let step else { return String(localized: "done today") }
        return step.cue.isEmpty ? row.goal.title : step.cue
    }
}

#Preview("Three goals") {
    let reading = Goal(title: "Read more", identityLine: "Reading every night.",
                       domain: ActivityDomain.reading.rawValue, isPrimary: true, sortIndex: 0)
    let readStep = GoalStep(goalID: reading.id, title: "Read 10 pages of Dune",
                            cue: "after your coffee", suggestedMinutes: 15,
                            kind: .recurring, sortIndex: 0)
    let fitness = Goal(title: "Get stronger", identityLine: "Training, not trying.",
                       domain: ActivityDomain.fitness.rawValue, isPrimary: false, sortIndex: 1)
    let fitStep = GoalStep(goalID: fitness.id, title: "Do a short workout",
                           cue: "before dinner", suggestedMinutes: 20,
                           kind: .recurring, sortIndex: 0)
    let building = Goal(title: "Build the thing", identityLine: "Shipping.",
                        domain: ActivityDomain.building.rawValue, isPrimary: false, sortIndex: 2)

    return ZStack {
        BDBackground()
        YourGoalsCard(
            identityLine: "Finishing what I start.",
            rows: [
                .init(goal: reading, domain: .reading, step: readStep),
                .init(goal: fitness, domain: .fitness, step: fitStep),
                .init(goal: building, domain: .building, step: nil)
            ],
            suggestedStepID: readStep.id,
            ctaTitle: "Feed my brain",
            onStart: { _ in }
        )
        .padding(18)
    }
}
