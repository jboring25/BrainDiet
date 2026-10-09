import SwiftUI
import SwiftData

// MARK: - "Block my feeds" — the schedule, on the Menu (Jack, 2026-10-08).
//
// Opal's Rules card, shrunk to one row: what the rule is called and when it
// runs ("Weekdays · 9am–5pm"). Tap to change it with the SAME chips onboarding
// used, so the answer looks identical in both places. Styled as the Menu's
// own setup row (`chooseAppsCTA`): white card, 16pt corners, leaf icon tile.

struct FeedScheduleCard: View {
    let window: FeedWindow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.bdLeafTint)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bdLeafDeep))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Block my feeds")
                        .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text(window.summary)
                        .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.bdLeafDeep)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Block my feeds, \(window.summary)"))
        .accessibilityHint(Text("Changes when your feeds are blocked."))
    }
}

// MARK: - The editor: onboarding's chips, writing straight to the profile.

struct FeedScheduleSheet: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editing: Edge?

    private enum Edge: String, Identifiable { case start, end; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Block my feeds")
                    .font(BDFont.serif(size: 24, relativeTo: .title2))
                    .foregroundStyle(Color.bdTextPrimary)
                Text(profile.feedWindow.summary)
                    .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.top, 4)

                FlowChips(items: FeedSchedule.allCases) { s in
                    OBPillChip(label: s.label, isSelected: profile.feedSchedule == s) {
                        withAnimation(Theme.Motion.snappy) { profile.feedScheduleRaw = s.rawValue }
                    }
                }
                .padding(.top, 18)

                if profile.feedSchedule == .custom {
                    customEditor
                        .padding(.top, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                BDPrimaryButton(title: "Done") { save(); dismiss() }
                    .padding(.top, 26)
            }
            .padding(.horizontal, Theme.Space.screenX)
            .padding(.top, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color.bdBackground.ignoresSafeArea())
        .onDisappear(perform: save)
        .sheet(item: $editing) { edge in
            FeedTimeSheet(title: edge == .start ? "Block from" : "Until",
                          minutes: edge == .start ? $profile.feedCustomStart : $profile.feedCustomEnd)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        }
    }

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            OBValueRow(label: String(localized: "From"), value: FeedWindow.clock(profile.feedCustomStart)) {
                editing = .start
            }
            OBValueRow(label: String(localized: "Until"), value: FeedWindow.clock(profile.feedCustomEnd)) {
                editing = .end
            }
            HStack(spacing: 6) {
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { i, d in
                    let day = i + 1
                    OBPillChip(label: d, isSelected: profile.feedCustomWeekdays.contains(day)) {
                        toggle(day)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// Never lets the last day go: a custom window with no days would be a
    /// block that never runs while the card still names one.
    private func toggle(_ day: Int) {
        var days = Set(profile.feedCustomWeekdays)
        if days.contains(day) { guard days.count > 1 else { return }; days.remove(day) }
        else { days.insert(day) }
        profile.feedCustomWeekdaysRaw = days.sorted().map(String.init).joined(separator: ",")
    }

    private func save() {
        do { try modelContext.save() }
        catch { Log.app.error("Feed schedule save FAILED: \(error.localizedDescription, privacy: .public)") }
    }
}

/// One wheel, the same one onboarding's DayTimeSheet shows.
private struct FeedTimeSheet: View {
    let title: LocalizedStringResource
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Text(title)
                .font(BDFont.serif(size: 22, relativeTo: .title3))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)
            DatePicker("", selection: Binding(
                get: { DayClock.date(minutes) },
                set: { minutes = DayClock.minutes($0) }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxHeight: 180)
            BDPrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, Theme.Space.screenX)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.bdBackground.ignoresSafeArea())
    }
}

#Preview {
    VStack(spacing: 12) {
        FeedScheduleCard(window: FeedWindow(schedule: .weekdays9to5, customStart: 0,
                                            customEnd: 0, customWeekdays: [])) {}
        FeedScheduleCard(window: .always) {}
    }
    .padding()
    .background(Color.bdGrayCanvas)
}
