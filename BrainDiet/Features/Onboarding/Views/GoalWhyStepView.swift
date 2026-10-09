import SwiftUI

// MARK: - Goal builder 4 · Why does this one matter to you? (mock4, screen 4).
//
// Show the answer working: a live preview of their own shield, built from
// their reason and their goal, updating as they tap. The payoff for answering
// is visible before the paywall, and it is the promise the video makes.

struct GoalWhyStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        if let scene = vm.currentScene {
            content(scene)
        }
    }

    private func content(_ scene: GoalScene) -> some View {
        let reason = vm.goalReasons[scene.domain]
        let goal = GoalSentenceText.display(vm.goalText(for: scene))
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(title: "Why does this one matter to you?", subtitle: "\(goal)")

                VStack(spacing: Theme.Space.sm) {
                    ForEach(GoalReason.allCases) { r in
                        OBOptionRow(label: r.label, isSelected: reason == r) {
                            withAnimation(Theme.Motion.snappy) { vm.setReason(r) }
                        }
                    }
                }
                .padding(.top, 18)

                ShieldPreviewCard(
                    headline: reason?.shieldWish ?? scene.domain.shieldWish,
                    line: String(localized: "Go get back to \(vm.shortGoal(for: scene)).")
                )
                .padding(.top, 20)
                .animation(Theme.Motion.smooth, value: reason)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pickedScenes = [.launched]
    vm.goalWords = [.building: "Get 100 ASU students using BrainDiet by May 1"]
    vm.goalReasons = [.building: .prove]
    return ZStack { BDBackground(); GoalWhyStepView(vm: vm).padding(Theme.Space.screenX) }
}
