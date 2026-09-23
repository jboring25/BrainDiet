import SwiftUI

// MARK: - Step: Screen Time permission (Opal mapping row 5 — the structural fix).
//
// Opal asks for Screen Time at PEAK curiosity, gating the aha-report on it,
// with a "does NOT see" privacy sheet. Ours sits right before the building →
// mirror pair, framed in the mirror's language: "Your mirror needs to see the
// damage." Runs through the gated ScreenTimeGateway — on the simulator /
// un-entitled builds (DegradedScreenTimeGateway) the request no-ops and the
// flow continues gracefully; denial also continues (the mirror still works
// from their own answer). No trap, no dead end.

struct ScreenAccessStepView: View {
    @Bindable var vm: OnboardingViewModel

    @Environment(BlockingService.self) private var blocking
    @State private var isRequesting = false
    @State private var showPrivacySheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR MIRROR")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, 18)

            Text("Which apps distract you most?")
                .font(BDFont.serif(size: 30, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // ⭐ SECOND SENTENCE CUT (2026-08-12, show-don't-tell pass). It read
            // "Replacing them with more nourishing habits is exactly what your
            // brain needs." — a claim about the user's brain, made at the exact
            // moment we are asking for the most invasive permission iOS has.
            // The `pause` step immediately before this one now SHOWS what we do
            // with the access, so the sentence was both unearned and redundant.
            // One line at a permission ask; the headline is the question.
            Text("Connect Screen Time and we'll show you.")
                .font(BDFont.body(.medium, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdGrayInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.md)

            // The transparency move (Opal's "does NOT see" sheet) — one quiet
            // row, opens the honest list.
            Button {
                showPrivacySheet = true
            } label: {
                HStack(spacing: Theme.Space.sm) {
                    Image(systemName: "lock")
                        .font(.system(size: 13, weight: .semibold))
                    Text("What BrainDiet does NOT see")
                        .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.bdGrayInk)
                .frame(minHeight: Theme.Size.minTouch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Space.sm)

            Spacer(minLength: Theme.Space.lg)

            BDPrimaryButton(title: "Connect Screen Time", isEnabled: !isRequesting) {
                requestAndContinue()
            }

            // ⭐ "Not now" REMOVED (Jack, 2026-08-05). Safe because
            // `requestAndContinue()` calls `vm.advance()` unconditionally —
            // whether the user grants or DENIES at the system sheet, onboarding
            // moves on. So Apple's own permission dialog is the decline path,
            // and nobody is stranded: one clear action instead of two doors to
            // the same next screen. (If this ever becomes blocking on denial,
            // the escape must come back — a permission screen with no way past
            // it is a dark pattern and an App Review rejection.)
            Spacer(minLength: Theme.Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showPrivacySheet) { PrivacyListSheet() }
    }

    /// Request via the gateway, then continue REGARDLESS of the outcome —
    /// degraded builds no-op instantly, denial still gets the (self-reported)
    /// mirror. The Menu tab keeps a quiet "Connect" path for later.
    private func requestAndContinue() {
        guard !isRequesting else { return }
        isRequesting = true
        Task { @MainActor in
            await blocking.authorize()
            // Carry the real outcome forward so `advance()` knows whether the
            // app-picker step has anything to show.
            vm.screenTimeAuthorized = blocking.isAuthorized
            isRequesting = false
            vm.advance()
        }
    }
}

// MARK: - PrivacyListSheet — the honest "does NOT see" list.
//
// Display-only claims, kept true: Apple's Screen Time stack hands apps opaque
// tokens + time totals; content, keystrokes, and browsing never reach us, and
// BrainDiet is local-first (nothing leaves the device).

private struct PrivacyListSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("BrainDiet does NOT see:")
                .font(BDFont.display(.semiBold, size: 24, relativeTo: .title2))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)

            VStack(alignment: .leading, spacing: Theme.Space.sm + 4) {
                notRow("Your passwords")
                notRow("What you watch, read, or type")
                notRow("Your browsing history")
            }
            .padding(.top, Theme.Space.xs)

            Text("Screen Time shares time totals only. They stay on your device.")
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.bottom, Theme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Color.bdSurface)
    }

    private func notRow(_ text: LocalizedStringResource) -> some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.bdSlopGray)
                .frame(width: 22)
            Text(text)
                .font(BDFont.body(.semiBold, size: 16, relativeTo: .body))
                .foregroundStyle(Color.bdTextPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let vm = OnboardingViewModel()
    return ZStack {
        Color.bdGrayCanvas.ignoresSafeArea()
        ScreenAccessStepView(vm: vm)
            .padding(.horizontal, Theme.Space.screenX)
            .environment(BlockingService())
    }
}
