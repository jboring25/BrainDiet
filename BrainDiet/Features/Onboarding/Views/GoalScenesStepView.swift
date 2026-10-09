import SwiftUI

// MARK: - Goal builder 1 · Picture the person you want to be (mock4, screen 1).
//
// Reflect their pain, then the future: the echo chip carries their own
// answers (hours, feeling) above the ask. Scenes grouped by life area; pick
// order shows as a numbered badge; after three picks the rest drop to 0.4 and
// can't be picked until one is unpicked. Pick #1 is the primary goal.

struct GoalScenesStepView: View {
    @Bindable var vm: OnboardingViewModel

    private var full: Bool { vm.pickedScenes.count >= OnboardingViewModel.maxScenes }
    private var betweenClasses: Bool { vm.whenItGets.contains(.betweenClasses) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let echo = vm.sceneEcho {
                    BuilderEchoChip(text: echo).padding(.bottom, 10)
                }
                StepHeader(title: "Picture the person you want to be, a year from now.",
                           subtitle: "Pick up to 3.", compact: true)

                ForEach(SceneGroup.allCases) { group in
                    BuilderLabel(text: group.label)
                        .padding(.top, 18)
                        .padding(.bottom, 2)
                    ForEach(GoalScene.scenes(in: group, betweenClasses: betweenClasses)) { scene in
                        row(scene).padding(.top, 6)
                    }
                }

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .animation(Theme.Motion.snappy, value: vm.pickedScenes)
    }

    private func row(_ scene: GoalScene) -> some View {
        let number = vm.pickedScenes.firstIndex(of: scene).map { $0 + 1 }
        // A same-domain swap is always allowed (see `toggleScene`).
        let swappable = vm.pickedScenes.contains { $0.domain == scene.domain }
        let dim = number == nil && full && !swappable
        return SceneRow(scene: scene, number: number) {
            vm.toggleScene(scene)
        }
        .opacity(dim ? 0.4 : 1)
        .disabled(dim)
    }
}

/// One scene: domain icon tile + label, numbered badge when picked.
struct SceneRow: View {
    let scene: GoalScene
    let number: Int?
    let action: () -> Void

    private var picked: Bool { number != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(scene.domain.tint.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay(BDPhIcon(icon: scene.domain.phIcon, size: 18, color: scene.domain.tint))
                Text(scene.label)
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if let number {
                    Text("\(number)")
                        .font(BDFont.body(.extraBold, size: 11, relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.bdLeafDeep, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.Size.minTouch + 4)
            .background(picked ? Color.bdLeafTint : Color.bdSurface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(picked ? Color.bdLeafDeep : Color.bdCardBorder, lineWidth: picked ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: picked)
        .accessibilityValue(number.map { String(localized: "Pick \($0)") } ?? "")
        .accessibilityAddTraits(picked ? [.isSelected] : [])
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.timeLostHours = 3
    vm.feelAfter = .behind
    vm.pickedScenes = [.launched, .readMonth, .strongest]
    return ZStack { BDBackground(); GoalScenesStepView(vm: vm).padding(Theme.Space.screenX) }
}
