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
    @Environment(StoreService.self) private var store
    @Environment(\.usageProvider) private var usageProvider
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ProtectSession]
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]

    @Environment(\.scenePhase) private var scenePhase
    /// "I did it" on the lock: fed into Home once the cover is gone, so the
    /// user lands on the brain and watches it eat (the drag's own path).
    @State private var lockFeed: PlateDraggable?

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
            domains: shieldDomains,
            servingsDone: plateEngine.doneCount,
            servingsPlanned: plateEngine.planCount,
            suggestedCategory: plateEngine.suggestion?.category,
            customLines: profiles.first?.shieldLines ?? [:],
            reasonLines: profiles.first?.reasonShieldLines ?? [:]
        )
    }

    /// Home's one focus, computed the same way, for the shield and the face.
    private var shieldFocus: TodaysFocus? {
        let dayStart = Calendar.current.startOfDay(for: .now)
        return TodaysFocus.pick(goals: goals,
                                doneToday: Set(sessions.lazy.filter { $0.startedAt >= dayStart }.compactMap(\.stepID)),
                                everDone: Set(sessions.compactMap(\.stepID)),
                                skips: MenuExposure.skips(sessions: sessions))
    }

    /// ⭐ ONE GOAL (the moonshot, 2026-10-10): the shield speaks only it. A
    /// legacy multi-goal profile rotates nothing either: its primary is the moonshot.
    private var shieldDomains: [ActivityDomain] {
        guard let profile = profiles.first else { return [] }
        guard let primary = profile.primaryDomain ?? profile.domains.first else { return [] }
        return [primary]
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
        .task(id: interceptContent.variants.map(\.headline).joined()
                  + interceptContent.headline + interceptContent.body + interceptContent.primary) {
            interceptContent.writeToAppGroup()
            // New words only show once the shield is re-applied; iOS keeps
            // drawing the old configuration otherwise.
            if blocking.hasSelection {
                blocking.clearStandingShield()
                blocking.applyStandingShield()
            }
        }
        // ⭐ RE-ARM THE STANDING SHIELD (2026-08-13). `BlockingService` is
        // created fresh on every launch with an EMPTY selection — it holds the
        // tokens in memory only — so without this the app would come back after
        // a restart believing nothing was selected. ManagedSettings itself
        // persists the shield, but any later `applyStandingShield()` (say after
        // the user edits their apps) would then write an empty set and silently
        // unblock everything. Loading from the profile first is what keeps the
        // in-memory selection and the OS in agreement.
        // Keyed on the schedule and the allow-list too (2026-10-08): changing
        // either on the Menu re-arms the window activities and hands the
        // monitor the new answer, the same way a new app selection does.
        .task(id: blockingKey) {
            // Hard paywall: nothing stays blocked without a subscription.
            if store.hasCheckedEntitlement && !store.isEntitled {
                blocking.releaseForNoSubscription()
                return
            }
            guard let profile = profiles.first else { return }
            blocking.loadAllowList(encoded: profile.allowSelectionData)
            guard profile.familySelectionData != nil else {
                blocking.setFeedWindow(profile.feedWindow)
                return
            }
            blocking.loadSelection(encoded: profile.familySelectionData,
                                   mockIDs: profile.junkAppIDs)
            // Selection first: the monitor needs both, and this also puts the
            // shield in the state the window says (down outside it).
            blocking.setFeedWindow(profile.feedWindow)
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
        // ⭐ DO IT NOW (2026-10-08). Hosted here, not on Home, so a lock that
        // is still running (or ran out unanswered) reopens on any launch.
        .fullScreenCover(isPresented: Binding(get: { blocking.doItNow != nil },
                                              set: { _ in }),
                         onDismiss: feedAfterLock) {
            if let session = blocking.doItNow {
                DoItNowLockView(
                    session: session,
                    onDidIt: {
                        lockFeed = draggable(for: session)
                        blocking.endDoItNow()
                    },
                    onNotYet: { blocking.endDoItNow() },
                    onExpire: { blocking.expireDoItNowIfNeeded() },
                    // Releases the lock + the one-off DeviceActivity; feeds nothing.
                    onEndEarly: { blocking.endDoItNow() })
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // A lock started from the shield while we were away.
            blocking.reloadDoItNow()
            blocking.expireDoItNowIfNeeded()
            if blocking.doItNow == nil, FaceRequest.takePending() { router.showFace = true }
        }
        .onAppear {
            if blocking.doItNow == nil, FaceRequest.takePending() { router.showFace = true }
        }
        // ⭐ "Go to BrainDiet" from a shield (Jack, 2026-10-12).
        .fullScreenCover(isPresented: $router.showFace) {
            if let p = profiles.first { InYourFaceView(profile: p, focus: shieldFocus) }
        }
        // What the shield's "Feed my brain" starts: the same step Home offers.
        .task(id: shieldFocus.map { "\($0.step.id)\($0.step.suggestedMinutes)" } ?? "none") {
            ShieldNextStep(focus: shieldFocus).write()
        }
        .fullScreenCover(isPresented: $router.showFinishLine) {
            if let p = profiles.first { FinishLineView(profile: p) }
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
            #endif
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showIntercept) {
            InterceptPreviewView(
                content: interceptContent,
                onResolve: { showIntercept = false },
                onProtect: { showIntercept = false }
            )
        }
        #endif
    }

    // MARK: Blocking sync (feed schedule + Do it now allow-list)

    /// Everything the standing shield, the window activities and the lock read
    /// from the profile. Any change re-runs the sync task.
    private var blockingKey: String {
        guard let p = profiles.first else { return "" }
        return [String(p.familySelectionData?.hashValue ?? 0), p.feedScheduleRaw,
                String(p.feedCustomStart), String(p.feedCustomEnd), p.feedCustomWeekdaysRaw,
                String(p.allowSelectionData?.hashValue ?? 0),
                String(p.firstHourBlock), String(p.wakeMinutes),
                String(store.hasCheckedEntitlement), String(store.isEntitled)].joined(separator: "|")
    }

    /// The serving "I did it" reports: the same shape the focus card's drag
    /// builds, so the brain, the toast and the session are identical.
    private func draggable(for s: DoItNowSession) -> PlateDraggable {
        let domain = ActivityDomain(rawValue: s.domainRaw)
        return PlateDraggable(title: s.title, subtitle: "",
                              activityID: domain?.activityID ?? s.domainRaw,
                              goalID: s.goalID, stepID: s.stepID,
                              minutes: s.minutes, icon: .leaf,
                              tint: domain?.tint ?? .bdLeaf, ink: .bdTextPrimary)
    }

    private func feedAfterLock() {
        guard let item = lockFeed else { return }
        lockFeed = nil
        router.selectedTab = .home
        router.pendingReport = item
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
}

// MARK: - BDTabBar — the appetite tab bar (2026-07-18).
//
// Opaque WHITE bar (mockup `.tabs{background:var(--card)}`), 1pt hairline top
// border, Phosphor duotone 20pt icons + 11pt labels, leaf-deep selected /
// muted warm-gray normal. No pill, no glass, no shadow.

private struct BDTabBar: View {
    @Binding var selection: AppRouter.Tab

    var body: some View {
        // Home · Blocking · Becoming (Menu → Blocking 2026-10-13, the food pass).
        HStack(spacing: 0) {
            item(.home, "Home", .record)
            item(.protect, "Blocking", .shieldCheck)
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
