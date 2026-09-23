import Foundation

// MARK: - Paywall pricing — LIVE from the store, with a fallback.
//
// ⭐ THE PRICES ARE NOT HARDCODED ANY MORE (2026-09-22). They were, and the
// paywall would have shown "$39.99" to a customer in Tokyo whose card was about
// to be charged in yen. Every display string below now prefers the real
// localized price that `StoreService` publishes from the RevenueCat offering,
// and falls back to the numbers here only until the store answers (or when it
// never does — offline, a sandbox hiccup). The fallback must therefore stay in
// step with App Store Connect; it is a last resort, not the source of truth.

enum PaywallPricing {

    /// Fallback figures (USD), used only until the store answers. These mirror
    /// App Store Connect: braindiet.pro.annual $39.99, braindiet.pro.monthly $7.99.
    static let annualPrice: Decimal = 39.99
    static let monthlyPrice: Decimal = 7.99

    // MARK: Live prices

    /// One plan's real price, as the store states it for THIS customer.
    struct Live {
        let display: String        // the store's own string: "$39.99", "¥6,000"
        let amount: Decimal        // for per-week / savings math
        let currencyCode: String   // so derived figures stay in the same currency
    }

    /// Published by StoreService once products load. MainActor-isolated because
    /// every reader is a paywall surface.
    @MainActor private(set) static var live: [PaywallPlan: Live] = [:]

    @MainActor static func setLive(_ prices: [PaywallPlan: Live]) { live = prices }

    /// Formats a derived figure in the plan's own currency, falling back to USD.
    @MainActor private static func money(_ value: Decimal, like plan: PaywallPlan) -> String {
        guard let code = live[plan]?.currencyCode else { return usd(value) }
        return value.formatted(.currency(code: code))
    }

    @MainActor private static func amount(_ plan: PaywallPlan) -> Decimal {
        live[plan]?.amount ?? (plan == .annual ? annualPrice : monthlyPrice)
    }
    // Annual carries a 7-DAY FREE TRIAL (StoreKit introductory offer on
    // braindiet.pro.annual; Jack 2026-07-22). Kept honest — the paywall + the
    // slide-16 chooser both surface a pre-charge reminder, so there's no
    // surprise. Monthly is a direct subscribe.
    static let trialDays = 7

    // MARK: Derived display

    private static func usd(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    @MainActor static var annualDisplay: String {
        live[.annual]?.display ?? usd(annualPrice)
    }

    @MainActor static var monthlyDisplay: String {
        live[.monthly]?.display ?? usd(monthlyPrice)
    }

    /// Annual broken down to a per-month figure ("$3.33/mo"), in the real currency.
    @MainActor static var annualPerMonthDisplay: String {
        money(amount(.annual) / 12, like: .annual)
    }

    /// Annual broken down to a per-week figure — the honest fractional frame
    /// ("That's $0.77/week"), derived from the price actually being charged.
    @MainActor static var annualPerWeekDisplay: String {
        money(amount(.annual) / 52, like: .annual)
    }

    /// Percent saved on annual vs. paying monthly for a year. Computed from the
    /// live pair when both are known, so a price change in App Store Connect can
    /// never leave a stale "save 58%" on screen.
    @MainActor static var annualSavingsPercent: Int {
        let yearAtMonthly = amount(.monthly) * 12
        guard yearAtMonthly > 0 else { return 0 }
        let saved = (yearAtMonthly - amount(.annual)) / yearAtMonthly
        let pct = (saved as NSDecimalNumber).doubleValue * 100
        return max(0, Int(pct.rounded()))
    }
}

// MARK: - Selectable plan

enum PaywallPlan: CaseIterable, Identifiable {
    case annual
    case monthly

    var id: Self { self }

    var title: String {
        switch self {
        case .annual:  return String(localized: "Annual")
        case .monthly: return String(localized: "Monthly")
        }
    }

    /// Headline price for the row — the store's own localized string.
    @MainActor var priceDisplay: String {
        switch self {
        case .annual:  return PaywallPricing.annualDisplay
        case .monthly: return PaywallPricing.monthlyDisplay
        }
    }

    var periodDisplay: String {
        switch self {
        case .annual:  return String(localized: "/year")
        case .monthly: return String(localized: "/month")
        }
    }
}
