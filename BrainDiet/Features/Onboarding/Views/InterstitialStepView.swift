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

struct InterstitialStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The lead-in: small, quiet, gray. It sets up the payoff.
            Text("This was never about willpower.")
                .font(BDFont.body(.semiBold, size: 17.5, relativeTo: .body))
                .foregroundStyle(Color.bdGrayInk)
                .fixedSize(horizontal: false, vertical: true)

            // The payoff. "Bottomless" is doing the work of a paragraph: it's
            // the app's own word for the feed (the hijack step's captions call
            // it the bottomless bowl), it names the design rather than blaming
            // the user, and it's the caption for the picture below it.
            Text("It was built to be bottomless.")
                .font(BDFont.serif(size: 31, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // 0.74, not 0.62: at the shorter reveal only one and a half cards
            // survived the fade, and one card is a screenshot — REPETITION is
            // what reads as endless. Two and a half identical cards running off
            // the bottom is the whole argument.
            BDDeviceFrame(width: 190, visibleFraction: 0.74) { DeadFeedPoster() }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.lg)
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 18)

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
        .accessibilityLabel("This was never about willpower. It was built to be bottomless.")
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

#Preview {
    ZStack {
        Color.bdGrayCanvas.ignoresSafeArea()
        InterstitialStepView().padding(Theme.Space.screenX)
    }
}
