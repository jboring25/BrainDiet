import SwiftUI

// MARK: - DayStatsRow — three numbers under the headline (Jack, 2026-09-13).
//
// ⭐ WHY THIS REPLACED "1m protected · enough for one more serving". That line
// was a fact, not a reading. Three figures together let you feel the shape of
// things in one glance; one fact does not.
//
// ⭐ WHY NOTHING HERE IS A DAILY COUNT (Jack, 2026-09-14): "they start off at
// zero whereas Opal's starts off at 100 and goes down. I don't like starting at
// zero, but we cannot blatantly copy Opal."
//
// He is right on both counts, and the two problems have one answer.
//
// Opal GRANTS you 100 at midnight and takes it away as you slip. It is loss
// aversion, it works, and it is also a lie — you did not earn that 100, and by
// 9am on a normal day the app is already telling you that you are losing.
//
// Starting at zero is the opposite lie: it says everything you did yesterday
// counted for nothing, which is the precise opposite of what this app claims
// about identity.
//
// ⭐ SO THE WINDOW IS SEVEN DAYS, NOT ONE. The big number is what you have
// actually built over the last week. It is never granted and it is never wiped —
// it rises when you feed it and drifts down on its own as dead days roll off the
// back. **Nothing is given to you, and nothing is taken away; it is only ever a
// measure of what you did.** That is a genuinely different mechanic from Opal's,
// not a reskin of it, and it is the only one of the three that is true to a diet:
// one bad meal is not a verdict, and one good meal is not a week.
//
// Today still shows, as the small delta under each label — so the day is legible
// without the day being the scoreboard.
//
// ⭐ TWO ROLL, ONE NEVER DOES. Fed and Protected are a moving window.
// Connections is ALL TIME and only ever goes up — the literal count of points
// drawn inside the brain above it (`fillSiteCount × growth`), so the number and
// the picture are the same fact and neither needs a caption.

struct DayStatsRow: View {

    /// Servings in the last seven days.
    let fedWeek: Int
    /// Protected minutes in the last seven days.
    let protectedWeek: Int
    /// Points inside the brain — all time.
    let connections: Int
    /// Today's contribution, shown small so the day is legible without the day
    /// being the scoreboard.
    let fedToday: Int
    let protectedToday: Int

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stat(value: "\(fedWeek)", label: "fed · 7 days",
                 foot: fedToday > 0 ? "+\(fedToday) today" : "none yet today",
                 lit: fedToday > 0, tint: .bdLeafDeep)
            divider
            stat(value: clock(protectedWeek), label: "protected · 7 days",
                 foot: protectedToday > 0 ? "+\(clock(protectedToday)) today" : "none yet today",
                 lit: protectedToday > 0, tint: .bdGoldText)
            divider
            stat(value: "\(connections)", label: "connections",
                 foot: "all time", lit: false, tint: .bdLeaf)
        }
        .frame(maxWidth: .infinity)
    }

    private func clock(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    private func stat(value: String, label: LocalizedStringKey,
                      foot: String, lit: Bool, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BDFont.serif(size: 25, relativeTo: .title2))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(BDFont.body(.bold, size: 9, relativeTo: .caption2))
                .kerning(0.7)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(foot)
                .font(BDFont.body(.regular, size: 9.5, relativeTo: .caption2))
                .foregroundStyle(lit ? Color.bdLeafDeep : Color.bdTextSecondary.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.bdCardBorder)
            .frame(width: 1, height: 34)
    }
}

// MARK: - TodaysFocusCard — the one thing, given the most weight on the screen.
//
// ⭐ It sits directly under the numbers because the numbers say how the day is
// going and this says what to do about it. Anything between them would be a
// change of subject.
//
// The reason line is ONE line and it names the user's own identity sentence, so
// the app is never the one making the claim — it is quoting them back.

struct TodaysFocusCard: View {

    let title: String
    let cue: String
    let minutes: Int
    let reason: String
    let symbol: String
    let tint: Color
    let onSelfReport: () -> Void
    let onTimer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's one thing")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdGoldText)

            HStack(alignment: .top, spacing: 11) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.3))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.bdTextPrimary.opacity(0.75))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BDFont.serif(size: 20, relativeTo: .title3))
                        .foregroundStyle(Color.bdTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !cue.isEmpty {
                        Text(cue)
                            .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.bdTextSecondary)
                    }
                }
                Spacer(minLength: 4)
                Text("\(minutes)m")
                    .font(BDFont.body(.bold, size: 13, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
            }
            .padding(.top, 9)

            Text(reason)
                .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)

            // ⭐ TWO WAYS IN, NOT ONE (Jack: "I don't think they're going to use
            // the timer"). Self-report is the wide, filled, default path; the
            // timer is the smaller one beside it. Neither is hidden.
            HStack(spacing: 9) {
                Button(action: onSelfReport) {
                    Text("I did this")
                        .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.bdLeafDeep, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onTimer) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer").font(.system(size: 13, weight: .bold))
                        Text("Time it").font(BDFont.body(.bold, size: 13, relativeTo: .caption))
                    }
                    .foregroundStyle(Color.bdLeafDeep)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 15)
                    .background {
                        Capsule().strokeBorder(Color.bdLeafDeep.opacity(0.35), lineWidth: 1.2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 13)
        }
        .padding(15)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
        }
    }
}
