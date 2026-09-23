import SwiftUI

// MARK: - Step: the pause — the mechanic, SHOWN, before we ask for the keys.
//
// ⭐ ADDED 2026-08-11 from Jack's Opal teardown: "their onboarding tells a story
// and has a deep talk to you one on one, with barely any text and all visuals
// and feeling."
//
// THE GAP THIS FILLS. The very next step asks for Family Controls — the most
// invasive permission iOS has — and until now we asked for it having never once
// shown what we'd do with it. Opal spends an entire screen first: a headline,
// one line of subtitle, and a phone with the pause actually happening on it.
// That screen is doing conversion work AND consent work at the same time, and
// we had no equivalent anywhere in the flow.
//
// WHY IT LOOKS LIKE THIS. Everything the app could say here it has already said
// in paragraphs elsewhere, and paragraphs are what Jack flagged. So: seven words
// of headline, nine of subtitle, and the rest is the product. `BDDeviceFrame`
// is what makes that honest — content inside a phone bezel reads as "this is
// the app", never as a claim about the user.
//
// The shared Continue at the bottom is the only action (`showsBottomCTA` covers
// this step by default). No skip, because there is nothing to skip: this asks
// for nothing.

struct PauseStepView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("You'll get a pause, not a wall.")
                    .font(BDFont.serif(size: 30, relativeTo: .largeTitle))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // ⭐ ONE LINE, and it names the DIFFERENCE rather than the
                // feature. Every competitor blocks; the thing worth a sentence
                // is that we ask why first and hand back something matched.
                Text("We ask what you're really after, then hand you that instead.")
                    .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            .padding(.top, Theme.Space.lg)

            Spacer(minLength: Theme.Space.md)

            TriagePoster.framed(width: 216)
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 18)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            guard !reduceMotion else { shown = true; return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.15)) {
                shown = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("You'll get a pause, not a wall. We ask what you're really after, then hand you that instead.")
    }
}

#Preview {
    ZStack {
        BDBackground(intensity: .standard)
        PauseStepView().padding(.horizontal, Theme.Space.screenX)
    }
}
