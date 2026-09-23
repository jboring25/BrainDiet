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
    /// Q3 — domains to pour time into (order preserved = pick order).
    var selectedDomains: [ActivityDomain] = []
    /// Q4 — the one that matters most.
    var primaryDomain: ActivityDomain? = nil
    /// Q5 — free-text aspiration ("who are you trying to become?").
    var aspiration: String = ""
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
    /// The concrete thing they are working toward, in their words. Optional.
    var specificGoal: String = ""
    /// Anchors that exist in their day — what cues get attached to.
    var dayAnchors: Set<DayAnchor> = []
    /// ⭐ THE THING ITSELF, per chosen domain (2026-09-21) — "Dune", "your app",
    /// "Spanish". The one fact the planner could never know, and the reason the
    /// plan used to hand every reader the same three lines. One tap on a
    /// suggestion is enough; typing is only for people who want their exact
    /// thing. Empty for a domain = that domain's steps stay generic.
    var domainObjects: [ActivityDomain: String] = [:]

    /// The plan with each domain's thing named in it — see `PlanPersonaliser`.
    /// Every path that produces a plan goes through here, so the reveal, the
    /// fallback and the persisted rows can never disagree about what it says.
    private func personalised(_ plan: GoalPlan) -> GoalPlan {
        PlanPersonaliser.apply(plan, objects: domainObjects)
    }

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
        // Real users name their thing now, so the fixture does too — otherwise
        // every reveal screenshot reviews the generic fallback, not the product.
        domainObjects = [.reading: "Dune", .fitness: "lifting", .building: "your app"]
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
        switch raw {
        case "hijack":        selectedHijackers = Self.defaultHijackers
        case "domains":       selectedDomains = []; primaryDomain = nil
        case "primaryDomain": primaryDomain = selectedDomains.first   // the derived default
        case "aspiration":    aspiration = ""
        case "specifics":     specificGoal = ""; dayAnchors = []; domainObjects = [:]
        case "blocker":       blocker = nil
        default:              break
        }

        switch raw {
        case "welcome":       step = .welcome
        case "hijack":        step = .hijack
        case "timeLost":      timeLostHours = nil; step = .timeLost
        case "domains":       selectedDomains = [.reading, .fitness]; step = .domains
        case "primaryDomain": step = .primaryDomain
        case "aspiration":    step = .aspiration
        case "specifics":     step = .specifics
        case "blocker":       step = .blocker
        case "interstitial":  step = .interstitial
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
            dreamDetails: DreamDetails.normalise(
                rankedDomains.compactMap { domainObjects[$0] } + [specificGoal]),
            dailyAnchors: DayAnchor.allCases.filter(dayAnchors.contains).map(\.rawValue)
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
        (generatedPlan ?? answers.map { personalised(HeuristicGoalPlanner.plan(from: $0)) })?.goals ?? []
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
            why: aspiration,
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
        // Remember each named thing, so "Make it yours" offers it back as the
        // first chip instead of asking the same question a second time.
        for (domain, object) in domainObjects {
            profile.rememberStepObject(object, for: domain)
        }

        // Materialise the plan (fall back to the deterministic floor if generation
        // never ran — e.g. jumped state).
        let plan = generatedPlan ?? answers.map { personalised(HeuristicGoalPlanner.plan(from: $0)) }
        plan?.persist(into: context)

        try? context.save()
        Log.onboarding.info("Persisted profile + plan (\(plan?.goals.count ?? 0, privacy: .public) goals, baseline \(self.baselineJunkMinutes, privacy: .public)m)")
    }

    // MARK: Per-step validation (gates the single primary CTA)

    var canAdvance: Bool {
        switch step {
        case .hijack:        return !selectedHijackers.isEmpty
        case .domains:       return !selectedDomains.isEmpty
        case .primaryDomain: return primaryDomain != nil
        case .aspiration:    return !aspiration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // The text is OPTIONAL — anchors alone already make the cues real, and a
        // required keyboard in the middle of onboarding is how you lose people.
        case .specifics:     return true
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
        if step == .domains {
            if let p = primaryDomain, !selectedDomains.contains(p) { primaryDomain = nil }
            if primaryDomain == nil { primaryDomain = selectedDomains.first }
        }
        guard var next = OnboardingStep(rawValue: step.rawValue + 1) else {
            didFinish = true          // ran off the end = done
            return
        }
        // ⭐ Nothing to pick without Screen Time access (2026-08-13). A user who
        // declined at the system sheet would otherwise land on a picker that
        // returns an empty selection no matter what they tap — a dead screen
        // that also teaches them the app is broken. `screenAccess` advances
        // unconditionally on grant OR denial, so this is the only guard.
        if next == .pickApps, !screenTimeAuthorized {
            next = .building
        }
        // ⭐ The cancel-reminder step exists only for people who really started a
        // trial. Everyone else (monthly, restore, "Not now"/free tier, or an
        // account StoreKit wouldn't grant a trial) goes straight to the first
        // serving — we never promise a reminder for a trial that isn't running.
        if next == .dinnerBell, !startedFreeTrial {
            didFinish = true          // no trial → no reminder step → done
            return
        }
        withAnimation(Theme.Motion.snappy) { step = next }
        Log.onboarding.info("Advanced to step \(next.rawValue, privacy: .public)")
    }

    func back() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(Theme.Motion.snappy) { step = prev }
    }

    // MARK: Toggles

    func toggleHijacker(_ h: AttentionHijacker) {
        if selectedHijackers.contains(h) { selectedHijackers.remove(h) }
        else { selectedHijackers.insert(h) }
    }

    func toggleDomain(_ d: ActivityDomain) {
        if let idx = selectedDomains.firstIndex(of: d) {
            selectedDomains.remove(at: idx)
            if primaryDomain == d { primaryDomain = nil }
        } else {
            selectedDomains.append(d)
        }
    }

    // MARK: Build → mirror — runs the planner once, then hands to the mirror.
    //
    // Opal mapping row 7: the loading theater ("Reading your day…") PRECEDES
    // the mirror — the report reads as computed-for-you work.

    func runBuildingThenMirror() async {
        if let answers {
            let planner = GoalPlannerFactory.make()
            generatedPlan = personalised(await planner.makePlan(from: answers))
        }
        // Let the honest assembly lines land in full (~3 × 0.8s) even when the
        // heuristic planner returns instantly.
        try? await Task.sleep(for: .seconds(2.4))
        withAnimation(Theme.Motion.snappy) { step = .mirror }
    }
}
