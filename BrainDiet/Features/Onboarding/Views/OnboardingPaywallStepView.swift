import SwiftUI

// MARK: - Step: in-onboarding Pro paywall — STORY CAROUSEL + a pinned offer.
//
// ⭐ REBUILT 2026-08-11 from Jack's own Opal screenshots: "their onboarding
// tells a story and has a deep talk to you one on one, with barely any text and
// all visuals and feeling." Ours said everything true and said all of it in
// prose — serif headline, a three-row text timeline, two text price rows, a
// two-line billing paragraph. One screenshot of each side settled it.
//
// Now: five swipeable STORY pages above (see `PaywallStoryPages.swift`) with
// the offer PINNED underneath the whole time.
//
// ⭐ WHY THIS ISN'T THE 3-PAGE PAGER WE DELETED IN JULY. That pager was a GATE —
// three screens standing between the user and the offer, which is why it went.
// Here the price, the plan rows and the CTA are on screen from the first frame
// and never move; the pages are an argument you can keep reading or ignore, and
// you can buy at any point in it. Swiping is optional, and the dots say so.
// Same transparency wedge, no gate.
//
// The trial timeline moved OUT of the always-on layout and became page 5. It
// was the single biggest block of text on the screen, and as a page it earns
// its space instead of pushing the offer below the fold.
//
// 7-DAY FREE TRIAL (Jack 2026-07-22): the offer is now a 7-day free trial of
// Pro, kept honest — the timeline names the pre-charge reminder (Day 5, which
// the slide-16 chooser schedules) so there's no surprise charge. Skipping via
// "Not now" still drops to the real free tier (one goal, one session a day).
//
// ⭐ NEUTRAL CTA (Jack, 2026-07-22): the primary button reads "Continue" in
// EVERY state — it never presumes the trial. It acts on whichever plan row is
// SELECTED (annual → trial when eligible, monthly → direct subscribe) through
// the same purchase path. The trial timeline and the trial-bearing billing line
// render only while a trial-bearing selection is active, and both update live
// when the user switches rows.
//
// TRANSPARENCY WEDGE: soft close always reachable (top X + quiet "Not now"),
// the free tier is the honest fallback, no fake timer, no pre-checked upsell.
// Purchase + restore reuse PaywallViewModel / StoreService — NO duplicated
// logic. Purchase-success and every skip path call onComplete(startedTrial:) —
// the cancel-reminder step (dinnerBell) runs ONLY when that Bool is true;
// onboarding then finishes on the first-serving payoff.
//
// ⭐ TRIAL COPY IS GATED ON REAL ELIGIBILITY (2026-07-22): every trial element
// — the "7 days free" badge, the Today/Day 5/Day 7 timeline, the CTA, and the
// billing line — renders ONLY when `StoreService.hasFreeTrial(.annual)` is true
// (StoreKit's `isEligibleForIntroOffer`). A RETURNING user who already used
// their trial gets the non-trial paywall: value rows, "Unlock BrainDiet Pro",
// "$39.99/year, billed today." StoreKit will not grant a second trial, so
// promising one would be a false promise. The free tier stays the fallback in
// both variants.
//
// DEBUG keys: BD_PAYWALL_PAGE is accepted but inert (the pager collapsed to
// one screen); BD_PAYWALL_SKIP_SHEET=1 still lands on the skip sheet;
// BD_TRIAL_INELIGIBLE=1 forces the returning-user (no-trial) variant.

struct OnboardingPaywallStepView: View {
    @Bindable var vm: OnboardingViewModel
    /// Purchase-success OR skip both land here (OnboardingView advances).
    /// The Bool = "this user actually STARTED A FREE TRIAL" — true only for a
    /// successful purchase of the trial-bearing annual plan while eligible.
    /// Monthly purchases, restores, "Not now", and every dismissal pass false,
    /// so the cancel-reminder step is skipped (never a false promise).
    let onComplete: (_ startedTrial: Bool) -> Void

    @Environment(StoreService.self) private var store

    @State private var pvm = PaywallViewModel()
    /// Which story page is showing. Starts on the personalised projection.
    @State private var page = 0
    private static let pageCount = 5

    // Skip → free-tier handoff: ONE warm sheet, once. Dismissing the sheet
    // itself still completes — never a trap.
    @State private var showSkipSheet = Self.forceSkipSheet
    @State private var skipSheetSeen = Self.forceSkipSheet
    @State private var returnToPaywall = false

    /// ⭐ SOFT PAYWALL (Jack approved 2026-10-09): the close X and "Not now"
    /// fade in after 4 seconds, so the offer is read once before the exit is
    /// the loudest thing on screen. Restore never hides. Starts true for the
    /// DEBUG skip-sheet seam so that capture is unchanged.
    @State private var exitsVisible = Self.forceSkipSheet
    static let exitDelay: Duration = .seconds(4)

    /// DEBUG screenshot seam: BD_PAYWALL_SKIP_SHEET=1 lands on the skip sheet.
    private static var forceSkipSheet: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BD_PAYWALL_SKIP_SHEET"] == "1"
        #else
        false
        #endif
    }

    // MARK: Personalization (reuses the reveal's derived figures)

    /// Whole reclaimed hours/day the deterministic plan returns.
    private var reclaimedHours: Int { vm.makePlan().reclaimedHours }
    /// The primary domain, lower-cased ("reading", "fitness"), for the headline.
    private var primaryWord: String {
        ((vm.primaryDomain ?? vm.selectedDomains.first)?.label ?? "what matters").lowercased()
    }

    /// ⭐ V3 (Jack approved 2026-10-09): the headline is THEIR goal, in their
    /// words. "Launch BrainDiet on the App Store and get 100 users" →
    /// "Launch BrainDiet on the App Store.\nKeep the time it needs."
    private var headline: String {
        let domain = vm.primaryDomain ?? vm.selectedDomains.first
        guard let domain, let clause = Self.firstClause(GoalSentenceText.display(vm.goalWords[domain] ?? "")) else {
            return personalizedHeadline
        }
        return clause + "\n" + String(localized: "Keep the time it needs.")
    }

    /// The first clause of their goal: split on " and ", ",", " then ", capped
    /// near 40 characters at a word boundary, capitalised, one period.
    static func firstClause(_ words: String) -> String? {
        var t = words.trimmingCharacters(in: .whitespacesAndNewlines)
        for sep in [",", " and ", " then ", ";", " & "] {
            if let r = t.range(of: sep, options: .caseInsensitive) { t = String(t[..<r.lowerBound]) }
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if t.count > 40 {
            var out = ""
            for w in t.split(separator: " ") {
                let next = out.isEmpty ? String(w) : out + " " + w
                if next.count > 40 { break }
                out = next
            }
            t = out.isEmpty ? String(t.prefix(40)) : out
        }
        guard t.count >= 3 else { return nil }
        return t.prefix(1).uppercased() + t.dropFirst() + "."
    }

    /// The pre-v3 headline: the fallback when there are no goal words.
    private var personalizedHeadline: String {
        guard reclaimedHours > 0 else {
            return String(localized: "Keep your reclaimed time pointed at \(primaryWord).")
        }
        let unit = reclaimedHours == 1 ? String(localized: "hour") : String(localized: "hours")
        return String(localized: "Keep your \(reclaimedHours) \(unit) a day pointed at \(primaryWord).")
    }

    /// Their STATED baseline in minutes — the honest "today" end of the curve.
    /// Falls back to the same default the scrubber uses for "I don't know".
    private var baselineMinutes: Int { (vm.timeLostHours ?? 3) * 60 }

    /// Chosen domains, primary first — the plan page shows what they picked,
    /// never a stock set.
    private var orderedDomains: [ActivityDomain] {
        guard let primary = vm.primaryDomain else { return vm.selectedDomains }
        return [primary] + vm.selectedDomains.filter { $0 != primary }
    }

    /// True only when the CURRENTLY SELECTED plan really carries a free trial.
    /// Every trial element on this screen (timeline, and the trial-bearing
    /// billing line via PaywallViewModel) keys off this — never off eligibility
    /// alone, because a LIFETIME selection gets no trial either way: a one-time
    /// purchase cannot carry an introductory offer.
    private var trialSelected: Bool { pvm.trialEligible && pvm.selectedPlan.isRecurring }

    var body: some View {
        VStack(spacing: 0) {
            header

            storyCarousel

            // Everything below is PINNED. The offer and the transparency wedge
            // are never something you have to swipe or scroll to reach.
            planSelector
                .padding(.top, Theme.Space.sm)
            transparentBilling
                .padding(.top, Theme.Space.sm)
            proofRow
                .padding(.top, Theme.Space.sm)
            ctaBlock
                .padding(.top, Theme.Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The skip sheet's scrim: the paywall itself softens to a blur behind
        // it (never a flat gray wash).
        .blur(radius: showSkipSheet ? 10 : 0)
        .animation(Theme.Motion.smooth, value: showSkipSheet)
        // Products + REAL intro-offer eligibility before any trial word renders.
        .task {
            try? await Task.sleep(for: Self.exitDelay)
            withAnimation(.easeOut(duration: 0.5)) { exitsVisible = true }
        }
        .task {
            await pvm.syncOffer(using: store)
            #if DEBUG
            // Screenshot seam: BD_PAYWALL_PLAN=weekly|lifetime pre-selects a row
            // so the billing line / timeline swap can be captured.
            switch ProcessInfo.processInfo.environment["BD_PAYWALL_PLAN"] {
            case "weekly":   pvm.selectedPlan = .weekly
            case "lifetime": pvm.selectedPlan = .lifetime
            default: break
            }
            // ⭐ BD_PAYWALL_PAGE is LIVE AGAIN (2026-08-11). It went inert when
            // the pager collapsed to one screen in July; the story carousel
            // brings pages back, and every one of them has to be screenshot-
            // verifiable or four fifths of this surface goes unreviewed.
            if let raw = ProcessInfo.processInfo.environment["BD_PAYWALL_PAGE"],
               let wanted = Int(raw), (0..<Self.pageCount).contains(wanted) {
                page = wanted
            }
            #endif
        }
        .sheet(isPresented: $showSkipSheet, onDismiss: {
            if returnToPaywall {
                returnToPaywall = false
            } else {
                // "Start free" AND a plain swipe-down both continue — never trap.
                onComplete(false)
            }
        }) {
            FreeTierHandoffSheet(
                onStartFree: { showSkipSheet = false },
                onSeePro: { returnToPaywall = true; showSkipSheet = false }
            )
        }
        .alert(
            "Something didn't go through",
            isPresented: Binding(
                get: { pvm.errorMessage != nil },
                set: { if !$0 { pvm.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { pvm.errorMessage = nil }
        } message: {
            Text(pvm.errorMessage ?? "")
        }
    }

    // MARK: Header — brand + an always-reachable close.

    private var header: some View {
        HStack {
            BrandWordmark(tone: .onDark, size: 13)
            Spacer()
            // ⭐ 2026-07-22 UX audit: the glyph's frame had no contentShape, so
            // only the small "X" itself was hittable, and it sat tight against
            // the status area — an easy mis-tap. Now a real 44×44 target (the
            // glyph is unchanged) with breathing room under the top edge.
            Button(action: skip) {
                Image(systemName: "xmark")
                    .font(.bdBodyStrong)
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .opacity(exitsVisible ? 1 : 0)
            .allowsHitTesting(exitsVisible)
            .accessibilityHidden(!exitsVisible)
        }
        .padding(.top, Theme.Space.md)
    }

    // MARK: The story — five pages, swipeable, never a gate.

    private var storyCarousel: some View {
        VStack(spacing: 8) {
            TabView(selection: $page) {
                // Page 1 leads with the user's OWN headline + their own curve —
                // the personalised line is the proven converter and it stays the
                // first thing read.
                PaywallProjectionPage(title: headline,
                                      baselineMinutes: baselineMinutes)
                    .tag(0)
                PaywallPlanPage(domains: orderedDomains).tag(1)
                PaywallProtectPage().tag(2)
                PaywallComebackPage().tag(3)
                // Trial framing ONLY when the CURRENT selection really carries a
                // trial (annual + StoreKit-eligible) — never for a monthly
                // selection or a returning account that already used it.
                PaywallTimelinePage(trialSelected: trialSelected).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Our own dots: the system's are white-on-white here, and these also
            // have to read as "there is more, optionally" rather than "you are
            // trapped in a flow" — hence no arrows and no forced order.
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.bdLeafDeep : Color.bdCardBorder)
                        .frame(width: i == page ? 7 : 6, height: i == page ? 7 : 6)
                }
            }
            .animation(Theme.Motion.snappy, value: page)
            .accessibilityHidden(true)
        }
    }

    // MARK: Price block + transparency wedge.

    private var planSelector: some View {
        VStack(spacing: Theme.Space.sm) {
            ForEach(PaywallPlan.allCases) { plan in
                PlanOptionRow(plan: plan, isSelected: pvm.selectedPlan == plan,
                              showsTrial: pvm.trialEligible) {
                    withAnimation(Theme.Motion.snappy) { pvm.selectedPlan = plan }
                }
            }
        }
    }

    private var transparentBilling: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("No surprises. Ever.")
                .font(BDFont.body(.medium, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
            Text(pvm.transparentBillingLine)
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Honest proof (2026-10-09) — three checkable lines, nothing invented.

    private var proofRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            proofLine(String(localized: "Built on habit research (Lally 2010, Gollwitzer 2006)"))
            proofLine(String(localized: "Made by an ASU student who had the problem"))
            proofLine(String(localized: "No account. No ads."))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func proofLine(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.bdLeaf.opacity(0.7))
                .accessibilityHidden(true)
            Text(text)
                .font(BDFont.body(.medium, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: CTA + the quiet free path.

    private var ctaBlock: some View {
        VStack(spacing: Theme.Space.xs) {
            // ⭐ NEUTRAL CTA (Jack, 2026-07-22): the button never presumes the
            // trial — it acts on whichever row is SELECTED (annual, with the
            // trial when eligible, or monthly), same purchase path as before.
            BDPrimaryButton(
                title: LocalizedStringResource("Continue"),
                trailingSymbol: "chevron.right",
                isEnabled: !pvm.isPurchasing
            ) {
                let startsTrial = trialSelected
                Task { await pvm.purchase(using: store) { onComplete(startsTrial) } }
            }

            // The quiet free path + Restore, one calm row under the CTA.
            HStack(spacing: Theme.Space.lg) {
                Group {
                    Button(action: skip) {
                        Text("Not now")
                            .font(.bdCaption)
                            .foregroundStyle(Color.bdTextSecondary)
                            .frame(minHeight: Theme.Size.minTouch)
                    }
                    .buttonStyle(.plain)

                    Text("·")
                        .font(.bdCaption)
                        .foregroundStyle(Color.bdTextSecondary.opacity(0.5))
                }
                .opacity(exitsVisible ? 1 : 0)
                .allowsHitTesting(exitsVisible)
                .accessibilityHidden(!exitsVisible)

                Button {
                    // A restore is never a NEW trial — no cancel-reminder step.
                    Task { await pvm.restore(using: store) { isPro in if isPro { onComplete(false) } } }
                } label: {
                    Text(pvm.isRestoring ? "Restoring…" : "Restore Purchases")
                        .font(.bdCaption)
                        .foregroundStyle(Color.bdTextSecondary)
                        .frame(minHeight: Theme.Size.minTouch)
                }
                .buttonStyle(.plain)
                .disabled(pvm.isRestoring)
            }
            .frame(maxWidth: .infinity)
            // (No extra "cancel anytime" caption — the pinned billing line
            // above already says it; one honest sentence, once.)
        }
        .padding(.bottom, Theme.Space.sm)
    }

    /// Skip ("Start free" / X): the FIRST skip offers the warm free-tier
    /// handoff sheet once; any later skip — or dismissing the sheet — continues.
    private func skip() {
        guard !skipSheetSeen else { onComplete(false); return }
        skipSheetSeen = true
        showSkipSheet = true
    }
}

// MARK: - FreeTierHandoffSheet — the warm skip → free-tier handoff (shown once).
//
// TRANSPARENCY WEDGE: no discount, no countdown, no guilt. Skipping is a real,
// named, permanent option — the sheet just makes the free tier feel like a
// doorway instead of a dead end. Every dismissal path continues onboarding.

private struct FreeTierHandoffSheet: View {
    let onStartFree: () -> Void
    let onSeePro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Start free.")
                .font(BDFont.display(.semiBold, size: 30, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)

            Text("Every goal's first step, one session a day. Yours forever. Upgrade whenever you're ready.")
                .font(.bdBody)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Space.md)

            BDPrimaryButton(title: "Start free", action: onStartFree)

            Button(action: onSeePro) {
                Text("See plans again")
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.bottom, Theme.Space.sm)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Color.bdSurface)
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.reading, .fitness]
    vm.primaryDomain = .reading
    vm.timeLostHours = 3
    vm.aspiration = "Finish my book"
    return ZStack {
        BDBackground(intensity: .standard)
        OnboardingPaywallStepView(vm: vm, onComplete: { _ in })
            .padding(.horizontal, Theme.Space.screenX)
            .environment(StoreService())
    }
}
