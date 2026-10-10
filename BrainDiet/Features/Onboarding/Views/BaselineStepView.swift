import SwiftUI

// MARK: - v2 · Where are you with it today? (Jack approved 2026-10-08)
//
// Asked once, about the PRIMARY goal, with their own words echoed in the sub
// line so the question is about their thing, not a category. Same OBOptionRow
// list as the blocker question. Nothing pre-selected: where you are is the one
// thing the app must not guess.

struct BaselineStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var typing: Bool

    private var domain: ActivityDomain? { vm.primaryDomain ?? vm.selectedDomains.first }

    /// Asked about the moonshot: its own words under the question.
    private var subtitle: LocalizedStringResource? {
        let words = vm.trimmedMoonshot.isEmpty
            ? (domain.flatMap { vm.goalWords[$0] } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            : vm.trimmedMoonshot
        if !words.isEmpty { return "\(GoalSentenceText.display(words))" }
        return domain.map { "\($0.label)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(title: "Where are you with it today?", subtitle: subtitle)

                VStack(spacing: Theme.Space.sm) {
                    ForEach(GoalBaseline.allCases) { b in
                        OBOptionRow(label: b.label, isSelected: vm.baseline == b) {
                            withAnimation(Theme.Motion.snappy) { vm.baseline = b }
                        }
                    }
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 8) {
                    OBSectionLabel(text: String(localized: "What's the next real piece? (optional)"))
                    OBTextArea(placeholder: String(localized: "e.g. Finish the App Store listing"),
                               text: $vm.nextPiece, minLines: 1, isFocused: typing)
                        .focused($typing)
                }
                .padding(.top, 26)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.building]
    vm.primaryDomain = .building
    vm.goalWords = [.building: "Launch BrainDiet and get 100 users"]
    return ZStack { BDBackground(); BaselineStepView(vm: vm).padding(Theme.Space.screenX) }
}
