import SwiftUI

// MARK: - Commit — drag who you're becoming into your brain.
//
// ⭐ REBUILT 2026-10-10 on HOME'S DRAG (Jack: "fix the drag to commit using the
// new drag animation method … way too buggy"). One mechanic app-wide, the one
// approved in builds 42–43 (`TodaysFocusCard` + `PlateDropController`):
//   • TOUCH  → the whole card lifts at once (1.025, deeper shadow, light tick);
//              a 0.16s hold arms the drag so a stray swipe never grabs it.
//   • DRAG   → the card follows the finger 1:1 (no easing on position) and, as
//              it nears the brain, shrinks/fades/blurs INTO the green serving
//              ball (`ServingBall`), collapsing toward the grab point so the ball
//              sits under the finger. Morph = `PlateDropController.morph`.
//   • DROP INSIDE the brain outline → `CultureCloudModel.feed(at:)` at that
//              exact spot (the existing absorb + wave), then commit + advance.
//   • DROP OUTSIDE / CANCEL → springs home and re-forms the card.
// What the old drag did wrong: an implicit animation on `dragging` eased the
// offset at pickup (the jump), the target was the brain's bounding box (not
// the outline), the brain never fed, and a dashed gold halo — banned on Home
// since 2026-08-20 — woke around it.
//
// Payload order still matters: here you feed WHO YOU'RE BECOMING; the first
// serving later feeds WHAT YOU'LL DO (Oyserman, Bybee & Terry 2006).
//
// ACCESSIBILITY: never drag-only. "Or tap to commit" (and the a11y actions)
// commit and feed from the default entry; Reduce Motion disables the drag and
// promotes the button.
//
// DEBUG: BD_COMMIT_STATE=committed holds the end state; BD_COMMIT_STATE=drag
// autoplays a drop through the same controller (for motion capture).

struct CommitStepView: View {
    @Bindable var vm: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    nonisolated static let space = "commit"

    @State var drop = PlateDropController()
    @State var culture = CultureCloudModel()
    @GestureState var pressing = false
    @State var committed = false
    @State var cardGone = false
    @State var cardRect: CGRect = .zero
    /// Where the finger grabbed the card, as a unit point — the morph collapses there.
    @State var grabAnchor: UnitPoint = .center
    /// DEBUG autoplay stands in for the finger's lift (GestureState can't be set).
    @State var debugLift = false

    /// Ad capture stretches the beat for the camera. Long enough for the
    /// absorb (1.0s) and most of the wave to play before the step leaves.
    var settleDelay: Int { AdMode.isEnabled ? 2800 : 2300 }

    var domain: ActivityDomain {
        vm.primaryDomain ?? vm.selectedDomains.first ?? .reading
    }

    /// The user's own line; falls back to the domain's identity line (same as
    /// the planner) so the card can never render blank.
    var identityLine: String {
        let picked = vm.aspiration.trimmingCharacters(in: .whitespacesAndNewlines)
        return picked.isEmpty ? domain.identityLine : picked
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Space.sm)

            Text("Feed your brain,\nand it comes back.")
                .font(BDFont.serif(size: 32, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Theme.Space.xl)

            brain

            caption
                // Reserved height so the brain never moves between hint and payoff.
                .frame(height: 78, alignment: .top)
                .padding(.top, Theme.Space.lg)

            Spacer(minLength: Theme.Space.md)

            // Stays in the layout after committing (faded, inert) so nothing reflows.
            CommitIdentityCard(domain: domain, line: identityLine, lifted: (pressing || debugLift) && !committed)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { cardRect = $0 }
                .modifier(CommitMorph(drop: drop, anchor: grabAnchor, gone: cardGone))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(dragGesture, isEnabled: !reduceMotion && !committed)
                .zIndex(2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(identityLine)
                .accessibilityHint("Drag into your brain to commit")
                .accessibilityAction { commit(at: nil) }
                .padding(.bottom, Theme.Space.sm)

            tapPath
                .opacity(committed ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: committed)
                .padding(.bottom, Theme.Space.sm)
        }
        .frame(maxWidth: .infinity)
        // The ball rides above everything, positioned in the same space as the drag.
        .overlay(alignment: .topLeading) { ball }
        .coordinateSpace(name: Self.space)
        .onChange(of: pressing) { _, now in if !now { recoverIfStranded() } }
        #if DEBUG
        .onAppear(perform: seedForScreenshots)
        #endif
    }

    // MARK: The brain — the same organism as Home, fed at the drop point.

    private var brain: some View {
        CultureCloudView(model: culture)
            .frame(width: 300, height: 200)
            // Taps on the brain must not feed it outside the commit path.
            .allowsHitTesting(false)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { drop.cultureRect = $0 }
            .onAppear { culture.seed(fraction: 0.06) }
            .accessibilityElement()
            .accessibilityLabel("Your brain")
            .accessibilityHint("Drag who you're becoming here, or use the button below")
            .accessibilityAction { commit(at: nil) }
    }

    /// The green serving ball the card turns into. Always mounted; opacity is
    /// driven by morph so a spring-back fades it out instead of popping it.
    /// ⭐ Finger-sized in the hand (Jack, 2026-10-10: "way too small"), shrinking
    /// to the brain's own serving over the last stretch (`DragBallSize`); a drop
    /// before that finishes hands off through `LandedServingBall`.
    @ViewBuilder
    private var ball: some View {
        let m = CommitMorph.eased(drop.morph)
        ZStack(alignment: .topLeading) {
            DraggedServingBall(handoff: drop.ballHandoff, cultureRect: drop.cultureRect)
                .scaleEffect(0.5 + 0.5 * m)
                .opacity(cardGone ? 0 : Double(max(0, min(1, (m - 0.3) / 0.45))))
                // The landed ball takes over in the same frame; no crossfade.
                .animation(nil, value: cardGone)
                .position(drop.point)
            if let landing = drop.landing {
                LandedServingBall(landing: landing, cultureRect: drop.cultureRect) {
                    if drop.landing == landing { drop.landing = nil }
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var caption: some View {
        if committed {
            VStack(spacing: Theme.Space.xs) {
                Text("Committed.")
                    .font(BDFont.serif(size: 24, relativeTo: .title2))
                    .foregroundStyle(Color.bdLeafDeep)
                Text("That's the person. Now we get you there.")
                    .font(BDFont.body(.medium, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.lg)
            }
            .transition(.opacity)
        } else {
            Text(reduceMotion ? "Commit to who you're becoming." : "Drag it into your brain ↑")
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// The always-available plain path (primary under Reduce Motion).
    @ViewBuilder
    private var tapPath: some View {
        if reduceMotion {
            BDPrimaryButton(title: "Commit", isEnabled: !committed) { commit(at: nil) }
        } else {
            Button { commit(at: nil) } label: {
                Text("Or tap to commit")
                    .font(BDFont.body(.regular, size: 12, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary.opacity(0.8))
                    .frame(minHeight: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
            .disabled(committed)
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.fitness, .reading]
    vm.primaryDomain = .fitness
    vm.aspiration = "Training, not trying."
    return ZStack {
        BDBackground()
        CommitStepView(vm: vm)
            .padding(.horizontal, Theme.Space.screenX)
    }
}
