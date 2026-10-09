import SwiftUI

// MARK: - v2 · The wheel picker behind each "When does your day run?" row.
//
// One field per sheet. Class or work gets two wheels and an honest "none",
// because plenty of people have no fixed block and a forced 9 to 5 would put
// every cue in the wrong place.

struct DayTimeSheet: View {
    @Bindable var vm: OnboardingViewModel
    let field: DayField
    @Environment(\.dismiss) private var dismiss

    private var title: LocalizedStringResource {
        switch field {
        case .wake:  return "Up at"
        case .busy:  return "Class or work"
        case .sleep: return "Asleep by"
        case .feedStart: return "Block from"
        case .feedEnd:   return "Until"
        }
    }

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Text(title)
                .font(BDFont.serif(size: 22, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)

            switch field {
            case .wake:  wheel(Binding(get: { vm.wakeMinutes }, set: { vm.wakeMinutes = $0 }))
            case .sleep: wheel(Binding(get: { vm.sleepMinutes }, set: { vm.sleepMinutes = $0 }))
            case .busy:  busyEditor
            case .feedStart: wheel(Binding(get: { vm.feedCustomStart }, set: { vm.feedCustomStart = $0 }))
            case .feedEnd:   wheel(Binding(get: { vm.feedCustomEnd }, set: { vm.feedCustomEnd = $0 }))
            }

            BDPrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, Theme.Space.screenX)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.bdBackground.ignoresSafeArea())
    }

    private func wheel(_ minutes: Binding<Int>) -> some View {
        DatePicker("", selection: Binding(
            get: { DayClock.date(minutes.wrappedValue) },
            set: { minutes.wrappedValue = DayClock.minutes($0) }
        ), displayedComponents: .hourAndMinute)
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxHeight: 180)
    }

    @ViewBuilder
    private var busyEditor: some View {
        let hasBusy = vm.busyStartMinutes != nil
        if hasBusy {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    caption("Starts")
                    wheel(Binding(get: { vm.busyStartMinutes ?? 540 }, set: { vm.busyStartMinutes = $0 }))
                }
                VStack(spacing: 0) {
                    caption("Ends")
                    wheel(Binding(get: { vm.busyEndMinutes ?? 1020 }, set: { vm.busyEndMinutes = $0 }))
                }
            }
        } else {
            Text("No fixed class or work block.")
                .font(BDFont.body(.medium, size: 15, relativeTo: .body))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(height: 196)
        }
        Button {
            if hasBusy { vm.busyStartMinutes = nil; vm.busyEndMinutes = nil }
            else { vm.busyStartMinutes = 540; vm.busyEndMinutes = 1020 }
        } label: {
            Text(hasBusy ? "I don't have one" : "Add class or work")
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdLeafDeep)
        }
        .buttonStyle(.plain)
    }

    private func caption(_ s: LocalizedStringResource) -> some View {
        Text(s)
            .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
            .textCase(.uppercase)
            .foregroundStyle(Color.bdLeaf)
    }
}

#Preview {
    DayTimeSheet(vm: OnboardingViewModel(), field: .busy)
}
