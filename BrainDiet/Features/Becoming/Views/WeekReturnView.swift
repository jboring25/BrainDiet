import SwiftUI

// MARK: - WeekReturnView — the week, returned (Jack, approved 2026-09-22).
//
// ⭐ THE TRANSLATION HAPPENS ONCE, AT THE END. Jack: "show them what that
// reduction actually accomplished in terms of their goals." Four findings decide
// the shape, and each one is a thing on this screen rather than a footnote:
//
//   • PEAK-END (Kahneman et al. 1993; Redelmeier & Kahneman 1996) — an episode is
//     remembered by its peak and its END. So the meaning lands in one moment at
//     the end of the week instead of being sprinkled across the tab.
//   • FRESH START (Dai, Milkman & Riis 2014) — a new week spikes goal-directed
//     behaviour, so this ends on Monday's first step, not on a summary.
//   • PROGRESS MONITORING (Harkin et al. 2016, 138 studies) — monitoring improves
//     attainment, more so when progress is physically recorded. This is the record.
//   • PROGRESS PRINCIPLE (Amabile & Kramer 2011) — visible small wins are the
//     strongest everyday motivator, hence counted nouns over raw minutes.
//
// ⚠️ TWO MEASURED NUMBERS, SIDE BY SIDE, NEVER A CAUSE. Feed minutes come from
// Screen Time; goal minutes come from sessions. The screen never says one became
// the other. And it says "feed", never "screen time", because the meter only sees
// the apps the user chose to rest.

struct WeekReturnView: View {

    let vm: BecomingViewModel
    var onDismiss: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var back: Int { vm.feedBackThisWeek ?? 0 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.bdGrayCanvas, Color.bdBackground],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    tradeCard.padding(.top, 16)
                    rowsBlock.padding(.top, 18)
                    if let m = vm.milestone { milestoneCard(m).padding(.top, 14) }
                    if let next = vm.nextWeekFirstStep { nextCard(next).padding(.top, 12) }

                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Text("Start the week")
                            .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Color.bdTextOnAccent)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.buttonHeight)
                            .background(Capsule().fill(Color.bdLeafDeep))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
                .padding(.horizontal, Theme.Space.screenX)
                .padding(.bottom, Theme.Space.xxl)
                .opacity(revealed || reduceMotion ? 1 : 0)
                .offset(y: revealed || reduceMotion ? 0 : 14)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            guard !revealed else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.88)) { revealed = true }
        }
    }

    // MARK: The one number

    private var header: some View {
        VStack(spacing: 6) {
            Text(vm.weekRangeLabel)
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdGoldText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(BecomingViewModel.hoursDisplay(back))
                    .font(BDFont.display(.extraBold, size: 46, relativeTo: .largeTitle))
                    .foregroundStyle(Color.bdLeafDeep)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Text("less feed than your usual week")
                .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.bdTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    // MARK: The two bars — the proof, not a decoration

    private var tradeCard: some View {
        VStack(spacing: 9) {
            bar(label: String(localized: "Usual"),
                value: BecomingViewModel.hoursDisplay(vm.usualFeedMinutesWeek),
                fraction: 1, color: Color.bdSlopGray, dashedRemainder: false)
            bar(label: String(localized: "You"),
                value: BecomingViewModel.hoursDisplay(vm.feedMinutesThisWeek ?? 0),
                fraction: vm.usualFeedMinutesWeek > 0
                    ? Double(vm.feedMinutesThisWeek ?? 0) / Double(vm.usualFeedMinutesWeek) : 0,
                color: Color.bdSlopGrayText, dashedRemainder: true)
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
    }

    private func bar(label: String, value: String, fraction: Double,
                     color: Color, dashedRemainder: Bool) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .font(BDFont.body(.bold, size: 11, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.bdBarTrack)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color)
                        .frame(width: max(6, geo.size.width * min(1, max(0, fraction))))
                    // The gap IS the story — the time the feed did not get.
                    if dashedRemainder, fraction < 1 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.bdLeaf, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: geo.size.width * (1 - min(1, max(0, fraction))))
                            .offset(x: geo.size.width * min(1, max(0, fraction)))
                    }
                }
            }
            .frame(height: 15)

            Text(value)
                .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(dashedRemainder ? Color.bdLeafDeep : Color.bdSlopGrayText)
                .frame(width: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(value)"))
    }

    // MARK: What it went into — counted nouns, not minutes

    private var rowsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You put \(BecomingViewModel.hoursDisplay(vm.goalMinutesThisWeek)) of it into")
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)

            ForEach(vm.weekRows) { row in
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(row.tint)
                        .frame(width: 32, height: 32)
                        .overlay(BDPhIcon(icon: row.icon, size: 16, color: row.color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(BDFont.body(.bold, size: 13.5, relativeTo: .subheadline))
                            .foregroundStyle(Color.bdTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if !row.note.isEmpty {
                            Text(row.note)
                                .font(BDFont.body(.regular, size: 11, relativeTo: .caption))
                                .foregroundStyle(Color.bdTextSecondary)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(BecomingViewModel.hoursDisplay(row.minutes))
                        .font(BDFont.body(.bold, size: 12, relativeTo: .footnote))
                        .monospacedDigit()
                        .foregroundStyle(row.textColor)
                }
                .padding(.vertical, 9)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: The milestone — where the week actually moved them

    private func milestoneCard(_ m: BecomingViewModel.MilestoneProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(m.title)
                .font(BDFont.body(.bold, size: 10, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdGoldText)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bdBarTrack)
                    Capsule().fill(Color.bdLeafDeep)
                        .frame(width: max(6, geo.size.width * m.fraction))
                }
            }
            .frame(height: 9)
            .padding(.top, 9)

            // ⚠️ The dates are a ROW, not pins on the bar. The bar measures STEPS;
            // hanging dates off it would encode time on an axis that is not time.
            if let projected = m.projected {
                HStack(spacing: 8) {
                    Text("At this pace")
                        .font(BDFont.body(.semiBold, size: 11.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                    Text(projected.formatted(.dateTime.month(.abbreviated).day()))
                        .font(BDFont.serif(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                    if let was = vm.milestoneProjectedLastWeek {
                        Text("·")
                            .foregroundStyle(Color.bdCardBorder)
                        Text("last week said \(was.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(BDFont.body(.regular, size: 11.5, relativeTo: .caption))
                            .foregroundStyle(Color.bdSlopGrayText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
            }

            if let shift = vm.milestonePaceShift {
                (Text("This week's pace moved it ")
                    .foregroundStyle(Color.bdTextSecondary)
                 + Text(shift.sooner
                        ? String(localized: "\(shift.days) days closer.")
                        : String(localized: "\(shift.days) days further out."))
                    .foregroundStyle(shift.sooner ? Color.bdLeafDeep : Color.bdSlopGrayText))
                    .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Ends pointed forward, never on a summary

    private func nextCard(_ next: (title: String, cue: String, minutes: Int)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Your next step")
                .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdGoldText)
            Text(next.title)
                .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(next.cue.isEmpty ? "\(next.minutes) min"
                                  : "\(next.cue) · \(next.minutes) min")
                .font(BDFont.body(.regular, size: 11.5, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.bdSurface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
