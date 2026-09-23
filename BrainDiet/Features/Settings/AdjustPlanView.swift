import SwiftUI
import SwiftData

// MARK: - Adjust plan — deliberately low-prominence goal editing (spec-v2.6).
//
// NOT surfaced on the Reclaim tab. Reached only from Settings, and gated by light
// friction: changing goals resets your steps (a confirm), so users can't keep
// swapping goals down to something easier. Re-runs the deterministic planner from
// the (edited) answers and replaces the persisted plan.

struct AdjustPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var domains: [ActivityDomain]
    @State private var primary: ActivityDomain?
    @State private var showConfirm = false
    /// ⭐ 2026-08-06 — the bounded "in your own words" slots. Always exactly
    /// `DreamDetails.maxCount` in the EDITOR (empty slots render as prompts);
    /// `DreamDetails.normalise` drops the blanks on save.
    @State private var details: [String]
    @FocusState private var focusedDetail: Int?

    init(profile: UserProfile) {
        self.profile = profile
        _domains = State(initialValue: profile.domains)
        _primary = State(initialValue: profile.primaryDomain)
        var slots = profile.dreamDetails
        while slots.count < DreamDetails.maxCount { slots.append("") }
        _details = State(initialValue: slots)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Theme.Space.md), GridItem(.flexible(), spacing: Theme.Space.md)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        StepHeader(
                            title: "Adjust your plan",
                            subtitle: "Change what you're pouring your time into. This rebuilds your steps."
                        )

                        group("WHAT MATTERS") {
                            LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                                ForEach(ActivityDomain.allCases) { domain in
                                    OBOptionCard(
                                        symbol: domain.symbol,
                                        label: domain.label,
                                        tint: domain.tint,
                                        isSelected: domains.contains(domain)
                                    ) { toggle(domain) }
                                }
                            }
                        }

                        if domains.count > 1 {
                            group("MATTERS MOST") {
                                LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                                    ForEach(domains) { domain in
                                        OBOptionCard(
                                            symbol: domain.symbol,
                                            label: domain.label,
                                            tint: domain.tint,
                                            isSelected: primary == domain
                                        ) { withAnimation(Theme.Motion.snappy) { primary = domain } }
                                    }
                                }
                            }
                        }

                        detailsSection

                        BDPrimaryButton(title: "Save changes", isEnabled: canSave) {
                            showConfirm = true
                        }
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.vertical, Theme.Space.lg)
                }
                .scrollIndicators(.hidden)
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
                "Changing your goals resets your steps.",
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

    private var canSave: Bool {
        !domains.isEmpty && primary != nil && domains.contains(primary!)
    }

    private func toggle(_ d: ActivityDomain) {
        if let i = domains.firstIndex(of: d) {
            domains.remove(at: i)
            if primary == d { primary = nil }
        } else {
            domains.append(d)
        }
        if domains.count == 1 { primary = domains.first }
    }

    // MARK: Rebuild — re-derive the plan from edited answers, replace persisted goals.

    private func rebuild() async {
        guard let primary else { return }
        let ranked = [primary] + domains.filter { $0 != primary }
        let answers = OnboardingAnswers(
            hijackers: profile.hijackers,
            timeLost: ShortFormBand.allCases.first { $0.baselineMinutes == profile.baselineJunkMinutes } ?? .oneToTwo,
            domains: ranked,
            primaryDomain: primary,
            aspiration: profile.why,
            blocker: profile.blocker ?? .distracted,
            // ⭐ From the EDITOR's slots, not the persisted row — the whole point
            // of this screen is that what you just typed shapes the plan you're
            // about to get. Reading `profile.dreamDetails` here would rebuild
            // against the previous save and quietly ignore this edit.
            dreamDetails: DreamDetails.normalise(details)
        )
        let planner = GoalPlannerFactory.make()
        let plan = await planner.makePlan(from: answers)

        // Replace the persisted plan.
        for g in (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? [] { modelContext.delete(g) }
        for s in (try? modelContext.fetch(FetchDescriptor<GoalStep>())) ?? [] { modelContext.delete(s) }
        plan.persist(into: modelContext)

        // Keep the profile's derived fields in sync.
        profile.domainsRaw = ranked.map(\.rawValue).joined(separator: ",")
        profile.primaryDomainRaw = primary.rawValue
        profile.goalIDsRaw = {
            var ids: [String] = []
            for d in ranked where !ids.contains(d.legacyGoalID) { ids.append(d.legacyGoalID) }
            return ids.joined(separator: ",")
        }()
        profile.planIdentityLine = plan.identityLine.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.dreamDetails = details   // setter normalises: trims, caps, drops blanks

        try? modelContext.save()
        Log.app.info("Plan adjusted: \(plan.goals.count, privacy: .public) goals rebuilt.")
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
