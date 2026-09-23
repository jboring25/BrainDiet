import SwiftUI

// MARK: - Step: the trial-cancel reminder (Opal mapping row 12, reworked
// 2026-07-22 for the 7-day free trial).
//
// Opal stages a trial-reminder ask here; ours makes it HONEST and ours: the
// user PICKS when we nudge them before the free trial ends, so the first charge
// is never a surprise (the transparency wedge). This is also where the app asks
// for notification permission (same as the old dinner bell did) — the real
// system prompt fires on selection, then we schedule the pre-trial-end
// reminder. "Not now" / deny still advances gracefully (no scheduling, no dead
// end). The daily 20:00 / 21:30 nudges still rely on this grant, but their
// framing is no longer shown here — only the cancel-reminder is.
//
// Staged/honey-card treatment kept. Reachable via BD_ONBOARDING_STEP=dinnerBell.

struct DinnerBellStepView: View {
    @Bindable var vm: OnboardingViewModel

    @State private var isRequesting = false
    @State private var chosen: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NO SURPRISES")
                .font(.bdEyebrow)
                .kerning(2.5)
                .foregroundStyle(Color.bdTextSecondary)
                .padding(.top, Theme.Space.xl)
                .padding(.bottom, Theme.Space.md)

            Text("When should we remind you?")
                .font(BDFont.serif(size: 30, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("We'll nudge you before your free trial ends, so you're never surprised.")
                .font(.bdBody)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.sm)

            // The two Jack-approved choices, staged on warm honey cards.
            VStack(spacing: Theme.Space.sm) {
                reminderOption(daysBefore: 3, label: "3 days before")
                reminderOption(daysBefore: 2, label: "2 days before")
            }
            .padding(.top, Theme.Space.lg)

            Spacer()

            Button {
                vm.advance()
            } label: {
                Text("Not now")
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
            .padding(.top, 2)
            .padding(.bottom, Theme.Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// One selectable reminder option — a staged honey card with a bell chip.
    private func reminderOption(daysBefore days: Int, label: LocalizedStringResource) -> some View {
        Button {
            choose(daysBefore: days)
        } label: {
            HStack(spacing: Theme.Space.md) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.bdSurface)
                    .frame(width: 42, height: 42)
                    .overlay(BDPhIcon(icon: .bell, size: 20, color: .bdHoneyText))

                Text(label)
                    .font(BDFont.body(.semiBold, size: 17, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)

                Spacer(minLength: 0)

                Image(systemName: chosen == days ? "checkmark.circle.fill" : "chevron.right")
                    .font(chosen == days ? .title3 : .bdCaption)
                    .foregroundStyle(chosen == days ? Color.bdLeaf : Color.bdTextSecondary)
            }
            .padding(Theme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color.bdHoneyTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(chosen == days ? Color.bdLeaf : Color.bdCardBorder,
                                          lineWidth: chosen == days ? 1.5 : 1)
                    )
                    .shadow(color: Theme.Shadow.cardColor, radius: Theme.Shadow.cardRadius / 2, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .accessibilityLabel("Remind me \(days) days before the trial ends")
    }

    /// Fire the ONE real system prompt; if granted, schedule the pre-trial-end
    /// reminder; then advance regardless (the nudges self-gate on authorization).
    private func choose(daysBefore days: Int) {
        guard !isRequesting else { return }
        isRequesting = true
        chosen = days
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task { @MainActor in
            let granted = await NotificationService.requestPermissionAfterFirstWin()
            if granted {
                await NotificationService.scheduleTrialEndReminder(daysBefore: days)
            }
            isRequesting = false
            vm.advance()
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.selectedDomains = [.reading]
    vm.primaryDomain = .reading
    vm.timeLostHours = 3
    vm.blocker = .distracted
    return ZStack {
        BDBackground()
        DinnerBellStepView(vm: vm).padding(.horizontal, Theme.Space.screenX)
    }
}
