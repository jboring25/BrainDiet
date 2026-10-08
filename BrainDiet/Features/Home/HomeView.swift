import SwiftUI
import SwiftData

// MARK: - Home (vision v2) — "What should I feed my brain next?"
//
// The Bible's HOME charter (§7): the plate dominates (hero + live steam), one
// qualitative state line (time-of-day honest, last word sage), one ingredient
// line (time→meaning), ONE serving card with the app's single primary CTA
// ("Feed my brain"), the Today's Plate card, one quiet protection line.
// Nothing else. No score, no stats, no charts.
//
// EVERY read comes from the Plate Engine (PLATE-ENGINE.md) — Home computes no
// recommendation or state of its own. Ground truth for layout/values:
// design/vision-v2/screens-final.src.html (the mockup SOURCE, never prose).

struct HomeView: View {

    @Environment(AppRouter.self) private var router
    @Environment(PlateEngine.self) private var plate
    @Environment(BlockingService.self) private var blocking
    @Environment(\.usageProvider) private var usageProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ProtectSession]
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]

    /// DEBUG seam (2026-08-06): `BD_OPEN_ADJUST=1` opens Settings on appear so
    /// the screenshot harness can reach the sheets behind it (see
    /// SettingsView's matching seam).
    @State private var showSettings = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_OPEN_ADJUST"] != nil
        #else
        return false
        #endif
    }()

    /// The onboarding gate (BrainDietApp) — SetPlateCard's route back into
    /// setup when Home is somehow reached with no profile (honesty law: no
    /// engine default may pose as the user's plan).
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    /// The open-choreography clock.
    @State private var phase: HomeRevealPhase = .initial
    /// The celebration beat (Bible §5): bounce + toast, state already committed.
    @State private var plateBounce = false
    @State private var toast: PlateCelebration?
    /// The daily-win signature window — which beat is currently playing over the
    /// plate (see `PlateWin`). `nil` = at rest.
    @State private var win: PlateWin?
    /// Was the meal ALREADY whole when this beat arrived? `doneCount` is clamped
    /// to `planCount`, so a serving past the meal does not move completeness at
    /// all — "it was already 1.0 before this landed" is the only thing that
    /// separates the bonus serving from the one that completed the plate.
    @State private var mealWasComplete = false

    // ⭐ SELF-REPORT PLATING (2026-08-20). See Features/Home/PlateDrop.swift.
    @Environment(\.modelContext) private var modelContext
    @State private var drop = PlateDropController()
    @State private var heroDropPoint: CGPoint?
    @State private var focusCardCentre: CGPoint = .zero
    @State private var showReportSheet = false
    /// One Home-wide coordinate space so the plate rect and the drag translation
    /// are measured against the same origin.
    private static let space = "homePlate"

    // Mockup rhythm (scoped to Home): 18pt screen margins, 10pt between cards.
    private enum Metrics {
        static let screenX: CGFloat = 18
        static let cardGap: CGFloat = 10
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                BDBackground(intensity: .standard)

                // ⭐ THE HEADER IS PINNED (Jack, 2026-08-05: "There is no
                // settings"). It used to be the first row INSIDE the scroll
                // body, so the wordmark and the settings gear scrolled away the
                // instant the user moved — and Home opens with a full-bleed
                // plate, so on a real device the gear was gone before it was
                // ever seen. Settings is the only door to the plan, categories,
                // restore, privacy and now Replay onboarding; it cannot be
                // something you have to scroll back up to find.
                // ⭐ ONE LAYER, NO OVERLAP (Jack, 2026-08-07 — device screenshot:
                // the top of the hero bowl was sliced off). The pin above was
                // implemented as an OVERLAY — the header floated at zIndex 2
                // with an opaque cream fill while the ScrollView still began at
                // the very top of the ZStack. So the hero scrolled UNDERNEATH
                // it and the header's own background painted over the rim.
                //
                // Header and scroll are SIBLINGS in a VStack now. The header is
                // still outside the ScrollView, so it cannot scroll away and the
                // gear stays reachable (which is the whole point of the pin) —
                // but the content starts BELOW it, so nothing is ever occluded.
                // Do not reintroduce zIndex or an opaque background here; both
                // only mattered because things were stacked.
                // ⭐ THE SOFT TOP EDGE (Jack, 2026-08-13): "a harsh border that
                // cuts off everything else... Opal has a semi transparent border
                // that has the title and settings on it but slowly fades the
                // stuff it is covering."
                //
                // ⛔️ `.scrollEdgeEffectStyle(.soft, for: .top)` DID NOT WORK
                // here — tried first, and the screenshot showed the wordmark
                // colliding with the goals card with no fade at all. It renders
                // for the bottom edge in this same view but not the top, inside
                // a ZStack that paints its own background.
                //
                // So the fade is explicit: the header carries a gradient that is
                // OPAQUE at the status bar (where the wordmark has to stay
                // legible) and CLEAR at its bottom edge, over an ultra-thin
                // material. Content scrolling up dissolves into it instead of
                // meeting a line. `safeAreaInset` still reserves the space, so
                // nothing is occluded at rest — the 2026-08-07 sliced-bowl bug
                // came from an overlay, and this is not one.
                Group {
                    ScrollViewReader { proxy in
                    ScrollView {
                    VStack(spacing: Metrics.cardGap) {

                        // The plate hero + headline + ingredient line — all
                        // engine reads. Nourishment = meal completeness; the
                        // serve bounce scales the whole hero (1.0→1.02→1.0).
                        hero
                        // The "Served." capsule rides ON the plate (demo source:
                        // `#toast{ top:188px }` sits over the hero stage — the
                        // celebration and its caption belong to the same object).
                        .overlay {
                            if let toast {
                                ServeToast(celebration: toast)
                                    .allowsHitTesting(false)
                                    .transition(.opacity.combined(with: .offset(y: 14)))
                            }
                        }

                        // ⭐ THE THREE NUMBERS (Jack, 2026-09-13). Two reset at
                        // midnight, one never does — see DayStatsRow.
                        DayStatsRow(fedWeek: week.fed,
                                    protectedWeek: week.minutes,
                                    daysToWired: wired.days,
                                    wiredHabit: wired.habit,
                                    fedToday: plate.doneCount,
                                    protectedToday: plate.protectedMinutesToday)
                            .padding(.top, 2)
                            .stageIn(phase.atLeastMeaning)

                        // The drag lesson only while there is nothing plated —
                        // it stops the moment it is no longer needed.
                        // (The "drag anything you've done into your brain" line was
                        // removed 2026-10-08: the card itself now says it moves.)

                        if let focus {
                            TodaysFocusCard(
                                title: focus.step.title,
                                cue: focus.step.cue,
                                minutes: focus.step.suggestedMinutes,
                                reason: focus.reason,
                                symbol: focus.domain.symbol,
                                tint: focus.domain.tint,
                                onSelfReport: { reportFocus(focus) },
                                onTimer: { startFocus(focus) },
                                onDragChanged: { value in
                                    if !drop.isDragging {
                                        drop.begin(focusDraggable(focus), rowID: focus.step.id, origin: focusCardCentre == .zero ? value.startLocation : focusCardCentre)
                                    }
                                    drop.update(value)
                                },
                                onDragEnded: {
                                    if let landed = drop.end() {
                                        UserDefaults.standard.set(true, forKey: "bd.hasFedByDrag")
                                        dropReport(landed)
                                    }
                                },
                                isLifted: drop.isDragging && drop.liftedRowID == focus.step.id)
                                .background(GeometryReader { g in
                                    Color.clear
                                        .onAppear { focusCardCentre = CGPoint(x: g.frame(in: .named(Self.space)).midX, y: g.frame(in: .named(Self.space)).midY) }
                                        .onChange(of: g.frame(in: .named(Self.space))) { _, f in focusCardCentre = CGPoint(x: f.midX, y: f.midY) }
                                })
                                .stageIn(phase.atLeastMeaning)
                        }

                        // With NO profile there is no real plan — the engine's
                        // catalog defaults are planner scaffolding, never "your
                        // serving." Honest setup prompt instead (honesty law).
                        if profiles.isEmpty {
                            SetPlateCard { hasCompletedOnboarding = false }
                                .stageIn(phase.atLeastMeaning)
                        } else {
                            // ⭐ THE DREAMS (Jack, 2026-08-11). "Always reminded
                            // of your goals" was simply false — Home showed one
                            // engine-picked serving and none of them. The goals
                            // card ABSORBS the serving card when the suggestion
                            // is one of the user's own steps (the usual case):
                            // running both printed the identical step twice, 200
                            // pt apart. The serving card survives for the cases
                            // the plan can't cover — dessert, catalog defaults,
                            // plate complete — where there is no row to raise.
                            // Never print the same step twice: the focus card above
                            // already carries it (Jack's screenshot, 2026-10-08).
                            if (goalRows.isEmpty || suggestedGoalStepID == nil),
                               plate.suggestion?.title != focus?.step.title {
                                TodaysServingCard(
                                    serving: plate.suggestion,
                                    onFeed: feedMyBrain,
                                    onNotNow: { plate.decline() }
                                )
                                .stageIn(phase.atLeastMeaning)
                            }

                            if !goalRows.isEmpty {
                                goalsCard
                                    .stageIn(phase.atLeastMeaning)
                            }

                            // Route-by-why entry (2026-07-23) — the entitlement-
                            // free path: tap before you scroll, we ask why, hand
                            // you the matched response. Sits right under the
                            // serving so it's visible for every real user.
                            TriageEntryCard { router.showTriage = true }
                                .stageIn(phase.atLeastMeaning)
                        }

                        // ⛔️ TODAY'S PLATE REMOVED (Jack, 2026-08-18).
                        //
                        // It rendered the same component Becoming's "Where they
                        // went" now uses — category chip, slim category bar,
                        // tabular minutes right — just scoped to today instead
                        // of the month. Home was keeping score, which is
                        // Becoming's job, and the duplication only became
                        // obvious once Becoming was rebuilt around exactly that
                        // row.
                        //
                        // Home now answers ONE question: what now. Hero → your
                        // goals → protection status.
                        //
                        // The honest cost did NOT disappear with it: the shield
                        // carries it in the moment, `protectionLine` names the
                        // apps off the menu below, and Becoming's trade bar
                        // shows the unconverted remainder ("15h unclaimed") for
                        // the month. The one thing genuinely gone is a per-day
                        // empty-calories read, which was a scorecard nobody
                        // asked for on the screen you open to decide something.
                        // (`TodaysPlateCard.swift` was deleted 2026-09-09 —
                        // dead files are not a precedent, they are a trap.)

                        protectionLine
                            .stageIn(phase.atLeastMeaning)
                            .id("homeBottom")
                    }
                    .padding(.horizontal, Metrics.screenX)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
                .onPreferenceChange(PlateRectKey.self) { drop.plateRect = $0 }
                .onPreferenceChange(CultureRectKey.self) { drop.cultureRect = $0 }
                .safeAreaInset(edge: .top, spacing: 0) {
                    headerRow
                        .padding(.horizontal, Metrics.screenX)
                        // Runway for the fade to finish BELOW the wordmark.
                        .padding(.bottom, 24)
                        .background {
                            // Material first (blurs whatever slides under it),
                            // then the cream gradient that dissolves downward.
                            // The gradient is what kills the hard line; the
                            // material is what keeps the wordmark readable over
                            // a moving plate render.
                            LinearGradient(
                                stops: [
                                    .init(color: Color.bdBackground, location: 0),
                                    .init(color: Color.bdBackground, location: 0.78),
                                    .init(color: Color.bdBackground.opacity(0), location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                            .background(.ultraThinMaterial)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0),
                                        .init(color: .black, location: 0.8),
                                        .init(color: .black.opacity(0), location: 1)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .ignoresSafeArea(edges: .top)
                        }
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .contentMargins(.bottom, Theme.Space.lg, for: .scrollContent)
                #if DEBUG
                .onAppear {
                    guard ProcessInfo.processInfo.environment["BD_SCROLL_BOTTOM"] == "1" else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { proxy.scrollTo("homeBottom", anchor: .bottom) }
                    }
                }
                #endif
                }
                }
            }
            // ⭐ The lifted card lives ABOVE the ScrollView so it is never clipped
            // by the scroll bounds and never scrolls with the content it left.
            .overlay(alignment: .topLeading) {
                if let item = drop.payload {
                    let m = drop.morph
                    let s = CultureCloudGeometry.transform(in: drop.cultureRect.size).a
                    ZStack {
                        PlateDragCard(item: item, near: drop.isOverPlate)
                            .frame(width: 292)
                            .scaleEffect(1 - 0.9 * m)
                            .opacity(Double(max(0, 1 - m * 1.5)))
                            .blur(radius: m * 5)
                        ServingBall(radius: max(4, 17 * s))
                            .opacity(Double(max(0, min(1, (m - 0.3) / 0.45))))
                            .scaleEffect(0.5 + 0.5 * m)
                    }
                        .position(x: drop.cardOrigin.x + drop.translation.width,
                                  y: drop.cardOrigin.y + drop.translation.height)
                        .rotationEffect(.degrees(tiltDegrees * Double(1 - drop.morph)), anchor: .center)
                        // NO animation on the offset: the card must track the
                        // finger frame-for-frame. Any easing here reads as lag,
                        // which is the single most common way a drag feels cheap.
                        .animation(.easeOut(duration: 0.18), value: drop.isOverPlate)
                        .transition(.identity)
                        .allowsHitTesting(false)
                        .zIndex(50)
                }
            }
            .coordinateSpace(name: Self.space)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showReportSheet) {
                ReportSomethingSheet(planActivityIDs: goalRows.map(\.domain.activityID),
                                     onReport: report(_:))
            }
        }
        .task {
            syncPlate()
            await runOpenChoreography()
            #if DEBUG
            await runDemoCompleteIfRequested()
            #endif
        }
        .onAppear {
            syncPlate()
            // Seed the tier baseline BEFORE playing anything: without this, a
            // relaunch onto an already-complete plate would read the next bonus
            // serving as the one that completed the meal and fire the full
            // signature a second time.
            mealWasComplete = plate.completeness >= 1
            playCelebrationIfPending()
            consumePendingReport()
            #if DEBUG
            // Screenshot helper: the Settings sheet (previously unreachable).
            if ProcessInfo.processInfo.environment["BD_SHOW_SETTINGS"] == "1" {
                showSettings = true
            }
            #endif
        }
        .onChange(of: sessions.count) { syncPlate() }
        .onChange(of: goals.count) { syncPlate() }
        .onChange(of: scenePhase) { _, new in
            if new == .active {
                syncPlate()
                // Screen Time access can be granted or revoked in Settings while
                // we are suspended, so the mirrored mode has to be re-pulled on
                // every return or the whole app renders a stale authorization.
                blocking.refreshMode()
            }
        }
        // A completion elsewhere (the protection flow) queues the beat; Home
        // plays it the moment it's visible. State committed FIRST, always.
        .onChange(of: plate.celebration) { _, new in
            if new != nil { playCelebrationIfPending() }
        }
        // ⭐ The Menu sets `pendingReport` and switches tabs in the same gesture.
        // Consuming it on tab arrival (not on set) is what makes the user LAND on
        // the brain and then watch the serving travel in — fire it early and the
        // whole animation happens on a screen they are no longer looking at.
        .onChange(of: router.selectedTab) { _, tab in
            guard tab == .home, router.pendingReport != nil else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                consumePendingReport()
            }
        }
    }

    // MARK: Engine sync — views @Query → engine (event-driven, never in body).

    private func syncPlate() {
        let ctx = EngineContext(profile: profiles.first, usage: usageProvider,
                                sessions: sessions)
        plate.sync(
            goals: goals,
            sessions: sessions,
            junkMinutes: ctx.engine.todayMentalDiet?.minutes[.junk] ?? 0,
            junkAppCount: profiles.first?.junkAppIDs.count ?? 0
        )
    }

    // MARK: The dreams card
    //
    // Extracted for the same reason as `hero`: the argument list plus the
    // ScrollView body exceeded the type-checker's budget when inlined.

    private var goalsCard: some View {
        YourGoalsCard(
            identityLine: dreamLine,
            rows: goalRows,
            suggestedStepID: suggestedGoalStepID,
            ctaTitle: plate.suggestion?.category.ctaTitle ?? "",
            drop: drop,
            onReport: dropReport(_:),
            onAddSomething: { showReportSheet = true },
            onStart: start,
            onFeed: feedMyBrain,
            onNotNow: { plate.decline() }
        )
    }

    // MARK: The hero
    //
    // Extracted to its own property: inlined with the drop-target chain the
    // ScrollView body stopped type-checking in reasonable time.

    private var hero: some View {
        HomeHeroView(
            headline: plate.headline(),
            secondary: Text(""),
            nourishment: plate.completeness,
            phase: phase,
            dropPoint: heroDropPoint,
            win: win,
            // One session = one thing the user actually reported. Seventy fills
            // the brain, which is the same arc the mockups were tuned against.
            growth: {
                #if DEBUG
                // ios-sim-review jump: BD_BRAIN_GROWTH=0…1 forces hero density so
                // the mature brain can be reviewed without seeding 70 sessions.
                if let raw = ProcessInfo.processInfo.environment["BD_BRAIN_GROWTH"],
                   let v = Double(raw) { return min(1, max(0, v)) }
                #endif
                return min(1, Double(sessions.count) / 70)
            }()
        )
        // No contact shadow: Culture is not resting on a surface. The plate's
        // shadow read as a smudge under a floating cloud.
        .reportsPlateRect(in: .named(Self.space))
        .scaleEffect(plateBounce ? 1.02 : 1.0)
        .animation(Theme.Motion.plate, value: plateBounce)
    }

    /// Momentum tilt, clamped — spec: `clamp(dx × 0.02, ±2°)`.
    private var tiltDegrees: Double {
        guard drop.isDragging else { return 0 }
        return max(-2, min(2, Double(drop.translation.width) * 0.02)) - (drop.isOverPlate ? 0.8 : 0)
    }

    // MARK: - Self-report — a serving that already happened, dropped on the plate.
    //
    // Same terminal state as a completed session, deliberately: the plate should
    // not care how the work got done. What differs is one stored field
    // (`source: .reported`), which is what stops Becoming from presenting a
    // user's word as a measurement. See ProtectSession.swift for the reasoning.

    /// The rolling seven-day window — the number is never granted and never
    /// wiped, it only ever measures what was done. See DayStatsRow.
    private var week: (fed: Int, minutes: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -6,
                                           to: Calendar.current.startOfDay(for: .now)) ?? .now
        let recent = sessions.filter { $0.startedAt >= cutoff }
        return (recent.count, recent.reduce(0) { $0 + $1.minutes })
    }

    /// Points currently drawn INSIDE the brain — the same figure the hero draws,
    /// so the number and the picture can never disagree.
    /// Days left until the main habit is automatic: 66 (Lally et al., 2010)
    /// minus the distinct days the user did their most-practised goal.
    private var wired: (days: Int, habit: String) {
        let cal = Calendar.current
        var byGoal: [UUID: Set<Date>] = [:]
        for s in sessions { if let g = s.goalID { byGoal[g, default: []].insert(cal.startOfDay(for: s.startedAt)) } }
        let top = byGoal.max { $0.value.count < $1.value.count }
        let goal = goals.first { $0.id == top?.key } ?? goals.first
        let domain = goal.flatMap { ActivityDomain(rawValue: $0.domain) }
        let habit = domain?.label.lowercased() ?? "your habit"
        return (max(0, 66 - (top?.value.count ?? 0)), habit)
    }

    private func focusDraggable(_ f: TodaysFocus) -> PlateDraggable {
        PlateDraggable(title: f.step.title, subtitle: f.step.cue,
                       activityID: f.domain.activityID,
                       goalID: f.goal.id, stepID: f.step.id,
                       minutes: f.step.suggestedMinutes,
                       icon: .leaf, tint: f.domain.tint, ink: .bdTextPrimary)
    }

    /// A drag that landed: the brain feeds at the drop spot, then the report runs.
    private func dropReport(_ item: PlateDraggable) {
        heroDropPoint = drop.lastDrop
        report(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { heroDropPoint = nil }
    }

    /// The one thing, ranked. Recomputed as sessions land so it never offers
    /// something already done.
    private var focus: TodaysFocus? {
        TodaysFocus.pick(goals: goals, doneToday: completedStepIDsToday,
                         everDone: Set(sessions.compactMap(\.stepID)),
                         skips: MenuExposure.skips(sessions: sessions))
    }

    /// The Menu hands a serving over rather than reporting it itself, so the
    /// celebration and the brain-feed fire on the screen the brain is on.
    private func consumePendingReport() {
        guard let item = router.pendingReport else { return }
        router.pendingReport = nil
        report(item)
    }

    private func reportFocus(_ f: TodaysFocus) {
        report(PlateDraggable(title: f.step.title, subtitle: f.step.cue,
                              activityID: f.domain.activityID,
                              goalID: f.goal.id, stepID: f.step.id,
                              minutes: f.step.suggestedMinutes,
                              icon: .leaf, tint: f.domain.tint, ink: .bdTextPrimary))
    }

    private func startFocus(_ f: TodaysFocus) {
        guard let serving = PlateEngine.serving(for: f.step, in: f.goal) else { return }
        start(serving)
    }

    private func report(_ item: PlateDraggable) {
        let session = ProtectSession(activityID: item.activityID,
                                     minutes: item.minutes,
                                     goalID: item.goalID,
                                     stepID: item.stepID,
                                     source: .reported)
        modelContext.insert(session)
        do { try modelContext.save() }
        catch { Log.app.error("Reported serving save FAILED: \(error.localizedDescription, privacy: .public)") }

        // Fold it into today's plate through the SAME path a finished session
        // takes, so the ramp, the celebration and the toast are identical.
        plate.recordCompletion(activityID: item.activityID,
                               stepID: item.stepID,
                               minutes: item.minutes)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Log.app.info("Serving REPORTED: \(item.activityID, privacy: .public) · \(item.minutes, privacy: .public)m")
    }

    // MARK: The one CTA — start the protection flow for the suggested serving.

    private func feedMyBrain() {
        guard let serving = plate.suggestion else { return }
        start(serving)
    }

    /// Start a specific goal's next step (a goals-card row) — the same route the
    /// primary CTA takes, so a row is a real action and not a link to one.
    private func start(_ row: YourGoalsCard.Row) {
        guard let step = row.step,
              let serving = PlateEngine.serving(for: step, in: row.goal) else { return }
        start(serving)
    }

    private func start(_ serving: PlateServing) {
        router.pendingServing = serving
        withAnimation(Theme.Motion.smooth) { router.selectedTab = .protect }
    }

    // MARK: The dreams — the committed sentence + each goal's next step.

    /// The sentence the user plated at onboarding. Falls back to the primary
    /// goal's identity line, then to any goal's — never to invented copy, and
    /// the card is hidden entirely when there are no goals to speak for.
    private var dreamLine: String {
        let stated = (profiles.first?.planIdentityLine ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stated.isEmpty { return stated }
        let primary = goals.first(where: \.isPrimary) ?? goals.first
        return primary?.identityLine ?? ""
    }

    /// Steps already served TODAY — so a goal shows tomorrow's move, not one the
    /// user has already made. Read from sessions, the same record Becoming
    /// counts, so Home can never disagree with the mirror about what happened.
    private var completedStepIDsToday: Set<UUID> {
        let dayStart = Calendar.current.startOfDay(for: .now)
        return Set(sessions.lazy
            .filter { $0.startedAt >= dayStart }
            .compactMap(\.stepID))
    }

    /// The engine's suggestion, but ONLY when it is a step the goals card is
    /// already showing — that row gets raised and carries the CTA. Nil when the
    /// suggestion is dessert or a catalog default (no row to raise), which is
    /// exactly when the standalone serving card is still needed.
    private var suggestedGoalStepID: UUID? {
        guard let stepID = plate.suggestion?.stepID else { return nil }
        return goalRows.contains { $0.step?.id == stepID } ? stepID : nil
    }

    /// One row per goal, carrying its next unserved step (nil = done today).
    private var goalRows: [YourGoalsCard.Row] {
        let done = completedStepIDsToday
        return goals
            .sorted { ($0.isPrimary ? 0 : 1, $0.sortIndex) < ($1.isPrimary ? 0 : 1, $1.sortIndex) }
            .compactMap { goal in
                guard let domain = ActivityDomain(rawValue: goal.domain) else { return nil }
                return YourGoalsCard.Row(
                    goal: goal,
                    domain: domain,
                    step: goal.orderedSteps.first { !done.contains($0.id) }
                )
            }
    }

    // MARK: Ingredient line — time is an ingredient, never the reward.

    private var ingredientLine: Text {
        if plate.doneCount == 0 {
            // ⭐ THE CAPTION SLOT TEACHES THE DRAG (2026-08-20).
            //
            // Self-report needed an affordance and every added one was worse: a
            // grab-handle fights the minutes column that already owns the row's
            // right edge, and a ring on a 34pt chip just reads as a chip border.
            // This line already sits under the hero and is already the first
            // thing read after it, so it does the teaching with ZERO new chrome —
            // and it reverts to the plain greeting the moment anything has been
            // plated, which is exactly when the lesson stops being needed.
            return reduceMotion
                ? plain("\(greeting) · first serving ready when you are")
                : plain("\(greeting) · drag anything you've done into your brain")
        }
        let time = goldTime(BDMealTray.display(plate.protectedMinutesToday))
        if plate.completeness >= 1 {
            return time + plain(String(localized: " protected · the kitchen is closed. Go live."))
        }
        return time + plain(String(localized: " protected · enough for one more serving"))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        default:      return String(localized: "Good evening")
        }
    }

    private func goldTime(_ s: String) -> Text {
        Text(s)
            .font(BDFont.body(.bold, size: 13.5, relativeTo: .subheadline))
            .foregroundColor(Color.bdGoldAccent)   // display gold — bold + short (accepted exception)
    }

    private func plain(_ s: String) -> Text {
        Text(s)
            .font(BDFont.body(.semiBold, size: 13.5, relativeTo: .subheadline))
            .foregroundColor(Color.bdTextSecondary)
    }

    // MARK: The quiet protection line — pulse dot + one honest sentence.

    private var protectionLine: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.bdSageFill)
                .frame(width: 7, height: 7)
                .background(Circle().fill(Color.bdSageSoft).frame(width: 13, height: 13))
            Text(protectionText)
                .font(BDFont.body(.regular, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    private var protectionText: String {
        if plate.junkAppCount > 0 {
            return plate.junkAppCount == 1
                ? String(localized: "Empty calories off the menu · 1 app")
                : String(localized: "Empty calories off the menu · \(plate.junkAppCount) apps")
        }
        if plate.protectedMinutesToday > 0 {
            return String(localized: "\(BDMealTray.display(plate.protectedMinutesToday)) protected today · the table is held for you")
        }
        return String(localized: "The table is held automatically. No timers.")
    }

    // MARK: The celebration (Bible §5 / PLATE-ENGINE §4) — visuals AFTER state.
    //
    // THE DAILY WIN (upgraded 2026-07-19, consistent with onboarding's
    // firstServing): state commits first, then the plate crossfades UP to its
    // new real state front-and-center (the hero's 0.8s ramp ease, driven by
    // engine completeness) while the signature beat plays — `.success` haptic
    // FIRST → scale-bounce + steam BURST + ONE gold flare (~1.5s) → "Served."
    // toast. Total ≤ 2.5s, never input-locked. Reduce Motion: crossfade +
    // haptic + toast only (no bounce/burst/flare). Chime = coded seam only.

    private func playCelebrationIfPending() {
        guard router.selectedTab == .home,
              let beat = plate.consumeCelebration() else { return }

        let landing = UINotificationFeedbackGenerator()
        landing.prepare()
        landing.notificationOccurred(.success)     // haptic FIRST — the win lands
        playChimeSeam()                            // chime SECOND (seam only)

        // ⭐ RANK THE BEAT (Jack, 2026-08-15). State has already committed, so
        // `completeness` reflects THIS serving; `mealWasComplete` still holds
        // the value from before it. Bonus servings leave completeness at 1.0
        // untouched, so the pair is what tells them apart.
        let tier: PlateWin = mealWasComplete ? .beyond
                           : (plate.completeness >= 1 ? .mealComplete : .building)
        mealWasComplete = plate.completeness >= 1

        // The bounce is the one universal acknowledgement — every serving gets
        // it, including the two that fire nothing over the plate.
        if !reduceMotion {
            plateBounce = true
            win = tier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { plateBounce = false }
            // The window has to outlast the longest beat it can play: the
            // meal-complete toss runs 0.5s + a 0.9s flare.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.4)) { win = nil }
            }
            flyOnSeam(beat)
        } else {
            // Reduce Motion still needs the serve sting, which lives on the
            // hero's `win` transition — set and clear it without animation.
            win = tier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { win = nil }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { toast = beat }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if toast?.id == beat.id { toast = nil }
                }
            }
        }
    }

    /// Coded seam: the small completion chime (haptic-first order preserved).
    /// No audio asset ships yet — when one lands, play it here via AVAudioPlayer
    /// with `.ambient` category so it respects silent mode.
    private func playChimeSeam() { /* seam — intentionally silent */ }

    /// Coded seam: the food-group fly-on (Bible §5, step 3). DISABLED until the
    /// greens-cutout render exists (`design/plate-concepts/gemini-render-prompts.md`).
    private func flyOnSeam(_ beat: PlateCelebration) { /* seam — awaiting render */ }

    #if DEBUG
    /// `BD_DEMO_COMPLETE=1` — fire a completion ~4s after launch so the
    /// celebration (bounce + toast + fed state) can be screenshot-verified.
    /// `BD_DEMO_COMPLETE=N` fires N completions, 3.5s apart. N > 1 exists so the
    /// TIERED win beats can be recorded in one take — building, then the meal
    /// landing, then a bonus glint — which stills cannot review (motion rule).
    /// `=1` keeps its original meaning.
    private func runDemoCompleteIfRequested() async {
        guard let raw = ProcessInfo.processInfo.environment["BD_DEMO_COMPLETE"],
              let times = Int(raw), times > 0 else { return }
        try? await Task.sleep(for: .seconds(4))
        for i in 0..<times {
            if i > 0 { try? await Task.sleep(for: .seconds(3.5)) }
            plate.debugComplete()
        }
    }
    #endif

    // MARK: Open choreography — plate settles, meaning cascades in beneath.

    private func runOpenChoreography() async {
        guard phase == .initial else { return }
        if reduceMotion {
            phase = .settled
            return
        }
        let pace = AdMode.pace
        try? await Task.sleep(for: .milliseconds(AdMode.openPrerollMilliseconds))
        withAnimation(.easeOut(duration: 0.4 * pace)) { phase = .ring }
        try? await Task.sleep(for: .milliseconds(Int(420.0 * pace)))
        phase = .number
        try? await Task.sleep(for: .milliseconds(Int(680.0 * pace)))
        withAnimation(.spring(response: 0.5 * pace, dampingFraction: 0.86)) { phase = .meaning }
        try? await Task.sleep(for: .milliseconds(Int(520.0 * pace)))
        phase = .settled
    }

    // MARK: Header — wordmark LEFT; share + settings RIGHT (both quiet, no streak).

    private var headerRow: some View {
        HStack(spacing: Theme.Space.sm) {
            // The plate-D lockup (2026-08-16). `size` is now the mark's HEIGHT,
            // not a font size, so 12 would render smaller than the old dot +
            // caps it replaces.
            BrandWordmark(tone: .onDark, size: 14)
            Spacer(minLength: Theme.Space.sm)
            PlanShareButton(
                plan: EngineContext(profile: profiles.first, usage: usageProvider,
                                    sessions: sessions).plan,
                servings: PlanServing.from(goals: goals),
                style: .compact,
                iconColor: .bdTextSecondary
            )
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.bdTabMuted)
                    .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 6)
    }
}

// MARK: - Phase-gated stage-in (matches the hero's cascade).

private extension View {
    func stageIn(_ active: Bool) -> some View {
        modifier(HomeStageIn(active: active))
    }
}

private struct HomeStageIn: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 16)
                .animation(.spring(response: 0.55, dampingFraction: 0.87), value: active)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .environment(PlateEngine())
        .modelContainer(for: [UserProfile.self, ProtectSession.self, Goal.self, GoalStep.self],
                        inMemory: true)
}
