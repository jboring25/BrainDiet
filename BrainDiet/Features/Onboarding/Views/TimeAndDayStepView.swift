import SwiftUI

// MARK: - v2 · How much time can you honestly give it? (Jack approved 2026-10-08)
//
// Replaces the guesses: real minutes a day (every step is capped by it) and the
// real shape of the day (up at / class or work / asleep by), then the existing
// DayAnchor chips the cues hang on. Rows open a wheel picker in a sheet.

struct TimeAndDayStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var editing: DayField?

    private var minutesLabel: String {
        vm.minutesPerDay >= 120 ? "2h+" : "\(vm.minutesPerDay) min"
    }

    private var busyLabel: String {
        guard let s = vm.busyStartMinutes, let e = vm.busyEndMinutes else {
            return String(localized: "None")
        }
        return DayClock.rangeLabel(s, e)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StepHeader(
                    title: "How much time can you honestly give it?",
                    subtitle: "Per day, on a normal day. Your steps are sized to fit."
                )

                minutesControl
                    .padding(.top, 30)

                OBSectionLabel(text: String(localized: "When does your day run?"))
                    .padding(.top, 30)
                VStack(spacing: Theme.Space.sm) {
                    OBValueRow(label: String(localized: "Up at"), value: DayClock.label(vm.wakeMinutes)) {
                        editing = .wake
                    }
                    OBValueRow(label: String(localized: "Class or work"), value: busyLabel) {
                        editing = .busy
                    }
                    OBValueRow(label: String(localized: "Asleep by"), value: DayClock.label(vm.sleepMinutes)) {
                        editing = .sleep
                    }
                }
                .padding(.top, 8)

                OBSectionLabel(text: String(localized: "Which of these happen most days?"))
                    .padding(.top, 28)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 9)],
                          alignment: .leading, spacing: 9) {
                    ForEach(DayAnchor.allCases) { anchor in
                        DayAnchorChip(anchor: anchor, isOn: vm.dayAnchors.contains(anchor)) {
                            if vm.dayAnchors.contains(anchor) { vm.dayAnchors.remove(anchor) }
                            else { vm.dayAnchors.insert(anchor) }
                        }
                    }
                }
                .padding(.top, 10)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .animation(Theme.Motion.smooth, value: vm.dayAnchors)
        .sheet(item: $editing) { field in
            DayTimeSheet(vm: vm, field: field)
                .presentationDetents([.height(field == .busy ? 400 : 340)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: The big number + slider

    private var minutesControl: some View {
        VStack(spacing: 10) {
            Text(minutesLabel)
                .font(.bdInstrument(60))
                .foregroundStyle(Color.bdLeafDeep)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .animation(Theme.Motion.snappy, value: vm.minutesPerDay)

            Slider(
                value: Binding(get: { Double(vm.minutesPerDay) },
                               set: { vm.minutesPerDay = Int($0) }),
                in: 15...120, step: 5
            )
            .tint(Color.bdLeaf)
            .sensoryFeedback(.selection, trigger: vm.minutesPerDay)
            .accessibilityLabel("Minutes a day")
            .accessibilityValue(minutesLabel)

            HStack {
                Text("15m")
                Spacer()
                Text("2h+")
            }
            .font(BDFont.body(.semiBold, size: 12, relativeTo: .caption))
            .foregroundStyle(Color.bdTextSecondary)
            .padding(.horizontal, 2)
        }
    }
}

enum DayField: String, Identifiable {
    case wake, busy, sleep, feedStart, feedEnd
    var id: String { rawValue }
}

#Preview {
    ZStack { BDBackground(); TimeAndDayStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX) }
}
