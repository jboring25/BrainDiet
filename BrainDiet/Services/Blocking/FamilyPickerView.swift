import SwiftUI

// MARK: - FamilyPickerView — the real system app picker (gated).
//
// Presented from onboarding (and Settings later) when the entitlement is live.
// In a degraded build this type still exists but renders an on-brand explainer
// instead of the system picker, so call sites compile + run everywhere.

#if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
import FamilyControls

struct FamilyPickerView: View {
    /// v2: the allow-list picker reuses this with its own title.
    var title: LocalizedStringKey = "Pick your junk apps"
    /// Called with the encoded selection when the user confirms.
    let onConfirm: (BlockingSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            onConfirm(RealScreenTimeGateway.encode(selection))
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#else

// Degraded stand-in — keeps call sites compiling without FamilyControls.
struct FamilyPickerView: View {
    var title: LocalizedStringKey = "Pick your junk apps"
    let onConfirm: (BlockingSelection) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BDBackground(intensity: .standard)
            VStack(spacing: Theme.Space.md) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.bdGoldDeep)
                Text("Real blocking is coming")
                    .font(.bdHeadline)
                    .foregroundStyle(Color.bdTextPrimary)
                Text("Connect Screen Time to shield these apps for real. For now, flag them manually.")
                    .font(.bdBody)
                    .foregroundStyle(Color.bdTextSecondary)
                    .multilineTextAlignment(.center)
                BDPrimaryButton(title: "Got it") { dismiss() }
                    .padding(.top, Theme.Space.sm)
            }
            .padding(Theme.Space.xl)
        }
    }
}

#endif
