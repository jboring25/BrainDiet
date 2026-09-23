import SwiftUI

// MARK: - TriageEntryCard — Home's everyday route-by-why entry (2026-07-23).
//
// (This file was the old SlopVoice-driven RedirectCard; repurposed in place as
// the entitlement-free entry into the route-by-why triage flow — TriageView.)
//
// The shippable path that needs NO Family Controls entitlement: when the user
// feels the pull to scroll, they tap here FIRST and we ask WHY before handing
// them the matched response. Visible on Home for every real user (not seeded).
//
// Attraction law: warm and inviting, never a warning. A leaf chip · "Reaching
// for a scroll?" · "Tap here first." · a quiet leaf-deep pill.

struct TriageEntryCard: View {
    /// Presents the triage flow (router.showTriage = true).
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Leaf chip — the good-choice color, inviting (never alarm).
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.bdLeafTint)
                    .frame(width: 38, height: 38)
                    .overlay(BDPhIcon(icon: .leaf, size: 18, color: .bdLeaf))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Reaching for a scroll?")
                        .font(BDFont.body(.bold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text("Tap here first.")
                        .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                // The quiet leaf-deep pill CTA.
                HStack(spacing: 5) {
                    Text("Start here")
                        .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 13)
                .background(Capsule().fill(Color.bdLeafDeep))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                    .fill(Color.bdSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                            .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reaching for a scroll? Tap here first.")
        .accessibilityHint(Text("Opens a quick check-in before you scroll."))
    }
}

#Preview {
    ZStack {
        BDBackground(intensity: .standard)
        TriageEntryCard(onTap: {})
            .padding(.horizontal, 18)
    }
}
