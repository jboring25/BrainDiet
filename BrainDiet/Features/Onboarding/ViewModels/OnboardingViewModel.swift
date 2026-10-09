import SwiftUI
import SwiftData

// MARK: - Onboarding state (spec-v2.6 — six judged questions → a derived plan).
//
// Collects the six answers in-memory, runs the GoalPlanner once on the building
// step, then on completion PERSISTS a UserProfile + the generated GoalPlan
// (Goal/GoalStep rows) to SwiftData. Legacy profile fields (goalIDs, junkAppIDs,
// appCategories, baseline) are DERIVED from the answers so the reframe engine,
// shield, and Mental Diet keep working unchanged.

@MainActor
@Observable
final class OnboardingViewModel {

    var step: OnboardingStep = .welcome

    // MARK: Answers

    /// Q1 — attention hijackers.
    ///
    /// ⭐ PRE-SELECTED, AND ONLY THIS ONE (2026-09-16). 70–90% of people never
    /// change a pre-filled input, which turns the screen from "compose an
    /// answer" into "confirm or adjust" — but that same statistic is why a
    /// dishonest default is worse than none at all.
    ///
    /// Scrolling and socials are the near-universal answer, so seeding them
    /// states something already true rather than deciding anything for the user.
    /// It also DRILLS instead of smoothing: the screen now opens by naming two
    /// of their problems back at them and asking what else, which is a harder
    /// question than an empty grid asks.
    ///
    /// ⚠️ Deliberately NOT extended to the other three question screens — see
    /// `blocker` and the note on `advance()`.
    var selectedHijackers: Set<AttentionHijacker> = OnboardingViewModel.defaultHijackers

    /// The pre-selection, named so the DEBUG jump can restore it rather than
    /// hard-coding a second copy that drifts.
    static let defaultHijackers: Set<AttentionHijacker> = [.shortVideo, .social]
    /// Q2 — hours a day the feed takes (the giant serif scrubber). Nil until the
    /// user touches the scrubber; advancing without touching (or tapping
    /// "I don't know") settles on the honest middle guess of 3.
    var timeLostHours: Int? = nil
    /// The "I don't know" default — also what an untouched Continue commits.
    static let defaultTimeLostHours = 3
    /// The planner's sizing band, derived from the scrubbed hours.
    var timeLostBand: ShortFormBand? {
        timeLostHours.map(ShortFormBand.nearest(toHours:))
    }
    /// The goals' domains in pick order. DERIVED from `pickedScenes` by the
    /// goal builder (2026-10-09); kept as storage because the planner, the
    /// mirror, the paywall and the persist path all read it.
    var selectedDomains: [ActivityDomain] = []
    /// Pick #1's domain.
    var primaryDomain: ActivityDomain? = nil
    /// The identity line anything that still reads `aspiration` gets: the
    /// primary goal's `GoalReason.aspiration` since the goal builder.
    var aspiration: String = ""

    // MARK: ⭐ Goal builder (Jack approved 2026-10-09, design/goal-builder/mock4).

    /// The scenes they picked, in pick order (≤ `maxScenes`). Pick #1 = primary.
    var pickedScenes: [GoalScene] = []
    static let maxScenes = 3
    /// Which pick the per-goal steps (sentence → sharpen → why) are on.
    var builderIndex: Int = 0
    /// Each goal's sentence in progress.
    var drafts: [GoalScene: GoalDraft] = [:]
    /// The sharpen call per goal, keyed to the sentence it was asked about.
    var sharpen: [GoalScene: SharpenState] = [:]
    /// Which sharper version they took. Absent = "Keep mine".
    var sharpenPick: [GoalScene: Int] = [:]
    /// Why each goal matters.
    var goalReasons: [ActivityDomain: GoalReason] = [:]
    /// Q6 (slide 7) — the obstacle question ("What's stopped you before?").
    /// Reverted 2026-07-21 to a plain nil default; the question sets it before
    /// .blocker can advance. Shapes the planner's step sizing.
    ///
    /// ⭐ STAYS NIL ON PURPOSE (Jack, 2026-09-16: "drill the user on the pain
    /// points and problems they have"). The smart-defaults rule says to
    /// pre-select — and this is the one screen where following it would defeat
    /// the screen. Pre-ticking "no time" tells someone what their problem is
    /// before they have said it, and a problem handed to you is not one you
    /// admitted. Seeding the hijackers is fine because it names a fact; seeding
    /// this would be answering the only question on the flow that requires
    /// someone to be honest with themselves.
    var blocker: Blocker? = nil
    /// Anchors that exist in their day — what cues get attached to.
    var dayAnchors: Set<DayAnchor> = []

    // MARK: ⭐ v3 pain sweep (Jack approved 2026-10-09). None pre-selected: these
    // are admissions, and an answer handed to you is not one you made (same
    // reasoning as `blocker`).

    /// When it gets them. Multi, ≥ 1.
    var whenItGets: Set<PullMoment> = []
    /// How they feel after. Single.
    var feelAfter: AfterFeeling? = nil
    /// What they already tried. Multi, ≥ 1; "Nothing yet" is exclusive.
    var triedBefore: Set<TriedFix> = []

    var orderedWhenItGets: [PullMoment] { PullMoment.allCases.filter(whenItGets.contains) }
    var orderedTriedBefore: [TriedFix] { TriedFix.allCases.filter(triedBefore.contains) }

    /// True when they named a real fix that failed (anything but "Nothing yet").
    var triedSomething: Bool { triedBefore.contains { $0 != .nothing } }

    // MARK: ⭐ Onboarding v2 answers (Jack approved 2026-10-08).
    //
    // The retired `specifics` step asked for a NOUN per goal ("Dune"); v2 asks
    // for the goal itself in the user's words, which is what a planner can
    // actually size steps against. `domainObjects` / `PlanPersonaliser` are no
    // longer fed from onboarding: their templates take a noun, and a sentence
    // dropped into "Read 10 pages of {o}" reads as broken English.

    /// The goal in their own words, per goal: the sentence they built in the
    /// goal builder, or the sharper version they took.
    var goalWords: [ActivityDomain: String] = [:]
    /// Where they are with the primary goal today. Nil until tapped.
    var baseline: GoalBaseline? = nil
    /// "What's the next real piece?" Optional.
    var nextPiece: String = ""
    /// Honest minutes a day, 15…120 in steps of 5 (120 reads "2h+").
    var minutesPerDay: Int = 45
    /// The day, in minutes after midnight. Class or work is optional.
    var wakeMinutes: Int = 7 * 60 + 30
    var busyStartMinutes: Int? = 9 * 60
    var busyEndMinutes: Int? = 17 * 60
    var sleepMinutes: Int = 23 * 60 + 30
    /// Encoded FamilyActivitySelection — the "Do it now" allow-list.
    var allowSelectionData: Data? = nil
    /// When the standing feed block runs. Pre-selected Always (the mockup).
    var feedSchedule: FeedSchedule = .always
    var feedCustomStart: Int = 21 * 60
    var feedCustomEnd: Int = 7 * 60
    /// Calendar weekdays, 1 = Sunday.
    var feedCustomWeekdays: Set<Int> = Set(1...7)
    /// Shield lines PlanService wrote; persisted with the profile.
    var shieldLines: [ActivityDomain: ShieldLine] = [:]
    /// What the menu hero serves, in order. Set once the plan is final.
    private(set) var servedSteps: [ServedStep] = []

    /// The goals that get a words field — the plan holds at most three.
    var goalWordDomains: [ActivityDomain] { Array(rankedDomains.prefix(3)) }

    /// Encoded FamilyActivitySelection from the real picker (entitled only).
    /// ⭐ Written for the first time 2026-08-13 by `PickAppsStepView`. Until then
    /// nothing ever assigned it, so every profile persisted a nil selection and
    /// no app was ever shielded.
    var familySelectionData: Data? = nil

    /// Whether Screen Time access was actually granted — set by the permission
    /// step so `advance()` can skip the picker when there is nothing to pick.
    var screenTimeAuthorized = false

    /// ⭐ Did the user ACTUALLY start a free trial at the onboarding paywall?
    /// Set only by a successful purchase of the trial-bearing annual plan while
    /// StoreKit-eligible. Gates the `.dinnerBell` cancel-reminder step: a
    /// monthly subscriber, a restorer, and a free-tier user never get told
    /// "we'll remind you before your free trial ends" — they have no trial.
    var startedFreeTrial = false

    /// Set when the flow has no steps left. `OnboardingView` watches this and
    /// persists + hands off — previously `firstServing` owned that job, and it
    /// was deleted with the duplicate plate moment.
    var didFinish = false

    /// The plan generated on the building step; persisted on completion.
    private(set) var generatedPlan: GoalPlan? = nil

    #if DEBUG
    /// Screenshot helper: jump to a step with coherent seeded state.
    func jumpToStepIfRequested() {
        guard let raw = ProcessInfo.processInfo.environment["BD_ONBOARDING_STEP"] else { return }
        selectedHijackers = [.shortVideo, .social, .youtube]
        timeLostHours = 3
        selectedDomains = [.reading, .fitness, .building]
        primaryDomain = .reading
        aspiration = "Reading every night."
        blocker = .distracted
        whenItGets = [.sitDownToWork, .waiting, .bedtime]
        feelAfter = .behind
        triedBefore = [.screenTimeLimits, .willpower]
        // The mockup's own answers (design/onboarding-v2/screens.html), so the
        // hero and every v2 screen reviews real words, not placeholders.
        // Jack's mock4 picks: launched (1), a book a month (2), strongest (3).
        pickedScenes = [.launched, .readMonth, .strongest]
        syncDomainsFromScenes()
        drafts = [.launched: Self.mockDraft(.launched),
                  .readMonth: Self.mockDraft(.readMonth),
                  .strongest: Self.mockDraft(.strongest)]
        goalReasons = [.building: .prove, .reading: .years, .fitness: .tired]
        aspiration = GoalReason.prove.aspiration
        goalWords = [.reading: "Finish Dune, then read 12 books by next summer",
                     .building: "Launch BrainDiet on the App Store and get 100 users at ASU",
                     .fitness: "Upper body twice a week, bench 225 by May"]
        baseline = .inconsistent
        nextPiece = "Finish the App Store listing"
        busyEndMinutes = 15 * 60
        dayAnchors = [.morningCoffee, .bedtime]
        // BD_DOMAINS=reading+creating+music — override the seeded domain set so a
        // shot can prove the surfaces that vary BY CATEGORY (the plan card's four
        // row colours + its dish art). PLUS-separated (the screenshot helper
        // splits its env list on commas). Unknown names are ignored.
        if let raw = ProcessInfo.processInfo.environment["BD_DOMAINS"] {
            let picked = raw.split(whereSeparator: { $0 == "+" || $0 == "," }).compactMap {
                ActivityDomain(rawValue: $0.trimmingCharacters(in: .whitespaces))
            }
            if !picked.isEmpty {
                selectedDomains = picked
                primaryDomain = picked[0]
            }
        }
        // ⭐ THE TARGET STEP'S OWN ANSWER GOES BACK TO ITS REAL DEFAULT.
        //
        // The seeding above fills every field, which is right for the steps
        // BEHIND the jump and wrong for the step itself: jumping to `.hijack`
        // rendered three tiles already muted — the fixture's answer, not the
        // app's default — so a screenshot of a question could never show what a
        // real user actually arrives at.
        //
        // Third instance of this failure class on 2026-09-16 (the other two were
        // `DemoSeed`: no self-reported sessions, and a profile dated today beside
        // thirty days of history). **A fixture that does not resemble a real user
        // turns every screenshot review into a guess.**
        let filled = ProcessInfo.processInfo.environment["BD_OB_FILLED"] == "1"
        switch raw {
        case "hijack":        selectedHijackers = Self.defaultHijackers
        // Goal builder: real defaults unless BD_OB_FILLED=1 (mock4's answers).
        case "goalScenes" where !filled:
            pickedScenes = []; syncDomainsFromScenes()
        case "goalSentence":
            builderIndex = 0
            drafts[.launched] = filled
                ? GoalDraft(choices: [.option(0), .option(1), nil], active: 1)
                : GoalDraft(blankCount: 3)
        case "goalSharpen":
            builderIndex = 0
            let mine = builtSentence(for: .launched) ?? ""
            if filled {
                let opts = SharpenService.stub(for: sharpenRequest(scene: .launched, sentence: mine))
                sharpen[.launched] = .ready(mine, opts)
                pickSharpen(0)
            } else {
                sharpen[.launched] = .loading(mine)
            }
        case "goalWhy":
            builderIndex = 0
            let mine = builtSentence(for: .launched) ?? ""
            sharpen[.launched] = .ready(mine, SharpenService.stub(for: sharpenRequest(scene: .launched, sentence: mine)))
            pickSharpen(0)
            if !filled { goalReasons[.building] = nil }
        case "baseline" where !filled:
            baseline = nil; nextPiece = ""
        case "baseline":
            primaryDomain = .building
        case "timeAndDay" where !filled:
            minutesPerDay = 45; wakeMinutes = 450; busyStartMinutes = 540
            busyEndMinutes = 1020; sleepMinutes = 1410; dayAnchors = []
        case "timeAndDay":
            sleepMinutes = 30           // 12:30, the mockup
        case "blocker":       blocker = nil
        case "whenItGets" where !filled:  whenItGets = []
        case "feelAfter" where !filled:   feelAfter = nil
        case "triedBefore" where !filled: triedBefore = []
        // BD_TRIED=nothing previews the other headline.
        case "emptyTimeInsight"
            where ProcessInfo.processInfo.environment["BD_TRIED"] == "nothing":
            triedBefore = [.nothing]
        default:              break
        }

        switch raw {
        case "welcome":       step = .welcome
        case "hijack":        step = .hijack
        case "timeLost":      timeLostHours = nil; step = .timeLost
        case "goalScenes":    step = .goalScenes
        case "goalSentence":  step = .goalSentence
        case "goalSharpen":   step = .goalSharpen
        case "goalWhy":       step = .goalWhy
        case "baseline":      step = .baseline
        case "timeAndDay":    step = .timeAndDay
        case "reachAndSchedule": step = .reachAndSchedule
        case "menuHero":      step = .menuHero
        case "blocker":       step = .blocker
        case "whenItGets":    step = .whenItGets
        case "feelAfter":     step = .feelAfter
        case "triedBefore":   step = .triedBefore
        case "emptyTimeInsight", "interstitial": step = .emptyTimeInsight
        case "cueInsight":    step = .cueInsight
        case "pause":         step = .pause
        case "screenAccess":  step = .screenAccess
        case "pickApps":      step = .pickApps
        case "building":      step = .building
        case "mirror":        step = .mirror
        case "commit":        step = .commit
        case "planReveal":    step = .planReveal
        case "onboardingPaywall": step = .onboardingPaywall
        // The reminder step is reachable for screenshots even though the real
        // flow only reaches it after a real trial purchase.
        case "dinnerBell":    startedFreeTrial = true; step = .dinnerBell
        default: break
        }
    }
    #endif

    // MARK: Ordered / derived helpers

    /// Hijackers in catalog order (stable for persistence + display).
    var orderedHijackers: [AttentionHijacker] {
        AttentionHijacker.allCases.filter { selectedHijackers.contains($0) }
    }

    /// Domains with the primary first (the plan's ranking).
    var rankedDomains: [ActivityDomain] {
        guard let primaryDomain, selectedDomains.contains(primaryDomain) else { return selectedDomains }
        return [primaryDomain] + selectedDomains.filter { $0 != primaryDomain }
    }

    /// Legacy goal keys (GoalCatalog), primary first, deduped — for the reframe engine.
    var derivedGoalIDs: [String] {
        var ids: [String] = []
        for d in rankedDomains where !ids.contains(d.legacyGoalID) { ids.append(d.legacyGoalID) }
        return ids
    }

    /// The apps to rest — the shield selection + Mental Diet junk set.
    // TEMP default block list — hijackers are pure framing now; the real list comes from Apple's FamilyActivityPicker later.
    var derivedJunkAppIDs: [String] {
        ["instagram", "tiktok", "youtube"]
    }

    /// Auto-seeded Mental Diet categories (no dedicated step now): the monitored
    /// catalog + the hijacker-derived apps, with those apps flagged junk.
    var derivedAppCategories: [String: AppCategory] {
        var map: [String: AppCategory] = [:]
        let junk = Set(derivedJunkAppIDs)
        var appIDs = MonitoredAppOption.catalog.map(\.id)
        for id in derivedJunkAppIDs where !appIDs.contains(id) { appIDs.append(id) }
        for id in appIDs {
            map[id] = junk.contains(id) ? .junk : AppCategoryCatalog.defaultCategory(forAppID: id)
        }
        return map
    }

    /// The baseline comes straight from the scrubbed hours (honest — no band
    /// midpoint rounding); 90m only in never-answered edge states.
    var baselineJunkMinutes: Int { timeLostHours.map { $0 * 60 } ?? 90 }

    /// The judged inputs, if complete enough to plan.
    var answers: OnboardingAnswers? {
        guard let timeLostBand, let primaryDomain, let blocker, !selectedDomains.isEmpty else { return nil }
        return OnboardingAnswers(
            hijackers: orderedHijackers,
            timeLost: timeLostBand,
            domains: selectedDomains,
            primaryDomain: primaryDomain,
            aspiration: aspiration,
            blocker: blocker,
            // The named things go to the on-device model as its "in their own
            // words" block, so where the model runs its wording already names them.
            // The goal words ARE the "in their own words" block now.
            dreamDetails: DreamDetails.normalise(
                goalWordDomains.compactMap { goalWords[$0] } + [nextPiece]),
            dailyAnchors: DayAnchor.allCases.filter(dayAnchors.contains).map(\.rawValue),
            goalWords: goalWords,
            baseline: baseline,
            nextPiece: nextPiece,
            minutesPerDay: minutesPerDay,
            wakeMinutes: wakeMinutes,
            busyStartMinutes: busyStartMinutes,
            busyEndMinutes: busyEndMinutes,
            sleepMinutes: sleepMinutes,
            whenItGets: orderedWhenItGets,
            feelAfter: feelAfter,
            triedBefore: orderedTriedBefore,
            goalScenes: pickedScenes,
            goalReasons: goalReasons.filter { goalWordDomains.contains($0.key) }
        )
    }

    // MARK: Plan-reveal (BrainPlan nutrition label) inputs

    var headlineGoalID: String? { (primaryDomain ?? selectedDomains.first)?.legacyGoalID }
    var goalNoun: String { GoalCatalog.noun(for: headlineGoalID) }

    func makePlan() -> BrainPlan {
        BrainPlan.generate(
            goalID: headlineGoalID,
            goalNoun: goalNoun,
            why: aspiration,
            baselineJunkMinutes: baselineJunkMinutes
        )
    }

    /// The goals the reveal's "Your Brain Diet" document prints as DAILY SERVINGS
    /// — the generated plan, or the deterministic floor for jumped/edge states.
    var revealGoals: [PlannedGoal] {
        (generatedPlan ?? answers.map { HeuristicGoalPlanner.plan(from: $0) })?.goals ?? []
    }

    // MARK: Persistence

    /// Persist the UserProfile + the generated GoalPlan. Single-profile app: wipes
    /// any prior profile + plan first.
    func persistProfile(into context: ModelContext) {
        for p in (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [] { context.delete(p) }
        for g in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] { context.delete(g) }
        for s in (try? context.fetch(FetchDescriptor<GoalStep>())) ?? [] { context.delete(s) }

        let profile = UserProfile(
            goalIDs: derivedGoalIDs,
            why: primaryAspiration,
            baselineJunkMinutes: baselineJunkMinutes,
            junkAppIDs: derivedJunkAppIDs,
            familySelectionData: familySelectionData,
            appCategories: derivedAppCategories,
            hijackers: orderedHijackers,
            domains: rankedDomains,
            primaryDomain: primaryDomain,
            blocker: blocker,
            planIdentityLine: (generatedPlan?.identityLine ?? aspiration).trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(profile)
        // v2 answers.
        profile.goalWords = goalWords.filter { goalWordDomains.contains($0.key) }
        profile.dreamDetails = answers?.dreamDetails ?? []
        profile.baselineRaw = baseline?.rawValue ?? ""
        profile.nextPiece = nextPiece.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.minutesPerDay = minutesPerDay
        profile.wakeMinutes = wakeMinutes
        profile.busyStartMinutes = busyStartMinutes ?? -1
        profile.busyEndMinutes = busyEndMinutes ?? -1
        profile.sleepMinutes = sleepMinutes
        profile.dayAnchorsRaw = DayAnchor.allCases.filter(dayAnchors.contains).map(\.rawValue).joined(separator: ",")
        profile.allowSelectionData = allowSelectionData
        profile.feedScheduleRaw = feedSchedule.rawValue
        profile.feedCustomStart = feedCustomStart
        profile.feedCustomEnd = feedCustomEnd
        profile.feedCustomWeekdaysRaw = feedCustomWeekdays.sorted().map(String.init).joined(separator: ",")
        profile.shieldLines = shieldLines
        // v3 pain sweep.
        profile.whenItGetsRaw = orderedWhenItGets.map(\.rawValue).joined(separator: ",")
        profile.feelAfterRaw = feelAfter?.rawValue ?? ""
        profile.triedBeforeRaw = orderedTriedBefore.map(\.rawValue).joined(separator: ",")
        // Goal builder.
        profile.goalScenesRaw = pickedScenes.map(\.rawValue).joined(separator: ",")
        profile.goalReasons = goalReasons.filter { goalWordDomains.contains($0.key) }
        var shorts: [ActivityDomain: String] = [:]
        for scene in pickedScenes { shorts[scene.domain] = shortGoal(for: scene) }
        profile.goalShorts = shorts

        // Materialise the plan (fall back to the deterministic floor if generation
        // never ran — e.g. jumped state).
        let plan = generatedPlan ?? answers.map { HeuristicGoalPlanner.plan(from: $0) }
        plan?.persist(into: context)

        try? context.save()
        Log.onboarding.info("Persisted profile + plan (\(plan?.goals.count ?? 0, privacy: .public) goals, baseline \(self.baselineJunkMinutes, privacy: .public)m)")
    }

    // MARK: Per-step validation (gates the single primary CTA)

    var canAdvance: Bool {
        switch step {
        case .hijack:        return !selectedHijackers.isEmpty
        case .whenItGets:    return !whenItGets.isEmpty
        case .feelAfter:     return feelAfter != nil
        case .triedBefore:   return !triedBefore.isEmpty
        case .goalScenes:    return !pickedScenes.isEmpty
        // Every blank filled: the plan is only as specific as this sentence.
        case .goalSentence:  return currentScene.map { draft(for: $0).isComplete } ?? false
        case .goalWhy:       return currentScene.map { goalReasons[$0.domain] != nil } ?? false
        case .baseline:      return baseline != nil
        case .blocker:       return blocker != nil   // slide 7 = the obstacle question
        // timeLost always advances: an untouched scrubber commits the honest
        // "I don't know" default (Opal's friction-free escape).
        default:             return true
        }
    }

    // MARK: Navigation

    func advance() {
        // Leaving timeLost untouched = the "I don't know" default.
        if step == .timeLost, timeLostHours == nil {
            timeLostHours = Self.defaultTimeLostHours
        }
        // Leaving the domains step: drop a stale primary, then default to their
        // FIRST pick.
        //
        // ⭐ DERIVED, NOT GUESSED (2026-09-16). This used to auto-pick only when
        // exactly one domain was chosen, so anyone who picked two or three
        // landed on the next screen with nothing selected and the CTA dead.
        // Seeding it with their own first tap is the smart default done
        // honestly: the app is not deciding what matters most to them, it is
        // proposing the thing they reached for first and letting them move it.
        //
        // This is also why `selectedDomains` itself is NOT pre-filled. Defaulting
        // which parts of a life someone is building would hand most users a plan
        // for a life they never chose — and personalization is the entire
        // product, so buying conversion with it is buying it with the thing
        // being sold.
        if step == .goalScenes || step.isPerGoal {
            advanceGoalBuilder()
            return
        }
        guard let next = nextRoutedStep(after: step) else {
            didFinish = true          // ran off the end = done
            return
        }
        withAnimation(Theme.Motion.snappy) { step = next }
        Log.onboarding.info("Advanced to step \(next.rawValue, privacy: .public)")
    }

    func back() {
        if step == .goalScenes || step.isPerGoal || step == .baseline {
            if backGoalBuilder() { return }
        }
        var prev = OnboardingStep(rawValue: step.rawValue - 1)
        while let p = prev, !isRouted(p) { prev = OnboardingStep(rawValue: p.rawValue - 1) }
        guard let prev else { return }
        withAnimation(Theme.Motion.snappy) { step = prev }
    }

    /// ⭐ THE ONE PLACE A STEP IS SKIPPED. Forward and back both read it, so the
    /// back chevron can never land on a step the flow would not show.
    func isRouted(_ s: OnboardingStep) -> Bool {
        switch s {
        // ⭐ Nothing to pick without Screen Time access (2026-08-13). A user who
        // declined at the system sheet would otherwise land on a picker that
        // returns an empty selection no matter what they tap.
        case .pickApps:   return screenTimeAuthorized
        // v2 (2026-10-08): the plan is served after the paywall by `menuHero`.
        case .planReveal: return false
        // ⭐ The cancel-reminder step exists only for people who really started a
        // trial — we never promise a reminder for a trial that isn't running.
        case .dinnerBell: return startedFreeTrial
        default:          return true
        }
    }

    func nextRoutedStep(after s: OnboardingStep) -> OnboardingStep? {
        var next = OnboardingStep(rawValue: s.rawValue + 1)
        while let n = next, !isRouted(n) { next = OnboardingStep(rawValue: n.rawValue + 1) }
        return next
    }

    // MARK: Menu hero — the served plan.

    /// Fold the server's plan into the plan the app already has and remember
    /// its shield lines. Nil = server failed: the heuristic plan stands.
    func applyServed(_ served: ServedPlan?) {
        let base = generatedPlan ?? answers.map { HeuristicGoalPlanner.plan(from: $0) }
        if let served {
            generatedPlan = base?.merging(served)
            shieldLines = served.shield
            servedSteps = served.steps
        } else {
            generatedPlan = base
            // Fallback menu: each goal's first step, primary first.
            servedSteps = (base?.goals ?? []).prefix(3).compactMap { g in
                g.steps.first.map { ServedStep(domain: g.domain, step: $0, why: "") }
            }
        }
    }

    func finishOnboarding() { didFinish = true }

    // MARK: Toggles

    func toggleHijacker(_ h: AttentionHijacker) {
        if selectedHijackers.contains(h) { selectedHijackers.remove(h) }
        else { selectedHijackers.insert(h) }
    }

    func togglePullMoment(_ m: PullMoment) {
        if whenItGets.contains(m) { whenItGets.remove(m) } else { whenItGets.insert(m) }
    }

    /// "Nothing yet" can't sit beside a fix they tried: picking it clears the
    /// rest, and picking a fix clears it.
    func toggleTriedFix(_ f: TriedFix) {
        if triedBefore.contains(f) { triedBefore.remove(f); return }
        if f == .nothing { triedBefore = [.nothing] }
        else { triedBefore.remove(.nothing); triedBefore.insert(f) }
    }

    // MARK: Build → mirror — runs the planner once, then hands to the mirror.
    //
    // Opal mapping row 7: the loading theater ("Reading your day…") PRECEDES
    // the mirror — the report reads as computed-for-you work.

    func runBuildingThenMirror() async {
        if let answers {
            let planner = GoalPlannerFactory.make()
            generatedPlan = await planner.makePlan(from: answers)
        }
        // Let the honest assembly lines land in full (~3 × 0.8s) even when the
        // heuristic planner returns instantly.
        try? await Task.sleep(for: .seconds(2.4))
        withAnimation(Theme.Motion.snappy) { step = .mirror }
    }
}
