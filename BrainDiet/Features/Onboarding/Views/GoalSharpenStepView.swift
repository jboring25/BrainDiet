import SwiftUI

// MARK: - Goal builder 3 · Sharper versions (mock4, screen 3).
//
// Optional AI, only options. Up to two tighter versions under their own
// sentence; one tap. "Keep mine" stays an option so the app never overrides
// them. Shown only when the call answered: while it is in flight a skeleton
// holds the space (≤ 6s); a failure skips the screen (see the VM).

struct GoalSharpenStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var pulse = false

    var body: some View {
        if let scene = vm.currentScene {
            content(scene)
        }
    }

    private func content(_ scene: GoalScene) -> some View {
        let template = vm.template(for: scene)
        let pick = vm.sharpenPick[scene]
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GoalProgressChip(vm: vm, scene: scene)
                StepHeader(title: "Make it yours.").padding(.top, 10)

                GoalSentenceCard(pieces: template.pieces(for: vm.draft(for: scene)),
                                 domain: scene.domain, size: 20)
                    .padding(.top, 14)

                HStack(spacing: 5) {
                    BDPhIcon(icon: .sparkle, size: 14, color: scene.domain.builderInk)
                    Text(String(localized: "Sharper versions"))
                        .font(BDFont.body(.extraBold, size: 13, relativeTo: .footnote))
                        .foregroundStyle(scene.domain.builderInk)
                }
                .padding(.top, 16)

                VStack(spacing: 7) {
                    if let options = vm.sharpenOptions {
                        ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                            BuilderAltRow(text: option, isSelected: pick == i, domain: scene.domain) {
                                vm.pickSharpen(i)
                            }
                        }
                    } else {
                        skeleton
                        skeleton
                    }
                    BuilderAltRow(text: String(localized: "Keep mine"),
                                  isSelected: pick == nil && vm.sharpenOptions != nil,
                                  domain: scene.domain) {
                        vm.pickSharpen(nil)
                    }
                }
                .padding(.top, 8)

                BuilderHelperLine(text: String(localized: "Your first step starts here."))
                    .padding(.top, 16)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .animation(Theme.Motion.smooth, value: vm.sharpenOptions)
    }

    private var skeleton: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.bdCardBorder.opacity(pulse ? 0.9 : 0.45))
            .frame(height: 46)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            }
            .accessibilityLabel("Loading")
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pickedScenes = [.launched]
    return ZStack { BDBackground(); GoalSharpenStepView(vm: vm).padding(Theme.Space.screenX) }
}
