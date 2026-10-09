import SwiftUI

// MARK: - One selectable plan row (Annual / Monthly).

struct PlanOptionRow: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// ⭐ REAL intro-offer eligibility (StoreService.hasFreeTrial). The "days
    /// free" badge renders ONLY when StoreKit would actually grant the trial —
    /// a returning user who already used theirs never sees trial copy.
    var showsTrial: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                // Selection indicator.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.bdAccent : Color.bdTextSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Theme.Space.sm) {
                        Text(plan.title)
                            .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                            .foregroundStyle(Color.bdTextPrimary)
                        if plan == .weekly, showsTrial {
                            trialBadge
                        }
                    }
                    if plan == .weekly {
                        Text("Billed weekly. Cancel anytime.")
                            .font(.bdCaption)
                            .foregroundStyle(Color.bdTextSecondary)
                    } else {
                        // 2026-10-09: "Pays for itself in 4 weeks" cut. One
                        // plain sentence about what it is.
                        Text("One payment. Nothing renews.")
                            .font(.bdCaption)
                            .foregroundStyle(Color.bdTextSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.priceDisplay)
                        .font(BDFont.body(.semiBold, size: 16, relativeTo: .body))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text(plan.periodDisplay)
                        .font(.bdCaption)
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(minHeight: Theme.Size.minTouch + Theme.Space.xl)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? Color.bdAccentSoft : Color.bdSurface)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .accessibilityLabel("\(plan.title), \(plan.priceDisplay) \(plan.periodDisplay)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The weekly plan leads with its free trial (the honest wedge), not a
    /// savings percentage — the trial is the offer. Length comes from
    /// PaywallPricing so the badge can never disagree with App Store Connect.
    private var trialBadge: some View {
        Text("\(PaywallPricing.trialDays) days free")
            .font(.bdCaption)
            .foregroundStyle(Color.bdTextOnAccent)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.bdAccent))
    }
}

#Preview {
    ZStack {
        BDBackground()
        VStack(spacing: Theme.Space.sm) {
            PlanOptionRow(plan: .weekly, isSelected: true, showsTrial: true) {}
            PlanOptionRow(plan: .weekly, isSelected: false, showsTrial: false) {}
            PlanOptionRow(plan: .lifetime, isSelected: false) {}
        }
        .padding(Theme.Space.screenX)
    }
}
