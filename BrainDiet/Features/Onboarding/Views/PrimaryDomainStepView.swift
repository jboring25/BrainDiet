import SwiftUI

// MARK: - Q4 — Which one matters most right now? (single) → primary anchor.
//
// Chosen only from the domains picked in Q3. TOP-ANCHORED (the appetite pass
// killed the centered float).
//
// ⭐ 2026-07-22 UX audit: this step used the SAME two-column tile grid as Q3,
// so reviewers read it as a repeat of the previous screen ("it feels like a
// bug") even though it was already filtered to their picks. The narrowing is
// now VISUAL as well as logical: the chosen domains render as a single-column
// list of LARGE cards — icon chip on the left, a bigger domain name, the
// food-word subtitle in the category color, and the leaf check on the right.
// Fewer, bigger, one per row = "pick one of these," not "pick again."

struct PrimaryDomainStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    StepHeader(
                        title: "Which one matters most right now?",
                        subtitle: "We'll build your brain plan around this one first."
                    )

                    VStack(spacing: 12) {
                        ForEach(vm.selectedDomains) { domain in
                            PrimaryDomainCard(
                                domain: domain,
                                isSelected: vm.primaryDomain == domain
                            ) {
                                withAnimation(Theme.Motion.snappy) { vm.primaryDomain = domain }
                            }
                        }
                    }
                    .padding(.top, 22)

                    Spacer(minLength: Theme.Space.lg)
                }
                .frame(minHeight: geo.size.height, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - The narrowing card — one chosen domain per row, at scale.
//
// Same color law as `DomainTile` (category-tint chip, category-ink food word),
// but laid out wide: a 54pt tint chip, the label at 20pt display, and the
// established leaf check on selection.

struct PrimaryDomainCard: View {
    let domain: ActivityDomain
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                // On the selected card the fill IS the category tint, so the
                // chip flips to white — otherwise tint-on-tint erases it.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.bdSurface : domain.categoryTint)
                    .frame(width: 54, height: 54)
                    .overlay(BDPhIcon(icon: domain.phIcon, size: 27, color: domain.categoryColor))

                VStack(alignment: .leading, spacing: 3) {
                    Text(domain.label)
                        .font(BDFont.display(.extraBold, size: 20, relativeTo: .title3))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text(domain.foodSubtitle)
                        .font(BDFont.body(.bold, size: 13, relativeTo: .subheadline))
                        .foregroundStyle(domain.categoryTextInk)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: Theme.Space.sm)

                // The established checked treatment — leaf, only when chosen.
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.bdLeaf : Color.bdCardBorder,
                                      lineWidth: 1.5)
                        .background(Circle().fill(isSelected ? Color.bdLeaf : .clear))
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? domain.categoryTint : Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? domain.categoryColor : Color.bdCardBorder,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(domain.label), \(domain.foodSubtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.reading, .fitness, .building]
    vm.primaryDomain = .reading
    return ZStack { BDBackground(); PrimaryDomainStepView(vm: vm).padding(Theme.Space.screenX) }
}
