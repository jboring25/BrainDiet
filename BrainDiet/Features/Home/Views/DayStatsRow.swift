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
    /// Days of practice left until the habit is automatic (see `wiredFoot`).
    let daysToWired: Int
    /// Which habit the number is about ("reading").
    let wiredHabit: String
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
            // ⭐ NEUROPLASTICITY, AS A NUMBER (Jack, 2026-10-07: "286 connections
            // means genuinely nothing"). Lally et al. (2010, EJSP): a new daily
            // behaviour took a median of 66 days of repetition to become
            // automatic. Each day the user actually does their main habit counts
            // one; this is how many such days remain.
            stat(value: daysToWired == 0 ? "wired" : "\(daysToWired)",
                 label: "days to wired",
                 foot: wiredHabit, lit: false, tint: .bdLeaf)
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
    /// The round button: lock the phone for this step (Do it now, 2026-10-08).
    let onDoItNow: () -> Void
    /// ⭐ DRAG, DON'T TAP (Jack, 2026-10-07): "I did this" is now a handle you
    /// drag into your brain. It turns into the serving ball and lands where you
    /// let go. The tap-only path survives as an accessibility action.
    var onDragChanged: ((DragGesture.Value) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    /// True while this card is in the user's hand (the overlay is drawn instead).
    var isLifted: Bool = false

    // ⭐ THE CARD IS THE OBJECT (Jack, 2026-10-08): "the overall box for the task
    // [is] what is dragged... the user [should] feel the need to drag it... so
    // nothing needs to be explicitly stated." No "drag" label anywhere. The
    // card says it moves the way physical things on iOS do:
    //
    //   • A GRABBER at the top edge — the same capsule a sheet uses, the one
    //     signifier every iPhone user already reads as "this lifts".
    //   • It sits HIGHER than every other card — a deeper, directional shadow —
    //     so it reads as a loose object resting on the page, not part of it.
    //   • It LIFTS ON TOUCH (scale + shadow + light haptic) before you move,
    //     exactly like a Home Screen icon or a reorderable row.
    //   • Until the first drag, it NUDGES toward the brain every few seconds —
    //     a short spring hop and settle, the same trick the Lock Screen uses to
    //     teach the swipe up to the camera. It stops for good once learned.
    //
    // Compact on purpose: one icon, the step, one meta line, and the timer as a
    // round button (Do it now). The specific action is the biggest type on the card.

    @State private var pressing = false
    @State private var nudge: CGFloat = 0
    @AppStorage("bd.hasFedByDrag") private var hasFedByDrag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.bdTextSecondary.opacity(0.28))
                .frame(width: 34, height: 4)
                .padding(.top, 7)
                .padding(.bottom, 8)

            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.3))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.bdTextPrimary.opacity(0.75))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BDFont.serif(size: 19, relativeTo: .title3))
                        .foregroundStyle(Color.bdTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cue.isEmpty ? "\(minutes)m" : "\(minutes)m · \(cue)")
                        .font(BDFont.body(.regular, size: 12.5, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)

                Button(action: onDoItNow) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.bdLeafDeep)
                        .frame(width: 40, height: 40)
                        .background(Circle().strokeBorder(Color.bdLeafDeep.opacity(0.3), lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Do it now")
                .accessibilityHint("Locks every app except your chosen ones for \(minutes) minutes.")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
        }
        // Resting higher than the page: a directional shadow, deeper on touch.
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: Color(hex: "#2F5E3C").opacity(pressing ? 0.22 : 0.12),
                radius: pressing ? 18 : 12, y: pressing ? 12 : 7)
        .scaleEffect(pressing ? 1.025 : 1)
        .offset(y: nudge)
        .opacity(isLifted ? 0 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: pressing)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .gesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "I did this") { onSelfReport() }
        .task(id: hasFedByDrag) { await teach() }
    }

    /// A short hold arms it (so a scroll that starts on the card still scrolls),
    /// but the card answers the instant the finger lands.
    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.16)
            .onChanged { _ in
                if !pressing {
                    pressing = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                }
            }
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("homePlate")))
            .onChanged { value in
                if case .second(true, let drag?) = value { onDragChanged?(drag) }
            }
            .onEnded { _ in
                pressing = false
                onDragEnded?()
            }
    }

    /// The Lock Screen's lesson: hop toward the target, settle, wait. Only until
    /// the user has fed their brain by dragging once.
    private func teach() async {
        guard !hasFedByDrag, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(2.2))
        while !Task.isCancelled, !hasFedByDrag {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) { nudge = -11 }
            try? await Task.sleep(for: .milliseconds(170))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) { nudge = 0 }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) { nudge = -5 }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { nudge = 0 }
            try? await Task.sleep(for: .seconds(5.5))
        }
    }
}
