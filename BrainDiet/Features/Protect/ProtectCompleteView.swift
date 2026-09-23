import SwiftUI

// MARK: - Reclaim COMPLETE — the GOLD FEED moment (soul pass, 2026-07-02;
// plate era 2026-07-11 — the brain is retired from the UI).
//
// A block ran its full course. The invested minutes FEED the plate: it warms
// dim → vivid center-stage and begins to steam, ONE gold shimmer rings it
// (gold fires only on earned moments), then everything settles calm. One
// richer haptic, one "Done." No confetti — the reward is who you're becoming.

struct ProtectCompleteView: View {
    @Bindable var vm: ProtectSessionViewModel
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    /// The plate warms as the invested minutes feed it.
    @State private var nourish: Double = 0.3
    /// One gold shimmer pulse — scale + fade, once, then gone.
    @State private var goldPulse = false

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            ZStack {
                // The single gold shimmer — an earned ring of light, once.
                Ellipse()
                    .stroke(
                        AngularGradient(
                            colors: [.bdGoldDeep, .bdGold, Color(hex: "#F0DCB2"), .bdGold, .bdGoldDeep],
                            center: .center, angle: .degrees(-90)),
                        lineWidth: 2.5
                    )
                    .frame(width: 250, height: 155)
                    .scaleEffect(goldPulse ? 1.16 : 0.82)
                    .opacity(goldPulse ? 0 : 0.9)
                    .blur(radius: goldPulse ? 2 : 0)
                    .allowsHitTesting(false)

                VStack(spacing: Theme.Space.md) {
                    // Center-stage: the fed plate, warming and steaming.
                    BDPlateMark(nourishment: nourish, steaming: settled)
                        .frame(width: 260)
                    // "A SERVING OF READING · 50M" — the block, plated.
                    Text(vm.completionEyebrow)
                        .font(.bdEyebrow)
                        .kerning(2.5)
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .frame(width: 280, height: 240)
            .accessibilityHidden(true)

            VStack(spacing: Theme.Space.md) {
                Text(vm.completionHeadline)
                    .font(BDFont.grotesk(.extrabold, size: 28, relativeTo: .title))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(settled ? 1 : 0)

                Text(vm.completionIdentityLine)
                    .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                    .foregroundStyle(Color.bdSage)   // readable sage on white (bright sage washed out)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(settled ? 1 : 0)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            BDPrimaryButton(title: "Done", action: onDone)
                .padding(.bottom, Theme.Space.md)
        }
        .padding(.horizontal, Theme.Space.screenX)
        .onAppear { settle() }
    }

    /// The feed: the plate warms to vivid + steams, the gold shimmer rings it
    /// once, everything settles calm. One richer haptic on the settle.
    private func settle() {
        guard !settled else { return }
        if reduceMotion {
            nourish = 1
            settled = true
            goldPulse = true   // pulse pre-expired → no motion, no lingering gold
        } else {
            // The invested minutes feed the plate.
            withAnimation(.easeOut(duration: 0.9)) { nourish = 1 }
            // The gold shimmer fires as the plate reaches vivid — once.
            withAnimation(.easeOut(duration: 0.9).delay(0.55)) { goldPulse = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.6)) {
                settled = true
            }
        }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.75)) {
            generator.notificationOccurred(.success)
        }
    }
}

#Preview {
    let vm = ProtectSessionViewModel()
    return ZStack {
        BDBackground()
        ProtectCompleteView(vm: vm, onDone: {})
            .onAppear {
                #if DEBUG
                vm.debugEnterCompleted()
                #endif
            }
    }
}
