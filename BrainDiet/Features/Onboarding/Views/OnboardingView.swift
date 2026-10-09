import SwiftUI
import SwiftData

// MARK: - Onboarding container.
//
// Owns the step machine, the top bar (back + progress), and the single
// bottom CTA. Step content is swapped in the middle. The "building" and
// "planReveal" steps are full-bleed moments and hide the chrome.
//
// On completion it PERSISTS the UserProfile, then signals the app to flip to
// the main flow.

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var vm = OnboardingViewModel()

    /// Persist the profile, then hand off to the app gate.
    private func finish() {
        vm.persistProfile(into: modelContext)
        onComplete()
    }

    /// ⭐ THE GRAY→COLOR ARC (appetite pass, 2026-07-18): the steps about the
    /// feed (hijack + timeLost) live in the GRAY WORLD — the canvas itself
    /// desaturates — and the pre-mirror beats (interstitial + Screen Time
    /// permission) stay gray so the held breath keeps its weight. The mirror
    /// bridges gray back into cream (top 58% gray, cream returning at the
    /// bottom, where hope lives). Everything else rides the cream canvas.
    /// Color is the reward; gray is what the feed costs you.
    private enum StepCanvas { case cream, gray, mirror }

    private var stepCanvas: StepCanvas {
        switch vm.step {
        case .hijack, .timeLost, .interstitial, .screenAccess: return .gray
        case .mirror:            return .mirror
        default:                 return .cream
        }
    }

    /// The gray world mutes the progress fill too; color steps run leaf.
    private var grayWorld: Bool { stepCanvas == .gray }

    var body: some View {
        ZStack {
            canvas
                .animation(.easeInOut(duration: 0.6), value: vm.step)

            VStack(spacing: 0) {
                if vm.step.showsProgress {
                    topBar
                }

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(vm.step)

                if showsBottomCTA {
                    bottomCTA
                }
            }
            .padding(.horizontal, Theme.Space.screenX)
        }
        // Finishing is no longer a step's job — the flow signals it.
        .onChange(of: vm.didFinish) { _, done in if done { finish() } }
        #if DEBUG
        .onAppear { vm.jumpToStepIfRequested() }
        #endif
    }

    // MARK: - Canvas (the gray→color arc)

    @ViewBuilder
    private var canvas: some View {
        switch stepCanvas {
        case .cream:
            Color.bdBackground.ignoresSafeArea()
        case .gray:
            Color.bdGrayCanvas.ignoresSafeArea()
        case .mirror:
            // Mockup `.m-body`: gray holds the loss (top 58%), cream returns
            // beneath it — the canvas itself performs the pivot.
            LinearGradient(
                stops: [
                    .init(color: Color.bdGrayCanvas, location: 0),
                    .init(color: Color.bdGrayCanvas, location: 0.58),
                    .init(color: Color.bdBackground, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top bar (back + progress)

    private var topBar: some View {
        HStack(spacing: Theme.Space.md) {
            Button {
                vm.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.bdBodyStrong)
                    .foregroundStyle(grayWorld ? Color.bdGrayInk : Color.bdTextPrimary)
                    .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .accessibilityLabel("Back")

            BDProgressBar(
                current: vm.step.progressIndex,
                total: OnboardingStep.progressTotal,
                grayWorld: grayWorld
            )
        }
        .padding(.top, Theme.Space.sm)
        .padding(.bottom, Theme.Space.lg)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .welcome:
            WelcomeStepView()
        case .hijack:
            HijackStepView(vm: vm)
        case .timeLost:
            TimeLostStepView(vm: vm)
        case .domains:
            DomainsStepView(vm: vm)
        case .primaryDomain:
            PrimaryDomainStepView(vm: vm)
        case .aspiration:
            AspirationStepView(vm: vm)
        case .goalWords:
            GoalWordsStepView(vm: vm)
        case .baseline:
            BaselineStepView(vm: vm)
        case .timeAndDay:
            TimeAndDayStepView(vm: vm)
        case .blocker:
            BlockerStepView(vm: vm)
        case .interstitial:
            InterstitialStepView()
        case .pause:
            PauseStepView()
        case .screenAccess:
            ScreenAccessStepView(vm: vm)
        case .pickApps:
            PickAppsStepView(vm: vm)
        case .reachAndSchedule:
            ReachAndScheduleStepView(vm: vm)
        case .building:
            BuildingStepView(vm: vm)
        case .mirror:
            MirrorStepView(vm: vm)
        case .commit:
            CommitStepView(vm: vm)
        case .planReveal:
            // The reveal no longer finishes — it advances INTO the paywall step.
            PlanRevealStepView(vm: vm, onComplete: { vm.advance() })
        case .onboardingPaywall:
            // Purchase-success AND every skip path resolve forward; the
            // cancel-reminder step only runs when a trial REALLY started
            // (vm.advance() skips it otherwise).
            OnboardingPaywallStepView(vm: vm, onComplete: { startedTrial in
                vm.startedFreeTrial = startedTrial
                vm.advance()
            })
        case .dinnerBell:
            DinnerBellStepView(vm: vm)
        case .menuHero:
            MenuHeroStepView(vm: vm)
        }
    }

    // MARK: - Bottom CTA (one primary per screen)

    private var showsBottomCTA: Bool {
        // These steps own their own actions / chrome. The interstitial rides
        // the shared Continue.
        switch vm.step {
        case .screenAccess, .pickApps, .building, .mirror, .commit, .planReveal,
             .onboardingPaywall, .dinnerBell, .menuHero:
            return false
        default: return true
        }
    }

    private var ctaTitle: LocalizedStringResource {
        switch vm.step {
        // ⭐ 2026-07-22 UX audit: "Take your life back" is the EARNED payoff at
        // the plan reveal — using it on screen 1 (before the user knows what
        // the app is) over-claims and dilutes it. Screen 1 invites, it doesn't
        // ask for the vow.
        case .welcome: return "Show me how"
        default: return "Continue"
        }
    }

    private var bottomCTA: some View {
        // ⭐ 2026-07-22 UX audit: the welcome ghost ("I'm just looking") is
        // DELETED. It was a pre-value escape hatch that did exactly what the
        // primary did — a second door that only invited bail-out before the
        // user had seen anything worth staying for. One CTA per screen.
        VStack(spacing: 0) {
            BDPrimaryButton(title: ctaTitle, isEnabled: vm.canAdvance) {
                vm.advance()
            }
        }
        .padding(.bottom, Theme.Space.sm)
    }
}

// MARK: - Continuous progress bar with a head start (Goal Gradient).
//
// The bar NEVER reads 0%: the first quiz step shows ~20% pre-filled — the user
// already "started" by tapping through the welcome hook, and a bar that's
// visibly underway is one people finish. Displayed fill = 0.2 + 0.8 × step
// fraction; the accessibility label stays literally accurate ("Step N of M").

struct BDProgressBar: View {
    let current: Int
    let total: Int
    /// Gray-world steps mute the fill (mockup `.prog i` gray-ink vs `.prog.c i`
    /// leaf) — even the progress bar loses its color in the feed's world.
    var grayWorld: Bool = false

    /// The pre-filled head start — the progress the welcome tap already earned.
    private static let baseline: Double = 0.2

    private var fill: Double {
        guard total > 1 else { return 1 }
        let step = Double(current - 1) / Double(total - 1)
        return Self.baseline + (1 - Self.baseline) * min(max(step, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bdProgressTrack)
                Capsule()
                    .fill(grayWorld ? Color.bdGrayInk : Color.bdLeaf)
                    .frame(width: max(10, geo.size.width * fill))
            }
        }
        .frame(height: 4)
        .animation(Theme.Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
