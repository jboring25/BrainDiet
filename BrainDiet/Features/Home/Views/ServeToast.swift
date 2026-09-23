import SwiftUI

// MARK: - ServeToast — the "Served." capsule that rides on the hero.
//
// ⚠️ RESTORED 2026-09-09. This type used to live at the bottom of
// `TodaysPlateCard.swift`, which was deleted as dead code because the CARD it is
// named after had no references. The file had a second top-level declaration and
// the check never looked past the first. **Before deleting a file, enumerate
// every top-level declaration in it, not just the one it is named after.**
//
// Spec of record: design/plating/index.html `.toast` — a dark capsule, cream
// text, 11.5pt bold, 8×16 padding, fully rounded, centred over the hero. It is
// the ONLY text in the celebration beat, and it is deliberately small: the gold
// flare is the reward, this just names what happened.

struct ServeToast: View {

    let celebration: PlateCelebration

    var body: some View {
        Text(label)
            .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption2))
            .foregroundStyle(Color.bdCream)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.bdInk.opacity(0.90), in: Capsule())
            .accessibilityLabel(Text("Served. \(celebration.title)"))
    }

    /// "Served · that's one" while the plate still has room, and the category is
    /// never named here — the row that was just plated already said it.
    private var label: String {
        String(localized: "Served · that's one")
    }
}

#Preview("Serve toast") {
    ZStack {
        Color.bdBackground
        ServeToast(celebration: PlateCelebration(category: .learning, title: "Read a few pages"))
    }
    .frame(height: 160)
}
