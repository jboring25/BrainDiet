import SwiftUI

// MARK: - Home hero — the PLATE, the daily mind-health visualization (v7, variant A).
//
// The near-real plate render REPLACES the signature ring + brain hero. The plate
// itself IS the Mind-Health visualization now — a great day reads vivid + steaming
// with gold sparks; a quiet day reads muted + still. No numeric 0–100 score: the
// food on the plate is the read.
//
// Three live layers:
//   1. the plate image, drag-parallax (rotation3DEffect on a DragGesture) — the
//      luxury "pick it up and look" moment; springs back to rest on release.
//      PARKED (2026-07-11): deferred by user — the DragGesture loses to the
//      ScrollView pan on device. Gated by `plateParallaxEnabled`; all wiring
//      stays live-compiled for an easy flip back once the feature settles.
//   2. a live steam/spark layer (gold dots that rise + fade) over the food — the
//      "nourished glows" signal, gated on Reduce Motion.
//   3. real-state ramp: `nourishment` (0…1) crossfades a 4-stop stack of
//      geometry-locked, FULL-COLOR renders [PlateEmpty → PlateMorning →
//      PlateMidday → PlateNourished] (bands [0,.33,.66,1]) — a partial day
//      shows a REAL partial plate, never a ghost of the full meal. Only two
//      adjacent renders blend at once; ~0.8s ease on change. LAW (Jack-rejected
//      2026-07-13): never fake emptiness by filtering a full render —
//      desaturation/opacity ramps read as a washed-out GRAY plate on device.
//
// PlateSlop (the gray empty-calorie anti-state) is renderable on BDPlateMark
// but deliberately UNWIRED here — where it surfaces is an open product call.
//
// Open choreography: HomeView advances `phase`. On `.ring`/`.number` the plate
// settles (fade + scale 0.94→1.0, first steam wisp begins); the caption cascades
// in on `.meaning`. Reduce Motion → instant settled state.

/// The stages of the open choreography, advanced on a timeline by HomeView.
enum HomeRevealPhase: Int, Comparable {
    case initial     // nothing shown (pre-roll)
    case ring        // plate begins to settle
    case number      // (kept for timeline compatibility) plate fully warmed
    case meaning     // caption cascades in beneath
    case settled     // everything present; haptic has fired

    static func < (l: HomeRevealPhase, r: HomeRevealPhase) -> Bool { l.rawValue < r.rawValue }
    var atLeastNumber: Bool { self >= .number }
    var atLeastMeaning: Bool { self >= .meaning }
}

/// Which beat a completion earns over the plate. Three components are the
/// minimum meal, so the reward is ranked against that — not against the count.
enum PlateWin: Equatable, Sendable {
    /// Servings 1 and 2. The plate is still being built.
    case building
    /// The serving that completes the meal. The day's one earned moment.
    case mealComplete
    /// Anything after the meal is whole. Rewarded, never escalated.
    case beyond
}

struct HomeHeroView: View {
    // ONE component for all three hero modes (live / protected / zero) — mode
    // differences are CONTENT ONLY, injected by HomeView, so the paths can
    // never drift apart again.
    /// The 24pt two-tone headline phrase (LAST word renders sage).
    let headline: String
    /// The compact 14pt line beneath (prebuilt — any gold time number included).
    let secondary: Text
    /// 0…1 vividness + steam drive (mind health, protected progress, or calm).
    let nourishment: Double
    /// The current stage of the open choreography.
    let phase: HomeRevealPhase
    /// ⭐ THE TIERED WIN (Jack, 2026-08-15). The signature used to fire
    /// IDENTICALLY on every completion — the first serving of the day and the
    /// seventh got the same treatment. That spent the biggest beat on the
    /// smallest moment and, repeated, turned the plate into a slot machine
    /// (which the boredom section forbids: the app never competes to be the more
    /// interesting feed).
    ///
    /// Three components are the MINIMUM MEAL, so the beats are ranked to match:
    ///   • `.building`     — servings 1 and 2. The food arriving IS the feedback.
    ///                       Sound + the caller's bounce, nothing over the plate.
    ///   • `.mealComplete` — the third. The steam BURSTS and the gold flare
    ///                       fires. The day's one earned moment.
    ///   • `.beyond`       — everything after. Sound and the toast only; nothing
    ///                       over the plate. Never escalating.
    ///
    /// Effects mark moments and DECAY; they never accumulate into standing
    /// state. `nil` = the plate is at rest.
    var win: PlateWin? = nil
    /// Long-run growth, 0…1. One reported serving ≈ one point of density; the
    /// brain fills over roughly seventy of them. Distinct from `nourishment`,
    /// which is only TODAY and resets at midnight.
    var growth: Double = 0

    // PARKED (2026-07-11): drag-parallax deferred by user — the DragGesture
    // loses to the ScrollView pan on device. Flip to true to restore; the tilt
    // math, rotation3DEffects, and dragGesture below all stay compiled.

    /// Drag-parallax state.
    /// Plate settle (fade + scale in on the open).
    @State private var settled = false
    /// The gold flare's pulse (scale + fade), driven by `.mealComplete`.
    @State private var flarePulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Measured plate width (mockup: ~96% of screen — it overhangs the 18pt
    /// screen padding). Drives the tilt divisor + steam sizing.
    /// How far the plate overhangs Home's horizontal padding on each side.
    /// The render carries baked-in margins (plate ≈ 70% of the asset width), so
    /// the IMAGE must slightly exceed the screen for the porcelain to read at
    /// the mockup's ~74%-of-screen size. The overflow is pure white — invisible.

    /// Clamped nourishment — drives STEAM presence + the 4-stop real-state
    /// ramp. It never filters the render (full color or not at all).
    private var drive: Double { max(0, min(1, nourishment)) }

    // 4-stop real-state ramp. Stops = the completeness value at which each
    // render is fully present: PlateEmpty(0) -> PlateMorning(0.33) ->
    // PlateMidday(0.66) -> PlateNourished(1.0). Each food layer stacks over the
    // one below and fades in ONLY across its own band; once it reaches opacity
    // 1 it fully occludes the layer beneath, so exactly two ADJACENT renders
    // ever blend at once (empty->morning [0,0.33], morning->midday [0.33,0.66],
    // midday->nourished [0.66,1.0]) -- a partial day shows a REAL partial plate,
    // never a ghost of the full meal, never a filter faking a low state.
    private static let ramp: [Double] = [0.0, 0.33, 0.66, 1.0]

    /// Opacity of food layer `stage` (0 = morning, 1 = midday, 2 = nourished).
    private static func rampOpacity(_ n: Double, stage: Int) -> Double {
        let lo = ramp[stage], hi = ramp[stage + 1]
        return max(0, min(1, (n - lo) / (hi - lo)))
    }

    var body: some View {
        // Mockup rhythm: headline sits directly under the plate (~2–4pt), the
        // reclaimed line ~3pt below that — a COMPACT hero, no display whitespace.
        VStack(spacing: 3) {
            culture
            caption
        }
        .onChange(of: phase) { _, new in applySettle(new) }
        .onChange(of: win) { _, now in
            guard let now else {
                flarePulse = false
                return
            }
            flarePulse = false
            // The sting fires on EVERY serve, Reduce Motion or not — the reward
            // is the sound; motion is the garnish.
            ServeSound.shared.play(.serve)

            guard !reduceMotion else { return }

            // Servings 1 and 2: the food landing on the porcelain is the whole
            // feedback. Nothing fires over the plate — the meal is still being
            // built, and there is nothing yet to celebrate.
            guard now == .mealComplete else { return }

            // ⛔️ THE TOSS AND THE GLINT ARE DELETED (Jack, 2026-08-16).
            //
            // A hand-built 360° rotation + scale bounce on the plate, and a
            // hand-built gold glint sweeping across it. Both violated the
            // ANIMATION GUARDRAIL that has been in this file's repo CLAUDE.md
            // since 2026-08-06: fluid and hero motion is GENERATED (Higgsfield),
            // never simulated in SwiftUI. Two earlier passes were rejected for
            // exactly this and the rule was written to stop a third.
            //
            // They had been dead code — declared and animated but never attached
            // to a view — which is to say the rule was working. Wiring them up
            // was the mistake. Jack's verdict on seeing them move: "the worst
            // looking animation I've ever seen."
            //
            // The meal-complete beat is now the pre-existing steam burst and
            // gold flare only. When this moment gets real motion it arrives as a
            // GENERATED clip built from the plate render, described by Jack.
            // Do not rebuild a rotation, a flip, a bounce or a sweep here.
            withAnimation(.easeOut(duration: 0.9)) { flarePulse = true }
        }
        .onAppear { applySettle(phase) }
    }

    // MARK: The hero — Culture.
    //
    // Replaces the plate render (2026-09-03). The organism's DENSITY is the
    // progress: points are earned one per reported serving, seeded on appear
    // from the user's lifetime total, and each new serving feeds it live —
    // membrane in, swarm converges, absorb, wave. `plate` below is retained
    // and still compiles; nothing references it.

    @State private var cultureModel = CultureCloudModel()

    private var culture: some View {
        CultureCloudView(model: cultureModel)
            .frame(height: 300)
            .onAppear { cultureModel.seed(fraction: max(0.04, growth)) }
            .onChange(of: win) { _, now in
                guard now != nil else { return }
                cultureModel.feed()
            }
    }

    // MARK: Caption — two-tone headline + the compact secondary line (mockup).

    private var caption: some View {
        VStack(spacing: 5) {
            twoToneHeadline
                .font(BDFont.serif(size: 25, relativeTo: .title2))
                .lineLimit(1)
                // The completion beat's final step — the headline crossfades to
                // the engine's new answer ("Your brain is hungry." → "Nicely fed.").
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: headline)
                .stageIn(phase.atLeastMeaning, delay: 0)

            secondary
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .stageIn(phase.atLeastMeaning, delay: 0.12)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Your brain is hungry." / "Well nourished." — serif two-tone: LAST word
    /// (with its punctuation) renders SALMON, the appetite display accent
    /// (appetite mockup: `.h-h em{color:var(--salmon)}` includes the period).
    /// Single-word phrases render all salmon.
    private var twoToneHeadline: Text {
        let words = headline.split(separator: " ").map(String.init)
        guard let last = words.last else { return Text(headline) }
        let prefix = words.dropLast().joined(separator: " ")
        let line = Text(last).foregroundColor(Color.bdSalmon)
        guard !prefix.isEmpty else { return line }
        return Text(prefix + " ").foregroundColor(Color.bdTextPrimary) + line
    }

    // MARK: Settle — plate fades + scales in when the open reaches .ring.

    private func applySettle(_ phase: HomeRevealPhase) {
        if reduceMotion { settled = true; return }
        if phase >= .ring, !settled {
            withAnimation(Theme.Motion.plate) { settled = true }
        }
    }

}

// MARK: - Staged entrance modifier — a gentle rise + fade, phase-gated.

private extension View {
    func stageIn(_ active: Bool, delay: Double) -> some View {
        modifier(StageIn(active: active, delay: delay))
    }
}

private struct StageIn: ViewModifier {
    let active: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(active ? 1 : 0)
                .offset(y: active ? 0 : 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.86).delay(delay), value: active)
        }
    }
}

#Preview("Live") {
    ZStack {
        BDBackground(intensity: .standard)
        HomeHeroView(
            headline: "Well nourished",
            secondary: Text("1h 42m").foregroundColor(.bdGoldAccent)
                + Text(" reclaimed today · 2 chapters' worth").foregroundColor(.bdTextSecondary),
            nourishment: 0.86,
            phase: .settled
        )
        .padding(Theme.Space.screenX)
    }
}

#Preview("Empty (morning)") {
    ZStack {
        BDBackground(intensity: .standard)
        HomeHeroView(
            headline: "Your brain is hungry.",
            secondary: Text("Nothing served yet. Your first serving is ready.")
                .foregroundColor(.bdTextSecondary),
            nourishment: 0,
            phase: .settled
        )
        .padding(Theme.Space.screenX)
    }
}

#Preview("Protected") {
    ZStack {
        BDBackground(intensity: .standard)
        HomeHeroView(
            headline: "Reading every night",
            secondary: Text("42m").foregroundColor(.bdGoldAccent)
                + Text(" protected today · goal 2h").foregroundColor(.bdTextSecondary),
            nourishment: 0.45,
            phase: .settled
        )
        .padding(Theme.Space.screenX)
    }
}
