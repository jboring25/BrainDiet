import SwiftUI

// MARK: - v2 · Who can still reach you? (Jack approved 2026-10-08)
//
// Two answers, collected and persisted only:
//   1. The "Do it now" allow-list. Phone is always on (static); everything
//      else comes from the system FamilyActivityPicker. Messages is the noted
//      default.
//   2. When the standing feed block runs.
//
// TODO(onboarding-v2): ENFORCEMENT. Neither answer changes behaviour yet. The
// "Do it now" lock (shield everything except the allow-list for the step's
// minutes) and a non-Always feed schedule both need DeviceActivity schedules
// in BrainDietMonitor that apply/clear the shield at interval boundaries.
// Today the standing shield is always on, whatever is chosen here.

struct ReachAndScheduleStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var showPicker = false
    @State private var editing: DayField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(
                    title: "Who can still reach you?",
                    subtitle: "When you hit \"Do it now\", every other app locks until the step's time is up."
                )

                VStack(spacing: Theme.Space.sm) {
                    row(symbol: "phone.fill", label: String(localized: "Phone")) {
                        Text("Always on")
                            .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Color.bdLeaf)
                    }
                    row(symbol: "message.fill", label: String(localized: "Messages")) {
                        check
                    }
                    Button { showPicker = true } label: {
                        row(symbol: vm.allowSelectionData == nil ? "plus" : "square.grid.2x2.fill",
                            label: vm.allowSelectionData == nil
                                ? String(localized: "Choose apps")
                                : String(localized: "Your chosen apps"),
                            muted: vm.allowSelectionData == nil) {
                            if vm.allowSelectionData != nil { check }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)

                OBSectionLabel(text: String(localized: "Block my feeds"))
                    .padding(.top, 28)
                FlowChips(items: FeedSchedule.allCases) { s in
                    OBPillChip(label: s.label, isSelected: vm.feedSchedule == s) {
                        withAnimation(Theme.Motion.snappy) { vm.feedSchedule = s }
                    }
                }
                .padding(.top, 10)

                if vm.feedSchedule == .custom {
                    customEditor
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showPicker) {
            FamilyPickerView(title: "Who can reach you") { selection in
                vm.allowSelectionData = selection.encoded
            }
        }
        .sheet(item: $editing) { field in
            DayTimeSheet(vm: vm, field: field)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }

    private var check: some View {
        Image(systemName: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.bdLeaf)
    }

    /// The OBOptionRow shell with an icon and a trailing accessory.
    private func row<T: View>(symbol: String, label: String, muted: Bool = false,
                              @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(muted ? Color.bdTextSecondary : Color.bdLeafDeep)
                .frame(width: 22)
            Text(label)
                .font(BDFont.body(.semiBold, size: 16, relativeTo: .body))
                .foregroundStyle(muted ? Color.bdTextSecondary : Color.bdTextPrimary.opacity(0.9))
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(minHeight: Theme.Size.minTouch + Theme.Space.sm)
        .background(Color.bdSurface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
        }
        .contentShape(Rectangle())
    }

    // MARK: Custom: two times + the days it runs.

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            OBValueRow(label: String(localized: "From"), value: DayClock.label(vm.feedCustomStart)) {
                editing = .feedStart
            }
            OBValueRow(label: String(localized: "Until"), value: DayClock.label(vm.feedCustomEnd)) {
                editing = .feedEnd
            }
            HStack(spacing: 6) {
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { i, d in
                    let day = i + 1
                    OBPillChip(label: d, isSelected: vm.feedCustomWeekdays.contains(day)) {
                        if vm.feedCustomWeekdays.contains(day) { vm.feedCustomWeekdays.remove(day) }
                        else { vm.feedCustomWeekdays.insert(day) }
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

/// Wrapping chip row (mockup `.chips`, flex-wrap).
struct FlowChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 7) {
            ForEach(items) { content($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for (i, p) in rows.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowH = max(rowH, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (points, maxX, y + rowH)
    }
}

#Preview {
    ZStack { BDBackground(); ReachAndScheduleStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
