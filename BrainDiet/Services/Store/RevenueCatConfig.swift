import Foundation

// MARK: - RevenueCatConfig — the one place the RevenueCat wiring is named.
//
// Why RevenueCat at all (2026-08-03): Shipaton 2026 entry requires the SDK to
// power at least one in-app purchase, and the Grand Prize shortlist is built
// from revenue "as reported in RevenueCat" — so purchases must actually FLOW
// through it, not merely link against it.
//
// Scope of the migration, deliberately narrow: StoreKit 2 still loads products,
// prices, and introductory-offer ELIGIBILITY (that logic is App-Review-sensitive
// and already correct — see StoreService.hasFreeTrial). RevenueCat owns the
// purchase call, the entitlement, and restore. One engine per job.

enum RevenueCatConfig {

    /// Public SDK key (RevenueCat → app → public API keys). Safe to ship in the
    /// binary — it can only *read* offerings and *make* purchases as the current
    /// user. The secret `sk_` key must NEVER appear here; it lives at
    /// `~/.config/revenuecat/secret_key` and is for tooling only.
    /// Empty = not configured; the app degrades to StoreKit-only rather than
    /// crashing, so builds and simulator work are never blocked on this string.
    static let apiKey = "appl_swQhUlaMHUPEEakfrfkWTAbhQRf"

    /// Entitlement lookup key in the RevenueCat dashboard (project `projb9e4bc82`,
    /// entitlement `entl524bf29825`). Both products grant it:
    /// `braindiet.weekly` and `braindiet.lifetime`, exposed through the
    /// `default` offering as `$rc_weekly` / `$rc_lifetime`. There is no free
    /// tier: the entitlement is what the 3-day trial grants.
    static let entitlementID = "pro"

    /// Whether we have a key to configure with.
    static var isConfigured: Bool { !apiKey.isEmpty }
}
