import SwiftUI

// MARK: - Moonshot 3 · Why does this matter to you? (Jack approved 2026-10-10, moon.png).
//
// One goal, so one answer. Show the answer working: a live preview of their
// own shield ("You wanted to prove it to yourself." / "Go get BrainDiet
// launched."), updating as they tap.

struct MoonshotWhyStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(title: "Why does this matter to you?", compact: true)

                VStack(spacing: 7) {
                    ForEach(GoalReason.allCases) { r in
                        ReasonRow(label: r.label, isSelected: vm.moonshotReason == r) {
                            withAnimation(Theme.Motion.snappy) { vm.setReason(r) }
                        }
                    }
                }
                .padding(.top, 12)

                ShieldPreviewCard(
                    headline: vm.moonshotReason?.shieldWish ?? vm.moonshotDomain.shieldWish,
                    line: MoonshotShield.goLine(short: vm.moonshotShort)
                )
                .padding(.top, 18)
                .animation(Theme.Motion.smooth, value: vm.moonshotReason)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// moon.png's compact answer row: leaf wash + deep border when chosen.
struct ReasonRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch, alignment: .leading)
                .padding(.horizontal, 14)
                .background(isSelected ? Color.bdLeafTint : Color.bdSurface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.bdLeafDeep : Color.bdCardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.moonshotShort = "BrainDiet launched"
    vm.moonshotReason = .prove
    return ZStack { BDBackground(); MoonshotWhyStepView(vm: vm).padding(Theme.Space.screenX) }
}
