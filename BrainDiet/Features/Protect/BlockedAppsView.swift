import SwiftUI
import SwiftData

#if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
import FamilyControls
import ManagedSettings
#endif

// MARK: - MENU tab — three levels, not one page (rebuilt 2026-08-28).
//
// ⭐ WHY THIS IS SHORTER THAN IT WAS. Jack: "you're still doubting the user's
// intelligence by overexplaining every little thing." He is right. The previous
// version put the whole feature on one screen and then narrated it — a two-line
// headline, a two-line subtitle, a paragraph under the pass count, a paragraph
// on the connect card. Nobody reads a paragraph to find out what "Unblock" does.
//
// ⭐ THE RULE NOW: each level shows the FEWEST things that let you decide where
// to go next, and the next level is earned by a tap. Level 1 is a status word, a
// count, and two rows. Level 2 is the apps themselves. Level 3 is the only place
// a sentence of explanation is allowed to exist, because by then the user has
// asked for it twice. This is Opal's own shape — their Apps screen is tiles and
// counts, and the list with toggles and "Add App or Website" is a push away.
//
// ⭐ WHY THIS FILE IMPORTS FamilyControls WHEN NO OTHER SCREEN DOES.
// BlockingService deliberately keeps the framework away from the UI, but a real
// app icon is only obtainable as `Label(ApplicationToken)` — a system view whose
// image and name cannot be unwrapped, recoloured, or copied out. Showing the
// user their actual app covers means the framework reaches exactly this far and
// no further, so the import is quarantined in this one file.

// MARK: Level 1 — THE SPLIT PLATE (Jack, 2026-09-12).
//
// ⭐ ONE HARD LINE ACROSS THE SCREEN. Above it the gray world: the apps you have
// put to rest, drained of colour. Below it the plate: what to do instead, in
// full category colour. The contrast IS the message and there is no legend for
// it anywhere — you read the state before you read a word.
//
// ⭐ GRAYSCALE IS THE STATE, AND IT IS THE ONLY STYLING. Nothing is ADDED to a
// tile to say "resting" — colour is taken away from it. That is the attraction
// law as written: the blocked app is never ugly, never red, never crossed out.
// Every drop of colour on this screen has moved to the half where the things
// worth doing live.
//
// ⭐ THE FRICTION IS ASYMMETRIC ON PURPOSE. Resting an app is one tap, free and
// instant. Taking one back is a press-and-hold that spends a pass and lasts
// three minutes, after which it rests again by itself. The good direction is
// frictionless; the expensive one needs a second of deliberate contact, which
// is the only thing that stops an autopilot unblock at eleven at night.
//
// ⭐ I AM BENDING THE "LEVEL 1 IS READ-ONLY" RULE HERE, KNOWINGLY. That rule
// bans SETTINGS controls on a tab root — sliders, pickers, switches. This is
// different: the tile is not a control attached to an object, it IS the object.
// No chrome was added and no row grew, so the screen stays as scannable as it
// was. A switch would have broken the rule; making the thing itself operable
// does not.

struct BlockedAppsView: View {

    @Environment(BlockingService.self) private var blocking
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [UserProfile]
    @Query private var goals: [Goal]
    @Query private var sessions: [ProtectSession]

    /// Opens the system picker.
    let onEdit: () -> Void
    /// Opens the self-report sheet.
    var onReport: () -> Void = {}

    /// Re-read on every change so the pips and the tiles agree with the ledger.
    @State private var released: [String: Date] = AppRest.released()
    @State private var undo: (id: String, at: Date)?

    /// ⭐ THE STEP BEING SHARPENED (2026-09-20). `MakeItMineSheet` and the whole
    /// `StepRefiner` stack beneath it — heuristic floor, on-device refiner,
    /// factory — were fully built and **referenced by nothing**. Jack:
    /// "the personalization right now is shit… it just doesn't show at all."
    /// It did not show because no screen in the app could reach it.
    ///
    /// Third time this has happened here: `FamilyPickerView` was written and
    /// never presented, so no app was ever shielded on any build. **A feature
    /// with no call site is not a feature**, and nothing in the build catches it
    /// because unreferenced SwiftUI views compile perfectly.
    @State private var tweaking: StepRow?
    /// The "Block my feeds" editor.
    @State private var editingSchedule = false

    private var profile: UserProfile? { profiles.first }
    private var tiles: [Tile] { Tile.current(blocking: blocking, profile: profile) }
    private var restingCount: Int { tiles.count - released.count }

    // ⭐ ONE SCROLL PLANE (Jack, 2026-09-18: "the bottom half is layered
    // underneath and it feels choppy and looks ugly").
    //
    // The gray half used to be a PINNED block with the plate scrolling beneath
    // it, so steps were sliced mid-row against a hard edge with nothing
    // explaining the seam. Two scroll planes stacked is the whole defect. The
    // gray half now scrolls away with the plate — the hard line between the two
    // worlds survives, it just stops being a scroll boundary.
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                offTheMenu
                Divider().overlay(Color.bdGrayTileBorder)
                onTheMenu
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.bdBackground)
        // Screenshot path for the sheet that spent its whole life unreachable —
        // a feature with no call site needs a review path too, or "wired up" is
        // just another claim nobody checked.
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.environment["BD_SHOW_MAKE_MINE"] == "1" {
                tweaking = stepRows.first
            }
        }
        #endif
        .sheet(isPresented: $editingSchedule) {
            if let profile {
                FeedScheduleSheet(profile: profile)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.environment["BD_SHOW_SCHEDULE"] == "1" { editingSchedule = true }
        }
        #endif
        .sheet(item: $tweaking) { row in
            MakeItMineSheet(step: row.step,
                            domain: row.domain,
                            profile: profile,
                            lastActionAt: sessions.map(\.startedAt).max())
        }
        .onAppear {
            refresh()
            // What was offered today — the only input a "skip" can be built from.
            MenuExposure.recordShown(stepRows.map(\.step.id))
        }
        .onChange(of: stepRows.map(\.step.id)) { _, ids in MenuExposure.recordShown(ids) }
        // Windows close on their own; the screen has to notice without a tap.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if released.contains(where: { $0.value <= .now }) { refresh() }
            }
        }
    }

    // MARK: The gray half — what is resting

    // ⭐ HALVED, BY DELETING THE THING THAT WAS SETTING THE HEIGHT.
    //
    // The headline and the pass pips now share one row instead of stacking, and
    // the tiles dropped 50pt → 34pt because they no longer carry a name (see
    // `SplitAppTile`). Measured 205pt → ~96pt for the whole gray half, and it
    // shows seven covers where it used to show one.
    private var offTheMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Off the menu")
                        .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                        .kerning(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bdSlopGrayText)

                    Text(headline)
                        .font(BDFont.serif(size: 17, relativeTo: .headline))
                        .foregroundStyle(Color.bdGrayInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 10)
                passLine
            }

            // ⭐ WITH NOTHING PICKED, THE SETUP ACTION IS THE SCREEN (Jack,
            // 2026-09-22: "it works when you click Add, but it should be more
            // apparent... right now it's kind of vague").
            //
            // He is right and the old layout was indefensible: the entire
            // first-run job — choose the apps — was a 34pt dashed square under
            // an 8.5pt word, sitting beside a capsule that described a different
            // action. Two vague affordances, neither of which says what happens.
            //
            // The "never a full-width slab competing with the plate below" rule
            // still holds once apps EXIST. It does not apply here, because with
            // nothing chosen there is nothing to compete with, and the rest of
            // the screen cannot do its job until this one tap happens.
            if tiles.isEmpty {
                chooseAppsCTA
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 9) {
                        ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                            SplitAppTile(tile: tile,
                                         releasedUntil: released[tile.id],
                                         // Only the first tile demonstrates, and
                                         // only until they have held one. Two
                                         // tiles moving at once is a screen
                                         // twitching, not a hint.
                                         demonstrates: index == 0 && showsHoldHint,
                                         onRest: { rest(tile.id) },
                                         onRelease: { release(tile.id) })
                        }
                        AddAppTile(action: onEdit)
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.top, 9)
                    .padding(.bottom, 2)
                }
                .padding(.horizontal, -Theme.Space.screenX)

                // ⭐ WHEN they rest (2026-10-08): Opal's Rules card as one row.
                if let profile {
                    FeedScheduleCard(window: profile.feedWindow) { editingSchedule = true }
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }
            }

            // Setup state, not the point of the screen — a quiet row, never a
            // full-width green slab competing with the plate below. Suppressed
            // when the CTA above already owns the setup job.
            if !blocking.isAuthorized, !tiles.isEmpty {
                Button(action: { Task { await blocking.authorize() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill").font(.system(size: 11, weight: .bold))
                        Text("Connect Screen Time to make this real")
                            .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.bdLeafDeep)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.bdLeafTint, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                // A failed connect used to reach only the log, so on a real
                // phone it was a button that did nothing. It says why now.
                if let reason = blocking.authorizationError {
                    Text(reason)
                        .font(BDFont.body(.regular, size: 11, relativeTo: .caption))
                        .foregroundStyle(Color.bdSlopGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                }
            }
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bdGrayCanvas)
    }

    /// The one thing to do when nothing is set up. It names the OUTCOME ("rest"),
    /// not the mechanism ("add"), and it does both halves of the job in one tap:
    /// asks for Screen Time if it has not been granted, then opens the picker.
    /// Two taps across two vague controls was the whole complaint.
    private var chooseAppsCTA: some View {
        Button {
            Task {
                if !blocking.isAuthorized { await blocking.authorize() }
                onEdit()
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.bdLeafDeep)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.bdTextOnAccent))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose the apps to rest")
                        .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text("Opening one brings you here first.")
                        .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.bdLeafDeep)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.bdLeafDeep.opacity(0.35), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 11)
        .padding(.bottom, 2)
        .accessibilityHint(Text("Connects Screen Time if needed, then opens the app picker."))
    }

    /// States the truth and nothing more (honesty law). Outside the feed
    /// window nothing is resting, so it says when the rest starts again.
    private var headline: String {
        if tiles.isEmpty { return String(localized: "Nothing is resting yet.") }
        if !blocking.isFeedWindowOpen, let line = blocking.feedWindow.openUntilLine() { return line }
        if restingCount == 0 { return String(localized: "Everything is out right now.") }
        if released.isEmpty {
            return restingCount == 1
                ? String(localized: "1 app is resting")
                : String(localized: "\(restingCount) apps are resting")
        }
        return String(localized: "\(restingCount) resting, \(released.count) out")
    }

    private var passLine: some View {
        HStack(spacing: 7) {
            HStack(spacing: 4) {
                ForEach(0..<InterceptPass.dailyAllowance, id: \.self) { i in
                    Circle()
                        .fill(i < InterceptPass.remainingToday()
                              ? Color.bdSlopFaint : Color.bdGrayTileBorder)
                        .frame(width: 5, height: 5)
                }
            }
            Text(InterceptPass.remainingToday() == 1
                 ? String(localized: "1 pass left")
                 : String(localized: "\(InterceptPass.remainingToday()) passes left"))
                .font(BDFont.body(.regular, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.bdGrayFaint)
        }
    }

    // MARK: The plate — what to do instead

    // No longer a ScrollView of its own — the whole screen is one scroll plane
    // now (see `body`). This is the half of the layering fix that removed the
    // sliced rows.
    private var onTheMenu: some View {
        Group {
            VStack(spacing: 0) {
                SectionRule(title: "on the menu")
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                // ⭐ THE MENU IS SIZED TO THEIR OWN REPORTED HOURS (Jack,
                // 2026-09-15): "show the user exactly what they are forgoing by
                // just scrolling their daily hours away."
                //
                // The list underneath is not abstract advice — it is what that
                // time could hold. The empty part of the bar IS the forgone
                // time, which is the whole point and needs no sentence.
                if dailyScrollMinutes > 0 {
                    CapacityBand(dailyMinutes: dailyScrollMinutes,
                                 usedToday: minutesToday,
                                 roomFor: roomForMore)
                        .padding(.bottom, 11)
                }

                if stepRows.isEmpty {
                    Text("Your plan lands here once you finish setting up.")
                        .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(stepRows) { row in
                            PlateStepRow(step: row.step, domain: row.domain, done: row.done,
                                         onSelfReport: { handOver(row) },
                                         onTimer: { startTimer(row) },
                                         onTweak: { tweaking = row })
                        }

                        // One line of evidence instead of rows — the count must
                        // never push the menu past three.
                        if doneTodayCount > 0 {
                            Text(doneTodayCount == 1
                                 ? "1 done today"
                                 : "\(doneTodayCount) done today")
                                .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption))
                                .foregroundStyle(Color.bdLeafDeep)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 2)
                        }
                        Button(action: { onReport() }) {
                            Text("＋ Add something you did")
                                .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                                .foregroundStyle(Color.bdLeafDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.bdCardBorder,
                                                      style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
    }

    private struct StepRow: Identifiable {
        let goal: Goal; let step: GoalStep; let domain: ActivityDomain; let done: Bool
        var id: UUID { step.id }
    }

    /// ⭐ EVERY step the plan contains, not one per goal (Jack, 2026-09-13):
    /// "a super personalized list of options… they can scroll through and tap it
    /// to self-report." A single suggestion is a command; a list is a menu, and
    /// the whole screen is named after being one.
    ///
    /// Undone first, in plan order, with today's completed ones kept at the
    /// bottom — a list that empties itself as you work throws away the evidence
    /// exactly when it is most worth seeing.
    /// ⭐ THREE. NOT "THE FIRST FEW" — THREE (Jack, 2026-09-20): "Max, the menu
    /// should be three items, and if they finish those three, you can give them
    /// a new three."
    ///
    /// This screen used to render EVERY step of EVERY goal — twelve-plus rows,
    /// all at equal weight. That is not a menu, it is a backlog, and a backlog
    /// is read as debt rather than as an offer. The steps have not gone
    /// anywhere: finishing one promotes the next into its slot, so the list
    /// refills instead of stretching.
    ///
    /// Interleaved across goals rather than draining the primary goal first —
    /// three reading steps in a row reads as a single chore with three parts,
    /// where reading/training/building reads as a day worth having.
    static let menuSize = 3

    /// The day's three — ranked by `TodaysFocus.pickThree` (hour, what's done,
    /// what keeps getting skipped), the same scorer Home's focus uses.
    private var stepRows: [StepRow] {
        let doneToday = Set(sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .compactMap(\.stepID))
        return TodaysFocus
            .pickThree(goals: goals, doneToday: doneToday,
                       everDone: Set(sessions.compactMap(\.stepID)),
                       skips: MenuExposure.skips(sessions: sessions))
            .prefix(Self.menuSize)
            .map { StepRow(goal: $0.goal, step: $0.step, domain: $0.domain, done: false) }
    }

    /// Steps finished today — shown as one line of evidence rather than as rows,
    /// so the count never pushes the menu past three.
    private var doneTodayCount: Int {
        let ids = Set(goals.flatMap { $0.orderedSteps.map(\.id) })
        return Set(sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .compactMap(\.stepID)
            .filter { ids.contains($0) }).count
    }

    // MARK: Actions

    /// What they told us they scroll in a day, at onboarding. The menu is
    /// measured against this and nothing else.
    private var dailyScrollMinutes: Int { profile?.baselineJunkMinutes ?? 0 }

    private var minutesToday: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.minutes }
    }

    /// How many more of the things ACTUALLY ON THIS LIST fit in what is left of
    /// that time today. Measured against the median option rather than the
    /// cheapest, so the number is not flattered by one ten-minute step.
    private var roomForMore: Int {
        let remaining = max(0, dailyScrollMinutes - minutesToday)
        let pending = stepRows.filter { !$0.done }.map(\.step.suggestedMinutes).sorted()
        guard !pending.isEmpty else { return 0 }
        let median = pending[pending.count / 2]
        guard median > 0 else { return 0 }
        return remaining / median
    }

    private func refresh() { released = AppRest.released() }

    // MARK: The hold hint
    //
    // ⭐ SHOW THE GESTURE, NEVER NAME IT (Jack, 2026-09-22: "it just needs to show
    // that holding or tapping would do anything... you know when you want to hold
    // or tap something, not because they say it, but because they show it").
    //
    // Two devices, both lifted from apps that teach a press without a sentence:
    //
    //   • A VISIBLE EMPTY RING around every resting tile. Me+ shows the ring's
    //     dark track before you touch it, so the eye reads "this fills". An empty
    //     track is a promise of a fill; a bare icon is not.
    //   • THE TILE PERFORMS THE GESTURE ITSELF, once. The first tile's ring
    //     sweeps and the cover lifts to colour, then settles back — the outcome
    //     of holding, demonstrated. Breathwrk and Atoms do the same job with
    //     brackets and a halo; this one has the advantage of showing the RESULT.
    //
    // It stops as soon as they have ever held one (a pass has been spent), and it
    // never runs while an app is actually out — a demo playing over live state
    // would be the app lying about itself.

    private static let hintKey = "bd.holdHintSeen.v1"

    private var showsHoldHint: Bool {
        guard released.isEmpty else { return false }
        guard InterceptPass.remainingToday() == InterceptPass.dailyAllowance else { return false }
        return !UserDefaults.standard.bool(forKey: Self.hintKey)
    }

    /// ⭐ THE MENU DOES NOT REPORT — IT HANDS OVER. Tapping an option sends it to
    /// Home and switches tabs, so the user lands on the brain and watches the
    /// serving travel in and get absorbed. The reward for reporting is seeing it
    /// eaten, and that only works on the screen the brain is on.
    private func handOver(_ row: StepRow) {
        router.pendingReport = PlateDraggable(
            title: row.step.title, subtitle: row.step.cue,
            activityID: row.domain.activityID,
            goalID: row.goal.id, stepID: row.step.id,
            minutes: row.step.suggestedMinutes,
            icon: .leaf, tint: row.domain.tint, ink: .bdTextPrimary)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        withAnimation(Theme.Motion.smooth) { router.selectedTab = .home }
    }

    private func startTimer(_ row: StepRow) {
        guard let serving = PlateEngine.serving(for: row.step, in: row.goal) else { return }
        router.pendingServing = serving
        withAnimation(Theme.Motion.smooth) { router.selectedTab = .protect }
    }

    private func rest(_ id: String) {
        AppRest.rest(id)
        refresh()
        blocking.applyStandingShield(excluding: Set(released.keys))
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    private func release(_ id: String) {
        // They have held one. The demonstration has done its job and stops.
        UserDefaults.standard.set(true, forKey: Self.hintKey)
        guard AppRest.release(id) != nil else { return }
        refresh()
        blocking.applyStandingShield(excluding: Set(released.keys))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - One app tile. Colour is the state; nothing else says it.

private struct SplitAppTile: View {

    let tile: Tile
    let releasedUntil: Date?
    /// Play the one-time hold demonstration on this tile. See `showsHoldHint`.
    var demonstrates: Bool = false
    let onRest: () -> Void
    let onRelease: () -> Void

    @State private var holdProgress: Double = 0
    @State private var isPressing = false
    /// Drives the one-time demonstration: the cover lifts to colour as the ring
    /// sweeps, so what the user sees is the OUTCOME of holding, not a mime of it.
    @State private var demoLift = false

    private var isResting: Bool { releasedUntil == nil }

    /// ⭐ NO NAME. NOT SMALLER — GONE (Jack, 2026-09-18).
    ///
    /// `Label(ApplicationToken)` is a SYSTEM-RENDERED view: `.font`, `.frame`
    /// and `.lineLimit` hung on it are silently ignored. `.labelStyle(.titleOnly)`
    /// therefore drew "Discord" at system size, broke its 58pt frame, and set the
    /// row height for every tile — which is why the strip was ~205pt tall for a
    /// single app and why a stray **"Disc…"** appeared under it. One line, three
    /// symptoms.
    ///
    /// There is no supported way to read the name out of a token (it is opaque
    /// by design), so the fix is not to style it differently — it is to stop
    /// printing it. **Opal never prints an app name on any screen**; the cover
    /// IS the label, and people recognise their own apps by cover faster than by
    /// text. Deleting it removes the bug and takes 50pt → 34pt in one move.
    private static let side: CGFloat = 34

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottomTrailing) {
                cover
                    .frame(width: Self.side, height: Self.side)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    // ⭐ THE ONE LINE THAT CARRIES THE WHOLE MECHANIC. `demoLift`
                    // borrows it for the hint: colour returning IS the outcome of
                    // a successful hold, so the demonstration and the real thing
                    // are the same animation.
                    .grayscale(isResting && !demoLift ? 1 : 0)
                    .opacity(isResting && !demoLift ? 0.82 : 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.bdTextPrimary.opacity(0.07), lineWidth: 1)
                    }
                    // Out on a pass wears a leaf ring, so the whole set's state
                    // reads at a glance rather than one tile at a time.
                    .overlay {
                        if !isResting {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.bdLeaf, lineWidth: 2)
                        }
                    }
                    // ⭐ THE EMPTY TRACK IS THE AFFORDANCE. Always drawn on a
                    // resting tile, faint, just outside the cover. Me+ shows the
                    // ring's track before the hold so the eye reads "this fills";
                    // a bare icon promises nothing. The fill then rides the same
                    // path, so the hint and the real gesture are one object.
                    .overlay {
                        if isResting {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(Color.bdSlopGrayText.opacity(0.28), lineWidth: 2)
                                .padding(-3)
                        }
                    }
                    .overlay {
                        if holdProgress > 0 {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .trim(from: 0, to: holdProgress)
                                .stroke(Color.bdLeaf, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .padding(-3)
                        }
                    }
                    // Touch-down answers "is this even a control?" before the
                    // hold has had time to say anything.
                    .scaleEffect(isPressing ? 0.93 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressing)

                if isResting {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 13, height: 13)
                        .background(Circle().fill(Color.bdSlopGrayText))
                        .overlay(Circle().strokeBorder(Color.bdGrayCanvas, lineWidth: 1.5))
                        .offset(x: 3, y: 3)
                }
            }

            // The window still counts itself down where the state is. The line
            // is ALWAYS reserved so resting a tile does not make the row jump.
            Group {
                if let until = releasedUntil {
                    Text(until, style: .timer)
                        .font(BDFont.body(.bold, size: 8.5, relativeTo: .caption2))
                        .foregroundStyle(Color.bdLeafDeep)
                        .monospacedDigit()
                } else {
                    Text(" ").font(BDFont.body(.bold, size: 8.5, relativeTo: .caption2))
                }
            }
            .frame(width: Self.side + 8)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isResting { onRest() } }
        .gesture(
            LongPressGesture(minimumDuration: 0.65)
                .onChanged { _ in
                    guard isResting else { return }
                    withAnimation(.linear(duration: 0.65)) { holdProgress = 1 }
                }
                .onEnded { _ in
                    holdProgress = 0
                    if isResting { onRelease() }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressing { isPressing = true } }
                .onEnded { _ in
                    isPressing = false
                    withAnimation(.easeOut(duration: 0.18)) { holdProgress = 0 }
                }
        )
        .task(id: demonstrates) { await demonstrateIfNeeded() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isResting
            ? Text("Press and hold to take it back for \(InterceptPass.windowMinutes) minutes. Spends a pass.")
            : Text("Tap to put it back to rest."))
    }

    /// The tile holds itself down, twice, then stops.
    ///
    /// Deliberately slower than the real 0.65s gesture: a hint that finishes as
    /// fast as the action reads as a glitch. It also RESETS afterwards — leaving
    /// the tile lifted would be the app claiming an app is out when it is not.
    private func demonstrateIfNeeded() async {
        guard demonstrates, isResting else { return }
        try? await Task.sleep(for: .milliseconds(650))   // let the screen settle first
        for _ in 0..<2 {
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.95)) { holdProgress = 1 }
            try? await Task.sleep(for: .milliseconds(780))
            withAnimation(.easeOut(duration: 0.28)) { demoLift = true }
            try? await Task.sleep(for: .milliseconds(620))
            withAnimation(.easeOut(duration: 0.34)) { demoLift = false; holdProgress = 0 }
            try? await Task.sleep(for: .milliseconds(900))
        }
    }

    @ViewBuilder private var cover: some View {
        switch tile {
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        case .real(let token): Label(token).labelStyle(.iconOnly)
        #endif
        case .stub(let id):
            // ⚠️ A placeholder tile is already grey, so `.grayscale()` does
            // nothing to it — which means the "colour returns" half of the hold
            // hint is INVISIBLE wherever real covers are unavailable (the
            // simulator, and any un-entitled build). It carries the state in its
            // own ink instead, so the demonstration reads everywhere.
            let awake = !isResting || demoLift
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(awake ? Color.bdLeafTint : Color.bdSlopGray.opacity(0.16))
                .overlay(BDPhIcon(icon: FallbackAppTile.glyph(for: id),
                                  size: 26,
                                  color: awake ? Color.bdLeafDeep : Color.bdSlopGrayText))
        }
    }

    // `name` DELETED 2026-09-18 — it was `Label(token).labelStyle(.titleOnly)`,
    // the system-rendered view described above. Nothing replaced it; the cover
    // is the label now. VoiceOver is unaffected: the accessibility label below
    // still reads the app, because that path does not go through a drawn view.
}

// MARK: - The add tile — last item IN the row, never a floating button.

private struct AddAppTile: View {
    let action: () -> Void
    var body: some View {
        // Mirrors SplitAppTile's geometry exactly — 34pt tile over the same
        // reserved caption line — so the row sits on one baseline. "Add" lives
        // in that reserved line, which costs no extra height.
        Button(action: action) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.bdGrayTileBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bdGrayFaint))
                Text("Add")
                    .font(BDFont.body(.bold, size: 8.5, relativeTo: .caption2))
                    .foregroundStyle(Color.bdGrayFaint)
                    .frame(width: 42)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - One step on the plate.

private struct PlateStepRow: View {
    let step: GoalStep
    let domain: ActivityDomain
    let done: Bool
    var onSelfReport: () -> Void = {}
    var onTimer: () -> Void = {}
    var onTweak: () -> Void = {}

    var body: some View {
        Button(action: { if !done { onSelfReport() } }) { rowBody }
            .buttonStyle(.plain)
            .disabled(done)
    }

    private var rowBody: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(done ? Color.bdLeafTint : domain.tint.opacity(0.30))
                .frame(width: 34, height: 34)
                .overlay {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.bdLeafDeep)
                    } else {
                        Image(systemName: domain.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bdTextPrimary.opacity(0.75))
                    }
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(BDFont.body(.bold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(done ? Color.bdTextSecondary : Color.bdTextPrimary)
                    .strikethrough(done, color: Color.bdTextSecondary)
                if !done, !step.cue.isEmpty {
                    Text(step.cue)
                        .font(BDFont.body(.regular, size: 12, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                }

                // ⭐ THE PERSONALISATION HAS TO BE VISIBLE TO COUNT.
                //
                // A long-press would have kept this screen exactly as anonymous
                // as it was — the complaint was that personalisation "doesn't
                // show at all", and an invisible gesture does not fix an
                // invisible feature. So a generic step wears the invitation,
                // and a sharpened one wears the receipt. The chip is not
                // permanent chrome: it disappears the moment the step becomes
                // theirs, which is also the only honest time to stop asking.
                if !done {
                    Button(action: onTweak) {
                        if step.isPersonalised {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 8, weight: .bold))
                                Text("yours")
                                    .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                            }
                            .foregroundStyle(Color.bdGoldText)
                        } else {
                            Text("Make it yours →")
                                .font(BDFont.body(.bold, size: 10.5, relativeTo: .caption2))
                                .foregroundStyle(Color.bdLeafDeep)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 6)

            Text("\(step.suggestedMinutes)m")
                .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)

            // The timer is the SECOND way in, never the first — a small glyph
            // beside the row, because the row itself is the self-report.
            if !done {
                Button(action: onTimer) {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bdLeafDeep)
                        .frame(width: 34, height: 34)
                        .background(Color.bdLeafTint, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
        }
    }
}

// MARK: Level 2 — the apps themselves. Unblock one, or add another.

struct BlockedAppsListView: View {

    @Environment(BlockingService.self) private var blocking
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [UserProfile]
    let onEdit: () -> Void

    private var tiles: [Tile] { Tile.current(blocking: blocking, profile: profiles.first) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !tiles.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                              spacing: 10) {
                        ForEach(tiles) { tile in
                            switch tile {
                            #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
                            case .real(let token): RealAppTile(token: token)
                            #endif
                            case .stub(let id): FallbackAppTile(appID: id)
                            }
                        }
                    }
                }

                // Opal keeps "Add App or Website" as the last row of the same
                // list rather than a floating button — the add affordance lives
                // where the things being added live.
                Button(action: onEdit) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                        Text("Add an app")
                    }
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdGoldText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.bdGoldText.opacity(0.35),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, tiles.isEmpty ? 0 : 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.Space.sm)
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Blocked apps")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: Level 3 — the only place a sentence is allowed.

struct PassesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let left = InterceptPass.remainingToday()

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(left)")
                        .font(BDFont.serif(size: 44, relativeTo: .largeTitle))
                        .foregroundStyle(left > 0 ? Color.bdLeafDeep : Color.bdSlopGrayDisplay)
                    Text(left == 1 ? "left today" : "left today")
                        .font(BDFont.body(.semiBold, size: 15, relativeTo: .callout))
                        .foregroundStyle(Color.bdTextSecondary)
                    Spacer(minLength: 8)
                    HStack(spacing: 5) {
                        ForEach(0..<InterceptPass.dailyAllowance, id: \.self) { i in
                            Capsule()
                                .fill(i < left ? Color.bdLeaf : Color.bdCardBorder)
                                .frame(width: 18, height: 6)
                        }
                    }
                }

                Text("A pass opens a blocked app for \(InterceptPass.windowMinutes) minutes. You get \(InterceptPass.dailyAllowance) a day.")
                    .font(BDFont.body(.medium, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.Space.sm)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Passes")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - DoorRow — a level you can open. Covers, name, count, chevron.

private struct DoorRow: View {
    let title: LocalizedStringKey
    let trailing: String
    let covers: [Tile]

    var body: some View {
        HStack(spacing: 12) {
            if !covers.isEmpty {
                // Overlapped covers, so the row shows WHAT is inside before the
                // user commits a tap — the count alone is a fact, the icons are
                // recognition.
                HStack(spacing: -11) {
                    ForEach(covers) { c in
                        CoverThumb(tile: c)
                    }
                }
            }
            Text(title)
                .font(BDFont.body(.bold, size: 17, relativeTo: .headline))
                .foregroundStyle(Color.bdTextPrimary)
            Spacer(minLength: 8)
            Text(trailing)
                .font(BDFont.body(.semiBold, size: 15, relativeTo: .callout))
                .foregroundStyle(Color.bdTextSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.bdCardBorder)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .bdTileCard()
    }
}

private struct CoverThumb: View {
    let tile: Tile
    var body: some View {
        Group {
            switch tile {
            #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
            case .real(let token):
                Label(token).labelStyle(.iconOnly)
            #endif
            case .stub(let id):
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.bdSlopGray.opacity(0.14))
                    .overlay(BDPhIcon(icon: FallbackAppTile.glyph(for: id),
                                      size: 17, color: Color.bdSlopGrayText))
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(Color.bdSurface, lineWidth: 2))
    }
}

// MARK: - Tile — one blocked app, real token or catalog stand-in.

enum Tile: Identifiable {
    #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
    case real(ApplicationToken)
    #endif
    case stub(String)

    var id: String {
        switch self {
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        case .real(let t): return String(describing: t.hashValue)
        #endif
        case .stub(let s): return s
        }
    }

    /// Real tokens where the entitlement is live; the onboarding catalog
    /// otherwise, so the screen stays reviewable in the simulator.
    @MainActor
    static func current(blocking: BlockingService, profile: UserProfile?) -> [Tile] {
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        let tokens = RealScreenTimeGateway.decode(blocking.selection).applicationTokens
        if !tokens.isEmpty { return tokens.map { Tile.real($0) } }
        #endif
        return (profile?.junkAppIDs ?? []).map { Tile.stub($0) }
    }
}

// MARK: - Tile chrome

/// The raised card every blocked app sits in. `icon` and `name` are supplied by
/// the caller because in the real build BOTH come out of the same system
/// `Label(token)` and neither can be reproduced by hand.
private struct AppTileCard<Icon: View, Name: View>: View {
    @ViewBuilder let icon: Icon
    @ViewBuilder let name: Name

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                icon
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                // The lock is the state; "Unblock" below is the verb. Opal prints
                // both, and the pair is why their grid reads as buttons.
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.bdSlopGray)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.bdSurface))
                    .overlay(Circle().strokeBorder(Color.bdCardBorder, lineWidth: 1))
                    .offset(x: 6, y: 5)
            }
            .frame(height: 56)

            name
                .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.bdTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 7)

            Text("Unblock")
                .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.bdLeafDeep)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 6)
        .bdTileCard()
    }
}

#if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
/// The real thing: iOS draws the app's own icon and name from the token.
private struct RealAppTile: View {
    let token: ApplicationToken
    var body: some View {
        AppTileCard(
            icon: { Label(token).labelStyle(.iconOnly) },
            name: { Label(token).labelStyle(.titleOnly) }
        )
    }
}
#endif

/// Stand-in for the simulator and unentitled builds — the onboarding catalog's
/// Phosphor glyph, worn in gray by the junk colour law.
struct FallbackAppTile: View {
    let appID: String

    var body: some View {
        AppTileCard(
            icon: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.bdSlopGray.opacity(0.14))
                    .overlay(BDPhIcon(icon: glyph, size: 27, color: Color.bdSlopGrayText))
            },
            name: { Text(MonitoredAppOption.named(appID)?.name ?? appID.capitalized) }
        )
    }

    var glyph: BDPh { Self.glyph(for: appID) }

    static func glyph(for appID: String) -> BDPh {
        switch appID {
        case "tiktok", "reels", "shorts":         return .handSwipeRight
        case "instagram", "snapchat", "facebook": return .usersThree
        case "x", "reddit", "news":               return .newspaper
        case "youtube", "netflix", "twitch":      return .monitorPlay
        case "whatsapp", "messages":              return .chatCircle
        default:                                  return .handSwipeRight
        }
    }
}

// MARK: - The one card treatment this screen uses

private extension View {
    /// White fill, hairline, soft warm shadow — the app's existing card recipe.
    /// Defined once here so every raised object on the Menu is identical, which
    /// is what makes "raised == tappable" legible as a rule.
    func bdTileCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1))
                .shadow(color: Color.bdTextPrimary.opacity(0.06), radius: 14, x: 0, y: 8)
        )
    }
}


// MARK: - CapacityBand — their own hours, and what those hours could hold.
//
// ⭐ IT NEVER SAYS "WASTED". The bar fills with what has been taken back today
// and the rest simply sits there — a person can read an empty bar without being
// told what it means, and being told would make it a scolding. The app's job is
// to put the alternative next to the number, which is exactly what the list
// below it is.
//
// The unit is THEIR unit: the count is in "these", meaning the options directly
// underneath, not in some abstract productivity figure.

private struct CapacityBand: View {

    let dailyMinutes: Int
    let usedToday: Int
    let roomFor: Int

    private var fraction: Double {
        guard dailyMinutes > 0 else { return 0 }
        return min(1, Double(usedToday) / Double(dailyMinutes))
    }

    private var hours: String {
        dailyMinutes >= 60
            ? (dailyMinutes % 60 == 0 ? "\(dailyMinutes / 60)h"
                                      : "\(dailyMinutes / 60)h \(dailyMinutes % 60)m")
            : "\(dailyMinutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                (Text(hours).foregroundStyle(Color.bdTextPrimary)
                 + Text(" a day is yours to spend").foregroundStyle(Color.bdTextSecondary))
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                Spacer(minLength: 8)
                if usedToday > 0 {
                    Text("\(usedToday)m taken back")
                        .font(BDFont.body(.bold, size: 11, relativeTo: .caption))
                        .foregroundStyle(Color.bdLeafDeep)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bdBarTrack)
                    Capsule().fill(Color.bdLeaf)
                        .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * fraction))
                }
            }
            .frame(height: 7)

            if roomFor > 0 {
                Text(roomFor == 1
                     ? String(localized: "Room for one more of these today.")
                     : String(localized: "Room for \(roomFor) more of these today."))
                    .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
