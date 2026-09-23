import SwiftUI

// MARK: - Step 1 — Welcome / hook (appetite pass, 2026-07-18).
//
// THE FEAST LEADS. Spec of record: design/plate-concepts/appetite-mockups.html
// (screen 1). The nourished plate renders HUGE — ~150% of screen width, melted
// into the cream canvas — before a single word. Then the serif two-tone promise:
// "You feed your body well. / Your brain eats too." (second line salmon), a
// two-line sub, and the container's single CTA ("Show me how"). Attraction law:
// the screen sells the meal, never the problem. (2026-07-22 UX audit: the
// "I'm just looking" ghost was deleted and the CTA softened — "Take your life
// back" is the earned payoff at the plan reveal, not the opening ask.)

// THE OPENING (2026-07-27, static since 2026-08-08). One orchestrated moment, not scattered
// effects: the feast is SERVED to you. The plate settles down onto the cream
// (spring, never a pop), then the promise, then the turn ("Your brain eats
// too."), then the sub. The honey bloom that used to rise through the plate is
// GONE and may not return as a backdrop — it drew behind an opaque render and
// exposed its bounding box (see the hero block below).
// Reduce Motion collapses the whole sequence to a single 200ms fade.

struct WelcomeStepView: View {
    /// Measured content width (inside the container's screenX padding).
    @State private var contentWidth: CGFloat = 337

    /// Entrance beats: 0 none · 1 feast · 2 promise · 3 the turn · 4 sub.
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func shown(_ beat: Int) -> Bool { phase >= beat }
    /// Rise distance for a text beat — flattened under Reduce Motion.
    private func rise(_ beat: Int, _ d: CGFloat) -> CGFloat {
        reduceMotion || shown(beat) ? 0 : d
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandWordmark(tone: .onDark, size: 12)

            // ⭐ THE FEAST — STATIC, AND DELIBERATELY SO (2026-08-08).
            //
            // ⏳ PLACEHOLDER. The hero animation is coming from Kling via the
            // Higgsfield MCP once Jack buys the subscription (deferred to the
            // end of the build so it can cover website work too). Until then
            // this is a still plate, and it must STAY a still plate: hand-built
            // fluid animation is banned here (see CLAUDE.md's animation
            // guardrail). Two hand-built versions were rejected; do not attempt
            // a third. The swap will be a video layer in this exact slot.
            //
            // SIZING. The original ran at 150% of screen width with negative
            // horizontal padding, which is where "too big / sides cut off" came
            // from. It now fits the content column — a plate that fits cannot be
            // clipped, and that failure mode is gone by construction rather than
            // by a tuned overhang.
            //
            // ⛔️ NOTHING MAY BE DRAWN BEHIND THIS IMAGE — no gradient, no bloom,
            // no tint. `PlateNourished` is an OPAQUE #FDF9F2 render: build 7
            // baked the melt into the PNGs (which is what finally killed the
            // device-only white band by removing the runtime `.blendMode`
            // entirely), and the cost of that fix is that the render only
            // disappears against the exact cream canvas. The old honey bloom
            // sat behind it and exposed the bounding box as a hard-edged pale
            // rectangle (design/aug06-verify, first pass). If warmth is wanted
            // here it has to be baked into the asset too.
            //
            // The settle-in below is an ordinary entrance transition, which the
            // guardrail explicitly still allows — it is state change, not motion
            // art.
            // The plate render is retired (2026-09-03); the hero is Culture.
            // All the guardrails above were about that PNG being an OPAQUE cream
            // bitmap — the cloud draws on transparency, so they no longer apply.
            BDPlateMark(nourishment: 0.62, steaming: true)
                .frame(height: 300)
                .scaleEffect(reduceMotion || shown(1) ? 1 : 0.94, anchor: .bottom)
                .offset(y: reduceMotion || shown(1) ? 0 : 18)
                .opacity(shown(1) ? 1 : 0)
                // ⛔️ NO NEGATIVE TOP PADDING. The old layout pulled the render
                // up to trim its baked-in steam headroom; at full width that
                // overlapped the wordmark, and because this PNG is OPAQUE cream
                // it painted straight over it (design/aug08-welcome, first pass)
                // — the identical failure Jack caught on Home the same week.
                // Headroom inside the asset is the asset's problem to fix, never
                // something to claw back by overlapping a sibling.
                .accessibilityHidden(true)

            headline
                .padding(.top, 2)

            Text("Feed your brain in line with the person you want to be.")
                .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, Theme.Space.md)
                .opacity(shown(4) ? 1 : 0)
                .offset(y: rise(4, 6))

            Spacer(minLength: Theme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Theme.Space.sm)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        .onAppear(perform: runEntrance)
    }

    /// One orchestrated sequence. Interruptible by construction (SwiftUI
    /// animations retarget); Reduce Motion collapses it to a single fade.
    private func runEntrance() {
        guard phase == 0 else { return }
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) { phase = 4 }
            return
        }
        // The feast settles.
        withAnimation(.spring(response: 0.62, dampingFraction: 0.82).delay(0.12)) { phase = 1 }
        // The promise.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.55)) { phase = 2 }
        // The turn — the line the whole app is built on.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.74)) { phase = 3 }
        // The invitation.
        withAnimation(.easeOut(duration: 0.5).delay(0.94)) { phase = 4 }
    }

    /// Serif two-tone (mockup `.w-h1`): the promise in ink, the hook in salmon.
    /// Split into two blocks so the salmon line can land as its own beat — the
    /// 3pt VStack spacing reproduces the original single-Text lineSpacing(3).
    private var headline: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("You feed your body well.")
                .foregroundColor(Color.bdTextPrimary)
                .opacity(shown(2) ? 1 : 0)
                .offset(y: rise(2, 10))
            Text("Your brain eats too.")
                .foregroundColor(Color.bdSalmon)
                .opacity(shown(3) ? 1 : 0)
                .offset(y: rise(3, 10))
        }
        .font(BDFont.serif(size: 40, relativeTo: .largeTitle))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You feed your body well. Your brain eats too.")
    }
}

#Preview {
    ZStack { BDBackground(intensity: .hero); WelcomeStepView().padding(.horizontal, Theme.Space.screenX) }
}
