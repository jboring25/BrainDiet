import SwiftUI

// MARK: - Q3 — Now, what should your brain eat instead? (multi) → goal seeds.
//
// COLOR RETURNS (appetite pass, 2026-07-18): after the gray world, the cream
// canvas comes back and every tile wears its plate-category color (the LAW:
// leaf / salmon / berry / honey) with a food-language subtitle. Spec of
// record: design/plate-concepts/appetite-mockups.html (screen 3).

struct DomainsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        // TOP-ANCHORED: header → 22pt → grid → footer; flex gap at the bottom.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    StepHeader(
                        title: "What would you rather be doing?",
                        subtitle: "Pick 1–3. Every hour we reclaim goes right here."
                    )

                    LazyVGrid(columns: OBGrid.columns, spacing: 12) {
                        ForEach(ActivityDomain.allCases) { domain in
                            DomainTile(
                                domain: domain,
                                isSelected: vm.selectedDomains.contains(domain)
                            ) {
                                vm.toggleDomain(domain)
                            }
                        }
                    }
                    .padding(.top, 22)

                    Text("This is where the color comes back.")
                        .font(BDFont.body(.bold, size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdLeaf)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.md)

                    Spacer(minLength: Theme.Space.lg)
                }
                .frame(minHeight: geo.size.height, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    ZStack { BDBackground(); DomainsStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
