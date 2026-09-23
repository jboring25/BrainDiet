import SwiftUI

// MARK: - Slide 7 — the obstacle question ("What's stopped you before?").
//
// Reverted 2026-07-21: the app-rest list is deferred to Apple's native
// FamilyActivityPicker (Family Controls) later, so this slide returns to the
// obstacle single-select — it shapes the planner's step sizing. The slide-2
// hijackers stay DECOUPLED: they are pure identity framing and do NOT drive the
// block list. Top-anchored, established OBOptionRow pattern + appetite tokens.

struct BlockerStepView: View {
    @Bindable var vm: OnboardingViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: "What's stopped you before?",
                subtitle: "No judgment. This just shapes how big your first steps are."
            )
            VStack(spacing: Theme.Space.sm) {
                ForEach(Blocker.allCases) { blocker in
                    OBOptionRow(label: blocker.label, isSelected: vm.blocker == blocker) {
                        withAnimation(Theme.Motion.snappy) { vm.blocker = blocker }
                    }
                }
            }
            .padding(.top, 22)
            Spacer(minLength: Theme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ZStack { BDBackground(); BlockerStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
