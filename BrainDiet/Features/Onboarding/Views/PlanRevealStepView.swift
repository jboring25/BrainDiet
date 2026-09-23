import SwiftUI

// MARK: - Step 6b — Plan Reveal (the shareable HERO moment) — art-direction v1b.
//
// THE SOUL: block the scroll → reclaim the stolen hours → pour them into the big
// dream. This screen is the start of the user's comeback arc — aspirational,
// determined, cinematic. The reclaimed-time → goal reframe is the EMOTIONAL hero
// (a promise about their future), elevated above the nutrition-label artifact.
//
// SHELL: plan values are mock, derived from onboarding answers via vm.makePlan().

struct PlanRevealStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0           // staggered reveal gate
    @State private var heroHours = 0       // count-up for the reclaim strip
    @State private var glow = false        // settling warm bloom
    /// Live viewport height — the content stretches to it so the CTA sits at the
    /// bottom of the SCREEN (mockup's `margin-top:auto`) without a fixed guess.
    @State private var viewportHeight: CGFloat = 0

    private var plan: BrainPlan { vm.makePlan() }
    private var servings: [PlanServing] { PlanServing.from(planned: vm.revealGoals) }
    private var doAnimate: Bool { !reduceMotion }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // 1 — Comeback headline.
                headline
                    .reveal(phase >= 1, index: 0, reduceMotion: reduceMotion)

                // 2 — The COMPACT reclaim strip. ⭐ 2026-07-22: this used to be a
                // 96pt serif numeral + a full promise line, a block so tall it
                // shoved the plan the user just EARNED off the bottom of the
                // screen. The reclaim is now one baseline-aligned line (serif
                // numeral + the promise, action in leaf) over a hairline, so the
                // card — the actual payoff — sits fully above the fold.
                reclaimStrip
                    .reveal(phase >= 1, index: 1, reduceMotion: reduceMotion)

                // 3 — The signature "Your BrainDiet" document (shareable artifact).
                // One gold flare sweeps the card as it materializes (Shot 13):
                // earned gold, once, then it settles to normal.
                PlanCard(plan: plan, servings: servings, animate: phase >= 2)
                    .overlay { GoldFlareSweep(trigger: phase >= 2) }
                    .reveal(phase >= 2, index: 0, reduceMotion: reduceMotion)
                    .padding(.top, 14)

                Spacer(minLength: Theme.Space.sm)

                // 4 — Primary CTA. (The projection footnote and the "what
                // changes" paragraph stay CUT from this step — they were the
                // rest of the reason the card ran off-screen.)
                BDPrimaryButton(title: "Take your life back") {
                    onComplete()
                }
                .reveal(phase >= 3, index: 0, reduceMotion: reduceMotion)

                // 5 — The share affordance, back on the reveal (2026-07-22).
                // The plan card IS the share artifact + ad prop and this is the
                // natural share moment, so cutting it entirely to win the fold
                // went too far. It returns COMPACT — a quiet secondary text
                // link under the CTA, reusing the same PlanShareButton →
                // PlanShareCard path (the shared artifact is unchanged), sized
                // so the whole screen still fits with zero scrolling.
                PlanShareButton(plan: plan, servings: servings)
                    .reveal(phase >= 3, index: 1, reduceMotion: reduceMotion)
                    .padding(.top, 2)
                    .id("revealBottom")
            }
            .frame(minHeight: viewportHeight, alignment: .top)
            .padding(.top, Theme.Space.md)
            .padding(.bottom, Theme.Space.md)
            // NOTE: OnboardingView already applies the horizontal screen inset
            // to this step's content, so we don't re-pad here.
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 - 2 * Theme.Space.md }
        // Bleed the cinematic background past the parent's horizontal inset.
        .background(RevealBackground(intensify: glow).padding(.horizontal, -Theme.Space.screenX))
        // Top scroll-edge treatment (Home's bottom fade, mirrored): scrolled
        // content dissolves into warm black under the status bar / Dynamic
        // Island instead of colliding with system UI raw. There's no nav bar on
        // this step, so the fade is explicit. Bled past the parent's inset.
        .overlay(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color.bdBackground, location: 0),
                    .init(color: Color.bdBackground, location: 0.55),
                    .init(color: Color.bdBackground.opacity(0), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            // 2026-07-22: shortened from 88 — the rebuilt step is a ONE-SCREEN
            // layout (nothing scrolls under the Island), and the taller fade
            // would have washed the eyebrow now that content sits higher.
            .frame(height: 52)
            .padding(.horizontal, -Theme.Space.screenX)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .task { await orchestrate() }
        #if DEBUG
        .onAppear {
            guard ProcessInfo.processInfo.environment["BD_SCROLL_BOTTOM"] == "1" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation { proxy.scrollTo("revealBottom", anchor: .bottom) }
            }
        }
        #endif
        }
    }

    // MARK: Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                // Leaf brand dot — semantic blue never leads a hero moment.
                Circle().fill(Color.bdLeaf).frame(width: 7, height: 7)
                Text("YOUR PLAN IS READY")
                    .font(BDFont.body(.bold, size: 10.5, relativeTo: .caption2))
                    .kerning(1.5)
                    .foregroundStyle(Color.bdLeafDeep)
            }
            Text("Take your\nlife back.")
                .font(BDFont.serif(size: 34, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Text(personalizedSubtext)
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
    }

    /// The subtext is now derived from the user's PRIMARY goal so the promise is
    /// personal ("Built to make you a reader." / "Built to get your project
    /// moving again."). Keyed on the same legacy goal ID as the identity phrasing
    /// used elsewhere (GoalCatalog.becameWishParts) so it never drifts.
    private var personalizedSubtext: String {
        switch vm.headlineGoalID {
        case "read":     return String(localized: "Built to make you a reader.")
        case "fitness":  return String(localized: "Built to make you someone who trains.")
        case "business": return String(localized: "Built to get your project moving again.")
        case "skill":    return String(localized: "Built to keep you getting better.")
        case "create":   return String(localized: "Built to get you making things again.")
        default:         return String(localized: "Built to point your time at what matters.")
        }
    }

    // MARK: The compact reclaim strip — the promise, on one line.

    private var reclaimStrip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(heroHours)")
                .font(BDFont.serif(size: 38, relativeTo: .largeTitle))
                .monospacedDigit()
                .foregroundStyle(Color.bdTextPrimary)
            Text(promiseLine)
                .font(BDFont.body(.semiBold, size: 13.5, relativeTo: .footnote))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bdCardBorder).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Every day you get back \(plan.reclaimedHours) hours for \(plan.goalNoun)")
    }

    /// "hours back a day — time to read" — the reclaim → redirect promise, the
    /// action in leaf. Singular/plural honest.
    private var promiseLine: AttributedString {
        var s = AttributedString(heroHours == 1 ? "hour back a day, " : "hours back a day, ")
        s.foregroundColor = Color.bdTextSecondary
        var goal = AttributedString("time to \(GoalCatalog.action(for: vm.headlineGoalID))")
        goal.foregroundColor = Color.bdLeaf
        goal.font = BDFont.body(.bold, size: 13.5, relativeTo: .footnote)
        s.append(goal)
        return s
    }

    // MARK: Orchestrated entrance — ONE cinematic moment.

    private func orchestrate() async {
        guard doAnimate else {
            phase = 3
            heroHours = plan.reclaimedHours
            glow = true
            return
        }
        // Headline + reframe in.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { phase = 1 }
        // The reclaimed number counts up with intent.
        withAnimation(.easeOut(duration: 1.1).delay(0.25)) { heroHours = plan.reclaimedHours }
        try? await Task.sleep(for: .milliseconds(620))
        // The label plates in — a soft impact as the cream card slides home.
        let plate = UIImpactFeedbackGenerator(style: .soft)
        plate.prepare()
        plate.impactOccurred(intensity: 0.7)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { phase = 2 }
        try? await Task.sleep(for: .milliseconds(520))
        // The rest settles + the warm glow blooms.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { phase = 3 }
        withAnimation(.easeInOut(duration: 1.2)) { glow = true }
    }
}

// MARK: - GoldFlareSweep — a single soft gold glint across the plan card.
//
// GOLD fires only on earned moments; the plan reveal is one. A diagonal band of
// warm gold light wipes across the card ONCE as it materializes, then the card
// settles to normal. Clipped to the card's printed-label radius. Honors Reduce
// Motion (no sweep at all).

private struct GoldFlareSweep: View {
    /// Flips true when the card reveals; the sweep fires once on that edge.
    let trigger: Bool

    @State private var sweep: CGFloat = -0.7   // band center, as a width fraction
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if visible {
                // True gold, softly — a near-white center blows out on cream,
                // so the peak stays at bdGold itself.
                LinearGradient(
                    colors: [.clear,
                             Color.bdGoldDeep.opacity(0.18),
                             Color.bdGold.opacity(0.30),
                             Color.bdGoldDeep.opacity(0.18),
                             .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.38, height: geo.size.height * 1.5)
                .rotationEffect(.degrees(14))
                .offset(x: sweep * geo.size.width, y: -geo.size.height * 0.25)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.label, style: .continuous))
        .onChange(of: trigger) { _, on in
            guard on else { return }
            fire()
        }
        .onAppear { if trigger { fire() } }
    }

    private func fire() {
        guard !visible, !reduceMotion, !UIAccessibility.isReduceTransparencyEnabled else { return }
        visible = true
        // Waits for the card to plate in, then one cinematic wipe — and gone.
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) { sweep = 1.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { visible = false }
    }
}

// MARK: - RevealBackground — cinematic warm-dark canvas (LOCAL to this proof).
//
// Visible emerald + gold bloom, layered for depth — NOT flat black. Honors
// Reduce Transparency (simpler warm fill). `intensify` swells the glow as the
// reveal settles.

private struct RevealBackground: View {
    var intensify: Bool

    var body: some View {
        // Uses the promoted app canvas; swells from standard → hero as it settles.
        ZStack {
            BDBackground(intensity: .standard, tint: .bdGold).opacity(intensify ? 0 : 1)
            BDBackground(intensity: .hero, tint: .bdGold).opacity(intensify ? 1 : 0)
        }
        .animation(.easeInOut(duration: 1.2), value: intensify)
    }
}

// MARK: - Reveal modifier (staggered slide-up + fade; clean fade on reduce-motion).

private extension View {
    func reveal(_ active: Bool, index: Int, reduceMotion: Bool) -> some View {
        modifier(RevealModifier(active: active, index: index, reduceMotion: reduceMotion))
    }
}

private struct RevealModifier: ViewModifier {
    let active: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(active ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: active)
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 24)
                .scaleEffect(active ? 1 : 0.98, anchor: .bottom)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.85).delay(0.05 * Double(index)),
                    value: active
                )
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.reading]
    vm.primaryDomain = .reading
    vm.timeLostHours = 3
    vm.aspiration = "I want to finally finish writing my book"
    return PlanRevealStepView(vm: vm, onComplete: {})
}
