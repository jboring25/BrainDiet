import SwiftUI

// MARK: - Q5 — Who do you want to become? → identity raw material.
//
// ⭐ REBUILT 2026-08-06 (Jack: "only buttons"). The free-text `TextEditor` is
// GONE. Four single-select options, derived from the PRIMARY DOMAIN the user
// picked one screen earlier (`ActivityDomain.aspirationOptions` — see that
// property for the Aspiration-Index rationale and the four fixed axes).
//
// WHAT THE BOX WAS ACTUALLY DOING. It was never the active ingredient: the
// planner reads `aspiration` as ONE STRING and ships it verbatim as the plan's
// identity line (`HeuristicGoalPlanner.identityLine`), falling back to
// `primaryDomain.identityLine` when it's empty. A tapped sentence travels the
// identical path. What the box really existed for was to cover the fact that
// the four chips were the SAME for everyone — a Fitness answer got offered
// "Someone who lives in the moment". Domain-derived options remove that need.
//
// ⚠️ THE HONEST COST — the generation effect. Self-generated material is better
// remembered and more committing than material you merely selected (Bertsch et
// al. 2007, Memory & Cognition 35, meta-analysis). Removing typing gives that
// up. It is worth it here because the commitment weight MOVES rather than
// vanishing: on the commit step the user physically drags THIS sentence onto
// the plate and serves it. And the detail that used to justify a keyboard now
// lives in `UserProfile.dreamDetails` — a bounded surface (Settings → Adjust
// plan) that feeds the planner without blocking onboarding.
//
// If this ever regresses to "no option fits me", the fix is a fifth option or a
// better roster — NOT putting the keyboard back in the middle of the flow.

struct AspirationStepView: View {
    @Bindable var vm: OnboardingViewModel

    /// The domain whose roster we show. Falls back through the same chain the
    /// rest of onboarding uses so this can never render an empty list.
    private var domain: ActivityDomain {
        vm.primaryDomain ?? vm.selectedDomains.first ?? .reading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            StepHeader(
                title: "Who do you want to become?",
                subtitle: "Pick the one that sounds most like you on your best day. Every serving we hand you builds that person."
            )

            VStack(spacing: Theme.Space.sm) {
                ForEach(domain.aspirationOptions, id: \.self) { option in
                    optionRow(option)
                }
            }

            Spacer()
        }
        .padding(.top, Theme.Space.sm)
        .animation(Theme.Motion.smooth, value: vm.aspiration)
    }

    // MARK: The option row — a real target, not a chip.
    //
    // These are full-width rows rather than the old wrapped chips because the
    // sentences run to two lines and a wrapped-chip layout ragged them into
    // unreadable shapes. Selection is carried by BOTH the tick and the tint —
    // never colour alone (a11y: color-not-only).

    private func optionRow(_ option: String) -> some View {
        let selected = vm.aspiration == option
        return Button {
            vm.aspiration = option
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(alignment: .center, spacing: Theme.Space.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.bdLeaf : Color.bdCardBorder, lineWidth: 1.5)
                        .background(Circle().fill(selected ? Color.bdLeaf : Color.clear))
                        .frame(width: 22, height: 22)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                Text(option)
                    .font(BDFont.body(selected ? .bold : .medium, size: 15, relativeTo: .body))
                    .foregroundStyle(selected ? Color.bdLeafDeep : Color.bdTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, 14)
            .frame(minHeight: Theme.Size.minTouch)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(selected ? Color.bdLeafTint : Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(selected ? Color.bdLeaf : Color.bdCardBorder,
                                  lineWidth: selected ? 1.8 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ZStack { BDBackground(); AspirationStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
