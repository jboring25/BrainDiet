import SwiftUI
import SwiftData

// MARK: - v2 · The menu hero (Jack approved 2026-10-08). After the paywall,
// or its dismissal: nothing is gated.
//
// Phase 1 · "Feeding your brain what you told it." Their own words sit around
// the Culture brain as pills and drift in; each one becomes the EXISTING
// serving ball (`CultureCloudModel.feed(from:)`) where it stood. Meanwhile
// PlanService runs. Held ≥ 3.5s, until the plan answers and the words are fed,
// never past 9s.
// Phase 2 · "Your menu is ready." The three steps rise out of the brain into
// the compact Home card, staggered springs. One button into Home.

struct MenuHeroStepView: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var model = CultureCloudModel()
    @State private var served = false
    @State private var cardsShown = 0
    @State private var chips = HeroChips()

    static let minHold: Duration = .seconds(3.5)
    static let maxHold: Duration = .seconds(9)

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(height: served ? 300 : 470)
                .padding(.top, served ? 24 : 36)

            Text(served ? "Your menu is ready." : "Feeding your brain\nwhat you told it.")
                .font(BDFont.serif(size: 26, relativeTo: .title2))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .contentTransition(.opacity)
                .padding(.top, served ? 18 : 26)

            if served {
                VStack(spacing: 12) {
                    ForEach(Array(vm.servedSteps.enumerated()), id: \.offset) { i, s in
                        ServedStepCard(served: s)
                            .opacity(i < cardsShown ? [1, 0.85, 0.7][min(i, 2)] : 0)
                            .scaleEffect(i < cardsShown ? 1 : 0.55)
                            .offset(y: i < cardsShown ? 0 : -220 - CGFloat(i) * 60)
                    }
                }
                .padding(.top, 22)
            }

            Spacer(minLength: Theme.Space.md)

            if served {
                BDPrimaryButton(title: "Start with the first one") { vm.finishOnboarding() }
                    .opacity(cardsShown >= vm.servedSteps.count ? 1 : 0)
                    .padding(.bottom, Theme.Space.sm)
            }
        }
        .task { await run() }
    }

    // MARK: Stage — the brain + the words drifting into it.

    private var stage: some View {
        GeometryReader { geo in
            ZStack {
                CultureCloudView(model: model)
                    .allowsHitTesting(false)
                // Anything not yet fed when the menu lands simply leaves.
                ForEach(chips.items) { chip in
                    HeroChipView(chip: chip, state: chips.state(of: chip.id), size: geo.size)
                }
                .opacity(served ? 0 : 1)
            }
            .task(id: geo.size) { await chips.choreograph(model: model, in: geo.size) }
        }
        .onAppear { model.seed(fraction: 0.04) }
    }

    // MARK: The sequence

    private func run() async {
        chips.load(from: vm)
        let clock = ContinuousClock()
        let start = clock.now

        // Persist first: the plan request is built from the stored profile, and
        // a quit mid-hero keeps everything they told us.
        vm.persistProfile(into: modelContext)
        let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first
        var result: ServedPlan?
        if let profile { result = await PlanService.plan(for: profile) }

        while clock.now - start < Self.maxHold {
            if clock.now - start >= Self.minHold, chips.wordsFed { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        vm.applyServed(result)
        Log.onboarding.info("Menu hero: \(result == nil ? "heuristic" : "served", privacy: .public) plan")

        withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) { served = true }
        try? await Task.sleep(for: .milliseconds(350))
        for i in vm.servedSteps.indices {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.74)) { cardsShown = i + 1 }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }
}

#Preview {
    MenuHeroStepView(vm: OnboardingViewModel())
        .padding(.horizontal, Theme.Space.screenX)
        .background(Color.bdBackground)
}
