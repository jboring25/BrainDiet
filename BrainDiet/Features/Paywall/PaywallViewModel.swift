import SwiftUI

// MARK: - Paywall state — real StoreKit 2 purchase/restore via StoreService.
//
// The view injects the app-wide StoreService; this stays a thin presenter:
// plan selection, in-flight flags, the transparent-billing line, and honest
// error surfacing. House rule: Restore is always present and really works.

@MainActor
@Observable
final class PaywallViewModel {

    var selectedPlan: PaywallPlan = .weekly   // the trial rides here, so it is the way in (clearly labeled)

    /// ⭐ REAL StoreKit intro-offer eligibility for the ANNUAL plan, refreshed
    /// from StoreService whenever a paywall appears. False = this Apple Account
    /// already used its 7-day trial, so EVERY trial promise on the surface
    /// (badge, timeline, CTA, billing line) must go dark. Defaults to false so
    /// a slow/failed store load can never over-promise.
    var trialEligible = false

    var isPurchasing = false
    var isRestoring = false
    /// A human, non-technical error line (nil = no error).
    var errorMessage: String?

    /// The transparent-billing sentence — built from the single pricing source.
    /// Weekly carries the 3-day free trial (the honest transparency wedge).
    /// Lifetime is a ONE-TIME purchase: it never renews, so it must never carry
    /// a "cancel anytime" or a trial word. Saying "cancel" about a thing that
    /// cannot renew is the same class of lie as promising a trial that does not
    /// exist.
    var transparentBillingLine: String {
        guard selectedPlan.isRecurring else {
            return String(
                format: String(localized: "%1$@ once. Not a subscription — nothing renews, nothing to cancel."),
                PaywallPricing.lifetimeDisplay
            )
        }
        guard trialEligible else {
            // Returning user: no trial exists for them, so no trial word.
            return String(
                format: String(localized: "%1$@/week, billed today. Cancel anytime in 2 taps: Settings ▸ Subscriptions."),
                PaywallPricing.weeklyDisplay
            )
        }
        return String(
            format: String(localized: "%1$d days free, then %2$@/week. Cancel anytime in 2 taps. We'll remind you before the trial ends."),
            PaywallPricing.trialDays, PaywallPricing.weeklyDisplay
        )
    }

    // MARK: Real actions (StoreKit 2)

    /// Load products, then read REAL intro-offer eligibility. Every paywall
    /// calls this in `.task` before it can promise anything.
    func syncOffer(using store: StoreService) async {
        await store.loadProducts()
        trialEligible = store.hasFreeTrial(for: .weekly)
    }

    func purchase(using store: StoreService, onSuccess: @escaping () -> Void) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await store.purchase(selectedPlan) {
                onSuccess()
            }
            // User cancelled / pending → no error, no dismissal. Calm.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(using store: StoreService, onFinish: @escaping (_ isPro: Bool) -> Void) async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        await store.restore()
        if !store.isPro {
            errorMessage = String(localized: "No previous purchase was found for this Apple Account.")
        }
        onFinish(store.isPro)
    }
}
