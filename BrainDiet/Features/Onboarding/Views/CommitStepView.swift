import SwiftUI

// MARK: - Step 11 — THE COMMITMENT BEAT: drag who you're becoming into your brain.
//
// 2026-10-09: all plate/meal imagery + copy removed (Jack). The target is the
// particle brain; no MealLibrary dish is chosen any more.
//
// ⭐ REBUILT 2026-08-06 (Jack: "change the hold to a plating moment").
//
// WHAT WAS HERE, AND WHY IT HAD TO GO. A press-and-hold that grew a code-drawn
// NEURAL NETWORK (`NeuralDendriteMark`). Two problems, and the device
// screenshot in design/b4-audit/11-commit.png shows both at once:
//   1 · AT REST IT IS EMPTY. The dendrite seed is a 30pt stem and one gold dot
//       inside a 216pt ring. The screen reads as a loading spinner that stopped.
//   2 · IT BROKE OUR OWN LAW. CLAUDE.md's one-living-object law says the PLATE
//       is the app's single living object. The dendrite tree was a second one
//       that appeared exactly once in the whole product and never again.
//
// WHAT IT IS NOW. The same drag-onto-the-plate choreography as the first
// serving (ported from `FirstServingStepView`), but the card you drag is YOUR
// IDENTITY ANSWER — the sentence picked on the aspiration step — not a task.
//
// ⭐ WHY THIS ISN'T JUST A REPEAT OF STEP 15. The payload differs, and the order
// is the whole point:
//     step 11 (here) → you plate WHO YOU'RE BECOMING     (the possible self)
//     step 15        → you plate WHAT YOU'LL DO TODAY    (the linked strategy)
// Oyserman, Bybee & Terry (2006, JPSP 91(2), 188–204) found a hoped-for self
// moved nothing on its own; it changed grades, attendance and behaviour — held
// at two-year follow-up — ONLY when it was linked to concrete strategies. These
// two beats are that finding rendered as interaction, in that order.
//
// ⭐ WHY THE FOOD APPEARS HERE and not only at step 15: commit sits BEFORE the
// paywall (step 13) and the first serving sits AFTER it. This is the only
// plate-fill every single user is guaranteed to reach. The cost is that the
// finale repeats the gesture, which is paid back in sound and in payload —
// `.serve` here (a rising triad), `.fullPlate` at step 15 (the same triad
// resolved an octave up), so the finale is audibly the bigger arrival.
//
// ACCESSIBILITY: never drag-only. "Or tap to commit" runs the identical
// sequence, and Reduce Motion skips the choreography entirely for a plain
// primary button (crossfade + haptic only). Matches the first-serving contract.
//
// DEBUG seam: BD_COMMIT_STATE=committed captures the plated state.

struct CommitStepView: View {
    @Bindable var vm: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Named space so the card's live center can be tested against the plate.
    private static let space = "commit"

    @State private var dragOffset: CGSize = .zero
    @State private var dragging = false
    @State private var overPlate = false
    @State private var committed = false
    @State private var cardDissolved = false
    @State private var goldPulse = false
    @State private var plateRect: CGRect = .zero
    @State private var cardRect: CGRect = .zero

    /// Ad capture stretches the beat for the camera.
    private var settleDelay: Int { AdMode.isEnabled ? 2200 : 1500 }

    /// Opal mapping row 10: social proof belongs AT the commitment moment —
    /// but ONLY as a real number (the App Store rating once live, or a real
    /// user count). nil until a real figure exists; NEVER invent one
    /// (honesty law). When nil, nothing renders.
    private let socialProofLine: String? = nil

    // MARK: The identity being served (never invented here)

    private var domain: ActivityDomain {
        vm.primaryDomain ?? vm.selectedDomains.first ?? .reading
    }

    /// The sentence the user picked on the aspiration step. The fallback is the
    /// domain's own identity line — the exact same fallback the planner uses,
    /// so the card can never render blank even from a jumped-to debug state.
    private var identityLine: String {
        let picked = vm.aspiration.trimmingCharacters(in: .whitespacesAndNewlines)
        return picked.isEmpty ? domain.identityLine : picked
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Space.sm)

            Text("Feed your brain,\nand it comes back.")
                .font(BDFont.serif(size: 32, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Theme.Space.xl)

            plateZone

            caption
                // Reserved height: the hint and the "Committed." payoff differ
                // in line count, and the plate must not move between them.
                .frame(height: 78, alignment: .top)
                .padding(.top, Theme.Space.lg)

            Spacer(minLength: Theme.Space.md)

            // The card stays in the LAYOUT after committing (faded, inert) —
            // removing it would reflow the stack and slide the plate right
            // through the payoff.
            identityCard
                .zIndex(2)
                .padding(.bottom, Theme.Space.sm)

            tapPath
                .opacity(committed ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: committed)
                .padding(.bottom, Theme.Space.sm)
        }
        .frame(maxWidth: .infinity)
        .coordinateSpace(name: Self.space)
        #if DEBUG
        .onAppear(perform: seedForScreenshots)
        #endif
    }

    // MARK: The plate — empty, receptive while dragging, plated on commit

    private var plateZone: some View {
        ZStack {
            // The receptive halo: the plate WAKES while the card is in the air.
            Ellipse()
                .stroke(Color.bdGold.opacity(overPlate ? 0.95 : 0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [7, 8]))
                .background(
                    Ellipse().fill(
                        RadialGradient(colors: [Color.bdGold.opacity(overPlate ? 0.18 : 0.07), .clear],
                                       center: .center, startRadius: 0, endRadius: 150)
                    )
                )
                .frame(width: 272, height: 172)
                .opacity(dragging && !committed ? 1 : 0)
                .animation(Theme.Motion.smooth, value: dragging)
                .animation(Theme.Motion.smooth, value: overPlate)

            // The single gold flare on the committed moment — earned, once.
            Ellipse()
                .stroke(Color.bdGold.opacity(goldPulse ? 0 : 0.55), lineWidth: 2)
                .background(
                    Ellipse().fill(
                        RadialGradient(colors: [Color.bdGold.opacity(goldPulse ? 0 : 0.22), .clear],
                                       center: .center, startRadius: 0, endRadius: 150)
                    )
                )
                .frame(width: 260, height: 160)
                .scaleEffect(goldPulse ? 1.45 : 0.85)
                .opacity(committed ? 1 : 0)

            // The particle brain (BDPlateMark renders CULTURE since 2026-09-03).
            BDPlateMark(nourishment: 0, steaming: committed)
                .frame(width: 300)
                .scaleEffect(overPlate && !committed ? 1.04 : 1.0)
                .animation(.easeOut(duration: 0.25), value: overPlate)
        }
        .frame(width: 300, height: 200)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { plateRect = $0 }
        .accessibilityElement()
        .accessibilityLabel("Your brain")
        .accessibilityHint("Drag who you're becoming here, or use the button below")
        .accessibilityAction { commit() }
    }

    // MARK: The caption — the hint, then the payoff

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

            if let socialProofLine {
                Text(socialProofLine)
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
            }
        } else {
            Text(reduceMotion ? "Commit to who you're becoming." : "Drag it into your brain ↑")
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: The draggable identity — the user's OWN answer

    private var identityCard: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(domain.categoryTint)
                .frame(width: 36, height: 36)
                // The DOMAIN's glyph, not a generic person mark. `BDPh` has no
                // `user` case and the icon law forbids inventing one inline —
                // adding a glyph means vendoring the Phosphor SVG (see
                // BDIcon.swift's header). The domain icon is also the truer
                // read: this is the identity that domain grows.
                .overlay(BDPhIcon(icon: domain.phIcon, size: 17, color: domain.categoryColor))

            VStack(alignment: .leading, spacing: 1) {
                Text(identityLine)
                    // (.bold = the Menu row's `extraBoldSafe` shim — same face.)
                    .font(BDFont.body(.bold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("who you're becoming")
                    .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
                    .foregroundStyle(domain.categoryTextInk)
            }

            Spacer(minLength: Theme.Space.sm)

            BDPhIcon(icon: .dotsSixVertical, size: 15, color: .bdTabMuted)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(minHeight: Theme.Size.minTouch + 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bdSurface)
                .shadow(color: Color.black.opacity(dragging ? 0.16 : 0.06),
                        radius: dragging ? 18 : 8, x: 0, y: dragging ? 12 : 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { rect in
            // Only the RESTING frame matters (the drag moves via offset, which
            // does not change layout), so this stays stable mid-gesture.
            cardRect = rect
        }
        .scaleEffect(cardDissolved ? 0.86 : (dragging ? 1.03 : 1.0))
        .rotationEffect(.degrees(dragging ? -1.2 : 0))
        .opacity(cardDissolved ? 0 : 1)
        .offset(dragOffset)
        .animation(.easeOut(duration: 0.22), value: dragging)
        .allowsHitTesting(!committed)
        .gesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(identityLine)
        .accessibilityHint("Drag into your brain to commit")
        .accessibilityAction { commit() }
    }

    /// The always-available plain path (primary under Reduce Motion).
    @ViewBuilder
    private var tapPath: some View {
        if reduceMotion {
            BDPrimaryButton(title: "Commit", isEnabled: !committed) { commit() }
        } else {
            Button { commit() } label: {
                Text("Or tap to commit")
                    .font(BDFont.body(.regular, size: 12, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary.opacity(0.8))
                    .frame(minHeight: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: The drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard !committed, !reduceMotion else { return }
                if !dragging {
                    dragging = true
                    let lift = UIImpactFeedbackGenerator(style: .soft)
                    lift.prepare()
                    lift.impactOccurred(intensity: 0.45)
                }
                dragOffset = value.translation
                let onTarget = isOverPlate(value.translation)
                if onTarget != overPlate {
                    overPlate = onTarget
                    if onTarget { UISelectionFeedbackGenerator().selectionChanged() }
                }
            }
            .onEnded { value in
                guard !committed, !reduceMotion else { return }
                dragging = false
                if isOverPlate(value.translation) {
                    commit()
                } else {
                    overPlate = false
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    /// True when the CARD'S CENTER sits inside the plate (small forgiveness
    /// inset). Falls back to a travel threshold before geometry has landed.
    private func isOverPlate(_ translation: CGSize) -> Bool {
        guard !plateRect.isEmpty, !cardRect.isEmpty else { return translation.height < -180 }
        let center = CGPoint(x: cardRect.midX + translation.width,
                             y: cardRect.midY + translation.height)
        return plateRect.insetBy(dx: -24, dy: -24).contains(center)
    }

    // MARK: Committed — the identity BECOMES the meal, then the reveal

    private func commit(autoAdvance: Bool = true) {
        guard !committed else { return }
        dragging = false
        overPlate = false
        committed = true

        // The landing: a real `.success` notification haptic — the same physical
        // signature the first serving uses, so the gesture reads as one grammar.
        let landing = UINotificationFeedbackGenerator()
        landing.prepare()
        landing.notificationOccurred(.success)
        // The rising triad. Step 15 answers it an octave higher.
        ServeSound.shared.play(.serve)

        if reduceMotion {
            cardDissolved = true
        } else {
            withAnimation(.easeOut(duration: 0.28)) { cardDissolved = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.20)) { goldPulse = true }
        }

        // Unlike step 15 (which ends onboarding on an explicit CTA), this beat
        // hands straight off to the plan reveal — the payoff there IS the next
        // screen, so a button in between would be a speed bump.
        guard autoAdvance else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(settleDelay))
            vm.advance()
        }
    }

    #if DEBUG
    /// Screenshot seams: BD_COMMIT_STATE=committed holds the plated state.
    /// Ad capture (BD_AD_SHOT=commit): auto-play the whole beat on a timer.
    private func seedForScreenshots() {
        if AdMode.isEnabled, AdMode.shot == .commit {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1400))
                commit(autoAdvance: false)
            }
            return
        }
        if ProcessInfo.processInfo.environment["BD_COMMIT_STATE"] == "committed" {
            commit(autoAdvance: false)
        }
    }
    #endif
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
