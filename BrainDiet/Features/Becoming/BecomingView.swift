import SwiftUI
import SwiftData

// MARK: - Becoming (rebuild 2026-08-17) — ONE screen, the numbers.
//
// Spec of record: design/becoming/becoming.html (approved), which replaced both
// the fridge exploration and the four-section stack that preceded it.
//
// The page answers exactly one question — what did the time you didn't give the
// feed turn into — and it says each thing ONCE. Two things collapsed the old
// version's height:
//
//   • The receipts and the breakdown were the same data twice ("24 reading
//     sessions" appeared in both). They are now one block.
//   • The comparison is stated once, in the header, as a MODE. Every number
//     below inherits "vs. last month" instead of a section repeating it.
//     (Gentler Streak's Activities screen; see the mockup's citations.)
//
// Order is load-bearing, and it is the identity argument:
//   claim → evidence → the trade → showing up + coming back → the one date.
// Claim-then-evidence reads as proof; the same numbers reversed read as a
// summary. The projected date goes last because it is the only forward-looking
// thing here, and the only reason to open the app tomorrow rather than admire
// yesterday.
//
// COLOUR: every row wears its category (PlateCategory.ink / .wash / .textInk) —
// leaf learning, salmon focus, berry creativity, honey dessert. That law is
// enforced app-wide and this screen is named in it.
//
// Everything is computed from real sessions + real usage. Honest empty states;
// nothing is invented, which is also why the projected date disappears rather
// than guessing when there is no rate behind it.

struct BecomingView: View {

    @Environment(\.usageProvider) private var usageProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppRouter.self) private var router

    @Query private var profiles: [UserProfile]
    @Query(sort: \ProtectSession.startedAt, order: .reverse) private var sessions: [ProtectSession]
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]
    @State private var revealed = false
    @State private var showsWeekReturn = false
    /// Measured width of the split bar — see the note where it is used.
    @State private var splitWidth: CGFloat = 300

    private var vm: BecomingViewModel {
        BecomingViewModel(
            ctx: EngineContext(profile: profiles.first, usage: usageProvider,
                               sessions: sessions),
            sessions: sessions,
            goals: goals
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground(intensity: .standard)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        monthHeader
                            .reveal(0, revealed, reduceMotion)

                        identity
                            .padding(.top, 14)
                            .reveal(0, revealed, reduceMotion)

                        // ⭐ THE GOAL IS THE HEADLINE, THE FEED TIME IS WHAT PAID
                        // FOR IT (Jack, approved 2026-09-22). The milestone moved
                        // from the bottom of the page to the top, because a page
                        // about becoming someone should open with how close you
                        // are, not with an accounting of hours. The hours stay —
                        // one level down, as the evidence.
                        if let milestone = vm.milestone {
                            milestoneHero(milestone)
                                .padding(.top, 18)
                                .reveal(1, revealed, reduceMotion)
                        } else {
                            pathLine
                                .padding(.top, 9)
                                .reveal(0, revealed, reduceMotion)
                        }

                        if vm.hasWeekReturn {
                            weekTrade
                                .padding(.top, 18)
                                .reveal(2, revealed, reduceMotion)
                        } else if !vm.hasConverted {
                            mirrorCard
                                .padding(.top, 18)
                                .reveal(2, revealed, reduceMotion)
                        }

                        if vm.hasAnyServing {
                            SectionRule(title: "Where it went")
                                .padding(.top, 22)
                                .reveal(3, revealed, reduceMotion)

                            rows
                                .padding(.top, 2)
                                .reveal(3, revealed, reduceMotion)

                            showingUp
                                .padding(.top, 16)
                                .reveal(3, revealed, reduceMotion)

                            if vm.hasWeekReturn {
                                weekReturnEntry
                                    .padding(.top, 16)
                                    .reveal(4, revealed, reduceMotion)
                            }
                        } else {
                            firstServingInvite
                                .padding(.top, 18)
                                .reveal(2, revealed, reduceMotion)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, Theme.Space.xs)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
                .modifier(DebugBottomAnchor())
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showsWeekReturn) {
            WeekReturnView(vm: vm)
        }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion { revealed = true } else { withAnimation { revealed = true } }
        }
    }

    // MARK: The header — the comparison, stated once, as a mode.

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(vm.monthLabel)
                .font(BDFont.serif(size: 19, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
            Spacer(minLength: 8)
            Text("vs. \(vm.previousMonthLabel)")
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: The claim — identity first, so what follows reads as proof.

    private var identity: some View {
        (Text(vm.identityParts.prefix)
            .foregroundStyle(Color.bdTextPrimary)
         + Text(vm.identityParts.accent)
            .foregroundStyle(Color.bdLeafDeep))
            .font(BDFont.serif(size: 23, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The path — where you are, and the next thing it asks for.
    //
    // Sits directly under the identity claim because it is the same sentence
    // finished: "Becoming a reader" is who, this is how far and what's next.

    private var pathLine: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(vm.pathPosition)
                .font(BDFont.body(.bold, size: 11, relativeTo: .caption))
                .kerning(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdGoldText)

            if let next = vm.nextStepTitle {
                (Text("Next on the path · ")
                    .foregroundStyle(Color.bdTextSecondary)
                 + Text(next)
                    .foregroundStyle(Color.bdTextPrimary))
                    .font(BDFont.body(.semiBold, size: 13.5, relativeTo: .subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: The conversion — the hero figure inside a sentence, then the GAP.
    //
    // ⭐ THE HERO IS THE CONVERSION, NOT THE RECLAIM (Jack, 2026-09-16): "the
    // hero number of how many hours they have converted from scrolling into
    // actually putting towards their goals and dreams."
    //
    // Reclaimed time held this slot until now and it was the wrong number to
    // blow up — every blocker on the store reclaims time, so leading with it
    // measures the blocker instead of the product. Reclaimed did not leave the
    // page; it dropped one level, to where it belongs: the evidence that the
    // converted hours came OUT of something.
    //
    // Opal's grammar is unchanged — plain words with one number blown up inside
    // them, no card, so the thesis reads as the page's voice and not a widget.
    //
    // Two numbers and never one, still. Reclaimed comes from Screen Time,
    // converted comes from sessions, they are measured independently, and the
    // space between them stays printed rather than rounded away.

    private var conversion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hours you turned into progress")
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vm.heroConverted.value)
                    .font(BDFont.display(.extraBold, size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(Color.bdLeafDeep)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(vm.heroConverted.unit)
                    .font(BDFont.serif(size: 21, relativeTo: .title3))
                    .foregroundStyle(Color.bdTextSecondary)
            }
            .padding(.top, 1)

            (Text("out of the feed and into ")
                .foregroundStyle(Color.bdTextSecondary)
             + Text(vm.becamePhrase ?? String(localized: "something you chose"))
                .foregroundStyle(Color.bdTextPrimary)
             + Text(", since you started.")
                .foregroundStyle(Color.bdTextSecondary))
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)

            // ⭐ THE SPLIT IS THE MOAT, SO IT GETS PRINTED. A chatbot takes the
            // user's word for all of it; this screen can say which part it
            // actually watched the clock on. Only shown when some of the total
            // came from self-report — otherwise it is noise.
            if vm.reportedMinutesAllTime > 0 {
                Text("\(BecomingViewModel.hoursDisplay(vm.verifiedMinutesAllTime)) measured by the app · \(BecomingViewModel.hoursDisplay(vm.reportedMinutesAllTime)) you told us")
                    .font(BDFont.body(.medium, size: 10.5, relativeTo: .caption2))
                    .foregroundStyle(Color.bdTextSecondary.opacity(0.85))
                    .padding(.top, 6)
            }

            // The month, demoted to what it is: this window's contribution to a
            // total that never resets. Inherits the header's "vs. last month".
            if vm.hasMonthTrade { monthTrade.padding(.top, 18) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("You have turned \(vm.convertedAllTimeDisplay) out of the feed into progress since you started."))
    }

    // MARK: This month — the reclaim, and the gap it still leaves.

    @ViewBuilder private var monthTrade: some View {
        if let reclaimed = vm.reclaimedMonthDisplay {
            VStack(alignment: .leading, spacing: 0) {
                (Text("\(vm.investedMonthDisplay) of it in \(vm.monthLabel)")
                    .foregroundStyle(Color.bdTextPrimary)
                 + Text(", out of \(reclaimed) you took back from scrolling.")
                    .foregroundStyle(Color.bdTextSecondary))
                    .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.bdBarTrack)
                        Capsule().fill(Color.bdLeaf)
                            .frame(width: max(6, geo.size.width * vm.convertedFraction))
                    }
                }
                .frame(height: 10)
                .padding(.top, 11)

                HStack {
                    Text(vm.leveragePercent.map { "\($0)% of it working for you" }
                         ?? "\(vm.investedMonthDisplay) leveraged")
                    if let unclaimed = vm.unclaimedDisplay {
                        Spacer(minLength: 8)
                        Text("\(unclaimed) still yours")
                    }
                }
                .font(BDFont.body(.bold, size: 10.5, relativeTo: .caption2))
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: The hero — how close you are, and whether it is getting closer.

    private func milestoneHero(_ m: BecomingViewModel.MilestoneProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your next milestone")
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)

            Text(m.title)
                .font(BDFont.serif(size: 25, relativeTo: .title2))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bdBarTrack)
                    Capsule().fill(Color.bdLeafDeep)
                        .frame(width: max(6, geo.size.width * m.fraction))
                }
            }
            .frame(height: 9)
            .padding(.top, 12)

            // Steps first, then the date, then whether the date MOVED — the only
            // thing on this page that says the last week actually mattered.
            (Text("\(m.done) of \(m.total) steps")
                .foregroundStyle(Color.bdTextSecondary)
             + Text(m.projected.map { " · at this pace \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "")
                .foregroundStyle(Color.bdTextPrimary))
                .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                .padding(.top, 10)

            if let shift = vm.milestonePaceShift {
                (Text(shift.sooner
                      ? String(localized: "\(shift.days) days sooner")
                      : String(localized: "\(shift.days) days further out"))
                    .foregroundStyle(shift.sooner ? Color.bdLeafDeep : Color.bdSlopGrayText)
                 + Text(" than last week's pace.")
                    .foregroundStyle(Color.bdTextSecondary))
                    .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: This week — what the feed did not get, and where it went instead.

    private var weekTrade: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("This week")
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)

            weekBar(label: String(localized: "Usual feed"),
                    value: BecomingViewModel.hoursDisplay(vm.usualFeedMinutesWeek),
                    fraction: 1, color: Color.bdSlopGray, showsGap: false)
                .padding(.top, 9)
            weekBar(label: String(localized: "This week"),
                    value: BecomingViewModel.hoursDisplay(vm.feedMinutesThisWeek ?? 0),
                    fraction: vm.usualFeedMinutesWeek > 0
                        ? Double(vm.feedMinutesThisWeek ?? 0) / Double(vm.usualFeedMinutesWeek) : 0,
                    color: Color.bdSlopGrayText, showsGap: true)
                .padding(.top, 7)

            (Text("\(BecomingViewModel.hoursDisplay(vm.feedBackThisWeek ?? 0)) back.")
                .foregroundStyle(Color.bdLeafDeep)
             + Text(vm.returnedUsedPercent.map { " \($0)% of it went to your goals." } ?? "")
                .foregroundStyle(Color.bdTextSecondary))
                .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                .padding(.top, 12)

            // The split: each goal's share of the returned time, then the rest,
            // hatched. The remainder is never red — it is still theirs.
            HStack(spacing: 0) {
                ForEach(vm.weekRows) { row in
                    Rectangle().fill(row.color)
                        .frame(width: max(0, CGFloat(row.fraction) * splitWidth))
                }
                Rectangle().fill(Color.bdBarTrack)
            }
            .frame(height: 13)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { splitWidth = $0 }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.top, 7)

            HStack(spacing: 11) {
                ForEach(vm.weekRows) { row in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(row.color)
                            .frame(width: 8, height: 8)
                        Text(row.legend)
                            .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                            .foregroundStyle(Color.bdTextSecondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.bdBarTrack)
                        .frame(width: 8, height: 8)
                    Text("still yours")
                        .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .padding(.top, 7)
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func weekBar(label: String, value: String, fraction: Double,
                         color: Color, showsGap: Bool) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(width: 62, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.bdBarTrack)
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color)
                        .frame(width: max(5, geo.size.width * min(1, max(0, fraction))))
                    if showsGap, fraction < 1 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.bdLeaf, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: geo.size.width * (1 - min(1, max(0, fraction))))
                            .offset(x: geo.size.width * min(1, max(0, fraction)))
                    }
                }
            }
            .frame(height: 14)
            Text(value)
                .font(BDFont.body(.bold, size: 11, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(showsGap ? Color.bdLeafDeep : Color.bdSlopGrayText)
                .frame(width: 48, alignment: .trailing)
        }
    }

    /// The way into the recap. Reads as ready only when the week is actually
    /// over — offering "your week" on a Tuesday would be the app inventing an
    /// occasion.
    private var weekReturnEntry: some View {
        Button { showsWeekReturn = true } label: {
            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your week, returned")
                        .font(BDFont.serif(size: 16, relativeTo: .headline))
                        .foregroundStyle(Color.bdTextOnAccent)
                    Text(vm.weekIsOver
                         ? String(localized: "Ready now")
                         : String(localized: "Ready Sunday night"))
                        .font(BDFont.body(.regular, size: 11.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextOnAccent.opacity(0.78))
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.bdTextOnAccent.opacity(0.9))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bdLeafDeep))
        }
        .buttonStyle(.plain)
    }

    // MARK: Where they went — counted nouns wearing their category colour.

    /// ⭐ THE WEEK, IN CREDITED MINUTES (2026-09-22). These were MONTH rows on
    /// RAW minutes while the hero used the capped credited figure, so the page
    /// showed two totals for the same idea and explained neither (1h vs 2h 35m on
    /// Jack's own screenshot). One capped figure now drives the hero, the split
    /// and these rows.
    private var rows: some View {
        VStack(spacing: 0) {
            let list = vm.weekRows
            ForEach(Array(list.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(row.tint)
                        .frame(width: 34, height: 34)
                        .overlay(BDPhIcon(icon: row.icon, size: 16, color: row.color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Color.bdTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if !row.note.isEmpty {
                            Text(row.note)
                                .font(BDFont.body(.regular, size: 11.5, relativeTo: .caption2))
                                .foregroundStyle(Color.bdTextSecondary)
                        }
                    }

                    Spacer(minLength: 6)

                    Text(BecomingViewModel.hoursDisplay(row.minutes))
                        .font(BDFont.body(.bold, size: 12.5, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(row.textColor)
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)

                if index < list.count - 1 {
                    Rectangle().fill(Color.bdCardBorder).frame(height: 1)
                }
            }
        }
    }

    // MARK: Showing up, and coming back.

    private var showingUp: some View {
        HStack(spacing: 11) {
            miniStat(value: "\(vm.daysShowedUp)",
                     suffix: "/\(vm.daysElapsedInMonth)",
                     label: "days you\nshowed up")
            miniStat(value: "\(vm.bounceBacks)",
                     suffix: nil,
                     label: "times you\nbounced back")
        }
    }

    private func miniStat(value: String, suffix: String?, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(BDFont.display(.extraBold, size: 23, relativeTo: .title3))
                    .foregroundStyle(Color.bdTextPrimary)
                    .monospacedDigit()
                if let suffix {
                    Text(suffix)
                        .font(BDFont.display(.extraBold, size: 14, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                        .monospacedDigit()
                }
            }
            Text(label)
                .font(BDFont.body(.semiBold, size: 11.5, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: How close you are — the one thing pointed forward.

    private func milestoneCard(_ m: BecomingViewModel.MilestoneProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.title)
                    .font(BDFont.serif(size: 16, relativeTo: .headline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text("\(m.done) / \(m.total)")
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Color.bdTextSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bdBarTrack)
                    Capsule().fill(Color.bdLeaf)
                        .frame(width: max(6, geo.size.width * m.fraction))
                }
            }
            .frame(height: 9)
            .padding(.top, 10)

            // The date is a ROW, not a moment (KOHO / Quicken) — a fact you
            // glance at. It disappears entirely when there is no rate behind
            // it, because this page does not guess.
            if let projected = m.projected {
                HStack(alignment: .firstTextBaseline) {
                    Text("At the pace you kept this month")
                        .font(BDFont.body(.semiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                    Spacer(minLength: 8)
                    Text(projected.formatted(.dateTime.month(.wide).day()))
                        .font(BDFont.serif(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                        .lineLimit(1)
                }
                .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Honest states before there is a trade to show.
    //
    // The "You used to scroll…" line renders ONLY when a real onboarding
    // baseline exists. A planning default stated as fact would break this
    // page's own promise.

    @ViewBuilder private var mirrorCard: some View {
        if vm.hasRealBaseline, let thisWeek = vm.weeklyJunkAverageDisplay {
            card {
                Text("You used to scroll \(vm.baselineDisplay) a day.")
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.bdSlopGray)

                (Text("This week: ")
                    .foregroundStyle(Color.bdTextPrimary)
                 + Text("\(thisWeek) a day.")
                    .foregroundStyle(Color.bdLeaf)
                 + Text(" The rest came back to you.")
                    .foregroundStyle(Color.bdTextPrimary))
                    .font(BDFont.body(.bold, size: 17, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
            .accessibilityElement(children: .combine)
        } else if vm.hasRealBaseline {
            card {
                Text("You used to scroll \(vm.baselineDisplay) a day.")
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.bdSlopGray)
                Text("A few more days and we can show you the change.")
                    .font(BDFont.body(.bold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                    .padding(.top, 3)
            }
            .accessibilityElement(children: .combine)
        } else {
            card {
                Text("A few more days and we can show you the change.")
                    .font(BDFont.body(.bold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var firstServingInvite: some View {
        card {
            Text("Your first serving starts the count.")
                .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
            Text("Everything on this page is built from what you actually do. Nothing is invented.")
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            Button {
                withAnimation(Theme.Motion.smooth) { router.selectedTab = .protect }
            } label: {
                Text("See the menu")
                    .font(BDFont.body(.bold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextOnAccent)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
                    .background(Capsule().fill(Color.bdLeafDeep))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.bdSurface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1.5))
    }
}

// MARK: - DebugBottomAnchor — screenshot the BOTTOM of a scrolling screen.
//
// The simulator has no scripted-gesture path on this machine (no idb, no
// cliclick), so a tall screen can only ever be reviewed from the top. Launching
// with BD_SCROLL_BOTTOM=1 opens the page already scrolled to the end, which is
// how the lower half gets a real screenshot review rather than an assumption.
// DEBUG-only and inert without the flag.

private struct DebugBottomAnchor: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_SCROLL_BOTTOM"] == "1" {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - SectionRule — a centred gold label between two hairlines.
//
// The Menu's own section grammar, reused so Becoming and Menu read as the same
// hand. Deliberately not a card title: these divide the page, they don't own a
// container.

/// A centred gold label between two hairlines. Promoted from private on
/// 2026-08-28 so the Menu tab can wear the SAME rule — the tabs read as one app
/// only if the shared furniture is literally shared, not re-typed per screen.
struct SectionRule: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 11) {
            line
            Text(title)
                .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                .kerning(1.9)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdGoldText)
                .fixedSize()
            line
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.bdCardBorder)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Reveal — a gentle staggered rise + fade on first appear.

private extension View {
    func reveal(_ index: Int, _ active: Bool, _ reduceMotion: Bool) -> some View {
        modifier(BecomingReveal(index: index, active: active, reduceMotion: reduceMotion))
    }
}

private struct BecomingReveal: ViewModifier {
    let index: Int
    let active: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 18)
                .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.07 * Double(index)),
                           value: active)
        }
    }
}

#Preview {
    BecomingView()
        .environment(AppRouter())
        .modelContainer(for: [UserProfile.self, ProtectSession.self, Goal.self, GoalStep.self],
                        inMemory: true)
}
