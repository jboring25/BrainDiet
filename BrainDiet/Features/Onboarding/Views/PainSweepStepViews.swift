import SwiftUI

// MARK: - v3 pain sweep (Jack approved 2026-10-09).
//
// "The pain points are still not being driven like they were in the video."
// His video: the phone pulls him away on the train, at the gym, at his desk,
// and he misses the person he wanted to be. These three questions name the
// moment, the feeling, and the fixes that already failed, before the app says
// one word about a solution.
//
// All three live in the GRAY WORLD with the hijack/timeLost steps: the
// existing OBOptionRow in its gray variant, the existing StepHeader. Nothing
// is pre-selected; these are admissions (see `OnboardingViewModel.blocker`).

/// When does it get you? (multi, ≥ 1)
struct WhenItGetsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        PainOptionList(title: "When does it get you?",
                       subtitle: "Pick every moment it happens.") {
            ForEach(PullMoment.allCases) { m in
                OBOptionRow(label: m.label, grayWorld: true,
                            isSelected: vm.whenItGets.contains(m)) {
                    withAnimation(Theme.Motion.snappy) { vm.togglePullMoment(m) }
                }
            }
        }
    }
}

/// How do you feel after? (single)
struct FeelAfterStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        PainOptionList(title: "How do you feel after?",
                       subtitle: "Be honest. Nobody else sees this.") {
            ForEach(AfterFeeling.allCases) { f in
                OBOptionRow(label: f.label, grayWorld: true, isSelected: vm.feelAfter == f) {
                    withAnimation(Theme.Motion.snappy) { vm.feelAfter = f }
                }
            }
        }
    }
}

/// What have you tried to stop it? (multi, ≥ 1)
struct TriedBeforeStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        PainOptionList(title: "What have you tried to stop it?", subtitle: nil) {
            ForEach(TriedFix.allCases) { f in
                OBOptionRow(label: f.label, grayWorld: true,
                            isSelected: vm.triedBefore.contains(f)) {
                    withAnimation(Theme.Motion.snappy) { vm.toggleTriedFix(f) }
                }
            }
        }
    }
}

/// The BlockerStepView layout (header → 22pt → rows), scrollable so six rows
/// survive large Dynamic Type.
private struct PainOptionList<Rows: View>: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource?
    @ViewBuilder let rows: Rows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(title: title, subtitle: subtitle)
                VStack(spacing: Theme.Space.sm) { rows }
                    .padding(.top, 22)
                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("When it gets you") {
    ZStack { Color.bdGrayCanvas.ignoresSafeArea(); WhenItGetsStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}

#Preview("Feel after") {
    ZStack { Color.bdGrayCanvas.ignoresSafeArea(); FeelAfterStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}

#Preview("Tried before") {
    ZStack { Color.bdGrayCanvas.ignoresSafeArea(); TriedBeforeStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
