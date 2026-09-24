import SwiftUI
import SwiftData

// MARK: - Paywall — real StoreKit 2 purchase/restore (v1.0).
//
// Wedge: RADICAL TRANSPARENCY. The #1 complaint about competitors is
// subscription resentment / surprise charges — so honesty is a visible FEATURE
// here, not fine print. No dark patterns: clear X, no fake timers, no
// pre-checked upsells, Restore always present. Voice = take-back-your-life.
//
// Display price lives in PaywallPricing (kept in sync with the store products);
// purchase/restore go through StoreService (StoreKit 2).
//
// ─────────────────────────────────────────────────────────────────────────
// REBUILT 2026-07-30 from the category paywall study
// (design/paywall-study/index.html — real Opal + Forest screens via Mobbin).
// Four evidenced changes, each answering a specific gap the study exposed:
//
//  1. OPEN ON THE USER'S OWN DATA, NOT FEATURES. Opal's paywall opens on the
//     viewer's own screen-time chart + a personal promise ("gain 2+ Hours
//     back") before any feature. Self-relevant information is attended to and
//     recalled more strongly (self-reference effect). We already compute
//     `plan.reclaimedHours` + `goalNoun` at plan reveal and were throwing it
//     away here. Now it's the headline.
//  2. SELL THE PLATE, NOT A FEATURE LIST. Every competitor paywall sells
//     RESTRICTION (block harder, buy minutes). The old screen sold a 4-line
//     feature list — the only screen in the app with no plate, no serving and
//     no becoming-language, which is why it read off-brand. The free/Pro gap
//     is now shown AS the plate: one serving vs the full plate. This is the
//     Attraction Law (show what you could have; never make junk ugly) and it
//     makes the gap concrete rather than abstract.
//  3. DE-RISK THE TRIAL EXPLICITLY, AND LEAD WITH $0.00. Opal spends a whole
//     screen on what happens during the trial and its CTA is literally "Try
//     for $0.00" with the annual figure in small print. Surprise auto-charge
//     is the #1 one-star driver in this category (Opal's own biggest wound).
//     Our cancel reminder is the direct counter and was invisible here.
//  4. CARRY PROOF — HONESTLY. Opal transfers trust with 100k reviews, press
//     logos and an Apple award. We have none of that at launch and inventing
//     any of it is banned. Our real, checkable proof is the privacy posture
//     and a free tier that never expires.
//
// Also removed: "Most people find a couple of hours a day quietly come back to
// them." — an invented outcome claim with no data behind it (honesty law).
// ─────────────────────────────────────────────────────────────────────────

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(StoreService.self) private var store
    @Environment(\.usageProvider) private var usageProvider

    @Query private var profiles: [UserProfile]

    @State private var vm = PaywallViewModel()
    @State private var revealed = false

    /// The user's own plan — the source of the personalized hero (finding 1).
    private var plan: BrainPlan {
        EngineContext(profile: profiles.first, usage: usageProvider).plan
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground(intensity: .standard)   // v2: flat — type + restraint carry it

                // ONE SCREEN. Nothing that matters lives below a scroll
                // (Jack, 2026-07-30). The container only becomes scrollable if
                // the content genuinely cannot fit — accessibility text sizes
                // or a very small device — via `.scrollBounceBehavior
                // (.basedOnSize)`, so it never bounces or hides content for a
                // normal user but also never clips for someone who needs
                // larger type.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                            .reveal(revealed, index: 0, reduceMotion: reduceMotion)

                        Spacer(minLength: Theme.Space.md)

                        trialTimeline
                            .reveal(revealed, index: 1, reduceMotion: reduceMotion)

                        Spacer(minLength: Theme.Space.md)

                        planSelector
                            .reveal(revealed, index: 2, reduceMotion: reduceMotion)

                        Spacer(minLength: Theme.Space.sm)

                        ctaBlock
                            .reveal(revealed, index: 3, reduceMotion: reduceMotion)

                        footer
                            .reveal(revealed, index: 4, reduceMotion: reduceMotion)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.top, Theme.Space.xs)
                    .padding(.bottom, Theme.Space.md)
                    .frame(maxWidth: .infinity, minHeight: screenContentHeight, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Clearly reachable close — never hidden.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.bdBodyStrong)
                            .foregroundStyle(Color.bdTextSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion { revealed = true }
            else { withAnimation { revealed = true } }
        }
        // Products + REAL intro-offer eligibility before any trial word renders.
        .task {
            await vm.syncOffer(using: store)
            #if DEBUG
            // Screenshot seam, same contract as OnboardingPaywallStepView:
            // BD_PAYWALL_PLAN=weekly|lifetime pre-selects a row so the billing
            // line and timeline swap can actually be reviewed. Without it the
            // lifetime copy ships unseen — and "nothing renews" is exactly the
            // sentence that must not be wrong.
            switch ProcessInfo.processInfo.environment["BD_PAYWALL_PLAN"] {
            case "weekly":   vm.selectedPlan = .weekly
            case "lifetime": vm.selectedPlan = .lifetime
            default: break
            }
            #endif
        }
        .alert(
            "Something didn't go through",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: Hero

    /// FINDING 1 — the viewer's OWN number and OWN goal, on the plate.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm) {
                BrandWordmark(tone: .onDark, size: 13)
                Text("PRO")
                    .font(.bdEyebrow)
                    .kerning(3)
                    .foregroundStyle(Color.bdAccentDeep)
            }

            // The plate is the brand's one living object. It belongs on the
            // screen that asks for money more than anywhere else.
            BDPlateMark(nourishment: 1, steaming: true)
                .frame(width: 124)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Text(personalHeadline)
                .font(BDFont.serif(size: 27, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Target height for the one-screen layout — the visible area minus the
    /// nav/toolbar and safe insets. Content is laid out to fill this exactly,
    /// so nothing important ever sits below the fold.
    private var screenContentHeight: CGFloat {
        let screen = UIScreen.main.bounds.height
        return max(500, screen - 210)
    }

    /// "Your 2 hours a day, fully fed." — their reclaim, their goal. Falls back
    /// cleanly when the plan has no reclaim figure yet (day zero / no data).
    private var personalHeadline: String {
        let hours = plan.reclaimedHours
        guard hours > 0 else {
            return String(localized: "Your day, fully fed.")
        }
        let unit = hours == 1 ? String(localized: "hour") : String(localized: "hours")
        return String(localized: "Your \(hours) \(unit) a day, fully fed.")
    }

    // MARK: The trial timeline — the Opal progression pattern, our voice

    /// A vertical progression rail down the left, one row per day that matters.
    /// Opal devotes a whole screen to this ("Design Your Trial Experience":
    /// today → day 6 → day 7) and it is the most-copied pattern in high-
    /// performing subscription paywalls, because the biggest friction on a free
    /// trial is not price, it is UNCERTAINTY about what happens and when the
    /// charge lands. Naming the days removes that uncertainty, and it lets us
    /// put our single strongest honesty asset — the reminder BEFORE the charge —
    /// in the middle of the sell instead of hiding it in settings.
    ///
    /// Replaced the Free/Pro comparison boxes (Jack, 2026-07-30): they were the
    /// bulk of the scroll and were text doing a job that feeling should do.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ⭐ A ONE-TIME PURCHASE HAS NO TRIAL RAIL (2026-09-23). Lifetime
            // never renews and carries no introductory offer, so a Today →
            // Day 2 → Day 3 countdown would be describing days that do not
            // exist for it. It gets the one row that IS true.
            if vm.selectedPlan.isRecurring {
                timelineRow(
                    marker: "leaf.fill",
                    title: "Today",
                    line: "Your whole plate unlocks.",
                    filled: true, isLast: false
                )
                timelineRow(
                    marker: "bell.fill",
                    title: "Day \(PaywallPricing.trialDays - 1)",
                    line: "We remind you. No surprises.",
                    filled: true, isLast: false
                )
                timelineRow(
                    marker: "checkmark",
                    title: "Day \(PaywallPricing.trialDays)",
                    line: trialEndLine,
                    filled: false, isLast: true
                )
            } else {
                timelineRow(
                    marker: "leaf.fill",
                    title: "Today",
                    line: "Your whole plate unlocks.",
                    filled: true, isLast: false
                )
                timelineRow(
                    marker: "checkmark",
                    title: "Forever",
                    line: trialEndLine,
                    filled: true, isLast: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Honest and exact: the real charge, on the real day, for the real plan.
    /// Lifetime has no trial and no recurrence, so it gets no "trial ends" line.
    private var trialEndLine: String {
        guard vm.selectedPlan.isRecurring else {
            return String(localized: "\(PaywallPricing.lifetimeDisplay) once. Nothing renews.")
        }
        return String(localized: "Trial ends. \(PaywallPricing.weeklyDisplay) a week.")
    }

    private func timelineRow(marker: String, title: LocalizedStringResource,
                             line: String, filled: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            // The rail: dot + connecting line (the progression bar).
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(filled ? Color.bdAccentDeep : Color.bdLeafTint)
                        .frame(width: 26, height: 26)
                    Image(systemName: marker)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(filled ? Color.white : Color.bdAccentDeep)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.bdAccentDeep.opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BDFont.body(.semiBold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                Text(line)
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Theme.Space.md)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Plan selector

    private var planSelector: some View {
        VStack(spacing: Theme.Space.sm) {
            ForEach(PaywallPlan.allCases) { plan in
                PlanOptionRow(plan: plan, isSelected: vm.selectedPlan == plan,
                              showsTrial: vm.trialEligible) {
                    withAnimation(Theme.Motion.snappy) { vm.selectedPlan = plan }
                }
            }
        }
    }

    // (The old standalone `transparentBilling` block was removed in the 2026-07-30
    // rebuild — its billing line now sits directly under the CTA, and the honesty
    // it carried is stated up front in `trialAssurance` instead of mid-scroll.)

    // MARK: CTA

    // MARK: CTA

    private var ctaBlock: some View {
        VStack(spacing: Theme.Space.sm) {
            // FINDING 3 — the CTA carries $0.00, not the price (Opal: "Try for
            // $0.00"). Trial wording still renders ONLY when StoreKit would
            // really grant the trial.
            BDPrimaryButton(
                // The CTA states what THIS tap does. Lifetime charges today and
                // has no trial, so it must never read "start N days free".
                title: !vm.selectedPlan.isRecurring
                    ? LocalizedStringResource("Buy once — \(PaywallPricing.lifetimeDisplay)")
                    : (vm.trialEligible
                        ? LocalizedStringResource("Start \(PaywallPricing.trialDays) days for \(PaywallPricing.freeDisplay)")
                        : LocalizedStringResource("Unlock BrainDiet")),
                trailingSymbol: "chevron.right",
                isEnabled: !vm.isPurchasing
            ) {
                Task { await vm.purchase(using: store) { dismiss() } }
            }

            // The price lives here, under the CTA — visible and honest, but no
            // longer the largest number on the screen.
            Text(vm.transparentBillingLine)
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Footer

    private var footer: some View {
        // Compact single row — the screen does not scroll, so Restore and the
        // legal links MUST fit on it. Apple requires working Terms + Privacy
        // links on a subscription paywall; unreachable links = rejection.
        VStack(spacing: Theme.Space.xs) {
            Button {
                Task {
                    await vm.restore(using: store) { isPro in
                        if isPro { dismiss() }
                    }
                }
            } label: {
                Text(vm.isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(minHeight: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
            .disabled(vm.isRestoring)

            HStack(spacing: Theme.Space.lg) {
                // Terms = Apple's standard EULA (we supply no custom terms);
                // Privacy = our hosted policy. Both MUST resolve — App Review
                // taps these on any subscription paywall.
                legalLink("Terms", "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                legalLink("Privacy", "https://braindiet.netlify.app/privacy-policy.html")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legalLink(_ title: LocalizedStringResource, _ urlString: String) -> some View {
        Button {
            // NOTE: these URLs must be LIVE before App Store submission.
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            Text(title)
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .frame(minHeight: Theme.Size.minTouch)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Staggered reveal (fade on reduce-motion).

private extension View {
    func reveal(_ active: Bool, index: Int, reduceMotion: Bool) -> some View {
        modifier(PaywallReveal(active: active, index: index, reduceMotion: reduceMotion))
    }
}

private struct PaywallReveal: ViewModifier {
    let active: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 16)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.85).delay(0.06 * Double(index)),
                    value: active
                )
        }
    }
}

#Preview { PaywallView().environment(StoreService()) }
