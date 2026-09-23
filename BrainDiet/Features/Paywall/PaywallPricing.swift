import Foundation

// MARK: - Paywall pricing — SINGLE SOURCE OF TRUTH.
//
// Price is NOT locked. Change it here and the whole paywall updates. When
// StoreKit 2 / RevenueCat is wired, these become display fallbacks and the
// live values come from the store products (localized prices) — see
// TODO(RevenueCat) in PaywallViewModel.

enum PaywallPricing {

    // Raw figures (USD) — swap freely. (Display-only until StoreKit is wired.)
    static let annualPrice: Decimal = 39.99
    static let monthlyPrice: Decimal = 7.99
    // Annual carries a 7-DAY FREE TRIAL (StoreKit introductory offer on
    // braindiet.pro.annual; Jack 2026-07-22). Kept honest — the paywall + the
    // slide-16 chooser both surface a pre-charge reminder, so there's no
    // surprise. Monthly is a direct subscribe.
    static let trialDays = 7

    // MARK: Derived display

    private static func usd(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    static var annualDisplay: String { usd(annualPrice) }
    static var monthlyDisplay: String { usd(monthlyPrice) }

    /// Annual broken down to a per-month figure ("$7.50/mo").
    static var annualPerMonthDisplay: String {
        let perMonth = annualPrice / 12
        return usd(perMonth)
    }

    /// Annual broken down to a per-week figure ("$1.15") — the honest fractional
    /// frame ("That's $1.15/week"). Derived from the same single price source.
    static var annualPerWeekDisplay: String {
        let perWeek = annualPrice / 52
        return usd(perWeek)
    }

    /// Percent saved on annual vs. paying monthly for a year.
    static var annualSavingsPercent: Int {
        let yearAtMonthly = monthlyPrice * 12
        guard yearAtMonthly > 0 else { return 0 }
        let saved = (yearAtMonthly - annualPrice) / yearAtMonthly
        let pct = (saved as NSDecimalNumber).doubleValue * 100
        return Int(pct.rounded())
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

    /// Headline price for the row.
    var priceDisplay: String {
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
