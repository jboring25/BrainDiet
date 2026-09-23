import SwiftUI

// MARK: - BDPlateMark — the shared hero.
//
// ⭐ THE PLATE IS RETIRED (2026-09-03). This type keeps its name and its whole
// public API so the ten call sites did not have to change, but it now renders
// CULTURE: the living particle brain. `nourishment` drives DENSITY instead of
// how much food is on a bowl, which is the same 0…1 contract every caller was
// already passing.
//
// Behaviour of the retained parameters:
//   • nourishment — density. 0 still shows the rim sketch, never nothing.
//   • steaming    — now means ALIVE. It feeds the organism once on appear so
//                   the surface has a moment instead of sitting static.
//   • slop        — the gray anti-state. Unwired before, still unwired.
//   • dish/dishAmount — no-ops. Retained so call sites compile untouched.
//   • heroOnly    — no-op. There is no 4-stop ramp any more.
//
// The old plate renders (PlateEmpty/Morning/Midday/Nourished), the meal library
// crossfade and the steam layer are no longer referenced from here.

struct BDPlateMark: View {
    /// 0…1 — how much of the organism has been earned.
    var nourishment: Double
    /// Alive: fires one feed on appear so the hero has a beat.
    var steaming: Bool = false
    /// The gray anti-state. Renderable but deliberately UNWIRED, as before.
    var slop: Bool = false
    /// No-ops, retained so the existing call sites compile unchanged.
    var dish: String? = nil
    var dishAmount: Double = 0
    var heroOnly: Bool = false

    @State private var model = CultureCloudModel()

    private var n: Double { max(0, min(1, nourishment)) }

    var body: some View {
        CultureCloudView(model: model)
            .onAppear {
                // Floor at 0.06 so an "empty" hero is still a legible brain
                // waiting to be fed, never a blank rectangle.
                model.seed(fraction: max(0.06, n))
                if steaming { model.feed() }
            }
            .onChange(of: nourishment) { _, _ in
                model.seed(fraction: max(0.06, n))
            }
            .accessibilityHidden(true)
    }
}
