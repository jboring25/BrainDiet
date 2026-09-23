import SwiftUI

// MARK: - BDDeviceFrame — the app, shown rather than described.
//
// ⭐ ADDED 2026-08-11 from Jack's Opal teardown: "their onboarding tells a story
// and has a deep talk to you one on one, with barely any text and all visuals
// and feeling." Every explain-the-feature beat we had was a PARAGRAPH. Opal's
// equivalent is a headline, one line of subtitle, and a phone showing the thing
// actually happening.
//
// ⭐ THE HONESTY ARGUMENT, which is why this component earns its place rather
// than being decoration. Our laws forbid dressing engine defaults or invented
// figures up as the user's own data. A device frame resolves that cleanly:
// content inside a phone bezel reads as "this is the product", not "this is
// you" — the same contract an App Store screenshot has. So a preview beat can
// finally show a populated, beautiful screen without claiming those numbers
// belong to anyone. Outside the frame, the honesty law is unchanged: every
// figure must be derived from the user's real answers.
//
// The bottom FADES rather than closing off a whole phone. A full device outline
// makes the content look small and finished; a fade says the screen continues
// past the edge, which is what makes Opal's read like a window instead of a
// sticker.

struct BDDeviceFrame<Content: View>: View {

    /// Screen width. Height follows the 19.5:9 iPhone ratio unless overridden.
    var width: CGFloat = 208
    /// How much of the phone is shown before the fade (1 = the whole device).
    var visibleFraction: CGFloat = 0.78
    /// Bezel thickness. 6 reads as a modern phone at this scale; thinner looks
    /// like a floating rectangle, thicker looks like an old device.
    var bezel: CGFloat = 6
    @ViewBuilder var content: Content

    private var fullHeight: CGFloat { width * 19.5 / 9 }
    private var shownHeight: CGFloat { fullHeight * visibleFraction }

    var body: some View {
        ZStack(alignment: .top) {
            // The screen.
            content
                .frame(width: width, height: fullHeight, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            // The Dynamic Island — small, but its absence is the single biggest
            // tell that a mockup is a rectangle rather than a phone.
            Capsule()
                .fill(Color.black)
                .frame(width: width * 0.30, height: width * 0.085)
                .padding(.top, width * 0.045)
        }
        .padding(bezel)
        .background(
            RoundedRectangle(cornerRadius: 30 + bezel, style: .continuous)
                .fill(Color.bdDeviceBezel)
        )
        .frame(width: width + bezel * 2, height: shownHeight, alignment: .top)
        .clipped()
        // The fade lives on the frame, not the content, so the bezel dissolves
        // with the screen instead of running on as a bright edge.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.72),
                    .init(color: .black.opacity(0), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 22, y: 12)
        .accessibilityHidden(true)   // decorative: the headline carries the meaning
    }
}

extension Color {
    /// The bezel. Deliberately the ink brown rather than pure black — a black
    /// rectangle on the cream canvas is the one element in the app that would
    /// read as foreign.
    static var bdDeviceBezel: Color { Color(red: 0.16, green: 0.14, blue: 0.11) }
}

#Preview("Frame") {
    ZStack {
        BDBackground()
        BDDeviceFrame {
            ZStack {
                Color.bdBackground
                VStack(spacing: 12) {
                    BDPlateMark(nourishment: 1, steaming: true)
                        .frame(width: 130)
                    Text("Your brain is hungry.")
                        .font(BDFont.serif(size: 15, relativeTo: .body))
                        .foregroundStyle(Color.bdTextPrimary)
                }
                .padding(.top, 60)
            }
        }
    }
}
