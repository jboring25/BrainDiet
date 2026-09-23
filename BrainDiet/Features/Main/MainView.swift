import SwiftUI
import SwiftData

// MARK: - Bottom tab skeleton (spec-v2.5: THREE surfaces by mindset).
//
// Home · Protect · Becoming — organized by the user's time-horizon, each tab
// answering ONE question. Protect is restored to its own tab: it's the core
// behavioral action (choose who to become right now), too important to bury on
// the dashboard. Settings/Plan are reached via the gear on Home, NOT a tab.
// Native, light-touch chrome — a quiet sage-tinted selected state, no heavy pill.

struct MainView: View {

    @Environment(AppRouter.self) private var router
    @Environment(PlateEngine.self) private var plateEngine
    @Environment(BlockingService.self) private var blocking
    @Environment(\.usageProvider) private var usageProvider
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ProtectSession]
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]

    /// DEBUG: auto-present the intercept preview at launch for clean screenshots.
    @State private var showIntercept = false
    private var forceIntercept: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BD_SHOW_INTERCEPT"] == "1"
        #else
        false
        #endif
    }

    /// Set once by onboarding completion; consumed here → the ONE dismissible
    /// post-plan-reveal paywall showing.
    @AppStorage("bd.pendingLaunchPaywall") private var pendingLaunchPaywall = false
    @State private var showPaywall = false

    /// The intercept copy, built from the user's real headline goal — today's
    /// junk minutes (slop-heavy days flip into slop-voice) and the plate's real
    /// serving counts (the possibility-voiced body speaks the plate's truth).
    private var interceptContent: ShieldContent {
        ShieldContentBuilder.make(
            goalID: profiles.first?.headlineGoalID,
            servingsDone: plateEngine.doneCount,
            servingsPlanned: plateEngine.planCount,
            suggestedCategory: plateEngine.suggestion?.category
        )
    }

    var body: some View {
        @Bindable var router = router
        // The mockup tab bar is a FLAT white bar with a hairline TOP border,
        // thin-line icons, sage selected state, and NO selection pill. The
        // iOS 26 Liquid Glass tab bar ignores UITabBarAppearance (floating
        // glass + selection bubble), so the system bar is hidden and BDTabBar
        // renders the mockup-exact chrome.
        // VStack (not safeAreaInset): a bottom safeAreaInset on TabView does NOT
        // propagate into the tab pages (their CTAs slid under the bar — verified
        // on-sim). Stacked, the pages end exactly at the bar's top edge.
        VStack(spacing: 0) {
            TabView(selection: $router.selectedTab) {
                HomeView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppRouter.Tab.home)

                ProtectTabView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppRouter.Tab.protect)

                BecomingView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(AppRouter.Tab.becoming)
            }

            BDTabBar(selection: $router.selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)   // the bar never rides the keyboard
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        // Sync the intercept's identity-framed copy into the App Group so the
        // gated ShieldConfiguration extension can render it at the fork. Keyed on
        // the rendered body + primary so a day going slop-heavy (or the plate
        // completing into dessert) re-syncs on next foreground.
        .task(id: interceptContent.headline + interceptContent.body + interceptContent.primary) {
            interceptContent.writeToAppGroup()
        }
        // ⭐ RE-ARM THE STANDING SHIELD (2026-08-13). `BlockingService` is
        // created fresh on every launch with an EMPTY selection — it holds the
        // tokens in memory only — so without this the app would come back after
        // a restart believing nothing was selected. ManagedSettings itself
        // persists the shield, but any later `applyStandingShield()` (say after
        // the user edits their apps) would then write an empty set and silently
        // unblock everything. Loading from the profile first is what keeps the
        // in-memory selection and the OS in agreement.
        .task(id: profiles.first?.familySelectionData) {
            guard let profile = profiles.first, profile.familySelectionData != nil else { return }
            blocking.loadSelection(encoded: profile.familySelectionData,
                                   mockIDs: profile.junkAppIDs)
            blocking.applyStandingShield()
            // ⭐ ARM THE USAGE METERS HERE TOO (2026-08-13). `armDailyCap` was
            // called from exactly ONE place — starting a protect session — so a
            // user who never ran a session generated NO DeviceActivity data at
            // all, and the mirror, the conversion card and the slop row would
            // have stayed empty forever while looking like a patient empty
            // state. Measurement must not depend on the user having already
            // done the thing we are trying to measure them doing instead.
            let ctx = EngineContext(profile: profile, usage: usageProvider, sessions: sessions)
            blocking.armDailyCap(minutes: ctx.plan.junkCapMinutes)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        // The route-by-why triage flow (2026-07-23) — entitlement-free, opened
        // from Home's "Reaching for a scroll?" card (and, in DEBUG, the
        // intercept). Every branch either starts the SAME live session or lets
        // the user pass cleanly.
        .fullScreenCover(isPresented: $router.showTriage) {
            TriageView(
                initialChoice: triageInitialChoice,
                onLetThrough: { router.showTriage = false },
                onServe: { short in
                    router.showTriage = false
                    startServingFromTriage(short: short)
                },
                onDismiss: { router.showTriage = false }
            )
        }
        .onAppear {
            #if DEBUG
            // Ad capture: never let a leftover queued paywall interrupt the shot.
            if AdMode.isEnabled { pendingLaunchPaywall = false }
            #endif
            if pendingLaunchPaywall {
                pendingLaunchPaywall = false
                showPaywall = true
            }
            #if DEBUG
            if forceIntercept {
                // The preview reads its plate + serving straight from the
                // engine — sync it BEFORE presenting so the launch shot shows
                // the real state, not an unsynced empty engine.
                syncPlateEngine()
                showIntercept = true
            }
            if ProcessInfo.processInfo.environment["BD_SHOW_PAYWALL"] == "1" {
                showPaywall = true
            }
            // Screenshot helper: land straight in the triage flow (BD_SHOW_TRIAGE),
            // optionally on a screen-2 branch (BD_TRIAGE_CHOICE=bored|anxious|habit).
            if ProcessInfo.processInfo.environment["BD_SHOW_TRIAGE"] == "1" {
                syncPlateEngine()
                router.showTriage = true
            }
            #endif
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showIntercept) {
            InterceptPreviewView(
                content: interceptContent,
                onResolve: { showIntercept = false },
                // Keep the intercept consistent with Home: its "Feed my brain"
                // routes into the SAME route-by-why triage flow (not a direct
                // session start). DEBUG surface, but one behavior.
                onProtect: {
                    showIntercept = false
                    DispatchQueue.main.async { router.showTriage = true }
                }
            )
        }
        #endif
    }

    /// DEBUG: which screen-2 branch to open the triage flow on (screenshots).
    private var triageInitialChoice: TriageChoice? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["BD_TRIAGE_CHOICE"] {
        case "bored":   return .bored
        case "anxious": return .anxious
        case "habit":   return .habit
        case "need":    return .need
        default:        return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: Loop stitching (critique ask #6) — the intercept's primary choice
    // lands in the SAME live session flow as Home's CTA and the Menu's Start:
    // queue the engine's serving, switch to the Menu tab, ProtectTabView
    // auto-starts it. Session → plate crossfade → Becoming, one visible thread.

    private func syncPlateEngine() {
        let ctx = EngineContext(profile: profiles.first, usage: usageProvider,
                                sessions: sessions)
        plateEngine.sync(
            goals: goals,
            sessions: sessions,
            junkMinutes: ctx.engine.todayMentalDiet?.minutes[.junk] ?? 0,
            junkAppCount: profiles.first?.junkAppIDs.count ?? 0
        )
    }

    /// The engine's ONE serving (or the primary goal's first step before a sync).
    private func engineServing() -> PlateServing? {
        if let s = plateEngine.suggestion { return s }
        if let goal = goals.first(where: \.isPrimary) ?? goals.first,
           let step = goal.orderedSteps.first,
           let domain = ActivityDomain(rawValue: goal.domain) {
            return PlateServing(
                id: step.id.uuidString, title: step.title, detail: goal.title,
                category: PlateEngine.category(forDomain: domain),
                minutes: step.suggestedMinutes,
                goalID: goal.id, stepID: step.id, activityID: domain.activityID)
        }
        return nil
    }

    private func startServingFromIntercept() {
        syncPlateEngine()
        if let serving = engineServing() { router.pendingServing = serving }
        router.selectedTab = .protect
    }

    /// Triage → the SAME live session. `short` (the habit branch's 10-minute
    /// version) re-sizes the same activity to a quick, honestly-labeled block.
    private func startServingFromTriage(short: Bool) {
        syncPlateEngine()
        if var serving = engineServing() {
            if short {
                serving = PlateServing(
                    id: serving.id, title: serving.title, detail: serving.detail,
                    category: serving.category, minutes: 10,
                    goalID: nil, stepID: nil, activityID: serving.activityID)
            }
            router.pendingServing = serving
        }
        router.selectedTab = .protect
    }
}

// MARK: - BDTabBar — the appetite tab bar (2026-07-18).
//
// Opaque WHITE bar (mockup `.tabs{background:var(--card)}`), 1pt hairline top
// border, Phosphor duotone 20pt icons + 11pt labels, leaf-deep selected /
// muted warm-gray normal. No pill, no glass, no shadow.

private struct BDTabBar: View {
    @Binding var selection: AppRouter.Tab

    var body: some View {
        // Appetite labels: Home · Menu · Becoming (Feed→Menu, Growth→Becoming,
        // 2026-07-18). The mounted screens are unchanged — tab identity only.
        HStack(spacing: 0) {
            item(.home, "Home", .record)
            item(.protect, "Menu", .forkKnife)
            item(.becoming, "Becoming", .plant)
        }
        .padding(.top, 10)
        .padding(.horizontal, Theme.Space.sm)
        .background(
            Color.bdSurface
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.bdCardBorder).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ tab: AppRouter.Tab, _ title: LocalizedStringKey, _ icon: BDPh) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                BDPhIcon(icon: icon, size: 20,
                         color: selection == tab ? Color.bdLeafDeep : Color.bdTabMuted)
                Text(title)
                    .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
            }
            .foregroundStyle(selection == tab ? Color.bdLeafDeep : Color.bdTabMuted)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
    }
}

#Preview {
    MainView()
        .environment(AppRouter())
        .environment(PlateEngine())
        .environment(BlockingService())
        .environment(StoreService())
        .modelContainer(for: [UserProfile.self, ProtectSession.self, Goal.self, GoalStep.self], inMemory: true)
}
