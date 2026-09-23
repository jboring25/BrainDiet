import SwiftUI
import SwiftData

// MARK: - MakeItMineSheet — turning a category into the user's actual action.
//
// ⭐ 2026-08-07. Jack's brief: "the best personalization with the least amount
// of friction." Those pull against each other — personalisation needs facts
// only the user has, and every fact costs a tap. Three decisions resolve it,
// and each one is a tap removed:
//
//   1 · THE MOMENT IS PRE-SET. The step already carries a cue from the planner
//       (`GoalStep.cue`), so the "when" starts answered. The user only touches
//       it if the default is wrong.
//   2 · THE OBJECT IS REMEMBERED. It is typed ONCE per domain and comes back
//       as a chip forever after (`UserProfile.stepObjects`). Second visit
//       onward there is nothing to type.
//   3 · CANDIDATES ARE ALREADY ON SCREEN, and TAPPING ONE APPLIES IT. No
//       select-then-confirm — that is two taps for one decision. Safe because
//       it is fully reversible: the generic step is stashed on the step itself
//       and revert is one tap (`GoalStep.revertPersonalisation`).
//
// So the returning-user path is: open → tap a candidate. One tap. First use
// costs one short answer, which is the fact that makes everything after it
// specific.
//
// ⭐ WHAT IT DOES NOT DO. It is not a chat. A blank box asks the user to supply
// context unprompted and reliably returns a mood rather than a fact — the same
// failure the aspiration step had before it became buttons. Every input here is
// a named question with a concrete answer.

struct MakeItMineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// The step being sharpened, and the domain it belongs to.
    let step: GoalStep
    let domain: ActivityDomain
    let profile: UserProfile?
    /// The most recent session's start — the acting limit's window boundary
    /// (`UserProfile.planningsSinceAction`). Nil = never acted.
    var lastActionAt: Date? = nil

    @State private var object: String = ""
    @State private var cue: String = ""
    @State private var candidates: [StepCandidate] = []
    @State private var isThinking = false
    @State private var refiner: StepRefiner? = nil
    @FocusState private var objectFocused: Bool

    /// Remembered things for this domain — the zero-typing path.
    private var knownObjects: [String] {
        profile?.stepObjects(for: domain) ?? []
    }

    /// Moment options: the step's own cue first (so the default is always
    /// present and selected), then the domain's other anchors. Never invented —
    /// these are the same `stepCues` the plan already uses.
    private var cueOptions: [String] {
        var options = [step.cue].filter { !$0.isEmpty }
        for c in domain.stepCues where !options.contains(c) { options.append(c) }
        return options
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        objectSection
                        if !cueOptions.isEmpty { cueSection }
                        candidateSection
                        if step.isPersonalised { revertRow }
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.top, Theme.Space.md)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Make it yours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.bdTextSecondary)
                }
            }
        }
        .task { await prepare() }
    }

    // MARK: The one fact the app can't know

    private var objectSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            // The eyebrow names the CATEGORY; the domain's question lives in the
            // field's placeholder. Using the question in both printed it twice.
            Text("THE THING ITSELF")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)

            if !knownObjects.isEmpty {
                BDFlowLayout {
                    ForEach(knownObjects, id: \.self) { known in
                        BDChip(title: known, isSelected: object == known) {
                            object = known
                            objectFocused = false
                            UISelectionFeedbackGenerator().selectionChanged()
                            Task { await regenerate() }
                        }
                    }
                }
            }

            TextField(domain.objectPrompt, text: $object)
                .font(.bdBody)
                .foregroundStyle(Color.bdTextPrimary)
                .focused($objectFocused)
                .submitLabel(.done)
                .autocorrectionDisabled(false)
                .onSubmit { Task { await regenerate() } }
                .padding(Theme.Space.md)
                .frame(minHeight: Theme.Size.minTouch)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(objectFocused ? Color.bdAccentSoft : Color.bdSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(objectFocused ? Color.bdLeaf : Color.bdCardBorder, lineWidth: 1.5)
                )
                .animation(Theme.Motion.smooth, value: objectFocused)
        }
    }

    // MARK: The moment — pre-answered from the step's own cue

    private var cueSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("WHEN DOES THIS RELIABLY HAPPEN?")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)

            BDFlowLayout {
                ForEach(cueOptions, id: \.self) { option in
                    BDChip(title: option, isSelected: cue == option) {
                        cue = option
                        UISelectionFeedbackGenerator().selectionChanged()
                        Task { await regenerate() }
                    }
                }
            }
        }
    }

    // MARK: The candidates — tapping one IS the commit

    @ViewBuilder
    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            // At the limit the header goes with the candidates: "PICK ONE" over
            // nothing to pick is a broken instruction, and a live regenerate
            // button next to a ceiling invites the user to keep tapping for a
            // way around it.
            if !atLimit {
                HStack {
                    Text("PICK ONE")
                        .font(.bdEyebrow)
                        .kerning(1.5)
                        .foregroundStyle(Color.bdTextSecondary)
                    Spacer()
                    Button { Task { await regenerate() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.bdTextSecondary)
                            .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch, alignment: .trailing)
                    }
                    .buttonStyle(.plain)
                    .disabled(isThinking)
                }
            }

            if atLimit {
                // ⭐ THE ACTING LIMIT (Jack, 2026-08-11). Candidates are gone,
                // not greyed: a disabled row still invites the tap and makes the
                // ceiling feel like a paywall. The step's own words stay on
                // screen above, and revert stays reachable below — you can
                // always undo, you just can't add more planning.
                limitNote
            } else if object.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Honest empty state: with no object there is nothing to be
                // specific about, so we say what's needed rather than showing
                // three reworded versions of the same generic step.
                Text("Name the thing above and we'll make this step about it.")
                    .font(BDFont.body(.medium, size: 13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.vertical, Theme.Space.sm)
            } else {
                ForEach(candidates) { candidate in
                    candidateRow(candidate)
                }
                .opacity(isThinking ? 0.45 : 1)
                .animation(Theme.Motion.smooth, value: isThinking)
            }
        }
    }

    /// True once sharpening again would be planning instead of acting.
    private var atLimit: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_PLAN_LIMIT"] == "1" { return true }
        #endif
        return profile?.atPlanningLimit(lastActionAt: lastActionAt) ?? false
    }

    /// The ceiling, stated once and calmly. Cream fill rather than a warning
    /// tint — this is a fact about where the user is, not an error they made.
    private var limitNote: some View {
        Text(UserProfile.PlanningLimit.reachedLine)
            .font(BDFont.body(.semiBold, size: 13.5, relativeTo: .subheadline))
            .foregroundStyle(Color.bdTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color.bdCream)
            )
    }

    private func candidateRow(_ candidate: StepCandidate) -> some View {
        Button { apply(candidate) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(BDFont.body(.bold, size: 15, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !candidate.cue.isEmpty {
                    Text("\(candidate.cue) · \(step.suggestedMinutes)m")
                        .font(BDFont.body(.medium, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.md)
            .frame(minHeight: Theme.Size.minTouch)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Applies this step")
    }

    /// Only shown once a step has actually been personalised — the safety net
    /// that makes tap-to-apply a fair trade rather than a trap.
    private var revertRow: some View {
        Button {
            step.revertPersonalisation()
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } label: {
            Text("Put the original step back")
                .font(BDFont.body(.medium, size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
        }
        .buttonStyle(.plain)
    }

    // MARK: Behaviour

    /// Open in the most-answered state we can honestly reach: the moment comes
    /// from the step, the object from what they told us last time.
    private func prepare() async {
        refiner = StepRefinerFactory.make()
        #if DEBUG
        // Screenshot seam: BD_MAKE_MINE=<object> seeds the returning-user state
        // (object already known → candidates on screen, zero typing).
        if let seeded = ProcessInfo.processInfo.environment["BD_MAKE_MINE"], seeded != "1" {
            object = seeded
            cue = step.cue.isEmpty ? (cueOptions.first ?? "") : step.cue
            await regenerate()
            return
        }
        #endif
        cue = step.cue.isEmpty ? (cueOptions.first ?? "") : step.cue
        if object.isEmpty, let remembered = knownObjects.first {
            object = remembered
            await regenerate()
        } else if object.isEmpty {
            // First ever visit for this domain: the keyboard is the next action,
            // so go straight there instead of making them tap the field.
            objectFocused = true
        }
    }

    /// The step the refiner should rewrite.
    ///
    /// ⭐ NOT always the step's own title. Opener steps are setup tasks ("Pick
    /// your next book"), and once the user names their thing that task is
    /// answered — the rewrite is meant to produce the ONGOING action instead
    /// (see `GoalStep.personalise`). Feeding the opener to the on-device model
    /// would ask it to rewrite the wrong verb and it would dutifully return
    /// "Pick your next Dune". So a one-off resolves to the domain's recurring
    /// seed. The heuristic floor ignores `action` entirely, so this only
    /// sharpens the model path — but it has to be right in both.
    private var baseAction: String {
        let current = step.isPersonalised ? step.originalTitle : step.title
        let wasOneOff = step.kind == .oneoff || !step.originalKindRaw.isEmpty
        guard wasOneOff,
              let ongoing = domain.stepSeeds.first(where: { $0.kind == .recurring })?.title
        else { return current }
        return ongoing
    }

    private func regenerate() async {
        let trimmed = object.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            candidates = []
            return
        }
        isThinking = true
        let request = StepRefinementRequest(
            action: baseAction,
            object: trimmed,
            cue: cue,
            domain: domain,
            minutes: step.suggestedMinutes
        )
        let engine = refiner ?? HeuristicStepRefiner()
        let result = await engine.candidates(for: request)
        candidates = result
        isThinking = false
    }

    private func apply(_ candidate: StepCandidate) {
        guard !atLimit else { return }
        step.personalise(title: candidate.title, cue: candidate.cue)
        profile?.rememberStepObject(object, for: domain)
        // Naming the book once makes the whole reading plan about that book —
        // every still-generic step in this domain picks it up, and each keeps
        // its own one-tap revert. Steps the user already sharpened are untouched.
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        PlanPersonaliser.apply(object: object, domain: domain, to: goals)
        // Counted here and nowhere else — the moment a rewrite is COMMITTED, not
        // when the sheet opens or candidates regenerate. Looking is free;
        // changing the plan is the thing being limited.
        profile?.recordPlanning(lastActionAt: lastActionAt)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
