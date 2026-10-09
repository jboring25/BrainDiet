import SwiftUI

// MARK: - v2 · Say what you want, in your words. (Jack approved 2026-10-08)
//
// One field per goal (the plan holds three), REQUIRED: Continue stays dead until
// every field has at least `OnboardingViewModel.minGoalWords` characters. The
// old `specifics` step kept this optional and the plans came out generic; the
// words are the single input that makes a plan theirs.

struct GoalWordsStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focused: ActivityDomain?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(
                    title: "Say what you want, in your words.",
                    subtitle: "The more specific, the better your plan. Nobody else sees this."
                )

                ForEach(vm.goalWordDomains) { domain in
                    VStack(alignment: .leading, spacing: 8) {
                        OBSectionLabel(text: domain.label, domain: domain)
                        OBTextArea(
                            placeholder: domain.goalPlaceholder,
                            text: binding(for: domain),
                            isFocused: focused == domain
                        )
                        .focused($focused, equals: domain)
                    }
                    .padding(.top, 22)
                }

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func binding(for domain: ActivityDomain) -> Binding<String> {
        Binding(
            get: { vm.goalWords[domain] ?? "" },
            set: { vm.goalWords[domain] = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.reading, .building, .fitness]
    return ZStack { BDBackground(); GoalWordsStepView(vm: vm).padding(Theme.Space.screenX) }
}
