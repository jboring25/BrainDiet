import SwiftUI

// MARK: - Moonshot 2 · That's the one. Here's the road. (Jack approved 2026-10-10, moon.png).
//
// Their moonshot on a card, then the road the plan server drew to it: three
// dated milestones on a thin leaf timeline, the first one lit (that is where
// the daily steps start), the moonshot itself as the last stop. Every row is
// editable in place. Skeleton rows while the call runs (≤ 8s); on failure one
// empty row they can type a milestone into, or skip. Continue never locks.

struct MoonshotRoadStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var editing: UUID?
    @FocusState private var focus: RoadField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(title: "That's the one. Here's the road.", compact: true)

                Text(vm.trimmedMoonshot)
                    .font(BDFont.serif(size: 19, relativeTo: .title3))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                    }
                    .padding(.top, 14)

                BuilderLabel(text: String(localized: "The road there"), color: .bdLeaf, size: 11)
                    .padding(.top, 18)

                road.padding(.top, 2)

                Text("Your daily steps start on the first one. Tap any to edit.")
                    .font(BDFont.body(.medium, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.top, 14)
                    .opacity(vm.roadLoading ? 0 : 1)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focus) { _, now in if now == nil { editing = nil } }
    }

    // MARK: The timeline

    private var road: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.roadLoading {
                ForEach(0..<4, id: \.self) { i in
                    RoadStop(lit: false, muted: true) { RoadSkeletonRow(index: i) }
                }
            } else {
                ForEach(Array(vm.milestones.enumerated()), id: \.element.id) { i, m in
                    RoadStop(lit: i == 0, muted: false) { milestoneRow(m, first: i == 0) }
                }
                RoadStop(lit: false, muted: false) {
                    RoadRow(title: vm.moonshotFinish, trailing: String(localized: "the moonshot"), first: false)
                }
            }
        }
        .padding(.top, 8)
        .background(alignment: .leading) {
            // The thin leaf line the stops hang on.
            Capsule()
                .fill(Color.bdLeaf.opacity(0.18))
                .frame(width: 2)
                .padding(.vertical, 22)
                .padding(.leading, 7)
        }
        .animation(Theme.Motion.smooth, value: vm.roadLoading)
    }

    @ViewBuilder
    private func milestoneRow(_ m: Milestone, first: Bool) -> some View {
        if editing == m.id || m.isBlank {
            RoadEditRow(milestone: m, first: first, focus: $focus,
                        onTitle: { vm.updateMilestone(m.id, title: $0) },
                        onBy: { vm.updateMilestone(m.id, by: $0) })
        } else {
            Button {
                editing = m.id
                focus = .title(m.id)
            } label: {
                RoadRow(title: m.title,
                        trailing: m.by.isEmpty ? "" : String(localized: "by \(m.by)"),
                        first: first)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit this milestone")
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.moonshot = "Build BrainDiet into the app that gets a million people off their phones"
    vm.milestones = [Milestone(title: "Launch on the App Store", by: "Nov 15"),
                     Milestone(title: "First 1,000 users", by: "Mar 1"),
                     Milestone(title: "Paying users every week", by: "Jun 1")]
    vm.roadFinish = "1 million people"
    return ZStack { BDBackground(); MoonshotRoadStepView(vm: vm).padding(Theme.Space.screenX) }
}
