import Foundation

// MARK: - Paywall pricing — LIVE from the store, with a fallback.
//
// ⭐ THE MODEL (2026-09-23, Jack). There is no free tier and no Pro tier. The
// app is one version behind a 3-day free trial. After the trial you either keep
// it weekly or buy it once, forever:
//
//     braindiet.weekly    $4.99/wk, 3 days free
//     braindiet.lifetime  $19.99 one-time, non-consumable
//
// Lifetime pays for itself in four weeks. That is deliberate positioning, not a
// mispriced anchor — people are tired of subscriptions, so the one-time price is
// the honest offer and the weekly is the low-commitment way in.
//
// ⭐ THE PRICES ARE NOT HARDCODED. They were, and the paywall would have shown
// "$4.99" to a customer in Tokyo whose card was about to be charged in yen.
// Every display string below prefers the real localized price that `StoreService`
// publishes from the RevenueCat offering, and falls back to the numbers here only
// until the store answers. The fallback must stay in step with App Store Connect;
// it is a last resort, not the source of truth.

enum PaywallPricing {

    /// Fallbacks, used only until the store answers. These mirror App Store
    /// Connect: braindiet.weekly $4.99, braindiet.lifetime $19.99.
    static let weeklyPrice: Decimal = 4.99
    static let lifetimePrice: Decimal = 19.99

    /// The free trial rides on the WEEKLY plan only — a one-time purchase cannot
    /// carry an introductory offer. 3 days, because a 7-day trial on a weekly
    /// plan gives away a full billing period before the first charge.
    static let trialDays = 3

    // MARK: Live prices

    /// One plan's real price, as the store states it for THIS customer.
    struct Live {
        let display: String        // the store's own string: "$4.99", "¥800"
        let amount: Decimal        // for break-even math
        let currencyCode: String   // so derived figures stay in the same currency
    }

    /// Published by StoreService once products load. MainActor-isolated because
    /// every reader is a paywall surface.
    @MainActor private(set) static var live: [PaywallPlan: Live] = [:]

    @MainActor static func setLive(_ prices: [PaywallPlan: Live]) { live = prices }

    @MainActor private static func amount(_ plan: PaywallPlan) -> Decimal {
        live[plan]?.amount ?? (plan == .weekly ? weeklyPrice : lifetimePrice)
    }

    private static func usd(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    /// Zero, in the customer's own currency — so the CTA reads "$0.00" in the
    /// US and "¥0" in Japan rather than a hardcoded dollar figure.
    @MainActor static var freeDisplay: String {
        guard let code = live[.weekly]?.currencyCode else { return usd(0) }
        return Decimal(0).formatted(.currency(code: code))
    }

    // MARK: Derived display

    @MainActor static var weeklyDisplay: String {
        live[.weekly]?.display ?? usd(weeklyPrice)
    }

    @MainActor static var lifetimeDisplay: String {
        live[.lifetime]?.display ?? usd(lifetimePrice)
    }
}

// MARK: - Selectable plan

enum PaywallPlan: CaseIterable, Identifiable {
    case weekly
    case lifetime

    var id: Self { self }

    /// True when this plan is a subscription that renews. Lifetime never does,
    /// so every "cancel anytime" / renewal sentence must gate on this.
    var isRecurring: Bool { self == .weekly }

    var title: String {
        switch self {
        case .weekly:   return String(localized: "Weekly")
        case .lifetime: return String(localized: "Lifetime")
        }
    }

    /// Headline price for the row — the store's own localized string.
    @MainActor var priceDisplay: String {
        switch self {
        case .weekly:   return PaywallPricing.weeklyDisplay
        case .lifetime: return PaywallPricing.lifetimeDisplay
        }
    }

    var periodDisplay: String {
        switch self {
        case .weekly:   return String(localized: "/week")
        case .lifetime: return String(localized: "once")
        }
    }
}
