import SwiftUI

// MARK: - Becoming presentation (rebuild 2026-07-19) — EVIDENCE, not assertion.
//
// Spec of record: design/plate-concepts/menu-becoming-mockups.html + the
// customer critique (ask #4): outcomes over minutes, week-as-plates, the
// ongoing mirror, a streak of days you beat the feed. Everything here derives
// from REAL session history + real usage data — no invented numbers, ever.
//
// Sections:
//   • "Reading every night." — the user's own aspiration, as a gerund.
//   • "Your week, plated" — 7 mini plates from real per-day serving counts.
//   • The ongoing mirror — onboarding baseline vs. this week's real junk average.
//   • "What your time became" — per-goal outcome rows from completed sessions.
//   • The covered-dish milestone teaser (static, unopened-not-ugly).

@MainActor
struct BecomingViewModel {

    let ctx: EngineContext
    /// The recorded sessions — the truth of where reclaimed time went.
    let sessions: [ProtectSession]
    /// The derived plan (identity + outcome grouping).
    let goals: [Goal]
    private var engine: BrainEngine { ctx.engine }
    private var calendar: Calendar { Calendar.current }

    init(ctx: EngineContext, sessions: [ProtectSession] = [], goals: [Goal] = []) {
        self.ctx = ctx
        self.sessions = sessions
        self.goals = goals
    }

    var hasAnyServing: Bool { !sessions.isEmpty }

    // MARK: Identity headline — the user's own sentence, in the first person.
    //
    // ⭐ This screen was reading `domain.identityLine` and slicing "becoming "
    // out of it, so it rendered "Becoming a reader." — a label the app assigned,
    // about the user, while the sentence they actually CHOSE at
    // onboarding sat unused in `profile.planIdentityLine`. The app was holding
    // the right words and showing its own. Order of preference now:
    //
    //   1. the aspiration the user picked, in their own words
    //   2. the primary domain's fallback ("Reading more.")
    //   3. nothing claimed yet — and it says so rather than inventing a claim
    //
    // The two-tone serif treatment is unchanged: first word ink, the rest deep
    // leaf, split on the first space so a one-word fallback ("Writing.") simply
    // renders with no accent rather than breaking.

    private var primaryGoal: Goal? { goals.first(where: \.isPrimary) ?? goals.first }

    private var primaryDomain: ActivityDomain? {
        primaryGoal.flatMap { ActivityDomain(rawValue: $0.domain) }
    }

    /// The whole headline, before it is split for the two-tone render.
    var identityClaim: String {
        if let domain = primaryDomain {
            let stated = ctx.profile?.planIdentityLine ?? ""
            if let claim = domain.identityClaim(for: stated) { return claim }
            return domain.identityLine
        }
        return String(localized: "Still choosing.")
    }

    /// ("Reading ", "every night.") — the accent part renders deep leaf.
    var identityParts: (prefix: String, accent: String) {
        let claim = identityClaim
        guard let space = claim.firstIndex(of: " ") else { return (claim, "") }
        return (String(claim[..<space]) + " ", String(claim[claim.index(after: space)...]))
    }

    // MARK: The ongoing mirror — baseline vs. this week's REAL junk average.

    /// TRUE only when the baseline is the user's OWN onboarding answer (a
    /// profile exists). Without a profile, EngineContext substitutes a 90m
    /// planning default — a sizing fallback the mirror must NEVER state as
    /// fact ("Nothing is invented" is this page's own promise).
    var hasRealBaseline: Bool { ctx.profile != nil }

    /// "3h a day" — the onboarding baseline, restated honestly.
    /// Only meaningful when `hasRealBaseline` is true.
    var baselineDisplay: String {
        Self.hoursDisplay(ctx.plan.baselineMinutes)
    }

    /// Average junk minutes/day across the last 7 days that HAVE data.
    /// nil until real usage data exists — the mirror never invents.
    var weeklyJunkAverage: Int? {
        guard engine.hasLiveData else { return nil }
        var total = 0, daysWithData = 0
        for ago in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -ago, to: engine.now) ?? engine.now
            guard let diet = engine.mentalDiet(on: day) else { continue }
            total += diet.minutes[.junk] ?? 0
            daysWithData += 1
        }
        guard daysWithData > 0 else { return nil }
        return total / daysWithData
    }

    var weeklyJunkAverageDisplay: String? {
        weeklyJunkAverage.map(Self.hoursDisplay)
    }

    // MARK: - ⭐ THE CONVERSION (2026-08-09) — the essence, per Jack.
    //
    // "It needs to show the amount of time they saved by not scrolling and how
    // that time was converted into progress. That is the essence of brain diet."
    //
    // The app already computed both halves of the BEFORE/AFTER ("you used to
    // scroll 3h, this week 1h 52m") and stopped there — at a subtraction. The
    // sentence that was missing is what the difference BECAME. Reclaiming time
    // is not the product; a scroll-blocker reclaims time. Converting it is.
    //
    // ⚠️ TWO NUMBERS, NEVER ONE, AND NEVER CAUSATION. `reclaimed` and
    // `invested` are measured independently: reclaimed comes from Screen Time,
    // invested from completed sessions. Most people will not convert all of it,
    // and the honest page says so by showing both rather than implying the gap
    // doesn't exist. Claiming "your 8 reclaimed hours became 8 hours of reading"
    // would be the invented-number failure this page's own header forbids
    // ("Nothing is invented").

    /// Minutes/day the user has clawed back versus their stated baseline,
    /// summed across the last 7 days THAT HAVE DATA. nil until both a real
    /// baseline and real usage exist — never estimated.
    ///
    /// Floored per-day at zero: a day worse than baseline is a bad day, not a
    /// negative withdrawal from the week's total. Averaging the debt in would
    /// let one heavy Sunday erase four honest weekdays, which is both wrong and
    /// discouraging in a way the data doesn't justify.
    var reclaimedMinutesThisWeek: Int? {
        guard hasRealBaseline, engine.hasLiveData else { return nil }
        let baseline = ctx.plan.baselineMinutes
        var total = 0, daysWithData = 0
        for ago in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -ago, to: engine.now) ?? engine.now
            guard let diet = engine.mentalDiet(on: day) else { continue }
            total += max(0, baseline - (diet.minutes[.junk] ?? 0))
            daysWithData += 1
        }
        guard daysWithData > 0, total > 0 else { return nil }
        return total
    }

    /// Minutes actually spent on completed sessions in the last 7 days — the
    /// reclaimed time that turned into something.
    var investedMinutesThisWeek: Int {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: engine.now) ?? engine.now
        return creditedMinutes(sessions.filter { $0.startedAt >= cutoff })
    }

    // MARK: - ⭐ THE PATH (2026-08-27) — position, not just a trophy case.
    //
    // Jack: "What they lose is the path to the life they desire." That is the
    // right frame, and it changes what belongs at the top of this screen.
    // Cumulative totals look BACKWARD, and a backward-looking screen is weakest
    // at exactly the moment someone churns — a bad week makes a trophy case read
    // as decline. A position reads fine on a bad week: it says where you are and
    // what is next, so the answer to "I fell off" is a small next thing rather
    // than a smaller number.
    //
    // "The life you desire" is a feeling every competitor also sells. "41 days
    // in, 6 of 9 steps, next is X" is a POSITION — and a position is the one
    // thing that cannot be rebuilt by cancelling and asking a chatbot, because
    // it takes measurement the chatbot never had.

    /// Days since the user started — the denominator of the whole record.
    var daysIn: Int {
        guard let start = ctx.profile?.createdAt else { return 0 }
        return max(1, (calendar.dateComponents([.day], from: start, to: engine.now).day ?? 0) + 1)
    }

    /// The next untouched step on the primary goal — what the path asks for now.
    /// Nil once every step has been aimed at at least once.
    var nextStepTitle: String? {
        guard let goal = primaryGoal else { return nil }
        let touched = Set(sessions.compactMap(\.stepID))
        return goal.orderedSteps.first { !touched.contains($0.id) }?.title
    }

    /// "41 days in · 6 of 9 steps" — position, stated once.
    var pathPosition: String {
        var parts = ["\(daysIn) \(daysIn == 1 ? "day" : "days") in"]
        if let m = milestone { parts.append("\(m.done) of \(m.total) steps") }
        return parts.joined(separator: " · ")
    }

    // MARK: Credit — self-report counts, but not without limit (2026-08-27)
    //
    // ⭐ THE MIDDLE GROUND. Dragging something onto the plate is real work, and
    // refusing to count it punishes an honest user for the app's own blind spot.
    // But an UNCAPPED self-report turns the record into a diary, and the record
    // is the entire moat: the one thing a chatbot cannot hold is a number the
    // user did not simply assert. ProtectSession already says reported minutes
    // are "never mixed into a measured figure" — until now, every total here
    // mixed them anyway.
    //
    // So: measured minutes count in full, always. Reported minutes count too,
    // up to `reportedDailyCap` per DAY. Log one real thing and it lands whole;
    // claim a fictional eight-hour day and only the first hour survives.

    /// The most self-reported time that can land on any single day.
    static let reportedDailyCap = 60

    private func creditedMinutes(_ list: [ProtectSession]) -> Int {
        let measured = list.lazy.filter { $0.source == .protected }
            .reduce(0) { $0 + $1.minutes }
        let byDay = Dictionary(grouping: list.filter { $0.source == .reported }) {
            calendar.startOfDay(for: $0.startedAt)
        }
        let reported = byDay.values.reduce(0) { running, day in
            running + min(Self.reportedDailyCap, day.reduce(0) { $0 + $1.minutes })
        }
        return measured + reported
    }

    /// Measured only — what the app actually watched the clock on. This is the
    /// number Becoming should lean on when it claims anything.
    var verifiedMinutesThisMonth: Int {
        thisMonthSessions.lazy.filter { $0.source == .protected }.reduce(0) { $0 + $1.minutes }
    }

    /// Credited self-report this month, after the daily cap.
    var reportedMinutesThisMonth: Int {
        max(0, investedMinutesThisMonth - verifiedMinutesThisMonth)
    }

    var reclaimedDisplay: String? { reclaimedMinutesThisWeek.map(Self.hoursDisplay) }
    var investedDisplay: String { Self.hoursDisplay(investedMinutesThisWeek) }

    /// The domains a set of sessions became, most first — "reading, training
    /// and building". Real completed sessions only; nil when nothing was served.
    private func gerundPhrase(_ list: [ProtectSession]) -> String? {
        guard !list.isEmpty else { return nil }

        var minutesByGerund: [String: Int] = [:]
        for session in list {
            let gerund = ActivityCatalog.activity(id: session.activityID)?.gerund
                ?? String(localized: "focus")
            minutesByGerund[gerund, default: 0] += session.minutes
        }
        let ordered = minutesByGerund.sorted { $0.value > $1.value }.map(\.key)
        switch ordered.count {
        case 0:  return nil
        case 1:  return ordered[0]
        case 2:  return String(localized: "\(ordered[0]) and \(ordered[1])")
        default: return String(localized: "\(ordered[0]), \(ordered[1]) and \(ordered[2])")
        }
    }

    /// The last seven days, as a phrase.
    var investedInPhrase: String? {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: engine.now) ?? engine.now
        return gerundPhrase(sessions.filter { $0.startedAt >= cutoff })
    }

    /// Everything, as a phrase — what the hero figure actually became.
    var becamePhrase: String? { gerundPhrase(sessions) }

    /// True only when BOTH halves are real — the conversion card renders on
    /// nothing less. A half-measured claim is the kind of number this page
    /// exists to not make.
    var hasConversion: Bool {
        reclaimedMinutesThisWeek != nil && investedMinutesThisWeek > 0
    }

    // MARK: What your time became — outcome rows from completed sessions only.

    struct Outcome: Identifiable {
        let id: String
        let icon: BDPh
        let color: Color
        let textColor: Color
        let tint: Color
        /// "4 workouts" — count × the goal's session noun. Real counts only.
        let title: String
        /// "3h 20m of training" — total time, category-colored.
        let subtitle: String
        let minutes: Int
    }

    var outcomes: [Outcome] {
        var rows: [Outcome] = []

        // Plan-tagged sessions, grouped per goal.
        for goal in goals {
            let tagged = sessions.filter { $0.goalID == goal.id }
            guard !tagged.isEmpty, let domain = ActivityDomain(rawValue: goal.domain) else { continue }
            let minutes = tagged.reduce(0) { $0 + $1.minutes }
            let cat = PlateEngine.category(forDomain: domain)
            let gerund = ActivityCatalog.activity(id: domain.activityID)?.gerund ?? domain.label.lowercased()
            rows.append(Outcome(
                id: goal.id.uuidString,
                icon: domain.phIcon,
                color: cat.ink, textColor: cat.textInk, tint: cat.wash,
                title: Self.countedNoun(tagged.count, domain: domain),
                subtitle: String(localized: "\(Self.hoursDisplay(minutes)) of \(gerund)"),
                minutes: minutes
            ))
        }

        // Off-plan sessions, grouped per activity (guitar, study, …).
        let offPlan = sessions.filter { $0.goalID == nil }
        let byActivity = Dictionary(grouping: offPlan, by: \.activityID)
        for (activityID, group) in byActivity {
            guard let activity = ActivityCatalog.activity(id: activityID) else { continue }
            let minutes = group.reduce(0) { $0 + $1.minutes }
            let cat = PlateEngine.category(forActivityID: activityID) ?? .focus
            let subtitle = String(localized: "\(Self.hoursDisplay(minutes)) of \(activity.gerund)")
            rows.append(Outcome(
                id: "activity.\(activityID)",
                icon: activity.phIcon,
                color: cat.ink, textColor: cat.textInk, tint: cat.wash,
                title: group.count == 1
                    ? String(localized: "1 \(activity.label.lowercased()) session")
                    : String(localized: "\(group.count) \(activity.label.lowercased()) sessions"),
                subtitle: subtitle,
                minutes: minutes
            ))
        }

        return rows.sorted { $0.minutes > $1.minutes }
    }

    /// "4 workouts" / "12 reading sessions" — HONEST nouns (a completed session
    /// of the goal is the unit; chapters/books are never claimed unverified).
    private static func countedNoun(_ count: Int, domain: ActivityDomain) -> String {
        let noun: String
        switch domain {
        case .reading:  noun = count == 1 ? String(localized: "reading session")  : String(localized: "reading sessions")
        case .fitness:  noun = count == 1 ? String(localized: "workout")          : String(localized: "workouts")
        case .music:    noun = count == 1 ? String(localized: "practice session") : String(localized: "practice sessions")
        case .building: noun = count == 1 ? String(localized: "build block")      : String(localized: "build blocks")
        case .writing:  noun = count == 1 ? String(localized: "writing session")  : String(localized: "writing sessions")
        case .learning: noun = count == 1 ? String(localized: "study session")    : String(localized: "study sessions")
        case .outdoors: noun = count == 1 ? String(localized: "session outside")  : String(localized: "sessions outside")
        case .creating: noun = count == 1 ? String(localized: "creative session") : String(localized: "creative sessions")
        case .social:   noun = count == 1 ? String(localized: "real conversation") : String(localized: "real conversations")
        case .mindful:  noun = count == 1 ? String(localized: "quiet session")    : String(localized: "quiet sessions")
        }
        return "\(count) \(noun)"
    }

    // MARK: The covered dish — the milestone you haven't tasted yet (teaser).

    /// ⭐ Shared with onboarding's `PlanProjection` via `DomainMilestone`
    /// (2026-08-18) — the noun a user was given at the paywall is the noun they
    /// see here, so the projection they were promised is the one being re-dated.
    var milestoneTitle: String {
        guard let domain = primaryGoal.flatMap({ ActivityDomain(rawValue: $0.domain) })
        else { return String(localized: "First milestone") }
        return domain.milestone.title
    }

    // MARK: - ⭐ THE MONTH (2026-08-17) — Becoming rebuilt around the numbers.
    //
    // The page moved from a week to a MONTH and from four stacked sections to
    // one. Two things drove that:
    //
    //  1. The receipts and the breakdown were the same data twice ("24 reading
    //     sessions" appeared in both), so they merged into one block.
    //  2. The month-over-month comparison is stated ONCE, in the header, so
    //     every number below inherits it as a mode instead of repeating it in a
    //     section of its own (Gentler Streak's Activities screen does this).
    //
    // A month is also the smallest window where "vs. last month" is a real
    // comparison rather than noise, and where a projected finish date has
    // enough rate behind it to be worth stating.

    /// Start of the current calendar month.
    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: engine.now)) ?? engine.now
    }

    /// Start of the previous calendar month.
    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
    }

    /// "August" — the window this page is reporting on.
    var monthLabel: String {
        engine.now.formatted(.dateTime.month(.wide))
    }

    /// "July" — the window every delta is measured against.
    var previousMonthLabel: String {
        previousMonthStart.formatted(.dateTime.month(.wide))
    }

    /// Days of the current month that have happened (1st → today inclusive).
    var daysElapsedInMonth: Int {
        (calendar.dateComponents([.day], from: monthStart, to: engine.now).day ?? 0) + 1
    }

    private func sessions(from start: Date, before end: Date) -> [ProtectSession] {
        sessions.filter { $0.startedAt >= start && $0.startedAt < end }
    }

    private var thisMonthSessions: [ProtectSession] {
        sessions.filter { $0.startedAt >= monthStart }
    }

    private var lastMonthSessions: [ProtectSession] {
        sessions(from: previousMonthStart, before: monthStart)
    }

    // MARK: The trade — two independently measured numbers, never one.

    /// Minutes clawed back against the stated baseline, summed across the days
    /// of THIS month that have usage data. Floored per-day at zero for the same
    /// reason as the weekly figure: a bad day is a bad day, not a debt that
    /// erases four good ones. nil until a real baseline and real usage exist.
    var reclaimedMinutesThisMonth: Int? {
        guard hasRealBaseline, engine.hasLiveData else { return nil }
        let baseline = ctx.plan.baselineMinutes
        var total = 0, daysWithData = 0
        for ago in 0..<daysElapsedInMonth {
            guard let day = calendar.date(byAdding: .day, value: -ago, to: engine.now),
                  day >= monthStart,
                  let diet = engine.mentalDiet(on: day) else { continue }
            total += max(0, baseline - (diet.minutes[.junk] ?? 0))
            daysWithData += 1
        }
        guard daysWithData > 0, total > 0 else { return nil }
        return total
    }

    /// Minutes on completed sessions this month — the reclaimed time that
    /// actually turned into something.
    var investedMinutesThisMonth: Int {
        creditedMinutes(thisMonthSessions)
    }

    /// The share of reclaimed time that got converted, 0…1 — the hero bar.
    /// The REMAINDER is the point: it is the gap the product still has to close,
    /// and hiding it would hide the thing worth fixing.
    var convertedFraction: Double {
        guard let reclaimed = reclaimedMinutesThisMonth, reclaimed > 0 else { return 0 }
        return min(1, Double(investedMinutesThisMonth) / Double(reclaimed))
    }

    /// ⭐ NOT A DEFICIT (Jack, 2026-09-15): "show how many of their hours they are
    /// leveraging, but not in a negative way." The same subtraction, framed as
    /// what is still in hand rather than what was squandered — see the label in
    /// BecomingView. The number is identical; only the claim about it changed.
    ///
    /// Reclaimed minus invested. nil when there's nothing left over.
    var unclaimedDisplay: String? {
        guard let reclaimed = reclaimedMinutesThisMonth else { return nil }
        let left = reclaimed - investedMinutesThisMonth
        guard left > 0 else { return nil }
        return Self.hoursDisplay(left)
    }

    /// The share of reclaimed time that became something, as a plain percent.
    /// Stated as leverage — what the hours DID — never as a completion rate.
    var leveragePercent: Int? {
        guard let reclaimed = reclaimedMinutesThisMonth, reclaimed > 0 else { return nil }
        return Int((Double(investedMinutesThisMonth) / Double(reclaimed) * 100).rounded())
    }

    var reclaimedMonthDisplay: String? { reclaimedMinutesThisMonth.map(Self.hoursDisplay) }
    var investedMonthDisplay: String { Self.hoursDisplay(investedMinutesThisMonth) }

    /// True only when BOTH halves are real. A half-measured claim is exactly the
    /// kind of number this page exists not to make.
    var hasMonthTrade: Bool {
        reclaimedMinutesThisMonth != nil && investedMinutesThisMonth > 0
    }

    // MARK: - ⭐ THE HERO (2026-09-16) — hours CONVERTED, counted from day one.
    //
    // Jack: "the hero number of how many hours they have converted from
    // scrolling into actually putting towards their goals and dreams."
    //
    // The old hero was `reclaimed`, and reclaimed is the wrong number to blow
    // up: any blocker reclaims time, so a page that leads with it is measuring
    // the blocker rather than the product. The conversion is the only figure
    // here a competitor cannot also print.
    //
    // ⚠️ THIS IS STILL NOT THE RECLAIMED NUMBER RENAMED. The two-numbers rule
    // above holds — reclaimed comes from Screen Time, converted comes from
    // sessions, and the gap between them stays on the page. What changed is
    // which one is 56pt.
    //
    // It counts from the START, not from the 1st of the month, for the reason
    // Jack gave on 2026-09-15: "I dont like starting at zero." A record that
    // resets on a calendar rollover reads as nothing on the morning someone
    // opens the app to see how far they have come. The month is still on the
    // page — as the line that says what this month ADDED to the total.

    /// Every credited minute ever converted. Measured sessions count in full;
    /// self-report counts up to `reportedDailyCap` a day (see `creditedMinutes`).
    var convertedMinutesAllTime: Int { creditedMinutes(sessions) }

    var convertedAllTimeDisplay: String { Self.hoursDisplay(convertedMinutesAllTime) }

    var hasConverted: Bool { convertedMinutesAllTime > 0 }

    /// What the app actually watched the clock on, all time.
    var verifiedMinutesAllTime: Int {
        sessions.lazy.filter { $0.source == .protected }.reduce(0) { $0 + $1.minutes }
    }

    /// Credited self-report, all time, after the daily cap.
    var reportedMinutesAllTime: Int {
        max(0, convertedMinutesAllTime - verifiedMinutesAllTime)
    }

    /// The hero splits into a numeral and its unit so the numeral carries the
    /// weight. Hours TRUNCATE rather than round: this is a claim about what
    /// someone did, and the honest direction to be wrong in is down. The exact
    /// figure is one line below, in the measured/reported split.
    var heroConverted: (value: String, unit: String) {
        let minutes = convertedMinutesAllTime
        guard minutes >= 60 else {
            return ("\(minutes)", minutes == 1 ? String(localized: "minute")
                                               : String(localized: "minutes"))
        }
        let hours = minutes / 60
        return ("\(hours)", hours == 1 ? String(localized: "hour")
                                       : String(localized: "hours"))
    }

    // MARK: Where they went — counted nouns, category colours, month deltas.

    struct MonthRow: Identifiable {
        let id: String
        let icon: BDPh
        /// Category ink — the chip glyph and the slim bar.
        let color: Color
        /// Contrast-safe category ink for TEXT (honey fails as text; the law
        /// already swaps it for bdHoneyText).
        let textColor: Color
        /// Category wash — the chip's background.
        let tint: Color
        /// "24 reading sessions" — count × the domain's honest session noun.
        let title: String
        /// "11h 05m".
        let subtitle: String
        let minutes: Int
        /// Change in session COUNT against the same slice of last month.
        /// nil on the dessert row: rest is not a number to grow, and a "+2"
        /// there would be the app pushing something it explicitly doesn't push.
        let deltaCount: Int?
        /// Share of the biggest row, 0…1 — the slim bar's width.
        var fraction: Double = 1
    }

    var monthRows: [MonthRow] {
        var rows: [MonthRow] = []
        let previous = lastMonthSessions

        // Plan-tagged sessions, grouped per goal (the noun comes from the
        // domain, the colour from the domain's CATEGORY — two domains can share
        // a category, and when they do they correctly share a colour).
        for goal in goals {
            let tagged = thisMonthSessions.filter { $0.goalID == goal.id }
            guard !tagged.isEmpty, let domain = ActivityDomain(rawValue: goal.domain) else { continue }
            let minutes = tagged.reduce(0) { $0 + $1.minutes }
            let cat = PlateEngine.category(forDomain: domain)
            let was = previous.filter { $0.goalID == goal.id }.count
            rows.append(MonthRow(
                id: goal.id.uuidString,
                icon: domain.phIcon,
                color: cat.ink, textColor: cat.textInk, tint: cat.wash,
                title: Self.countedNoun(tagged.count, domain: domain),
                subtitle: Self.hoursDisplay(minutes),
                minutes: minutes,
                deltaCount: tagged.count - was
            ))
        }

        // Off-plan sessions, grouped per activity (guitar, study, rest…).
        let offPlan = thisMonthSessions.filter { $0.goalID == nil }
        for (activityID, group) in Dictionary(grouping: offPlan, by: \.activityID) {
            guard let activity = ActivityCatalog.activity(id: activityID) else { continue }
            let minutes = group.reduce(0) { $0 + $1.minutes }
            let cat = PlateEngine.category(forActivityID: activityID) ?? .focus
            let isDessert = cat == .entertainment
            let was = previous.filter { $0.goalID == nil && $0.activityID == activityID }.count
            rows.append(MonthRow(
                id: "activity.\(activityID)",
                icon: activity.phIcon,
                color: cat.ink, textColor: cat.textInk, tint: cat.wash,
                title: group.count == 1
                    ? String(localized: "1 \(activity.label.lowercased()) session")
                    : String(localized: "\(group.count) \(activity.label.lowercased()) sessions"),
                subtitle: Self.hoursDisplay(minutes),
                minutes: minutes,
                deltaCount: isDessert ? nil : group.count - was
            ))
        }

        rows.sort { $0.minutes > $1.minutes }
        guard let top = rows.first?.minutes, top > 0 else { return rows }
        return rows.map {
            var row = $0
            row.fraction = Double($0.minutes) / Double(top)
            return row
        }
    }

    // MARK: Showing up, and coming back — the two figures that aren't time.

    /// Distinct days this month with at least one session.
    var daysShowedUp: Int {
        Set(thisMonthSessions.map { calendar.startOfDay(for: $0.startedAt) }).count
    }

    /// ⭐ THE BOUNCE-BACK (2026-08-17). Days this month where the user recorded
    /// nothing and then showed up again the very next day.
    ///
    /// This is the most important number on the page and it looks like the
    /// smallest. What ends a behaviour change is almost never the missed day —
    /// it is reading the missed day as proof you were never that person, and
    /// quitting on the evidence. A page that only ever rewards unbroken runs
    /// makes that reading MORE available, which is also why the streak chip was
    /// cut from this screen in 2026-07-23. Counting recoveries as wins is the
    /// direct counter, and it is the one figure here that still says something
    /// good on a bad month — exactly when someone opens this page.
    ///
    /// Costs nothing to compute: it falls straight out of the per-day session
    /// counts the week strip has always used.
    var bounceBacks: Int {
        let fed = Set(thisMonthSessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !fed.isEmpty else { return 0 }
        var count = 0
        for ago in 0..<daysElapsedInMonth {
            guard let day = calendar.date(byAdding: .day, value: -ago, to: engine.now) else { continue }
            let start = calendar.startOfDay(for: day)
            guard start >= monthStart, !fed.contains(start),
                  let next = calendar.date(byAdding: .day, value: 1, to: start),
                  fed.contains(calendar.startOfDay(for: next))
            else { continue }
            count += 1
        }
        return count
    }

    // MARK: How close you are — the only forward-looking thing on the page.

    struct MilestoneProgress {
        let title: String
        let done: Int
        let total: Int
        /// nil until there's a real rate to project from — the page never
        /// invents a date it can't support.
        let projected: Date?
        var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }

    /// Progress toward the primary goal's milestone.
    ///
    /// A step counts as DONE once at least one protected session has been aimed
    /// at it — the strongest signal the app actually has. (It enforces the
    /// block; it cannot verify the reading happened, which is why every surface
    /// says time was "protected for" a thing rather than claiming the thing.)
    ///
    /// The projection divides the steps still untouched by the rate at which
    /// the user has been touching new ones, and is suppressed entirely below
    /// two touched steps, because one data point is not a pace.
    var milestone: MilestoneProgress? {
        guard let goal = primaryGoal else { return nil }
        let steps = goal.orderedSteps
        guard steps.count > 1 else { return nil }

        let touched = Set(sessions.compactMap(\.stepID))
        let done = steps.filter { touched.contains($0.id) }.count
        let remaining = steps.count - done

        var projected: Date?
        if remaining > 0, done >= 2 {
            // Rate = steps first touched per day, across the span from the
            // earliest tagged session to now.
            let tagged = sessions.filter { $0.stepID != nil }
            if let first = tagged.map(\.startedAt).min() {
                let span = max(1, calendar.dateComponents([.day], from: first, to: engine.now).day ?? 1)
                let perDay = Double(done) / Double(span)
                if perDay > 0 {
                    let daysLeft = Int((Double(remaining) / perDay).rounded(.up))
                    // Anything past a year is a rate too slow to be a promise.
                    if daysLeft <= 365 {
                        projected = calendar.date(byAdding: .day, value: daysLeft, to: engine.now)
                    }
                }
            }
        }
        return MilestoneProgress(title: milestoneTitle, done: done,
                                 total: steps.count, projected: projected)
    }

    // MARK: - ⭐ THE WEEK, RETURNED (Jack, 2026-09-21 → approved 2026-09-22)
    //
    // "Pull their average screen time and then when a day or week is over show
    // them what that reduction actually accomplished in terms of their goals."
    //
    // The shape is: the GOAL is the headline, the feed time is what paid for it.
    // Peak-end (Kahneman) says an episode is remembered by its end, so the full
    // translation lands once, at the end of the week, not drip-fed across a tab.
    //
    // ⚠️ THE TWO NUMBERS NEVER CLAIM CAUSE. Feed time comes from Screen Time via
    // the Monitor extension; goal time comes from sessions. "11h 40m less feed"
    // and "you put 4h 50m into" are both measured; "your 11h 40m became reading"
    // is not, and this file does not say it.
    //
    // ⚠️ IT SAYS "FEED", NOT "SCREEN TIME". The meter only sees the apps the user
    // chose to rest. Calling it screen time would claim a number it cannot see.

    /// A week's worth of their stated usual, in minutes.
    var usualFeedMinutesWeek: Int { ctx.plan.baselineMinutes * 7 }

    /// Measured feed minutes across the last 7 days that have data.
    /// nil until real usage exists — never estimated.
    var feedMinutesThisWeek: Int? {
        guard engine.hasLiveData else { return nil }
        var total = 0, days = 0
        for ago in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -ago, to: engine.now),
                  let diet = engine.mentalDiet(on: day) else { continue }
            total += diet.minutes[.junk] ?? 0
            days += 1
        }
        return days > 0 ? total : nil
    }

    /// What the feed did NOT get this week, against their usual. Floored at zero.
    var feedBackThisWeek: Int? {
        guard hasRealBaseline, let actual = feedMinutesThisWeek else { return nil }
        let back = usualFeedMinutesWeek - actual
        return back > 0 ? back : nil
    }

    private var thisWeekSessions: [ProtectSession] {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: engine.now) ?? engine.now
        return sessions.filter { $0.startedAt >= cutoff }
    }

    private var lastWeekSessions: [ProtectSession] {
        let start = calendar.date(byAdding: .day, value: -14, to: engine.now) ?? engine.now
        let end = calendar.date(byAdding: .day, value: -7, to: engine.now) ?? engine.now
        return sessions.filter { $0.startedAt >= start && $0.startedAt < end }
    }

    /// Credited goal minutes this week — the SAME capped figure everywhere, which
    /// is what retires the old hero-vs-rows contradiction (hero applied the daily
    /// self-report cap, the rows showed raw minutes, and nothing said so).
    var goalMinutesThisWeek: Int { creditedMinutes(thisWeekSessions) }

    /// The share of the returned time that landed on a goal, 0…1.
    var returnedUsedFraction: Double {
        guard let back = feedBackThisWeek, back > 0 else { return 0 }
        return min(1, Double(goalMinutesThisWeek) / Double(back))
    }

    var returnedUsedPercent: Int? {
        guard let back = feedBackThisWeek, back > 0 else { return nil }
        return Int((Double(goalMinutesThisWeek) / Double(back) * 100).rounded())
    }

    /// One goal's week: what it was, what it got, and how it moved.
    struct WeekRow: Identifiable {
        let id: String
        let icon: BDPh
        let color: Color
        let textColor: Color
        let tint: Color
        /// "5 reading sessions"
        let title: String
        /// "Reading" — the legend's word. The legend must NOT repeat the row
        /// beneath it; a key that restates its own list is noise.
        let legend: String
        /// "1 more than last week" / "new this week" / "" — honest, computed.
        let note: String
        let minutes: Int
        /// Share of the week's returned time, for the split bar.
        var fraction: Double = 0
    }

    var weekRows: [WeekRow] {
        let previous = lastWeekSessions
        var rows: [WeekRow] = []
        for goal in goals {
            let mine = thisWeekSessions.filter { $0.goalID == goal.id }
            guard !mine.isEmpty, let domain = ActivityDomain(rawValue: goal.domain) else { continue }
            let cat = PlateEngine.category(forDomain: domain)
            let was = previous.filter { $0.goalID == goal.id }.count
            let delta = mine.count - was
            let note: String
            if was == 0 {
                note = String(localized: "new this week")
            } else if delta > 0 {
                note = delta == 1 ? String(localized: "1 more than last week")
                                  : String(localized: "\(delta) more than last week")
            } else {
                note = ""
            }
            rows.append(WeekRow(
                id: goal.id.uuidString, icon: domain.phIcon,
                color: cat.ink, textColor: cat.textInk, tint: cat.wash,
                title: Self.countedNoun(mine.count, domain: domain),
                legend: domain.label,
                note: note,
                minutes: creditedMinutes(mine)))
        }
        rows.sort { $0.minutes > $1.minutes }
        guard let back = feedBackThisWeek, back > 0 else { return rows }
        return rows.map { var r = $0; r.fraction = Double($0.minutes) / Double(back); return r }
    }

    /// ⭐ THE PACE, LAST WEEK. The milestone's projected date recomputed as it
    /// stood 7 days ago, so the card can show the date MOVING rather than a
    /// number that means nothing on its own (goal gradient: proximity is what
    /// accelerates effort).
    ///
    /// Shown even when this week is SLOWER. Only ever printing good news is
    /// selective reporting, and this page's header promises it invents nothing.
    var milestoneProjectedLastWeek: Date? {
        guard let goal = primaryGoal else { return nil }
        let steps = goal.orderedSteps
        guard steps.count > 1 else { return nil }
        let asOf = calendar.date(byAdding: .day, value: -7, to: engine.now) ?? engine.now
        let older = sessions.filter { $0.startedAt <= asOf }
        let touched = Set(older.compactMap(\.stepID))
        let done = steps.filter { touched.contains($0.id) }.count
        let remaining = steps.count - done
        guard remaining > 0, done >= 2,
              let first = older.filter({ $0.stepID != nil }).map(\.startedAt).min() else { return nil }
        let span = max(1, calendar.dateComponents([.day], from: first, to: asOf).day ?? 1)
        let perDay = Double(done) / Double(span)
        guard perDay > 0 else { return nil }
        let daysLeft = Int((Double(remaining) / perDay).rounded(.up))
        guard daysLeft <= 365 else { return nil }
        return calendar.date(byAdding: .day, value: daysLeft, to: asOf)
    }

    /// "8 days sooner" / "3 days later" / nil when there is nothing to compare.
    var milestonePaceShift: (days: Int, sooner: Bool)? {
        guard let now = milestone?.projected, let was = milestoneProjectedLastWeek else { return nil }
        let days = calendar.dateComponents([.day], from: now, to: was).day ?? 0
        guard days != 0 else { return nil }
        return (abs(days), days > 0)
    }

    /// The first step of the coming week — what the recap ends on, because a
    /// fresh-start landmark is worth more pointed forward than summarised.
    var nextWeekFirstStep: (title: String, cue: String, minutes: Int)? {
        guard let focus = TodaysFocus.pickThree(
            goals: goals, doneToday: [],
            everDone: Set(sessions.compactMap(\.stepID)),
            skips: MenuExposure.skips(sessions: sessions)).first else { return nil }
        return (focus.step.title, focus.step.cue, focus.step.suggestedMinutes)
    }

    /// True once there is enough measured data for the week card to be honest.
    var hasWeekReturn: Bool { feedBackThisWeek != nil }

    /// Sunday evening onward — when the weekly recap is worth opening.
    var weekIsOver: Bool {
        calendar.component(.weekday, from: engine.now) == 1 && calendar.component(.hour, from: engine.now) >= 17
    }

    /// "Sep 15 · 21"
    var weekRangeLabel: String {
        let start = calendar.date(byAdding: .day, value: -6, to: engine.now) ?? engine.now
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let g = DateFormatter(); g.dateFormat = "d"
        return "\(f.string(from: start)) · \(g.string(from: engine.now))"
    }

    // MARK: Display helpers

    static func hoursDisplay(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
