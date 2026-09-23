import Foundation
import SwiftUI

// MARK: - PlateEngine — the app's ONE state object (PLATE-ENGINE.md).
//
// Every screen reads its recommendation from here; no view computes its own.
// This is a near line-for-line Swift port of the reference reducer in
// `design/vision-v2/plate-engine-demo.src.html` (catalog, deficits, sticky
// reroll, menu scoring, completeness, headline, insight).
//
// The engine constantly answers four questions:
//   1. What is today's plate missing?          → `missingCategories`
//   2. What should the user do next?           → `suggestion` (ONE serving)
//   3. How balanced is today's plate?          → `balanceWord()` + `completeness`
//   4. What insight should be shown?           → `insight()`
//
// Soft inferred plan (NOT per-category quotas): v1 = 3 servings/day, one each
// Learning / Focus / Creativity. Servings are CONCRETE actions derived from the
// user's Goal/GoalStep data ("Finish a chapter — Read more"), never categories.
// Empty Calories is OBSERVED ONLY: no target, never recommended.
//
// Sticky-moment rule (§3): the suggestion re-rolls ONLY on completed · declined ·
// new time-of-day block · new day — never on a view refresh. Declines pick a
// DIFFERENT serving in the category; if everything is declined, forgive & reset.
//
// The user speaks activities; the engine translates to nutrition (Law Two):
// ProtectSessions map into the five categories via their activity id.

// MARK: - The five categories

enum PlateCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case learning, focus, creativity, entertainment, emptyCalories

    var id: String { rawValue }

    /// Activity-first name (Language law: activity FIRST, food explains).
    /// Junk is "Slop" (appetite pass 2026-07-18 — the mockup's honest name).
    var label: String {
        switch self {
        case .learning:      return String(localized: "Learning")
        case .focus:         return String(localized: "Focus")
        case .creativity:    return String(localized: "Creativity")
        case .entertainment: return String(localized: "Dessert")
        case .emptyCalories: return String(localized: "Slop")
        }
    }

    /// The food explanation (subtitle voice, never the primary name).
    var food: String {
        switch self {
        case .learning:      return String(localized: "brain vegetables")
        case .focus:         return String(localized: "brain protein")
        case .creativity:    return String(localized: "brain fruit")
        // ⭐ NOT "guilt-free" (2026-09-14). The app does not hand out permission.
        // It still NAMES entertainment honestly where it happened — it just does
        // not editorialise that it was fine.
        case .entertainment: return String(localized: "what was left")
        case .emptyCalories: return String(localized: "empty calories")
        }
    }

    /// Category ink (chip icon + bar) — ⭐ THE CATEGORY-COLOR LAW (2026-07-18):
    /// leaf / salmon / berry / honey / slop-gray, enforced on every surface.
    var ink: Color {
        switch self {
        case .learning:      return .bdLeaf
        case .focus:         return .bdSalmon
        case .creativity:    return .bdBerry
        case .entertainment: return .bdHoney
        case .emptyCalories: return .bdSlopGray
        }
    }

    /// Category color as TEXT (honey fails contrast as text → honey-text; the
    /// slop row's caption fades further by design).
    var textInk: Color {
        switch self {
        case .entertainment: return .bdHoneyText
        case .emptyCalories: return .bdSlopFaint
        default:             return ink
        }
    }

    /// Soft chip wash behind the icon (the category's tint).
    var wash: Color {
        switch self {
        case .learning:      return .bdLeafTint
        case .focus:         return .bdSalmonTint
        case .creativity:    return .bdBerrySoft
        case .entertainment: return .bdHoneyTint
        case .emptyCalories: return .bdSlopTint
        }
    }

    /// Slim-bar fill — the category color, always.
    var barFill: Color { ink }

    /// The serving-aware primary-CTA title — ONE source for Home's serving
    /// card, the intercept, and the synced shield, so the verb can never
    /// drift between surfaces: dessert is SERVED, everything else feeds.
    /// One CTA, always. "Serve dessert" is gone with the dessert suggestion —
    /// the app has exactly one thing it asks you to do.
    var ctaTitle: String { String(localized: "Feed my brain") }

    /// Thin-line SF Symbol — one icon language, never emoji.
    var symbol: String {
        switch self {
        case .learning:      return "book"
        case .focus:         return "scope"   // never "target"/"circle.circle" — collides with the Home tab plate icon
        case .creativity:    return "paintbrush.pointed"
        case .entertainment: return "popcorn"
        case .emptyCalories: return "takeoutbag.and.cup.and.straw"
        }
    }
}

// MARK: - A serving — one concrete action ("Finish a chapter"), never a category.

struct PlateServing: Identifiable, Equatable, Sendable {
    /// Stable id (GoalStep UUID string, or a "default.*" catalog id).
    let id: String
    /// The concrete action — "Finish a chapter". Never "Learning".
    let title: String
    /// The quiet source line — the goal it serves ("Read more"). Optional.
    let detail: String?
    let category: PlateCategory
    let minutes: Int
    /// Plan attribution (nil for catalog defaults).
    let goalID: UUID?
    let stepID: UUID?
    /// The ActivityCatalog id the protection flow aims at.
    let activityID: String
}

/// The completion beat Home plays (Bible §5): set by the engine when a serving
/// completes, consumed once by Home. State commits FIRST; visuals follow.
struct PlateCelebration: Equatable, Sendable {
    let id: UUID
    let category: PlateCategory
    let title: String

    init(category: PlateCategory, title: String) {
        self.id = UUID()
        self.category = category
        self.title = title
    }
}

// MARK: - The engine

@MainActor
@Observable
final class PlateEngine {

    /// Why the suggestion last re-rolled (the sticky rule's audit trail).
    enum RerollReason: String, Codable, Sendable {
        case newDay, newTimeBlock, completed, declined
    }

    /// Time-of-day blocks — a new block is a sanctioned re-roll moment.
    enum TimeBlock: String, Codable, Sendable {
        case morning, midday, evening, night

        init(for date: Date, calendar: Calendar = .current) {
            switch calendar.component(.hour, from: date) {
            case 5..<12:  self = .morning
            case 12..<17: self = .midday
            case 17..<22: self = .evening
            default:      self = .night
            }
        }
    }

    /// The soft inferred plan — 3 servings/day, one per recommended category.
    /// Order matters: it is the deficit priority (reference reducer's key order).
    static let planOrder: [PlateCategory] = [.learning, .focus, .creativity]
    let plan: [PlateCategory: Int] = [.learning: 1, .focus: 1, .creativity: 1]

    // Derived per-sync from persisted truth (sessions map in via activity ids).
    private(set) var done: [PlateCategory: Int] = [:]
    private(set) var minutes: [PlateCategory: Int] = [:]
    /// Observed only — no target, never recommended, never alarm-red.
    private(set) var emptyCaloriesMinutes: Int = 0
    /// Apps currently off the menu (the quiet protection line).
    private(set) var junkAppCount: Int = 0
    /// Every valid serving today (multiple per category — variety).
    private(set) var catalog: [PlateServing] = []
    /// THE answer to "what should I do next" — one serving, sticky.
    private(set) var suggestion: PlateServing?
    /// The pending completion beat (consumed once by Home).
    private(set) var celebration: PlateCelebration?

    // Sticky-moment state (persisted per day).
    private var declined: [PlateCategory: [String]] = [:]
    private var completedIDs: Set<String> = []
    private var rerollReason: RerollReason = .newDay
    private var timeBlock: TimeBlock = .morning
    private var dayKey: String = ""
    private var storedSuggestionID: String?

    // MARK: Sync — views @Query → engine (the engine never touches SwiftData).

    /// Recompute today's plate from persisted truth. Idempotent + event-driven
    /// (never called from a view body). The suggestion stays STICKY across syncs.
    func sync(goals: [Goal], sessions: [ProtectSession], junkMinutes: Int,
              junkAppCount: Int, now: Date = .now) {
        #if DEBUG
        // Screenshot determinism: a seeded run starts from a clean day state
        // (the seeds regenerate every launch; yesterday's sticky ids are stale).
        if DemoSeed.isRequested, !debugStateCleared {
            UserDefaults.standard.removeObject(forKey: Self.stateKey)
            debugStateCleared = true
            dayKey = ""
        }
        #endif
        let key = Self.dayKey(for: now)
        if key != dayKey { loadDayState(for: key, now: now) }

        catalog = Self.buildCatalog(goals: goals, everDone: Set(sessions.compactMap(\.stepID)))

        // Fold today's sessions into per-category servings + minutes. A session
        // is the user speaking an ACTIVITY; the map below is our translation.
        let cal = Calendar.current
        var d: [PlateCategory: Int] = [:]
        var m: [PlateCategory: Int] = [:]
        for s in sessions where cal.isDate(s.startedAt, inSameDayAs: now) {
            guard let cat = Self.category(forActivityID: s.activityID) else { continue }
            d[cat, default: 0] += 1
            m[cat, default: 0] += s.minutes
            if let stepID = s.stepID { completedIDs.insert(stepID.uuidString) }
        }
        #if DEBUG
        applyDebugServedIfRequested()
        for (c, v) in debugDone { d[c, default: 0] += v }
        for (c, v) in debugMinutes { m[c, default: 0] += v }
        #endif
        done = d
        minutes = m
        emptyCaloriesMinutes = junkMinutes
        self.junkAppCount = junkAppCount

        // Sticky suggestion — re-roll ONLY on the four sanctioned events (or
        // when the plate's truth moved underneath it: a stale answer is worse
        // than a re-rolled one, and that is a state change, not a glance).
        let block = TimeBlock(for: now)
        if block != timeBlock {
            timeBlock = block
            reroll(.newTimeBlock)
        } else if let s = suggestion {
            if completedIDs.contains(s.id) { reroll(.completed) }
            else if !catalog.contains(where: { $0.id == s.id }) { reroll(.newDay) }
            else if isStale(s) { reroll(rerollReason) }
            // else: sticky — the answer does not reshuffle on a glance.
        } else if let sid = storedSuggestionID,
                  let s = catalog.first(where: { $0.id == sid }),
                  !completedIDs.contains(s.id), !isStale(s) {
            suggestion = s            // restored across launches — still sticky
            storedSuggestionID = nil
        } else {
            storedSuggestionID = nil
            reroll(rerollReason == .declined ? .declined : .newDay)
        }
        persistDayState()
    }

    // MARK: The four questions

    /// 1 · What is today's plate missing? (plan order = priority)
    var missingCategories: [PlateCategory] {
        Self.planOrder.filter { (done[$0] ?? 0) < (plan[$0] ?? 0) }
    }

    /// ⭐ WHAT'S LEFT (2026-08-09) — servings still to plate in a category today.
    ///
    /// Every mass-market food tracker leads with what REMAINS, never what's been
    /// consumed: "1,505 calories left", "1,284 remaining", "Protein 71g/138g".
    /// 175–200M people read that grammar fluently, and it is also goal-gradient —
    /// people accelerate toward what's left rather than away from what's done.
    ///
    /// ⚠️ nil WHERE THERE IS NO TARGET, and this is load-bearing. Dessert and
    /// Slop are OBSERVED, not budgeted. "40m of slop left today" would read as an
    /// allowance to spend — a permission slip for the exact behaviour the app
    /// exists to reduce. The remaining-frame is only ever applied to things the
    /// user is trying to DO.
    func servingsLeft(_ cat: PlateCategory) -> Int? {
        guard let target = plan[cat], target > 0 else { return nil }
        return max(0, target - (done[cat] ?? 0))
    }

    var planCount: Int { Self.planOrder.reduce(0) { $0 + (plan[$1] ?? 0) } }
    var doneCount: Int {
        Self.planOrder.reduce(0) { $0 + min(done[$1] ?? 0, plan[$1] ?? 0) }
    }
    /// The one sanctioned meal-completeness number (0…1).
    var completeness: Double {
        #if DEBUG
        // `BD_PLATE_N=0.85` — pin the plate's fill for review. Exists because
        // `BD_DEMO_COMPLETE` runs out of suggestions once the day's plan is
        // exhausted, which makes a fed plate unreproducible on a simulator that
        // has already been driven; the steam gate and the food ramp both hang
        // off this number, so both need to be steerable directly.
        if let raw = ProcessInfo.processInfo.environment["BD_PLATE_N"],
           let n = Double(raw) { return max(0, min(1, n)) }
        #endif
        guard planCount > 0 else { return 0 }
        return Double(doneCount) / Double(planCount)
    }

    /// 3 · How balanced is today's plate? — qualitative, never a percent on screen.
    func balanceWord() -> String {
        let c = completeness
        if c >= 1 { return String(localized: "Balanced") }
        if c >= 0.6 { return String(localized: "Almost there") }
        if c > 0 { return String(localized: "Getting there") }
        return String(localized: "Not started")
    }

    /// Home's honest state line — the last word renders sage at the view.
    func headline() -> String {
        let c = completeness
        if c >= 1 { return String(localized: "Well nourished.") }
        if c > 0 { return String(localized: "Nicely fed.") }
        return String(localized: "Your brain is hungry.")
    }

    /// 4 · What insight should be shown?
    func insight(now: Date = .now) -> String {
        let missing = missingCategories
        if missing.isEmpty { return String(localized: "Balanced day. The kitchen is closed.") }
        if missing.count == 1, let s = suggestion {
            return String(localized: "One serving left: \(s.minutes) minutes finishes today's meal.")
        }
        if TimeBlock(for: now) == .evening || TimeBlock(for: now) == .night {
            return String(localized: "Evening: finish the plate before the kitchen closes.")
        }
        return String(localized: "\(missing[0].label) is missing from today's plate.")
    }

    /// Nourishing minutes protected today (time is an ingredient, never the reward).
    var protectedMinutesToday: Int {
        (minutes[.learning] ?? 0) + (minutes[.focus] ?? 0) + (minutes[.creativity] ?? 0)
    }

    func minutesToday(_ cat: PlateCategory) -> Int {
        cat == .emptyCalories ? emptyCaloriesMinutes : (minutes[cat] ?? 0)
    }

    /// Slim-bar fraction for a category row (plan categories: served vs. plan;
    /// empty calories: observed vs. a fixed quiet scale — never a target).
    func barFraction(_ cat: PlateCategory) -> Double {
        if cat == .emptyCalories {
            return min(1, Double(emptyCaloriesMinutes) / 90)
        }
        guard let target = plan[cat], target > 0 else { return 0 }
        return min(1, Double(done[cat] ?? 0) / Double(target))
    }

    // MARK: FEED's menu — every serving, scored (reference `menu()` port).

    func menu(now: Date = .now) -> [PlateServing] {
        let missing = missingCategories
        let block = TimeBlock(for: now)
        let evening = block == .evening || block == .night
        func score(_ s: PlateServing) -> Int {
            if completedIDs.contains(s.id) { return -100 }
            var v = 0
            if let sug = suggestion, s.id == sug.id { v += 100 }
            if let i = missing.firstIndex(of: s.category) { v += 50 - i }
            // (The evening bonus that floated dessert to the top is gone — see
            // the note in `reroll()`.)
            if s.category == .entertainment { v = -1_000 }
            if (declined[s.category] ?? []).contains(s.id) { v -= 10 }
            return v
        }
        return catalog.sorted { score($0) > score($1) }
    }

    func isCompleted(_ serving: PlateServing) -> Bool { completedIDs.contains(serving.id) }

    // MARK: Events — the ONLY re-roll moments (plus new day / new block in sync).

    /// "Not now" — store the decline, pick a DIFFERENT serving (variety).
    func decline() {
        guard let s = suggestion else { return }
        declined[s.category, default: []].append(s.id)
        reroll(.declined)
        persistDayState()
    }

    /// A protection/serving flow finished. State commits FIRST; the celebration
    /// is queued for Home to play (visuals follow, input never hard-locked).
    /// `done`/`minutes` fold in via sync (the session is already persisted).
    func recordCompletion(activityID: String, stepID: UUID?, minutes completedMinutes: Int) {
        let cat = Self.category(forActivityID: activityID) ?? suggestion?.category ?? .focus
        let serving: PlateServing
        if let stepID, let s = catalog.first(where: { $0.id == stepID.uuidString }) {
            serving = s
        } else if let s = suggestion, s.category == cat {
            serving = s
        } else if let s = catalog.first(where: { $0.category == cat && !completedIDs.contains($0.id) }) {
            serving = s
        } else {
            serving = PlateServing(id: UUID().uuidString, title: cat.label, detail: nil,
                                   category: cat, minutes: completedMinutes,
                                   goalID: nil, stepID: stepID, activityID: activityID)
        }
        completedIDs.insert(serving.id)
        reroll(.completed)
        celebration = PlateCelebration(category: serving.category, title: serving.title)
        persistDayState()
    }

    /// Home consumes the celebration exactly once (nil if already played).
    func consumeCelebration() -> PlateCelebration? {
        defer { celebration = nil }
        return celebration
    }

    // MARK: Selection (reference `reroll()` port)

    private func reroll(_ why: RerollReason) {
        rerollReason = why
        let missing = missingCategories
        guard let cat = missing.first else {
            // ⭐ NO DESSERT (Jack, 2026-09-14): "this app should not cut people
            // slack. They should consume what the person they want to be in the
            // future consumes." Finishing the plan used to hand the user an
            // episode — the app rewarding a good day by pointing at the thing it
            // exists to displace.
            //
            // A finished plan now offers ANOTHER serving from their own plan. If
            // there is genuinely nothing left, it offers NOTHING, and Home says
            // the kitchen is closed. Boredom is the healthy outcome here; the app
            // never competes to be the more interesting thing on the screen.
            suggestion = catalog
                .filter { $0.category != .entertainment && !completedIDs.contains($0.id) }
                .first
            return
        }
        let opts = servings(in: cat).filter { !completedIDs.contains($0.id) }
        var notDeclined = opts.filter { !(declined[cat] ?? []).contains($0.id) }
        if notDeclined.isEmpty {          // everything declined → forgive & reset
            declined[cat] = []
            notDeclined = opts
        }
        suggestion = notDeclined.first
    }

    private func servings(in cat: PlateCategory) -> [PlateServing] {
        catalog.filter { $0.category == cat }
    }

    /// A suggestion is STALE when the plate's truth no longer supports it —
    /// deficits exist but it points elsewhere, or the plan completed and it
    /// still isn't dessert. (Guards against out-of-band state changes.)
    private func isStale(_ s: PlateServing) -> Bool {
        // Dessert is never a valid suggestion, whatever the plate says.
        if s.category == .entertainment { return true }
        let missing = missingCategories
        if missing.isEmpty { return false }
        return !missing.contains(s.category)
    }

    /// One (goal, step) pair as a serving — the SAME construction `buildCatalog`
    /// uses, exposed so surfaces that start a specific step (Home's goals card)
    /// don't rebuild the mapping and drift from it. Nil when the goal's domain
    /// is unknown, which is the one case the catalog also skips.
    static func serving(for step: GoalStep, in goal: Goal) -> PlateServing? {
        guard let domain = ActivityDomain(rawValue: goal.domain) else { return nil }
        return PlateServing(
            id: step.id.uuidString, title: step.title, detail: goal.title,
            category: category(forDomain: domain), minutes: step.suggestedMinutes,
            goalID: goal.id, stepID: step.id, activityID: domain.activityID)
    }

    // MARK: Catalog — concrete servings from the user's REAL plan (Law Three).

    /// ⚠️ `everDone` retires one-off setup steps with the SAME rule Today's Focus
    /// uses (`TodaysFocus.isRetired`). Without it this catalog kept "Put Dune
    /// where you'll see it" forever, and the intercept — which reads the plate
    /// engine, not Today's Focus — offered it to someone twelve chapters in.
    static func buildCatalog(goals: [Goal], everDone: Set<UUID> = []) -> [PlateServing] {
        var out: [PlateServing] = []
        let sorted = goals.sorted {
            ($0.isPrimary ? 0 : 1, $0.sortIndex) < ($1.isPrimary ? 0 : 1, $1.sortIndex)
        }
        for goal in sorted {
            guard let domain = ActivityDomain(rawValue: goal.domain) else { continue }
            let cat = category(forDomain: domain)
            for step in goal.orderedSteps
            where !TodaysFocus.isRetired(step, in: goal, everDone: everDone) {
                out.append(PlateServing(
                    id: step.id.uuidString, title: step.title, detail: goal.title,
                    category: cat, minutes: step.suggestedMinutes,
                    goalID: goal.id, stepID: step.id, activityID: domain.activityID))
            }
        }
        // Sensible defaults for any plan category the goals didn't cover.
        for cat in planOrder where !out.contains(where: { $0.category == cat }) {
            out.append(contentsOf: defaults(for: cat))
        }
        // ⛔️ Dessert defaults are NOT appended (2026-09-14). The category still
        // exists so real entertainment USAGE can be classified — it is simply
        // never something the app hands you.
        return out
    }

    private static func defaults(for cat: PlateCategory) -> [PlateServing] {
        switch cat {
        case .learning: return [
            PlateServing(id: "default.learning.read", title: String(localized: "Read a few pages"),
                         detail: String(localized: "your current book"), category: .learning,
                         minutes: 15, goalID: nil, stepID: nil, activityID: "read"),
            PlateServing(id: "default.learning.article", title: String(localized: "Read a saved article"),
                         detail: String(localized: "12 min read"), category: .learning,
                         minutes: 12, goalID: nil, stepID: nil, activityID: "read")]
        case .focus: return [
            PlateServing(id: "default.focus.block", title: String(localized: "One focused work block"),
                         detail: String(localized: "deep work"), category: .focus,
                         minutes: 25, goalID: nil, stepID: nil, activityID: "build")]
        case .creativity: return [
            PlateServing(id: "default.creativity.make", title: String(localized: "Make something small"),
                         detail: String(localized: "creating"), category: .creativity,
                         minutes: 15, goalID: nil, stepID: nil, activityID: "create")]
        case .entertainment: return [
            PlateServing(id: "default.entertainment.show", title: String(localized: "Watch your show"),
                         detail: String(localized: "one episode"), category: .entertainment,
                         minutes: 45, goalID: nil, stepID: nil, activityID: "rest")]
        case .emptyCalories: return []   // never recommended
        }
    }

    /// Activity → nutrition translation (Law Two: our job, never the user's).
    /// Pure function — nonisolated so the design system can read it too.
    nonisolated static func category(forActivityID id: String) -> PlateCategory? {
        switch id {
        case "read", "study":                                   return .learning
        case "build", "lift", "run", "ride", "walk", "meditate": return .focus
        case "create", "write", "guitar", "cook":               return .creativity
        case "rest", "connect":                                 return .entertainment
        default:                                                return nil
        }
    }

    nonisolated static func category(forDomain domain: ActivityDomain) -> PlateCategory {
        switch domain {
        case .reading, .learning:            return .learning
        case .building, .fitness, .outdoors: return .focus
        case .music, .writing, .creating:    return .creativity
        }
    }

    // MARK: Day-state persistence (UserDefaults — sticky across launches)

    private struct DayState: Codable {
        var dayKey: String
        var timeBlock: String
        var suggestionID: String?
        var rerollReason: String
        var declined: [String: [String]]
        var completedIDs: [String]
    }

    private static let stateKey = "bd.plate.dayState"

    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func loadDayState(for key: String, now: Date) {
        dayKey = key
        suggestion = nil
        if let data = UserDefaults.standard.data(forKey: Self.stateKey),
           let s = try? JSONDecoder().decode(DayState.self, from: data),
           s.dayKey == key {
            declined = Dictionary(uniqueKeysWithValues: s.declined.compactMap { k, v in
                PlateCategory(rawValue: k).map { ($0, v) }
            })
            completedIDs = Set(s.completedIDs)
            timeBlock = TimeBlock(rawValue: s.timeBlock) ?? TimeBlock(for: now)
            rerollReason = RerollReason(rawValue: s.rerollReason) ?? .newDay
            storedSuggestionID = s.suggestionID
        } else {
            declined = [:]
            completedIDs = []
            rerollReason = .newDay
            storedSuggestionID = nil
            timeBlock = TimeBlock(for: now)
        }
    }

    private func persistDayState() {
        let s = DayState(
            dayKey: dayKey,
            timeBlock: timeBlock.rawValue,
            suggestionID: suggestion?.id,
            rerollReason: rerollReason.rawValue,
            declined: Dictionary(uniqueKeysWithValues: declined.map { ($0.key.rawValue, $0.value) }),
            completedIDs: Array(completedIDs))
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
    }

    // MARK: DEBUG screenshot hooks

    #if DEBUG
    private var debugDone: [PlateCategory: Int] = [:]
    private var debugMinutes: [PlateCategory: Int] = [:]
    private var debugServedApplied = false
    private var debugStateCleared = false

    /// `BD_PLATE_SERVED=1|2|3` — pre-serve N plan categories (fed / nourished shots).
    private func applyDebugServedIfRequested() {
        guard !debugServedApplied else { return }
        debugServedApplied = true
        guard let raw = ProcessInfo.processInfo.environment["BD_PLATE_SERVED"],
              let n = Int(raw), n > 0 else { return }
        for cat in Self.planOrder.prefix(n) {
            let serving = catalog.first { $0.category == cat && !completedIDs.contains($0.id) }
            debugDone[cat, default: 0] += 1
            debugMinutes[cat, default: 0] += serving?.minutes ?? 18
            if let serving { completedIDs.insert(serving.id) }
        }
    }

    /// `BD_DEMO_COMPLETE=1` (via HomeView) — complete the live suggestion so the
    /// celebration beat can be screenshot-verified without a real session.
    func debugComplete() {
        guard let s = suggestion else { return }
        completedIDs.insert(s.id)
        debugDone[s.category, default: 0] += 1
        debugMinutes[s.category, default: 0] += s.minutes
        done[s.category, default: 0] += 1
        minutes[s.category, default: 0] += s.minutes
        reroll(.completed)
        celebration = PlateCelebration(category: s.category, title: s.title)
        persistDayState()
    }
    #endif
}
