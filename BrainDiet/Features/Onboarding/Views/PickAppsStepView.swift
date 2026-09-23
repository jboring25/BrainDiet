import SwiftUI

// MARK: - Step: pick the apps — the one that was MISSING (Jack, 2026-08-13).
//
// ⭐ THE BUG THIS FIXES. `FamilyPickerView` has existed since the blocking work
// landed and was never presented from anywhere — its only mentions in the whole
// codebase were two comments. So `UserProfile.familySelectionData` was never
// written, `BlockingSelection.encoded` was always nil, `decode()` always
// returned an empty `FamilyActivitySelection`, and every `applyShield` call set
// `shield.applications = nil`. **No app was ever shielded, on any build.**
// Authorization worked, which is exactly why it went unnoticed: the permission
// sheet appeared, so the rest looked done.
//
// The step sits immediately after `screenAccess` because the picker cannot be
// presented before authorization is granted — the system picker returns an
// empty selection without it.
//
// HONEST ON DENIAL. If the user declined Screen Time (or this is a degraded
// build), there is nothing to pick and pretending otherwise would strand them.
// `OnboardingView` skips straight past this step in that case — see
// `OnboardingViewModel.advance()`.

struct PickAppsStepView: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(BlockingService.self) private var blocking

    @State private var showPicker = false

    /// How many apps/categories the user has chosen, for the confirmation line.
    private var hasPicked: Bool { vm.familySelectionData != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which ones pull you in?")
                .font(BDFont.serif(size: 31, relativeTo: .largeTitle))
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.xxl)

            Text("Pick the apps you lose time to. Opening one will bring you here first.")
                .font(BDFont.body(.semiBold, size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Space.sm)

            Spacer(minLength: Theme.Space.lg)

            // The chosen state is deliberately quiet and countless. Screen Time
            // hands us opaque tokens, and counting them accurately across apps
            // AND categories is more precision than this moment needs — the
            // user just picked them, they know what they picked.
            if hasPicked {
                HStack(spacing: 9) {
                    // SF, not Phosphor — the icon law exempts system chrome
                    // (chevrons, gear, checkmarks) and there is no check glyph
                    // in the Phosphor set we bundle.
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.bdLeaf)
                    Text("Your apps are set. You can change them any time in Settings.")
                        .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(Color.bdLeafTint)
                )
            }

            Spacer(minLength: Theme.Space.lg)

            // ⭐ THE STEP OWNS ITS BUTTONS (`showsBottomCTA` excludes .pickApps).
            // It first shipped riding the shared Continue and rendered TWO
            // stacked leaf pills — the screenshot caught it immediately. There
            // is exactly one primary here, and which action is primary CHANGES:
            // before picking, the job is to open the picker; after picking, the
            // job is to move on.
            if hasPicked {
                BDPrimaryButton(title: "Continue") { vm.advance() }
                ghost("Change my apps") { showPicker = true }
            } else {
                BDPrimaryButton(title: "Choose my apps") { showPicker = true }
                // Never a trap: a user who wants to get through onboarding can,
                // and Settings keeps a permanent door. Forcing the picker would
                // be a dark pattern and an App Review risk.
                ghost("I'll do this later") { vm.advance() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showPicker) {
            FamilyPickerView { selection in
                vm.familySelectionData = selection.encoded
                // Arm immediately. Waiting until onboarding finishes would mean
                // a user who quits at the paywall keeps an unshielded phone
                // despite having chosen apps — the selection has to take effect
                // the moment it is made.
                blocking.updateSelection(selection)
                blocking.applyStandingShield()
            }
        }
    }

    private func ghost(_ title: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.buttonHeight)
        }
        .buttonStyle(.plain)
        .padding(.bottom, Theme.Space.xs)
    }
}
