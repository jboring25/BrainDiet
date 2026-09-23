import SwiftUI

// MARK: - BrainDiet wordmark — the plate D (Jack, 2026-08-16).
//
// ⭐ WHAT CHANGED. The mark used to be a flat leaf dot + "BRAINDIET" in tracked
// extra-bold caps, with a code comment claiming the dot was "a plate-dot glyph"
// when it was just a circle. The name now carries the idea itself: the capital
// D IS a plate seen from the side — a solid half-disc with a crescent counter
// where the hollow of the plate would be. A D is already a plate shape, so the
// letter is not being forced into anything.
//
// The dot is gone (it was doing the plate's job badly, and the plate does it),
// and the name is mixed case — there is no capital D to replace in BRAINDIET
// without it reading as a dropped cap.
//
// COLOUR: all leaf, Jack's pick from four lockups judged in the real header at
// real size. All-black lost the plate into the word; a coral accent arc was too
// fine to resolve at 27px; green-D-only kept more hierarchy but he chose the
// full word.
//
// The asset is a TEMPLATE (alpha only), so `foregroundStyle` tints it and the
// crescent inside the plate is genuinely transparent — the counter takes
// whatever is behind it, the way a real letterform does. That is what lets the
// same mark sit on the cream canvas, the gray onboarding world and the share
// card without three separate renders.

struct BrandWordmark: View {
    enum Tone { case onDark, onCream }
    var tone: Tone = .onDark
    /// Rendered HEIGHT of the wordmark in points (was a font size before —
    /// the mark is now art, so it is measured the way art is).
    var size: CGFloat = 13

    /// Width ÷ height of the source lockup. Hard-coded so the mark can never be
    /// stretched by a mis-sized frame.
    private static let aspect: CGFloat = 4.957

    /// ⚠️ The `Tone` names are legacy and inverted: `.onDark` has always meant
    /// "dark ink, for a LIGHT canvas" — every call site passes it and every one
    /// of them sits on cream. So both cases resolve to the deep leaf, which is
    /// the value that holds against cream. A genuinely dark canvas would want
    /// `.bdLeaf` (the lighter leaf); nothing renders the mark there yet, and
    /// guessing a variant nobody uses is how the old "plate-dot" comment ended
    /// up describing a plain circle.
    private var inkColor: Color { Color.bdLeafDeep }

    var body: some View {
        Image("BrandWordmarkPlate")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * Self.aspect, height: size)
            .foregroundStyle(inkColor)
            .accessibilityElement()
            .accessibilityLabel("BrainDiet")
    }
}

#Preview {
    VStack(spacing: 0) {
        BrandWordmark(tone: .onCream, size: 13)
            .padding(28).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdBackground)
        BrandWordmark(tone: .onCream, size: 26)
            .padding(28).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdBackground)
        BrandWordmark(tone: .onDark, size: 20)
            .padding(28).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdGrayCanvas)
    }
}
