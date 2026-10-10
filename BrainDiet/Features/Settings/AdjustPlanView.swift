import SwiftUI
import SwiftData

// MARK: - Adjust plan — deliberately low-prominence goal editing (spec-v2.6).
//
// NOT surfaced on the Reclaim tab. Reached only from Settings, and gated by light
// friction: changing the plan resets your steps (a confirm), so users can't keep
// swapping goals down to something easier.
//
// ⭐ ONE MOONSHOT (2026-10-10): edits the moonshot text and its road (title,
// date, done). The domain grids are gone: there is one goal, and its domain is
// the plan server's read of the moonshot. Saving rebuilds the single goal with
// the heuristic floor, then asks the plan server for steps aimed at the
// current milestone (first not done) and folds them in. A legacy multi-goal
// profile opens with its primary goal's words as the moonshot; saving turns
// it into a moonshot profile.

struct AdjustPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var moonshot: String
    @State private var milestones: [Milestone]
    @State private var showConfirm = false
    @State private var saving = false
    /// ⭐ 2026-08-06 — the bounded "in your own words" slots. Always exactly
    /// `DreamDetails.maxCount` in the EDITOR (empty slots render as prompts);
    /// `DreamDetails.normalise` drops the blanks on save.
    @State private var details: [String]
    @FocusState private var focusedDetail: Int?

    init(profile: UserProfile) {
        self.profile = profile
        _moonshot = State(initialValue: profile.moonshotText)
        let road = profile.milestones.filled
        _milestones = State(initialValue: road.isEmpty ? [Milestone(title: "", by: "")] : road)
        var slots = profile.dreamDetails
        while slots.count < DreamDetails.maxCount { slots.append("") }
        _details = State(initialValue: slots)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        StepHeader(
                            title: "Adjust your plan",
                            subtitle: "Change your moonshot or the road to it. This rebuilds your steps."
                        )

                        group("YOUR MOONSHOT") {
                            TextField(String(localized: "The biggest thing you'd go after"),
                                      text: Binding(get: { moonshot },
                                                    set: { moonshot = String($0.prefix(MoonshotExamples.maxLength)) }),
                                      axis: .vertical)
                                .font(BDFont.serif(size: 19, relativeTo: .title3))
                                .foregroundStyle(Color.bdTextPrimary)
                                .lineLimit(2...6)
                                .padding(Theme.Space.md)
                                .background(Color.bdSurface,
                                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .strokeBorder(Color.bdCardBorder, lineWidth: 1.5))
                        }

                        group("THE ROAD THERE") {
                            AdjustRoadEditor(milestones: $milestones)
                        }

                        detailsSection

                        BDPrimaryButton(title: saving ? "Rebuilding…" : "Save changes", isEnabled: canSave) {
                            showConfirm = true
                        }
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.vertical, Theme.Space.lg)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // DEBUG seam (2026-08-06): BD_OPEN_ADJUST=bottom lands on the
                // "in your own words" section, which otherwise sits below the
                // fold and can't be captured by the screenshot harness.
                .modifier(DebugBottomAnchor())
            }
            .navigationTitle("Adjust plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.bdTextSecondary)
                }
            }
            .confirmationDialog(
                "Changing your plan resets your steps.",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Rebuild my plan", role: .destructive) { Task { await rebuild() } }
                Button("Keep what I have", role: .cancel) {}
            } message: {
                Text("Your progress so far stays. Only the steps ahead change.")
            }
        }
    }

    private var trimmed: String { moonshot.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool { !saving && trimmed.count >= MoonshotExamples.minLength }

    // MARK: Rebuild — one goal from the edited moonshot + road.

    private func rebuild() async {
        saving = true
        defer { saving = false }
        let domain = profile.primaryDomain ?? profile.domains.first ?? .building
        let road = milestones.filled
        let wasLegacy = !profile.hasMoonshot

        // Write the edit first: the plan request is built from the profile.
        profile.moonshot = trimmed
        profile.milestones = road
        profile.goalWords = [domain: trimmed]
        if let r = profile.goalReasons[domain] { profile.goalReasons = [domain: r] }
        // A legacy short ("training") does not read as "Go get ___.".
        if wasLegacy { profile.goalShorts = [:] }
        profile.domainsRaw = domain.rawValue
        profile.primaryDomainRaw = domain.rawValue
        profile.goalIDsRaw = domain.legacyGoalID
        profile.dreamDetails = details   // setter normalises: trims, caps, drops blanks

        let answers = OnboardingAnswers(
            hijackers: profile.hijackers,
            timeLost: ShortFormBand.allCases.first { $0.baselineMinutes == profile.baselineJunkMinutes } ?? .oneToTwo,
            domains: [domain],
            primaryDomain: domain,
            aspiration: profile.why,
            blocker: profile.blocker ?? .distracted,
            // ⭐ From the EDITOR, not the persisted row: what you just typed
            // shapes the plan you are about to get.
            dreamDetails: DreamDetails.normalise([trimmed, road.current?.title ?? ""] + details)
        )
        var plan = MoonshotPlan.focus(HeuristicGoalPlanner.plan(from: answers), moonshot: trimmed, short: "")
        if let served = await PlanService.plan(for: profile) {
            plan = plan.merging(served)
            profile.shieldLines = served.shield
        }

        // Replace the persisted plan.
        for g in (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? [] { modelContext.delete(g) }
        for s in (try? modelContext.fetch(FetchDescriptor<GoalStep>())) ?? [] { modelContext.delete(s) }
        plan.persist(into: modelContext)
        profile.planIdentityLine = plan.identityLine.trimmingCharacters(in: .whitespacesAndNewlines)

        try? modelContext.save()
        Log.app.info("Plan adjusted: moonshot rebuilt (\(road.count, privacy: .public) milestones).")
        dismiss()
    }

    // MARK: - ⭐ "In your own words" (2026-08-06) — the bounded detail surface.
    //
    // Onboarding's identity answer is four buttons now, which keeps the flow
    // fast but can't hold a specific dream. This is where the specific dream
    // goes. It sits HERE rather than in onboarding on purpose: saving on this
    // screen re-runs the planner, so writing something has a visible
    // consequence — the menu changes. A note field that changed nothing would
    // be a diary, and this app does not keep a diary.
    //
    // Bounds (3 slots × 140 chars) and the slot prompts both come from
    // `DreamDetails` — never re-stated here, so the UI and the planner can
    // never disagree about what's allowed. Each slot is PROMPTED rather than
    // blank: a labelled ask gets a concrete answer, a blank box gets a mood.
    private var detailsSection: some View {
        group("IN YOUR OWN WORDS") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Optional. Anything you put here gets used to make your steps specific to you instead of generic.")
                    .font(BDFont.body(.medium, size: 13.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(details.indices), id: \.self) { index in
                    detailField(index)
                }
            }
        }
    }

    private func detailField(_ index: Int) -> some View {
        let isFocused = focusedDetail == index
        let remaining = DreamDetails.maxLength - details[index].count
        return VStack(alignment: .leading, spacing: 6) {
            TextField(
                DreamDetails.placeholders[index],
                text: Binding(
                    get: { details[index] },
                    // Hard-capped at the source: the field cannot hold more than
                    // the planner will accept, so the count below never lies and
                    // there is no silent truncation on save.
                    set: { details[index] = String($0.prefix(DreamDetails.maxLength)) }
                ),
                axis: .vertical
            )
            .font(.bdBody)
            .foregroundStyle(Color.bdTextPrimary)
            .lineLimit(1...3)
            .focused($focusedDetail, equals: index)
            .submitLabel(.done)
            .padding(Theme.Space.md)
            .frame(minHeight: Theme.Size.minTouch)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isFocused ? Color.bdAccentSoft : Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isFocused ? Color.bdLeaf : Color.bdCardBorder, lineWidth: 1.5)
            )
            .animation(Theme.Motion.smooth, value: isFocused)

            // The counter appears only in the last stretch — a permanent
            // "0/140" turns a sentence into a form to be filled correctly.
            if isFocused, remaining <= 30 {
                Text("\(remaining) left")
                    .font(.bdCaption)
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 0 ? Color.bdSalmon : Color.bdTextSecondary)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.smooth, value: remaining <= 30)
    }

    @ViewBuilder
    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(title)
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)
            content()
        }
    }
}

/// DEBUG-only: anchor a ScrollView to its bottom so the screenshot harness can
/// capture below-the-fold sections. Compiles to a no-op in Release.
private struct DebugBottomAnchor: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_OPEN_ADJUST"] == "bottom" {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
