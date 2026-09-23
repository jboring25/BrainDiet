import SwiftUI

// MARK: - Q1 — What's been eating your time? (multi-select) → the junk to cut.
//
// THE GRAY WORLD (appetite pass, 2026-07-18): this step lives on the gray
// canvas — the feed's snacks are shown already drained of color, and selecting
// one MUTES it (slop tint + "MUTED" badge) rather than lighting it up. Spec of
// record: design/plate-concepts/appetite-mockups.html (screen 2).

struct HijackStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        // TOP-ANCHORED: header → 22pt → grid → footer note; the flex gap
        // collects at the BOTTOM (never a centered float). Still scrolls under
        // large Dynamic Type via the minHeight floor.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    StepHeader(
                        title: "What's been eating your time?",
                        // ⭐ 2026-07-22 UX audit: reviewers read the mixed list
                        // ("Oversleeping" next to "Socials") as an unrelated
                        // grab-bag — "is this a sleep tracker or a blocker?".
                        // Naming the ORGANIZING IDEA makes all six cohere as
                        // avoidance behaviors. The labels are unchanged.
                        subtitle: "Pick what you reach for when you're avoiding something."
                    )

                    LazyVGrid(columns: OBGrid.columns, spacing: 12) {
                        ForEach(AttentionHijacker.allCases) { hijacker in
                            HijackTile(
                                hijacker: hijacker,
                                isSelected: vm.selectedHijackers.contains(hijacker)
                            ) {
                                vm.toggleHijacker(hijacker)
                            }
                        }
                    }
                    .padding(.top, 22)

                    Text("Everything here turns gray for a reason.")
                        .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Color.bdGrayFaint)
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
    ZStack { Color.bdGrayCanvas.ignoresSafeArea(); HijackStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
