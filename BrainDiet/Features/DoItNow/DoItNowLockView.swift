import SwiftUI

// MARK: - Do it now — the lock screen (Jack, 2026-10-08).
//
// Built from design/rewiring/feed-prototype.html `.lock`: night-green ground,
// mint eyebrow, the step in Young Serif, a 230pt countdown ring, one line about
// what is locked, and one way out: "I did it", which feeds the brain exactly
// like dragging the card into it.
//
// When the time runs out the same screen asks "Time's up. Did you do it?" and
// adds a quiet "Not yet" that just closes. Nothing here is a new animation.

struct DoItNowLockView: View {

    let session: DoItNowSession
    let onDidIt: () -> Void
    let onNotYet: () -> Void
    /// Fires once when the countdown crosses zero (releases the system shield).
    var onExpire: () -> Void = {}
    /// The honest exit (Jack, 2026-10-09): releases the lock, feeds nothing.
    var onEndEarly: () -> Void = {}

    @State private var confirmingEnd = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let over = session.isOver(context.date)
            content(now: context.date, over: over)
                .onChange(of: over) { _, isOver in if isOver { onExpire() } }
        }
        .background(Color.bdLockGround.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func content(now: Date, over: Bool) -> some View {
        VStack(spacing: 0) {
            Text("Do it now")
                .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdMint)
                .padding(.top, 64)

            Text(session.title)
                .font(BDFont.serif(size: 28, relativeTo: .title))
                .foregroundStyle(Color.bdLockInk)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            ring(now: now)
                .padding(.top, 34)
                .padding(.bottom, 20)

            if over {
                Text("Time's up. Did you do it?")
                    .font(BDFont.serif(size: 21, relativeTo: .title3))
                    .foregroundStyle(Color.bdLockInk)
                    .multilineTextAlignment(.center)
            } else {
                Text(session.shielded
                     ? "Every app is locked except your chosen ones"
                     : "Put the phone down until it's done")
                    .font(BDFont.body(.regular, size: 12.5, relativeTo: .footnote))
                    .foregroundStyle(Color.bdMint)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 24)

            Button(action: onDidIt) {
                Text("I did it")
                    .font(BDFont.body(.bold, size: 16, relativeTo: .headline))
                    .foregroundStyle(Color.bdLockGround)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Size.buttonHeight)
                    .background(Color.bdMint, in: Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: over)

            if over {
                Button(action: onNotYet) {
                    Text("Not yet")
                        .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdMint)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Size.minTouch + 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                // ⭐ THE HONEST EXIT (2026-10-09). A lock with no way out gets
                // the app deleted, and a fake "I did it" poisons the record.
                // Ending early costs exactly one thing: this step does not count.
                Button { confirmingEnd = true } label: {
                    Text("End early")
                        .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdMint.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Size.minTouch)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 24)
        .animation(Theme.Motion.smooth, value: over)
        .confirmationDialog("End early?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End early", role: .destructive, action: onEndEarly)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This one won't count.")
        }
    }

    private func ring(now: Date) -> some View {
        let left = session.remaining(now)
        return ZStack {
            Circle()
                .stroke(Color.bdMint.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: session.fractionLeft(now))
                .stroke(Color.bdMint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: session.fractionLeft(now))
            Text(Self.clock(left))
                .font(BDFont.serif(size: 46, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdLockInk)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 230, height: 230)
        .accessibilityElement()
        .accessibilityLabel(left > 0
            ? Text("\(Int((left / 60).rounded(.up))) minutes left")
            : Text("Time's up"))
    }

    /// 1199 → "19:59", 3725 → "1:02:05".
    private static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

#Preview("Running") {
    DoItNowLockView(session: DoItNowSession(title: "Read 10 pages of Atomic Habits",
                                            domainRaw: "reading", goalID: nil, stepID: nil,
                                            minutes: 20, shielded: true),
                    onDidIt: {}, onNotYet: {})
}

#Preview("Time's up") {
    DoItNowLockView(session: DoItNowSession(title: "Read 10 pages of Atomic Habits",
                                            domainRaw: "reading", goalID: nil, stepID: nil,
                                            minutes: 20, startedAt: .now.addingTimeInterval(-1300),
                                            shielded: true),
                    onDidIt: {}, onNotYet: {})
}
