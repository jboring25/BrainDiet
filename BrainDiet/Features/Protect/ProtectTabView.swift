import SwiftUI
import SwiftData

// MARK: - Reclaim (v1.0) — the core behavioral action, its own tab.
//
// "What do you want your reclaimed time to become right now?" Pick a plan step,
// pick a duration, tap Reclaim, and leave the phone. Flips between IDLE (the
// plan), ACTIVE (a calm lock screen), and COMPLETED (the quiet win moment).
//
// KEYSTONE: on start we persist a ProtectSession to SwiftData and keep the
// handle so an early end reconciles minutes to actual elapsed time.
//
// GATES (free tier = 1 goal + 1 session/day):
//   • starting a second session in a day without Pro presents the paywall
//   • non-primary goals are locked in the idle plan (ProtectIdleView)
//
// NOTIFICATIONS: permission is requested at the FIRST completed session (the
// win moment); the streak-save nudge is cancelled the moment a session starts.

struct ProtectTabView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(PlateEngine.self) private var plateEngine
    @Environment(BlockingService.self) private var blocking
    @Environment(StoreService.self) private var store
    @Environment(\.usageProvider) private var usageProvider

    @Query private var profiles: [UserProfile]
    /// The derived plan — the menu of goals + actionable steps (spec-v2.6).
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]
    /// All sessions — feeds the engine loop, the daily gate, and notifications.
    @Query private var sessions: [ProtectSession]

    @State private var vm = ProtectSessionViewModel()
    /// Pre-prompt priming sheet — shown before the FIRST system notification ask.
    @State private var showNotifPrimer = false
    /// The system app picker — the only way to change the block list.
    @State private var showPicker = false

    /// 1 Hz tick that drives the active countdown. Anchored to wall-clock in the VM.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var hasSessionToday: Bool {
        sessions.contains { Calendar.current.isDateInToday($0.startedAt) }
    }

    // MARK: Servings — each completed plan-tagged block is a serving of its goal.

    /// Today's servings: completed blocks tagged to any plan step.
    private var servingsToday: Int {
        sessions.filter { $0.stepID != nil && Calendar.current.isDateInToday($0.startedAt) }.count
    }

    /// The gentle daily rhythm: 3, or the plan's step count if smaller.
    private var servingTarget: Int {
        max(1, min(3, goals.reduce(0) { $0 + $1.steps.count }))
    }

    /// The plan's next step (primary goal first) for the daily nudge copy.
    private var nudgeStep: GoalStep? {
        (goals.first(where: \.isPrimary) ?? goals.first)?.orderedSteps.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground(intensity: .standard)

                switch vm.state {
                case .idle:
                    // ⭐ THE MENU TAB IS THE BLOCK LIST NOW (2026-08-26). The
                    // course list, the leader dots and the pinned CTA are gone;
                    // the servings live on Home. ProtectIdleView stays on disk
                    // unused until Home has absorbed everything it did.
                    BlockedAppsView { showPicker = true }
                        .transition(transition(reversed: false))
                case .active:
                    ProtectActiveView(vm: vm) {
                        vm.end(reduceMotion: reduceMotion)
                    }
                    .transition(transition(reversed: true))
                case .completed:
                    ProtectCompleteView(vm: vm) {
                        vm.acknowledgeCompletion(reduceMotion: reduceMotion)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(vm.state == .idle ? .automatic : .hidden, for: .navigationBar)
        }
        // A firm impact on commit; the completion moment fires its own soft
        // haptic; an early end returns to idle silently.
        .sensoryFeedback(trigger: vm.state) { old, new in
            if case (.idle, .active) = (old, new) { return .impact(weight: .medium) }
            return nil
        }
        .onReceive(ticker) { _ in vm.tick() }
        .onChange(of: vm.state) { old, new in
            if old == .active, new == .completed { handleCompletion() }
        }
        // Home's "Feed my brain" hand-off — apply the Plate Engine's suggested
        // serving (select the step, size the block) and start protection.
        .onChange(of: router.pendingServing) { _, new in
            if new != nil { applyPendingServing() }
        }
        .sheet(isPresented: $showPicker) {
            FamilyPickerView { selection in
                // Persist to the profile FIRST — the standing shield is re-armed
                // from `familySelectionData` on every launch (MainView), so a
                // selection that only lives in the service survives until the
                // next cold start and then silently disappears.
                blocking.updateSelection(selection)
                if let profile = profiles.first {
                    profile.familySelectionData = selection.encoded
                }
                blocking.applyStandingShield()
            }
        }
        .sheet(isPresented: $showNotifPrimer) {
            NotificationPrimerView(
                stepTitle: nudgeStep?.title ?? String(localized: "A block for your goal"),
                stepMinutes: nudgeStep?.suggestedMinutes ?? 25,
                onEnable: {
                    showNotifPrimer = false
                    Task {
                        let granted = await NotificationService.requestPermissionAfterFirstWin()
                        if granted { await refreshNudges() }
                    }
                },
                onNotNow: { showNotifPrimer = false }   // system ask NOT burned
            )
        }
        .onAppear {
            configure()
            preselectChefsPick()
        }
        .task {
            // Keep the two nudges honest on every visit: fresh next-step copy
            // (slop-voiced when today ran junk-heavy), and tonight's streak-save
            // only if no session has happened yet.
            await NotificationService.scheduleDailyPlanNudge(
                stepTitle: nudgeStep?.title ?? String(localized: "A block for your goal"),
                minutes: nudgeStep?.suggestedMinutes ?? 25
            )
            await NotificationService.refreshStreakSave(hasSessionToday: hasSessionToday)
            #if DEBUG
            if ProcessInfo.processInfo.environment["BD_SHOW_COMPLETE"] == "1" {
                vm.debugEnterCompleted()
            }
            // Screenshot helper: render the live ACTIVE session screen (no
            // persistence, no shield) — the previously unreachable state.
            if ProcessInfo.processInfo.environment["BD_SESSION_ACTIVE"] == "1" {
                if vm.selectedStepID == nil,
                   let goal = goals.first(where: \.isPrimary) ?? goals.first,
                   let step = goal.orderedSteps.first(where: { $0.kind == .recurring })
                                ?? goal.orderedSteps.first {
                    vm.selectStep(step, in: goal)
                }
                vm.debugEnterActive()
            }
            // Screenshot helper: force the notification pre-prompt primer.
            if ProcessInfo.processInfo.environment["BD_SHOW_NOTIF_PRIMER"] == "1" {
                showNotifPrimer = true
            }
            // Screenshot helper: move selection OFF the chef's pick (a second
            // goal's free first step) so the one-decision law is verifiable.
            // Never selects a depth-locked step — mirrors what a tap can reach.
            if ProcessInfo.processInfo.environment["BD_SELECT_STEP"] == "1",
               let goal = goals.first(where: { !$0.isPrimary }) ?? goals.first,
               let step = goal.orderedSteps.first {
                vm.selectStep(step, in: goal)
            }
            #endif

            // Cold-path hand-off: if Home queued a serving before this tab was
            // ever mounted, onChange never fires — apply it here instead.
            applyPendingServing()
        }
    }

    // MARK: Home's serving hand-off — picking a serving holds the table.

    private func applyPendingServing() {
        guard let serving = router.pendingServing else { return }
        // iOS 26 pre-mounts this tab: onChange(router.pendingServing) can fire
        // BEFORE onAppear has run configure(), leaving vm.persistSession nil —
        // start() would then silently skip persistence (ship-blocker, 2026-07-27).
        // Guarantee wiring before any start.
        if vm.persistSession == nil { configure() }
        router.pendingServing = nil
        if let stepID = serving.stepID,
           let goal = goals.first(where: { $0.id == serving.goalID }),
           let step = goal.orderedSteps.first(where: { $0.id == stepID }) {
            vm.selectStep(step, in: goal)
        } else if let activity = ActivityCatalog.activity(id: serving.activityID) {
            vm.selectActivity(activity)
            // Honor the serving's own minutes exactly (e.g. triage's 10-minute
            // version) — the serving carries an honest duration, don't round it.
            vm.selectedLength = SessionLength.exact(serving.minutes)
        }
        guard vm.state == .idle else { return }
        attemptStart()
    }

    // MARK: One decision law — Home's proposal arrives pre-selected (chef's pick).
    //
    // The Menu never re-asks the decision Home already made: the Plate Engine's
    // live suggestion lands selected; picking another row just moves selection.

    private func preselectChefsPick() {
        syncPlateEngine()
        guard vm.state == .idle, vm.selectedStepID == nil, vm.selectedStepTitle.isEmpty else { return }
        if let sug = plateEngine.suggestion, let stepID = sug.stepID,
           let goal = goals.first(where: { $0.id == sug.goalID }),
           let step = goal.orderedSteps.first(where: { $0.id == stepID }) {
            vm.selectStep(step, in: goal)
        } else if let goal = goals.first(where: \.isPrimary) ?? goals.first,
                  let step = goal.orderedSteps.first {
            // Suggestion isn't a selectable plan step (a catalog default) — the
            // primary goal's first step holds the table.
            vm.selectStep(step, in: goal)
        }
    }

    /// The Menu may be the first tab mounted — sync the engine from persisted
    /// truth so the chef's pick is live without a Home visit first.
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

    // MARK: Start — ungated (2026-08-26).
    //
    // The free tier used to allow ONE serving a day. That capped the exact
    // behaviour the app exists to produce: a user who wanted a second serving
    // was shown a paywall instead of a plate. Servings are unlimited.

    private func attemptStart() {
        NotificationService.cancelStreakSave()   // tonight's streak is safe
        vm.start(reduceMotion: reduceMotion)
    }

    // MARK: Completion — the win moment; ask for notifications HERE, not onboarding.
    //
    // The first ask is PRIMED: an in-app preview sheet fires before the one
    // system prompt, so the real ask only happens after an explicit yes.
    // "Not now" defers without burning it — a later win re-offers the primer.

    private func handleCompletion() {
        // Plate Engine FIRST (state commits before any visuals): sync from
        // persisted truth, then record the completed serving — Home plays the
        // queued celebration the moment it's visible.
        let ctx = EngineContext(profile: profiles.first, usage: usageProvider,
                                sessions: sessions)
        plateEngine.sync(
            goals: goals,
            sessions: sessions,
            junkMinutes: ctx.engine.todayMentalDiet?.minutes[.junk] ?? 0,
            junkAppCount: profiles.first?.junkAppIDs.count ?? 0
        )
        plateEngine.recordCompletion(
            activityID: vm.selectedActivity.id,
            stepID: vm.selectedStepID,
            minutes: vm.completedMinutes
        )

        if !NotificationService.didRequest {
            showNotifPrimer = true
            return
        }
        Task { await refreshNudges() }
    }

    /// Re-arms both nudges (each no-ops unless notifications are authorized).
    private func refreshNudges() async {
        await NotificationService.scheduleDailyPlanNudge(
            stepTitle: nudgeStep?.title ?? String(localized: "A block for your goal"),
            minutes: nudgeStep?.suggestedMinutes ?? 25
        )
        await NotificationService.refreshStreakSave(hasSessionToday: true)
    }

    // MARK: Wiring

    private func configure() {
        vm.configure(
            from: EngineContext(profile: profiles.first, usage: usageProvider,
                                sessions: sessions),
            blocking: blocking
        )
        // The keystone record: each Reclaim commit persists to SwiftData and is
        // handed back so an early end can reconcile to actual elapsed minutes.
        vm.persistSession = { activityID, minutes, startedAt, goalID, stepID in
            let session = ProtectSession(activityID: activityID, minutes: minutes,
                                         startedAt: startedAt, goalID: goalID, stepID: stepID)
            modelContext.insert(session)
            do {
                try modelContext.save()
                Log.app.info("ProtectSession recorded: \(activityID, privacy: .public) · \(minutes, privacy: .public)m")
            } catch {
                Log.app.error("ProtectSession save FAILED: \(error.localizedDescription, privacy: .public)")
            }
            return session
        }
        vm.saveContext = {
            do { try modelContext.save() }
            catch { Log.app.error("ProtectSession reconcile save FAILED: \(error.localizedDescription, privacy: .public)") }
        }
    }

    /// Idle slides from the leading edge, active rises in — one orchestrated flip.
    private func transition(reversed: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: reversed ? .bottom : .leading).combined(with: .opacity),
            removal: .opacity
        )
    }
}

#Preview {
    ProtectTabView()
        .modelContainer(for: [UserProfile.self, ProtectSession.self, Goal.self, GoalStep.self], inMemory: true)
        .environment(AppRouter())
        .environment(PlateEngine())
        .environment(BlockingService())
        .environment(StoreService())
}
