#if DEBUG
import SwiftUI
import SwiftData

// MARK: - AdShotView — DEBUG-only standalone capture surfaces (BD_AD_SHOT).
//
// Rendered INSTEAD of MainView when BD_AD_MODE=1 and the requested shot isn't
// the full Home open. Each shot is a clean, chrome-free cinematic frame:
//
//   brain-loop — the pink brain alone, centered, radiant, breathing (loopable)
//   commit     — the hold-to-commit glow ramp + gold pulse, auto-playing
//   plan       — the "Your Brain Diet" card, biking servings, slow gold flare
//   green      — full-screen chroma green (#00FF00), zero chrome (tracking clip)
//   endtag     — the quiet closing lockup (brain + wordmark + tagline glint)

struct AdShotView: View {
    let shot: AdMode.Shot

    var body: some View {
        Group {
            if shot == .green {
                // Pure chroma green, nothing else — played on the phone during
                // the toss so the editor can key the glowing UI on in post.
                Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1)
                    .ignoresSafeArea()
            } else {
                ZStack {
                    // The end tag stays quiet; the hero canvas serves the rest.
                    BDBackground(intensity: shot == .endtag ? .standard : .hero)

                    switch shot {
                    case .brainLoop:
                        // The vivid, steaming plate IS the loop (brain retired).
                        BDPlateMark(nourishment: 0.98, steaming: true)
                            .frame(width: 320)

                    case .commit:
                        AdCommitShot()

                    case .plan:
                        AdPlanShot()

                    case .tray:
                        AdTrayShot()

                    case .intercept:
                        AdInterceptShot()

                    case .endtag:
                        AdEndTagShot()

                    case .open, .unspin, .green:
                        EmptyView() // handled by MainView / above, never reaches here
                    }
                }
            }
        }
        // The intercept is the shipping cream surface — light chrome. The
        // remaining shots keep their original capture scheme.
        .preferredColorScheme(shot == .intercept ? .light : .dark)
        // No chrome on the tracking clip or the brand lockup.
        .statusBarHidden(shot == .green || shot == .endtag)
        .persistentSystemOverlays(shot == .green || shot == .endtag ? .hidden : .automatic)
    }
}

// MARK: - AdWarmGrade — the golden-hour grade layer (BD_AD_GRADE=warm).
//
// Subtle and cinematic, never instagram-filter: a soft amber temperature shift
// through the midtones, blacks lifted off pure #000, and a gentle (+8%)
// additive bloom on the bright center of frame. Screen-fixed (applied OUTSIDE
// any entrance transform), hit-testing transparent.

struct AdWarmGrade: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .compositingGroup()
                .saturation(1.05)
                .brightness(0.012)
                .overlay(
                    // Amber temperature shift (midtones).
                    Color(red: 1.0, green: 0.72, blue: 0.38).opacity(0.10)
                        .blendMode(.softLight)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Lifted blacks — nothing reads pure black.
                    Color(red: 0.10, green: 0.075, blue: 0.045)
                        .blendMode(.lighten)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
                .overlay(
                    // Gentle warm bloom on the bright center of frame.
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.86, blue: 0.62).opacity(0.08), .clear],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0, endRadius: 640
                    )
                    .blendMode(.plusLighter)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                )
        } else {
            content
        }
    }
}

extension View {
    /// Golden-hour grade for ad capture (no-op when `active` is false).
    func adWarmGrade(_ active: Bool) -> some View {
        modifier(AdWarmGrade(active: active))
    }
}

// MARK: - AdUnspinEntrance — the pass-through-the-screen landing (BD_AD_SHOT=unspin).
//
// The whole Home surface starts scaled 260% and rotated 70° (as if the camera
// just passed through the spinning phone), holds a beat for the cut, then one
// smooth spring arc decelerates it into place — and the open choreography
// (Home's pre-roll waits for the landing) plays as normal.

struct AdUnspinEntrance: ViewModifier {
    let active: Bool
    @State private var landed = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active && !landed ? 70 : 0))
            .scaleEffect(active && !landed ? 2.6 : 1.0)
            .task {
                guard active, !landed else { return }
                // A beat of stillness at full spin so the editor has frames
                // to cut into after the flash frame.
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.spring(response: 0.95, dampingFraction: 0.84)) {
                    landed = true
                }
            }
    }
}

// MARK: - Commit — the real CommitStepView, driven on a timer (no touch needed).
// The autoplay itself lives in CommitStepView (BD_AD_SHOT=commit): ~1.4s of
// still ember, then the cinematic ramp + the single gold pulse.

private struct AdCommitShot: View {
    @State private var vm = OnboardingViewModel()

    var body: some View {
        CommitStepView(vm: vm)
            .padding(.horizontal, Theme.Space.screenX)
    }
}

// MARK: - Plan — "Your Brain Diet" with biking servings + one slow gold flare.

private struct AdPlanShot: View {
    @State private var reveal = false

    private var plan: BrainPlan {
        BrainPlan.generate(goalID: "fitness", goalNoun: "the rides you love",
                           why: "", baselineJunkMinutes: 180)
    }

    private var servings: [PlanServing] {
        [
            PlanServing(symbol: "bicycle",       title: "Ride more",   count: 1,
                        minutes: 45, domain: .fitness),
            PlanServing(symbol: "book.fill",     title: "Read more",   count: 1,
                        minutes: 25, domain: .reading),
            PlanServing(symbol: "figure.hiking", title: "Get outside", count: 1,
                        minutes: 25, domain: .outdoors)
        ]
    }

    var body: some View {
        PlanCard(plan: plan, servings: servings, animate: reveal)
            .overlay { AdGoldFlare(trigger: reveal) }
            .padding(.horizontal, Theme.Space.screenX)
            .task {
                // A beat of stillness for the camera, then the card plates in.
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation { reveal = true }
            }
    }
}

// MARK: - AdGoldFlare — the plan-reveal gold glint, slowed for the camera.
// (A cinematic-pace sibling of PlanRevealStepView's private GoldFlareSweep.)

private struct AdGoldFlare: View {
    let trigger: Bool

    @State private var sweep: CGFloat = -0.7
    @State private var visible = false

    var body: some View {
        GeometryReader { geo in
            if visible {
                LinearGradient(
                    colors: [.clear,
                             Color.bdGoldDeep.opacity(0.18),
                             Color.bdGold.opacity(0.30),
                             Color.bdGoldDeep.opacity(0.18),
                             .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.38, height: geo.size.height * 1.5)
                .rotationEffect(.degrees(14))
                .offset(x: sweep * geo.size.width, y: -geo.size.height * 0.25)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.label, style: .continuous))
        .onChange(of: trigger) { _, on in
            guard on, !visible else { return }
            visible = true
            // Waits for the plating, then ONE slow cinematic wipe — and gone.
            withAnimation(.easeInOut(duration: 2.2).delay(1.4)) { sweep = 1.3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { visible = false }
        }
    }
}

// MARK: - Tray — the meal-tray 2-second moment, chrome-free (BD_AD_SHOT=tray).
//
// A beat of stillness for the camera, then the tray card plates in on its own
// staggered springs: nourishing glows on, leisure settles, the slop plops matte
// — and holds. Numbers land the spec labels exactly: NOURISHING · 3h 10m /
// LEISURE · 1h / SLOP · 40m.

private struct AdTrayShot: View {
    var body: some View {
        BDMealTray(
            diet: MentalDiet(
                minutes: [.nourishing: 190, .leisure: 60, .junk: 40],
                percents: [.nourishing: 65, .leisure: 21, .junk: 14],
                totalMinutes: 290
            ),
            junkBudget: JunkBudget(spentMinutes: 40, budgetMinutes: 90),
            servingsLine: String(localized: "2 of 3 servings today"),
            animate: true,
            pace: AdMode.pace,
            startDelay: 1.1,
            footer: String(localized: "Spend it well.")
        )
        .padding(.horizontal, Theme.Space.screenX)
    }
}

// MARK: - Intercept — THE ATTRACTION INTERCEPT as a full-screen auto-playing
// moment (BD_AD_SHOT=intercept).
//
// The shipping InterceptPreviewView IS the component (rebuilt here 2026-07-19;
// the old slop-era layout is gone) — so the ad surface can never drift from
// the product again. Everything on it is the ad seed's REAL engine state:
// today's plate at actual completeness with the honey glow on the empty
// region, the identity headline ("You wanted to become someone who trains."),
// the engine's ONE serving, the serving-aware primary CTA. A beat of cream
// stillness for the camera, then the whole intercept rises in on one spring —
// and holds. Attraction law: what he COULD have, never what he's avoiding.

private struct AdInterceptShot: View {

    @Environment(PlateEngine.self) private var plate
    @Environment(\.usageProvider) private var usageProvider
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ProtectSession]
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]

    @State private var revealed = false

    /// Same composition as MainView's interceptContent — the ad seed's real
    /// goal + the engine's real plate truth, never hand-written numbers.
    private var content: ShieldContent {
        ShieldContentBuilder.make(
            goalID: profiles.first?.headlineGoalID,
            servingsDone: plate.doneCount,
            servingsPlanned: plate.planCount,
            suggestedCategory: plate.suggestion?.category
        )
    }

    var body: some View {
        InterceptPreviewView(content: content)
            // The entrance: one spring rise from below, cinematic pace.
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 120)
            .task {
                // Sync the engine from the ad seed BEFORE the reveal so the
                // plate + serving rise in at their real state.
                let ctx = EngineContext(profile: profiles.first, usage: usageProvider,
                                        sessions: sessions)
                plate.sync(
                    goals: goals,
                    sessions: sessions,
                    junkMinutes: ctx.engine.todayMentalDiet?.minutes[.junk] ?? 0,
                    junkAppCount: profiles.first?.junkAppIDs.count ?? 0
                )
                // A beat of cream stillness for the camera, then the rise.
                try? await Task.sleep(for: .milliseconds(Int(1100 * AdMode.pace)))
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { revealed = true }
            }
    }
}

// MARK: - End tag — the quiet closing lockup.
//
// Brain mark (small, radiant) over "Brain Diet" in the display face, the brand
// promise beneath in secondary. Fades in over 0.8s, holds, one soft gold glint
// sweeps the tagline at ~3s (earned gold, once), then holds to the end.

private struct AdEndTagShot: View {
    @State private var visible = false
    /// The glint band's center, as a fraction of the tagline's width.
    @State private var glint: CGFloat = -0.6

    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            BDPlateMark(nourishment: 1.0, steaming: true)
                .frame(width: 150)
                .padding(.bottom, Theme.Space.xs)

            Text("BrainDiet")
                .font(BDFont.display(.bold, size: 40, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)

            tagline
        }
        .opacity(visible ? 1 : 0)
        .task {
            // A short black beat, the 0.8s fade, then the glint at ~3s.
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.8)) { visible = true }
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(.easeInOut(duration: 1.3)) { glint = 1.4 }
        }
    }

    /// The tagline with a soft gold specular glint masked to the glyphs.
    private var tagline: some View {
        let text = Text("Reclaim your mind.")
            .font(.bdHeadline)
        return ZStack {
            text.foregroundStyle(Color.bdTextSecondary)
            text.foregroundStyle(Color.bdGold)
                .mask(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: glint * geo.size.width)
                    }
                )
        }
    }
}

#Preview("Brain loop") { AdShotView(shot: .brainLoop) }
#Preview("Plan") { AdShotView(shot: .plan) }
#Preview("Tray") { AdShotView(shot: .tray) }
#Preview("Intercept") { AdShotView(shot: .intercept) }
#Preview("End tag") { AdShotView(shot: .endtag) }
#endif
