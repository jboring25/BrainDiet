import SwiftUI

// MARK: - TriageView — ROUTE-BY-WHY (2026-07-23, BrainDiet's differentiator).
//
// When the user reaches for a distraction, we don't hand them a fixed response —
// we ask WHY, then hand them the MATCHED one. This runs entirely IN-APP with NO
// Family Controls entitlement (the OS shield can only draw icon/title/buttons,
// never this), so it ships everywhere the entry card does.
//
// Screen 1 asks the question (four options). Screens 1→3 branch on the answer:
//   • bored   → boredom is the good part: normalise the feeling, then the
//               engine's serving as the thing to start anyway. NOT entertainment
//               — the app never competes to be the more interesting feed.
//   • anxious → take the edge off first: a short regulate beat, then a small
//               serving. HONESTY LAW — behavioral description only, NEVER a
//               clinical claim ("reduces anxiety/stress" is banned).
//   • habit   → name the autopilot (the intervention), then the 10-minute version.
//   • need it → dismiss instantly, zero friction. This lane exists so legitimate
//               use is never punished.
//
// Every branch ends by either starting the SAME stitched live session as
// Home/Menu/intercept, or letting the user pass cleanly. Fast and warm, never
// an interrogation.

enum TriageChoice: String, CaseIterable, Sendable {
    case bored, anxious, habit, need
}

struct TriageView: View {

    /// DEBUG jump straight to a screen-2 branch (nil = start at the question).
    var initialChoice: TriageChoice? = nil
    /// "I actually need it" — dismiss instantly, zero friction.
    var onLetThrough: () -> Void = {}
    /// Route into the SAME live session as Home/Menu/intercept. `short` = the
    /// habit branch's ~10-minute version.
    var onServe: (_ short: Bool) -> Void = { _ in }
    /// Quiet escape ("Head back out" / "I'm good").
    var onDismiss: () -> Void = {}

    @Environment(PlateEngine.self) private var plate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// nil = the question; a value = its matched screen-2 branch.
    @State private var choice: TriageChoice?
    /// The anxious branch's two beats: breathing → "feel any different?".
    @State private var anxiousResolved = false

    var body: some View {
        ZStack {
            Color.bdBackground.ignoresSafeArea()

            Group {
                switch choice {
                case nil:        questionScreen
                case .bored:     boredScreen
                case .anxious:   anxiousScreen
                case .habit:     habitScreen
                case .need:      Color.clear   // instant exit (handled on appear)
                }
            }
            .padding(.horizontal, 26)
            .transition(.opacity)
        }
        .onAppear {
            // `need` has no screen 2 — it's the instant exit, never a landing.
            if let initialChoice, initialChoice != .need { choice = initialChoice }
        }
    }

    // MARK: Screen 1 — the question (appetite canvas, warm, ≤1 screen, no scroll).

    private var questionScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // ⭐ THE LIVING OBJECT (2026-08-04). This screen previously had NONE —
            // in violation of our own one-living-object law — so three chevroned
            // cards carried the most emotionally loaded question in the app and it
            // read as a settings menu. Reference: Apple Journal's "Choose how
            // you're feeling right now" (Mobbin), which centres ONE responsive
            // object and lets a single control take the input; it reads as an
            // instrument rather than a form.
            // The plate is EMPTY here on purpose — it IS the argument. The user is
            // standing at the moment of the reach with nothing on their plate, and
            // the question below is what fills it. No steam (nothing is cooking
            // yet), no gold (gold is for earned moments only).
            BDPlateMark(nourishment: 0, steaming: false)
                .frame(width: 132)
                .accessibilityHidden(true)
                .padding(.bottom, 22)

            Text("What's this really about?")
                .font(BDFont.serif(size: 30, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Name it and the next move gets easy.")
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.horizontal, 6)

            VStack(spacing: 11) {
                optionRow(title: "I'm bored", sub: "nothing feels interesting") { select(.bored) }
                optionRow(title: "I'm anxious", sub: "need to get out of my head") { select(.anxious) }
                optionRow(title: "Just habit", sub: "my hands did it on their own") { select(.habit) }
            }
            .padding(.top, 30)

            // The escape — deliberately QUIETER (a plain text button, not a
            // card): legitimate use is the low-friction lane, never punished.
            Button { select(.need) } label: {
                VStack(spacing: 2) {
                    Text("I actually need it")
                        .font(BDFont.body(.semiBold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextSecondary)
                    Text("let me through")
                        .font(BDFont.body(.regular, size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.Size.minTouch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityHint(Text("Closes this and lets you continue."))

            Spacer(minLength: 0)
        }
    }

    /// A neutral tappable row. ⭐ THE CHEVRON WAS REMOVED (2026-08-04): a
    /// right-chevron is the grammar of NAVIGATION ("this pushes a screen"), and
    /// with three of them stacked the screen read as a settings list. These are
    /// not destinations — they are an answer to a question about yourself. The
    /// white card + hairline stays so the row still LOOKS tappable (interactive
    /// things must look interactive), but the row is now quieter and tighter so
    /// the plate above stays the hero. Category-NEUTRAL by design.
    private func optionRow(title: LocalizedStringKey, sub: LocalizedStringKey,
                           _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BDFont.body(.bold, size: 16.5, relativeTo: .body))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text(sub)
                        .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                }
                Spacer(minLength: Theme.Space.sm)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func select(_ c: TriageChoice) {
        if c == .need { onLetThrough(); return }
        withAnimation(.easeInOut(duration: 0.28)) { choice = c }
    }

    // MARK: Screen 2 · bored — "Boredom is the good part."
    //
    // ⭐ REWRITTEN 2026-08-11. This branch used to say "Then let's make it
    // interesting," which promised ENTERTAINMENT — the app volunteering to be
    // the next hit. That is the app arguing the scroll's own case in a nicer
    // voice, and it is backwards for a product whose whole premise is that a
    // brain fed every ten seconds gets nothing built. The boredom is not the
    // problem to be solved here; needing it solved instantly is.
    //
    // The copy does two jobs and no more: normalise the feeling (it is what an
    // unfed brain feels like, not a fault), and remove the precondition people
    // wait on ("nothing has to feel interesting before you start"). HONESTY LAW
    // still applies — this is a behavioural description, never a claim that
    // boredom makes you creative or that we have reset anyone's dopamine.
    //
    // The exit changed too, and that carries as much of the argument as the
    // headline: "Head back out" reads as giving up, so sitting with the feeling
    // had no name. "I'll sit with it" makes doing nothing an endorsed choice
    // rather than a failure to convert.
    private var boredScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            branchHeadline("Boredom is the", emphasis: "good part.")
            Text("That's what your brain feels like when it isn't being fed every ten seconds. Nothing has to feel interesting before you start.")
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 6)
            if let s = serving {
                servingCard(s).padding(.top, 22)
            }
            Spacer(minLength: 0)
            BDPrimaryButton(title: LocalizedStringResource(stringLiteral: serveTitle)) {
                onServe(false)
            }
            ghostButton("I'll sit with it") { onDismiss() }
        }
        .padding(.bottom, 10)
    }

    // MARK: Screen 2 · anxious — regulate first, then a small serving.

    private var anxiousScreen: some View {
        Group {
            if anxiousResolved {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    branchHeadline("Feel any", emphasis: "different?")
                    Text("Even a small serving beats the scroll right now.")
                        .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 8)
                    Spacer(minLength: 0)
                    BDPrimaryButton(title: "Serve something small") { onServe(false) }
                    ghostButton("I'm good, head back") { onDismiss() }
                }
                .padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    breathingCircle
                        .padding(.bottom, 30)
                    branchHeadline("Let's take the", emphasis: "edge off first.")
                    // HONESTY LAW: behavioral description only. No "reduces
                    // anxiety/stress," no clinical claim of any kind.
                    Text("This feeling peaks and passes. Ride it for a few breaths.")
                        .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .padding(.horizontal, 6)
                    Spacer(minLength: 0)
                    ghostButton("Skip") { resolveAnxious() }
                }
                .padding(.bottom, 10)
                // Auto-advance after a calm beat; Skip is always available.
                .task {
                    try? await Task.sleep(for: .seconds(35))
                    resolveAnxious()
                }
            }
        }
    }

    private func resolveAnxious() {
        guard !anxiousResolved else { return }
        withAnimation(.easeInOut(duration: 0.3)) { anxiousResolved = true }
    }

    /// A slow-pulsing circle, ~4s in / 4s out. Reduce Motion = a static circle
    /// (no TimelineView), honoring the accessibility contract.
    @ViewBuilder private var breathingCircle: some View {
        if reduceMotion {
            pulseCircle(scale: 0.9)
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // period = 2π / (π/4) = 8s → 4s inhale, 4s exhale.
                let phase = (sin(t * .pi / 4) + 1) / 2
                pulseCircle(scale: 0.72 + 0.28 * phase)
            }
        }
    }

    private func pulseCircle(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.bdLeafTint, Color.bdLeafTint.opacity(0)],
                    center: .center, startRadius: 0, endRadius: 110))
            Circle()
                .strokeBorder(Color.bdLeaf.opacity(0.45), lineWidth: 2)
                .scaleEffect(scale)
        }
        .frame(width: 190, height: 190)
        .accessibilityHidden(true)
    }

    // MARK: Screen 2 · habit — "Nice catch. That was autopilot."

    private var habitScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            branchHeadline("Nice catch.", emphasis: "That was autopilot.")
            // Naming the autopilot IS the intervention (habit reversal). Self-
            // compassion + agency, never shame.
            Text("Your hands did it on their own. No shame in that. Noticing is how you take the wheel back.")
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .padding(.horizontal, 6)
            Spacer(minLength: 0)
            BDPrimaryButton(title: "Give me the 10-minute version") { onServe(true) }
            ghostButton("Head back out") { onDismiss() }
        }
        .padding(.bottom, 10)
    }

    // MARK: Shared pieces

    /// The engine's ONE highest-value serving (PLATE-ENGINE.md: no surface
    /// computes its own). Falls back to a catalog default before any plan syncs.
    private var serving: PlateServing? {
        plate.suggestion ?? PlateEngine.buildCatalog(goals: []).first
    }

    /// The serving-aware verb (PlateCategory.ctaTitle — the shared source with
    /// Home's card + the intercept): "Serve dessert" or "Feed my brain."
    private var serveTitle: String {
        serving?.category.ctaTitle ?? String(localized: "Feed my brain")
    }

    /// A serif branch headline with the closing words in salmon (app pattern).
    private func branchHeadline(_ prefix: String, emphasis: String) -> some View {
        (Text(prefix + " ").foregroundColor(Color.bdTextPrimary)
         + Text(emphasis).foregroundColor(Color.bdSalmon))
            .font(BDFont.serif(size: 29, relativeTo: .title))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The engine's serving as a card (reuses the intercept/Home visual: tint
    /// chip, concrete action, food-word subtitle in the category ink).
    private func servingCard(_ s: PlateServing) -> some View {
        HStack(spacing: 12) {
            PlateCategoryChip(category: s.category, size: 42, iconSize: 20, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title)
                    .font(BDFont.display(.extraBold, size: 16, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                Text("\(s.minutes) minutes")   // food word cut 2026-08-18 — see PlanCard
                    .font(BDFont.body(.bold, size: 12.5, relativeTo: .footnote))
                    .foregroundStyle(s.category.textInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private func ghostButton(_ title: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.buttonHeight)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Question") {
    let engine = PlateEngine()
    engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    return TriageView().environment(engine)
}

#Preview("Bored") {
    let engine = PlateEngine()
    engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    return TriageView(initialChoice: .bored).environment(engine)
}

#Preview("Anxious") {
    let engine = PlateEngine()
    engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    return TriageView(initialChoice: .anxious).environment(engine)
}

#Preview("Habit") {
    let engine = PlateEngine()
    engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    return TriageView(initialChoice: .habit).environment(engine)
}
