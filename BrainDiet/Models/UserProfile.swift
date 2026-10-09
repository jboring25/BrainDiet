import Foundation
import SwiftData

// MARK: - UserProfile — persisted onboarding answers (Functional M1).
//
// The single persisted record of who the user is + their baseline. The reframe
// engine and the generated BrainPlan read from this. Local-first (SwiftData) —
// now the ONLY persisted model (the manual Diary is gone; usage is automatic).
// One row per user; created at onboarding completion. Survives relaunch.

@Model
final class UserProfile {

    /// Selected goal IDs from onboarding (GoalOption.id). First = headline goal.
    var goalIDsRaw: String           // comma-joined ids (SwiftData-simple)
    /// The user's free-text "why".
    var why: String
    /// Their stated current short-form baseline, in minutes/day (from ShortFormBand).
    var baselineJunkMinutes: Int
    /// Selected junk-app IDs (JunkAppOption.id) — degraded-mode mock list.
    var junkAppIDsRaw: String        // comma-joined ids
    /// Encoded FamilyActivitySelection (real Screen Time tokens). Nil until the
    /// user picks apps via the real FamilyActivityPicker (entitled builds only).
    var familySelectionData: Data?
    /// JSON map of appID → AppCategory.rawValue — the one-time "Today's Mental
    /// Diet" categorization (spec-v2.1). Set once at setup with smart defaults,
    /// adjustable in Settings; NEVER a daily log. Empty until categorization runs.
    var appCategoriesRaw: String
    /// When onboarding completed.
    var createdAt: Date

    // MARK: Judged onboarding answers (spec-v2.6) — the raw material the goal
    // planner interprets, kept so "Adjust plan" can re-derive without re-asking.
    /// Q1 — attention hijackers (AttentionHijacker.id), comma-joined.
    var hijackersRaw: String = ""
    /// Q3 — chosen domains (ActivityDomain.rawValue), comma-joined (order preserved).
    var domainsRaw: String = ""
    /// Q4 — the single primary domain (ActivityDomain.rawValue).
    var primaryDomainRaw: String = ""
    /// Q6 — what's stopped them before (Blocker.rawValue).
    var blockerRaw: String = ""
    /// The plan-level identity line (personalised by the planner) — the header on
    /// the Reclaim tab. Falls back to the raw aspiration when generation didn't run.
    var planIdentityLine: String = ""
    /// ⭐ 2026-08-07 — the user's actual THINGS, remembered per domain ("Dune"
    /// for reading, "push day" for fitness). JSON map of
    /// ActivityDomain.rawValue → [String], most-recent first.
    ///
    /// This is the friction fix for "Make it mine": the object is the one fact
    /// the app cannot derive, so it has to be typed — but only ONCE. On every
    /// later visit it comes back as a chip and the whole interaction collapses
    /// to a single tap. Defaults to "" (lightweight SwiftData migration).
    var stepObjectsRaw: String = ""
    /// ⭐ 2026-08-06 — the bounded "in your own words" entries (see `DreamDetails`).
    /// NEWLINE-joined rather than comma-joined: these are sentences and commas
    /// inside them are expected, so a comma separator would shred them.
    /// Defaulted to "" so this is a LIGHTWEIGHT SwiftData migration — existing
    /// TestFlight installs keep their profile row untouched.
    var dreamDetailsRaw: String = ""

    // MARK: ⭐ THE ACTING LIMIT (Jack, 2026-08-11) — see `PlanningLimit`.
    //
    // Planning actions taken since the user last actually ran a session, and
    // when that counting window opened. Both default so this stays a lightweight
    // migration. Never read these directly — go through the two helpers below,
    // which resolve the window against the real session history.
    var planCount: Int = 0
    // Fully qualified — the @Model macro cannot resolve `.distantPast` shorthand.
    var planWindowStart: Date = Date.distantPast

    // MARK: ⭐ Onboarding v2 (Jack approved 2026-10-08). Every field defaulted:
    // lightweight SwiftData migration, existing installs keep their row.

    /// JSON map ActivityDomain.rawValue → the goal in their own words.
    var goalWordsRaw: String = ""
    /// GoalBaseline.rawValue for the primary goal.
    var baselineRaw: String = ""
    /// "What's the next real piece?" Optional.
    var nextPiece: String = ""
    /// Honest minutes a day (15…120). 0 = never answered.
    var minutesPerDay: Int = 0
    /// Minutes after midnight. -1 = never answered.
    var wakeMinutes: Int = -1
    var busyStartMinutes: Int = -1
    var busyEndMinutes: Int = -1
    var sleepMinutes: Int = -1
    /// DayAnchor.rawValue, comma-joined.
    var dayAnchorsRaw: String = ""
    /// Encoded FamilyActivitySelection: the apps "Do it now" leaves reachable.
    var allowSelectionData: Data?
    /// FeedSchedule.rawValue. Empty reads as `.always`.
    var feedScheduleRaw: String = ""
    /// Custom schedule window (minutes after midnight) + weekdays (1 = Sunday).
    var feedCustomStart: Int = 1260
    var feedCustomEnd: Int = 420
    var feedCustomWeekdaysRaw: String = "1,2,3,4,5,6,7"
    /// JSON map ActivityDomain.rawValue → {"wish","go"} from PlanService. When a
    /// domain has a line here the shield speaks it instead of the stock copy.
    var shieldLinesRaw: String = ""

    // MARK: ⭐ Onboarding v3 pain sweep (Jack approved 2026-10-09). Defaulted:
    // lightweight migration. Comma-joined raw values.
    var whenItGetsRaw: String = ""
    var feelAfterRaw: String = ""
    var triedBeforeRaw: String = ""

    init(
        goalIDs: [String],
        why: String,
        baselineJunkMinutes: Int,
        junkAppIDs: [String],
        familySelectionData: Data? = nil,
        appCategories: [String: AppCategory] = [:],
        hijackers: [AttentionHijacker] = [],
        domains: [ActivityDomain] = [],
        primaryDomain: ActivityDomain? = nil,
        blocker: Blocker? = nil,
        planIdentityLine: String = "",
        createdAt: Date = .now
    ) {
        self.goalIDsRaw = goalIDs.joined(separator: ",")
        self.why = why.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baselineJunkMinutes = baselineJunkMinutes
        self.junkAppIDsRaw = junkAppIDs.joined(separator: ",")
        self.familySelectionData = familySelectionData
        self.appCategoriesRaw = Self.encode(appCategories)
        self.hijackersRaw = hijackers.map(\.rawValue).joined(separator: ",")
        self.domainsRaw = domains.map(\.rawValue).joined(separator: ",")
        self.primaryDomainRaw = primaryDomain?.rawValue ?? ""
        self.blockerRaw = blocker?.rawValue ?? ""
        self.planIdentityLine = planIdentityLine
        self.createdAt = createdAt
    }

    // MARK: Typed accessors

    var goalIDs: [String] {
        goalIDsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }
    var junkAppIDs: [String] {
        junkAppIDsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }
    var headlineGoalID: String? { goalIDs.first }

    // MARK: Judged-answer accessors (spec-v2.6)

    var hijackers: [AttentionHijacker] {
        hijackersRaw.split(separator: ",").compactMap { AttentionHijacker(rawValue: String($0)) }
    }
    var domains: [ActivityDomain] {
        domainsRaw.split(separator: ",").compactMap { ActivityDomain(rawValue: String($0)) }
    }
    var primaryDomain: ActivityDomain? { ActivityDomain(rawValue: primaryDomainRaw) }
    var blocker: Blocker? { Blocker(rawValue: blockerRaw) }

    // MARK: v2 accessors

    var goalWords: [ActivityDomain: String] {
        get { Self.decodeDomainMap(goalWordsRaw, as: String.self) }
        set { goalWordsRaw = Self.encodeDomainMap(newValue) }
    }
    var baseline: GoalBaseline? { GoalBaseline(rawValue: baselineRaw) }
    var dayAnchors: [DayAnchor] {
        dayAnchorsRaw.split(separator: ",").compactMap { DayAnchor(rawValue: String($0)) }
    }
    var feedSchedule: FeedSchedule { FeedSchedule(rawValue: feedScheduleRaw) ?? .always }
    var feedCustomWeekdays: [Int] {
        feedCustomWeekdaysRaw.split(separator: ",").compactMap { Int($0) }
    }

    var whenItGets: [PullMoment] {
        whenItGetsRaw.split(separator: ",").compactMap { PullMoment(rawValue: String($0)) }
    }
    var feelAfter: AfterFeeling? { AfterFeeling(rawValue: feelAfterRaw) }
    var triedBefore: [TriedFix] {
        triedBeforeRaw.split(separator: ",").compactMap { TriedFix(rawValue: String($0)) }
    }

    /// The planner's shield lines, per domain. Empty until PlanService answers.
    var shieldLines: [ActivityDomain: ShieldLine] {
        get { Self.decodeDomainMap(shieldLinesRaw, as: ShieldLine.self) }
        set { shieldLinesRaw = Self.encodeDomainMap(newValue) }
    }

    private static func decodeDomainMap<V: Decodable>(_ raw: String, as: V.Type) -> [ActivityDomain: V] {
        guard let map = try? JSONDecoder().decode([String: V].self, from: Data(raw.utf8)) else { return [:] }
        var out: [ActivityDomain: V] = [:]
        for (k, v) in map { if let d = ActivityDomain(rawValue: k) { out[d] = v } }
        return out
    }

    private static func encodeDomainMap<V: Encodable>(_ map: [ActivityDomain: V]) -> String {
        var raw: [String: V] = [:]
        for (k, v) in map { raw[k.rawValue] = v }
        guard let data = try? JSONEncoder().encode(raw) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: Remembered step objects ("Make it mine")

    /// Max remembered things per domain. Four fills one chip row; beyond that
    /// the user is scanning a list instead of recognising an answer, which is
    /// the friction this was added to remove.
    static let maxStepObjects = 4

    /// The things this user has named for a domain, most-recent first.
    func stepObjects(for domain: ActivityDomain) -> [String] {
        Self.decodeObjects(stepObjectsRaw)[domain.rawValue] ?? []
    }

    /// Record a thing, moving it to the front if already known (so the one they
    /// keep using stays the first chip) and capping the list.
    func rememberStepObject(_ raw: String, for domain: ActivityDomain) {
        let object = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !object.isEmpty else { return }
        var map = Self.decodeObjects(stepObjectsRaw)
        var list = map[domain.rawValue] ?? []
        list.removeAll { $0.caseInsensitiveCompare(object) == .orderedSame }
        list.insert(object, at: 0)
        map[domain.rawValue] = Array(list.prefix(Self.maxStepObjects))
        stepObjectsRaw = Self.encodeObjects(map)
    }

    private static func decodeObjects(_ raw: String) -> [String: [String]] {
        guard let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return map
    }

    private static func encodeObjects(_ map: [String: [String]]) -> String {
        guard let data = try? JSONEncoder().encode(map) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// The bounded "in your own words" entries. Normalising on BOTH read and
    /// write means a row written by an older build (or hand-edited) can never
    /// hand the planner more entries or longer text than `DreamDetails` allows.
    var dreamDetails: [String] {
        get { DreamDetails.normalise(dreamDetailsRaw.components(separatedBy: "\n")) }
        set { dreamDetailsRaw = DreamDetails.normalise(newValue).joined(separator: "\n") }
    }

    // MARK: - ⭐ THE ACTING LIMIT (Jack, 2026-08-11)
    //
    // "Make sure the screen does not turn into mental masturbation and there is
    // a limit to how much you can plan without acting. That mindset should be
    // engrained into the app."
    //
    // WHAT IT GUARDS. Sharpening a step feels like progress and isn't — it is
    // the intention–behaviour gap with a nicer interface, and the substitution
    // effect says the good feeling of planning can stand in for doing the thing.
    // A personalisation surface with no ceiling is the most seductive dead end
    // we could ship, because every tap returns something that reads as work.
    //
    // WHY THE COUNT IS DERIVED, NOT STORED FLAT. The window has to reopen the
    // moment the user acts, and hooking "a session finished" from every place a
    // session can finish is exactly the kind of coupling that rots. Instead the
    // caller hands in the timestamp of the most recent session and the window
    // resolves itself: if they have acted since this window opened, the count is
    // zero and the next planning action starts a fresh window. No reset hook, no
    // surface that can forget to call it.
    //
    // NOT A PUNISHMENT. Reverting a personalisation is always allowed (it is
    // undoing, not planning), the plan itself stays fully readable, and the
    // limit clears the instant one real session starts. It costs nothing to
    // someone who is acting; it only binds someone who is circling.

    enum PlanningLimit {
        /// Sharpened steps allowed between real sessions.
        ///
        /// THREE, because three is exactly one pass over a plan: the default
        /// plan carries one goal per chosen domain, so a user can personalise
        /// every goal they have and then has to go do one. Two would interrupt a
        /// single honest setup pass; five stops being a limit and becomes a
        /// number nobody ever meets.
        static let maxBeforeAction = 3

        /// ⭐ THE SETTLING-IN GRACE (Jack, 2026-08-27): "only use it on extreme
        /// measures and not right away. Because the user should not be punished
        /// while settling into the app or the rhythm."
        ///
        /// He is right, and the old rule broke exactly this way: a user who has
        /// never run a session has `lastActionAt == nil`, so `planningsSinceAction`
        /// returned the raw `planCount` and a brand-new user could hit the wall
        /// on their FIRST evening — while still learning what a serving even is.
        /// For the first week the limit simply does not exist.
        ///
        /// The other half of his instruction ("even without rhythm, if they are
        /// getting it done it is fine") was already satisfied: any real session
        /// opens a new window, so someone who acts is never limited regardless of
        /// how irregularly they do it.
        static let graceDays = 7

        /// The line shown once the limit is reached. "Prep" is doing the work:
        /// meal prep is real, useful, and unmistakably NOT the meal — which is
        /// the whole argument in a word the audience already uses. No shame, and
        /// the exit is named in the same breath.
        static let reachedLine = String(localized: "That's your prep. Start one and you can sharpen the next.")
    }

    /// How many steps have been sharpened since the last real session.
    /// `lastActionAt` = the most recent `ProtectSession.startedAt`, or nil if
    /// the user has never run one.
    func planningsSinceAction(lastActionAt: Date?) -> Int {
        if let lastActionAt, lastActionAt > planWindowStart { return 0 }
        return planCount
    }

    /// True when the next sharpen would be planning without acting — and only
    /// once the user is past the settling-in grace.
    func atPlanningLimit(lastActionAt: Date?, now: Date = .now) -> Bool {
        let daysIn = Calendar.current.dateComponents([.day], from: createdAt, to: now).day ?? 0
        guard daysIn >= PlanningLimit.graceDays else { return false }
        return planningsSinceAction(lastActionAt: lastActionAt) >= PlanningLimit.maxBeforeAction
    }

    /// Count one sharpened step, opening a new window if they have acted since
    /// the current one started.
    func recordPlanning(lastActionAt: Date?) {
        if let lastActionAt, lastActionAt > planWindowStart {
            planCount = 1
            planWindowStart = .now
        } else {
            if planCount == 0 { planWindowStart = .now }
            planCount += 1
        }
    }

    /// Rebuild the planner inputs from the persisted answers (for "Adjust plan").
    /// Returns nil if the profile predates the judged-answers schema.
    func onboardingAnswers() -> OnboardingAnswers? {
        guard let primaryDomain, let blocker, !domains.isEmpty else { return nil }
        let band = ShortFormBand.allCases.first { $0.baselineMinutes == baselineJunkMinutes } ?? .oneToTwo
        return OnboardingAnswers(
            hijackers: hijackers,
            timeLost: band,
            domains: domains,
            primaryDomain: primaryDomain,
            aspiration: why,
            blocker: blocker,
            dreamDetails: dreamDetails,
            dailyAnchors: dayAnchors.map(\.rawValue),
            goalWords: goalWords,
            baseline: baseline,
            nextPiece: nextPiece,
            minutesPerDay: minutesPerDay > 0 ? minutesPerDay : nil,
            wakeMinutes: wakeMinutes >= 0 ? wakeMinutes : nil,
            busyStartMinutes: busyStartMinutes >= 0 ? busyStartMinutes : nil,
            busyEndMinutes: busyEndMinutes >= 0 ? busyEndMinutes : nil,
            sleepMinutes: sleepMinutes >= 0 ? sleepMinutes : nil,
            whenItGets: whenItGets,
            feelAfter: feelAfter,
            triedBefore: triedBefore
        )
    }

    /// Headline goal phrased as a noun for the reframe engine.
    var goalNoun: String { GoalCatalog.noun(for: headlineGoalID) }

    // MARK: App categories (Mental Diet)

    /// The one-time Mental Diet categorization: appID → nutrition class.
    var appCategories: [String: AppCategory] {
        get { Self.decode(appCategoriesRaw) }
        set { appCategoriesRaw = Self.encode(newValue) }
    }

    /// Whether the user has categorized their apps yet (drives the Mental Diet card).
    var hasCategorized: Bool { !appCategories.isEmpty }

    private static func encode(_ map: [String: AppCategory]) -> String {
        let raw = map.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(raw),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    private static func decode(_ raw: String) -> [String: AppCategory] {
        guard let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map.compactMapValues(AppCategory.init(rawValue:))
    }
}

// MARK: - Goal catalog — goal → noun + per-unit reframe conversion.
//
// The canonical goal mapping. Extends the old goalNoun switch and adds the
// "unit" (e.g. chapters) + minutes-per-unit so reclaimed time converts into
// concrete progress toward their life. Tunable constants.

enum GoalCatalog {

    /// Reframe noun for the headline goal (used in "poured into <noun>").
    static func noun(for goalID: String?) -> String {
        switch goalID {
        case "fitness":  return String(localized: "the body you want")
        case "business": return String(localized: "your business")
        case "read":     return String(localized: "your reading list")
        case "skill":    return String(localized: "the skill you're chasing")
        case "create":   return String(localized: "the things you'll make")
        case "people":   return String(localized: "the people who matter")
        case "sleep":    return String(localized: "real rest")
        case "mindful":  return String(localized: "a quieter mind")
        case "money":    return String(localized: "your money goals")
        default:         return String(localized: "the life you want")
        }
    }

    // ⭐ REMOVED 2026-09-04: `identity(for:)`, `becomingPhrase(for:)` and
    // `identityNoun(for:)`. Three parallel identity-copy tables from the v6 /
    // v2.2 / spec-v2.4 era, all with zero call sites, all still phrased "You're
    // becoming someone who…" — the exact third-person wording the live copy just
    // moved off. Left in place they are a trap: the next grep for "identity"
    // finds them and reintroduces the slop. Live identity copy is
    // `ActivityDomain.identityLine` / `identityClaims` and `Activity.identityLine`.

    /// The IDENTITY, stated as already true — "You're a reader." The intercept
    /// headline at the fork, and the string the shield extension is synced with.
    /// Present tense since 2026-09-21; see `becameWishParts` for why.
    static func becameWish(for goalID: String?) -> String {
        let p = becameWishParts(for: goalID)
        return p.prefix + " " + p.emphasis
    }

    /// The same wish split for the attraction intercept's two-tone serif
    /// headline (intercept-attraction-mockup.html `.h1 em`): the closing
    /// identity words render SALMON, the lead-in stays ink. One source with
    /// `becameWish` so the shield's synced string can never drift from the
    /// in-app rendering.
    /// ⭐ PRESENT TENSE. THE IDENTITY IS ALREADY TRUE (Jack, 2026-09-21): "We
    /// need to tell users that you are that person so act like it."
    ///
    /// Every line here used to open "You WANTED to become…" — past tense, and
    /// past tense at the shield does three things wrong at once:
    ///
    ///   • It puts the identity in the past, which frames the person standing
    ///     there as someone who USED to want this. That is a eulogy, not a cue.
    ///   • It is an accusation. "You wanted to" and then here you are — the
    ///     unstated second half is "and you failed", which is the shame this
    ///     app has a law against.
    ///   • It is unanswerable. There is no action that makes a past want true.
    ///
    /// Present tense makes it a claim the next sixty seconds can either honour
    /// or contradict, and that is the whole mechanism. This is also the
    /// identity-naming rule already on file (Patrick & Hagtvedt: "I don't"
    /// beats "I can't"; Bryan: noun identity beats verb behaviour) — a reader
    /// is a thing you ARE, and the shield is the one surface where saying so
    /// costs nothing and lands hardest.
    ///
    /// ⚠️ The nouns stay nouns. "You read" would be a behaviour; "You're a
    /// reader" is a self. Bryan's whole finding is that the noun outperforms.
    static func becameWishParts(for goalID: String?) -> (prefix: String, emphasis: String) {
        switch goalID {
        case "fitness":  return (String(localized: "You're"), String(localized: "someone who trains."))
        case "business": return (String(localized: "You're"), String(localized: "a builder."))
        case "read":     return (String(localized: "You're"), String(localized: "a reader."))
        case "skill":    return (String(localized: "You're"), String(localized: "someone who keeps getting better."))
        case "create":   return (String(localized: "You're"), String(localized: "someone who makes things."))
        case "people":   return (String(localized: "You're"), String(localized: "there for the people who matter."))
        case "sleep":    return (String(localized: "You're"), String(localized: "someone who actually rests."))
        case "mindful":  return (String(localized: "You're"), String(localized: "present."))
        case "money":    return (String(localized: "You're"), String(localized: "someone who does the real work."))
        default:         return (String(localized: "This time"), String(localized: "is yours."))
        }
    }

    /// The imperative VERB for the redirect nudge + the Protect action — "read",
    /// "train", "practice"… Used in "Protect time to <action>" and "Go <action>."
    /// (spec-v2.3: the reclaimed time gets pointed at a concrete goal action.)
    static func action(for goalID: String?) -> String {
        switch goalID {
        case "fitness":  return String(localized: "train")
        case "business": return String(localized: "build")
        case "read":     return String(localized: "read")
        case "skill":    return String(localized: "practice")
        case "create":   return String(localized: "create")
        case "people":   return String(localized: "be present")
        case "sleep":    return String(localized: "rest")
        case "mindful":  return String(localized: "slow down")
        case "money":    return String(localized: "get to work")
        default:         return String(localized: "go live it")
        }
    }

    /// SF Symbol that represents what the reclaimed minutes are BECOMING (v6).
    static func symbol(for goalID: String?) -> String {
        switch goalID {
        case "fitness":  return "figure.run"
        case "business": return "briefcase.fill"
        case "read":     return "book.fill"
        case "skill":    return "graduationcap.fill"
        case "create":   return "paintbrush.pointed.fill"
        case "people":   return "person.2.fill"
        case "sleep":    return "moon.stars.fill"
        case "mindful":  return "figure.mind.and.body"
        case "money":    return "chart.line.uptrend.xyaxis"
        default:         return "sparkles"
        }
    }

    /// A countable unit of progress + how many reclaimed minutes earn one unit.
    /// e.g. reading: ~45 min = 1 chapter. Drives "≈ N chapters of your book".
    /// Carries singular + plural so the copy reads naturally ("1 hour" / "2 hours").
    struct Unit {
        let singular: String
        let plural: String
        let minutesPer: Int
        /// Back-compat: callers that just want the plural noun.
        var noun: String { plural }
        func noun(for count: Int) -> String { count == 1 ? singular : plural }
    }

    static func unit(for goalID: String?) -> Unit {
        switch goalID {
        case "read":     return Unit(singular: String(localized: "chapter"), plural: String(localized: "chapters"), minutesPer: 45)
        case "create":   return Unit(singular: String(localized: "session"), plural: String(localized: "sessions"), minutesPer: 60)
        case "business": return Unit(singular: String(localized: "work block"), plural: String(localized: "work blocks"), minutesPer: 50)
        case "skill":    return Unit(singular: String(localized: "lesson"), plural: String(localized: "lessons"), minutesPer: 30)
        case "fitness":  return Unit(singular: String(localized: "workout"), plural: String(localized: "workouts"), minutesPer: 45)
        case "people":   return Unit(singular: String(localized: "real conversation"), plural: String(localized: "real conversations"), minutesPer: 30)
        case "sleep":    return Unit(singular: String(localized: "early night"), plural: String(localized: "early nights"), minutesPer: 60)
        case "mindful":  return Unit(singular: String(localized: "quiet session"), plural: String(localized: "quiet sessions"), minutesPer: 20)
        case "money":    return Unit(singular: String(localized: "focused sprint"), plural: String(localized: "focused sprints"), minutesPer: 50)
        default:         return Unit(singular: String(localized: "hour"), plural: String(localized: "hours"), minutesPer: 60)
        }
    }
}

// MARK: - ShortFormBand → baseline minutes

extension ShortFormBand {
    /// Midpoint-ish minutes/day for the band, used as the junk baseline.
    var baselineMinutes: Int {
        switch self {
        case .under1:    return 40
        case .oneToTwo:  return 90
        case .twoToFour: return 180
        case .fourPlus:  return 300
        }
    }
}
