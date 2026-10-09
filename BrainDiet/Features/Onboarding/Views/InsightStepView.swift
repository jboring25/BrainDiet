import SwiftUI

// MARK: - Step: interstitial — the held breath (Opal mapping row 4).
//
// Opal paces its emotional beats with one-sentence theater ("Some not-so-good
// news, and some great news."). Ours: the beat on the gray canvas before the
// permission ask + mirror — the mirror lands harder after a held breath. The
// container's shared Continue is the only action.
//
// ⭐ 2026-07-22 UX audit: both lines were the same 26pt serif differing only in
// color, which read flat ("a slide deck"). Fixed with a real hierarchy — a small
// gray lead-in over a large serif payoff.
//
// ⭐ SHOW IT (Jack, 2026-08-12): "as long as you show more than you tell and you
// convey a feeling... in a way with not that much text that evokes a feeling in
// the user, then it is good."
//
// This screen was the worst offender in the app by that bar. Its ONLY job is a
// feeling, and it delivered the feeling as an assertion — four lines of serif
// telling you your attention is targeted, over half a screen of nothing. You
// cannot argue someone into a feeling.
//
// Now the phone does it: a dead gray feed that runs off the bottom of the
// screen and fades out without ending. `BDDeviceFrame`'s mask gives us
// "bottomless" for free, with no animation — which matters, because the
// no-hand-built-animation guardrail is absolute and a self-scrolling feed is
// exactly the kind of thing that would tempt a violation. A still image of
// something endless reads as endless.
//
// ⭐ AND THE PROMISE WAS CUT. The old payoff ended "Strong habits are how you
// take it back" — a claim that the very NEXT step now demonstrates (the `pause`
// step shows the real triage screen). Promising a fix immediately before
// showing the fix is the definition of telling when you could show. Two short
// lines survive; the picture carries the rest.

// ⭐ V3 (Jack approved 2026-10-09): the layout is now a reusable insight
// beat, `InsightStepView`, carrying two screens of the pain sweep:
//   • emptyTimeInsight — on gray, with the bottomless feed under it: why the
//     fixes they just named never stuck.
//   • cueInsight — on cream, after they describe their day: the
//     implementation-intention finding, with its citation.
// The old "never about willpower / built to be bottomless" copy is retired.

struct InsightStepView: View {
    /// The small lead-in line.
    let lead: String
    /// The serif payoff.
    let headline: String
    let message: String
    var footnote: String? = nil
    /// The dead, bottomless feed under the text (gray world only).
    var showsFeed: Bool = false
    var grayWorld: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The lead-in: small, quiet. It sets up the payoff.
            Text(lead)
                .font(BDFont.body(.semiBold, size: 17.5, relativeTo: .body))
                .foregroundStyle(grayWorld ? Color.bdGrayInk : Color.bdTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(headline)
                .font(BDFont.serif(size: 31, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                .foregroundStyle(grayWorld ? Color.bdGrayInk : Color.bdTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if let footnote {
                Text(footnote)
                    .font(BDFont.body(.medium, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary.opacity(0.8))
                    .padding(.top, 2)
            }

            if showsFeed {
                // Two and a half identical cards running off the bottom: the
                // place you go back to when the freed time sits empty.
                BDDeviceFrame(width: 190, visibleFraction: 0.74) { DeadFeedPoster() }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.lg)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown || reduceMotion ? 0 : 18)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard !reduceMotion else { shown = true; return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.86).delay(0.2)) {
                shown = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel([lead, headline, message, footnote ?? ""].joined(separator: " "))
    }
}

/// v3 · Why it never stuck. The headline answers their own triedBefore.
struct EmptyTimeInsightStepView: View {
    let vm: OnboardingViewModel

    var body: some View {
        InsightStepView(
            lead: String(localized: "Why it never stuck"),
            headline: vm.triedSomething
                ? String(localized: "Blocking frees the time. Nothing fills it. So you go back.")
                : String(localized: "Most people block the apps. Then the time sits empty, and they go back."),
            message: String(localized: "BrainDiet fills it with what the person you want to be would do."),
            showsFeed: true,
            grayWorld: true)
    }
}

/// v3 · One thing that works (Gollwitzer & Sheeran 2006).
struct CueInsightStepView: View {
    var body: some View {
        InsightStepView(
            lead: String(localized: "One thing that works"),
            headline: String(localized: "Steps tied to something you already do get done about twice as often."),
            message: String(localized: "So every step you get hangs on a moment that already happens in your day."),
            footnote: String(localized: "Gollwitzer and Sheeran, 2006"))
    }
}

// MARK: - The feed, with no bottom.
//
// Abstracted post cards — an avatar dot, two text bars, a media block — in the
// gray-world palette and nothing else. No logos, no brand marks, no emoji: this
// has to read as THE feed rather than as any particular company's, both because
// naming one would be a legal problem and because the argument is about the
// design pattern, not about one app.
//
// Every card is identical on purpose. Sameness is the feeling; variety would
// make it look interesting, which is the opposite of the point.

private struct DeadFeedPoster: View {
    var body: some View {
        ZStack {
            Color.bdGrayCanvas
            VStack(spacing: 11) {
                ForEach(0..<5, id: \.self) { _ in card }
            }
            .padding(.horizontal, 12)
            .padding(.top, 44)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(Color.bdSlopLight).frame(width: 17, height: 17)
                VStack(alignment: .leading, spacing: 3) {
                    bar(width: 52, height: 5)
                    bar(width: 34, height: 4)
                }
                Spacer(minLength: 0)
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.bdSlopLight)
                .frame(height: 62)
            bar(width: 96, height: 5)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule().fill(Color.bdSlopLight).frame(width: width, height: height)
    }
}

#Preview("Empty time") {
    ZStack {
        Color.bdGrayCanvas.ignoresSafeArea()
        EmptyTimeInsightStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX)
    }
}

#Preview("Cue") {
    ZStack {
        BDBackground()
        CueInsightStepView().padding(Theme.Space.screenX)
    }
}
