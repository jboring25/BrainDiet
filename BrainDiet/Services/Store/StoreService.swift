import Foundation
import StoreKit
import RevenueCat

// MARK: - StoreService — the single monetization seam (v1.0).
//
// SPLIT ENGINE (2026-08-03). StoreKit 2 still loads products, prices, and
// introductory-offer ELIGIBILITY — that logic is App-Review-sensitive and
// already correct, so it stays. RevenueCat owns the PURCHASE, the ENTITLEMENT,
// and RESTORE, because Shipaton requires purchases to actually flow through it
// (the Grand Prize shortlist reads revenue "as reported in RevenueCat").
// When RevenueCat has no API key, every path falls back to pure StoreKit, so
// simulator work and CI are never blocked on configuration. See RevenueCatConfig.
//
// Loads the two Pro subscriptions, purchases/restores for real, listens for
// entitlement updates (renewals, refunds, Ask-to-Buy resolutions, family
// sharing), and exposes ONE flag the app gates on: `isPro`.
//
// FREE tier: 1 active goal + 1 session/day. PRO: unlimited. The gates live in
// the views (ProtectTabView / ProtectIdleView); this service only answers
// "is this user Pro?"
//
// Local testing: select `Products.storekit` (repo root) as the scheme's
// StoreKit Configuration. Production: create the same product IDs in
// App Store Connect.

@MainActor
@Observable
final class StoreService {

    enum ProductID {
        static let weekly = "braindiet.weekly"        // $4.99/wk, 3 days free
        static let lifetime = "braindiet.lifetime"    // $19.99 once, non-consumable
        static let all: Set<String> = [weekly, lifetime]
    }

    /// The one flag the app gates on.
    private(set) var isPro = false
    /// Live store products (lifetime first). Empty until loaded / when unavailable.
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    /// Real StoreKit intro-offer eligibility per product id, cached on load.
    /// ABSENT = unknown → we treat it as NOT eligible (never over-promise).
    private(set) var introOfferEligibility: [String: Bool] = [:]

    /// ⭐ THE REVENUECAT OFFERING (2026-09-22). The dashboard's `default`
    /// offering carries `$rc_weekly` and `$rc_lifetime`. Purchasing the PACKAGE
    /// rather than a bare product is what attributes the sale to an offering in
    /// RevenueCat — without it the offering config is decorative and every
    /// purchase lands unattributed. Nil = offerings unreachable; the purchase
    /// path then falls back to the wrapped StoreKit product, which still flows
    /// through RevenueCat, just without attribution.
    private(set) var offering: Offering?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    // MARK: Products

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Lifetime first: it is the offer, the weekly is the way in.
            products = loaded.sorted { $0.id == ProductID.lifetime && $1.id != ProductID.lifetime }
            await refreshIntroEligibility()
            publishLivePrices()
        } catch {
            Log.app.error("StoreKit products failed to load: \(error.localizedDescription, privacy: .public)")
        }
        await loadOffering()
    }

    /// Fetches the current RevenueCat offering. Never throws upward: a missing
    /// offering degrades attribution, not the ability to buy.
    private func loadOffering() async {
        guard RevenueCatConfig.isConfigured, Purchases.isConfigured, offering == nil else { return }
        do {
            offering = try await Purchases.shared.offerings().current
            if offering != nil { publishLivePrices() }
            if offering == nil {
                Log.app.error("RevenueCat returned no current offering — check the dashboard's default offering.")
            }
        } catch {
            Log.app.error("RevenueCat offerings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The package backing a plan, by RevenueCat's standard identifiers.
    func package(for plan: PaywallPlan) -> Package? {
        plan == .weekly ? offering?.weekly : offering?.lifetime
    }

    /// ⭐ Publishes the store's OWN localized price strings to the paywall, so
    /// nothing on screen is a hardcoded number. A customer outside the US sees
    /// the price their card will actually be charged, in their currency.
    private func publishLivePrices() {
        var live: [PaywallPlan: PaywallPricing.Live] = [:]
        for plan in PaywallPlan.allCases {
            // RevenueCat's own StoreProduct first: it carries the localized price
            // whenever the offering loaded, and does not depend on the separate
            // StoreKit lookup having succeeded. `sk2Product` is deliberately NOT
            // used here — it is optional, and reaching for it reintroduces the
            // dependency this is meant to remove.
            if let rc = package(for: plan)?.storeProduct {
                live[plan] = PaywallPricing.Live(
                    display: rc.localizedPriceString,
                    amount: rc.price,
                    currencyCode: rc.currencyCode ?? "USD"
                )
            } else if let sk2 = product(for: plan) {
                live[plan] = PaywallPricing.Live(
                    display: sk2.displayPrice,
                    amount: sk2.price,
                    currencyCode: sk2.priceFormatStyle.currencyCode
                )
            }
        }
        guard !live.isEmpty else { return }
        PaywallPricing.setLive(live)
    }

    /// Asks StoreKit, per subscription, whether THIS Apple Account may still
    /// receive the introductory offer. A returning user who already burned the
    /// 7-day trial answers false — and every trial promise in the UI must go
    /// dark for them (App Review + the honesty law).
    private func refreshIntroEligibility() async {
        var map: [String: Bool] = [:]
        for product in products {
            guard let subscription = product.subscription else { continue }
            map[product.id] = await subscription.isEligibleForIntroOffer
        }
        introOfferEligibility = map
    }

    func product(for plan: PaywallPlan) -> Product? {
        let id = plan == .weekly ? ProductID.weekly : ProductID.lifetime
        return products.first { $0.id == id }
    }

    /// The introductory offer (the 7-day free trial on Annual), if the product
    /// carries one. StoreKit only vends the intro offer to eligible accounts;
    /// callers wanting strict eligibility should also check
    /// `product.subscription?.isEligibleForIntroOffer`.
    func introductoryOffer(for plan: PaywallPlan) -> Product.SubscriptionOffer? {
        product(for: plan)?.subscription?.introductoryOffer
    }

    /// ⭐ THE ONE TRIAL SEAM (2026-07-22). True ONLY when the plan carries a
    /// free-trial introductory offer AND this Apple Account is still eligible
    /// for it. Every "7 days free" element in the app gates on this — a
    /// returning user who already used their trial sees the non-trial paywall,
    /// because StoreKit will not grant a second trial and promising one is a
    /// false promise.
    ///
    /// Unknown (products unavailable, eligibility not yet answered) = NOT
    /// eligible in release: we would rather under-promise than lie. DEBUG
    /// assumes the weekly trial so the shipping variant is screenshot-able on
    /// a simulator with no StoreKit configuration attached; `BD_TRIAL_INELIGIBLE=1`
    /// forces the returning-user variant.
    func hasFreeTrial(for plan: PaywallPlan) -> Bool {
        // A one-time purchase cannot carry an introductory offer. The trial
        // rides on the weekly plan only — never promise it on lifetime.
        guard plan.isRecurring else { return false }
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_TRIAL_INELIGIBLE"] == "1" { return false }
        #endif
        guard let product = product(for: plan) else {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        guard product.subscription?.introductoryOffer?.paymentMode == .freeTrial else { return false }
        return introOfferEligibility[product.id] ?? false
    }

    // MARK: Purchase / restore

    /// Purchases the plan. Returns true when the entitlement is now active.
    ///
    /// Routed through RevenueCat when configured — it finishes the transaction
    /// and updates `CustomerInfo` itself, so we never double-finish. Falls back
    /// to direct StoreKit when there's no API key.
    func purchase(_ plan: PaywallPlan) async throws -> Bool {
        if products.isEmpty { await loadProducts() }

        // ⭐ THE PACKAGE IS ENOUGH (2026-09-22). This used to demand a StoreKit
        // `Product` first and throw `.productUnavailable` if that one lookup had
        // failed — even when RevenueCat held a perfectly good package. A
        // transient StoreKit hiccup could therefore block a sale RevenueCat was
        // ready to make. The package path no longer depends on it.
        if RevenueCatConfig.isConfigured, Purchases.isConfigured {
            if offering == nil { await loadOffering() }
            if let package = package(for: plan) {
                let result = try await Purchases.shared.purchase(package: package)
                if result.userCancelled { return false }
                applyCustomerInfo(result.customerInfo)
                await refreshIntroEligibility()
                Log.app.info("Purchase via RevenueCat package \(package.identifier, privacy: .public), pro=\(self.isPro, privacy: .public)")
                return isPro
            }
        }

        guard let product = product(for: plan) else {
            throw StoreError.productUnavailable
        }

        guard RevenueCatConfig.isConfigured, Purchases.isConfigured else {
            return try await purchaseViaStoreKit(product)
        }

        // No package (offerings unreachable): still go through RevenueCat, just
        // unattributed, so the entitlement and the revenue are never lost.
        Log.app.error("No RevenueCat package for \(product.id, privacy: .public); purchasing unattributed.")
        let result = try await Purchases.shared.purchase(product: StoreProduct(sk2Product: product))
        if result.userCancelled { return false }
        applyCustomerInfo(result.customerInfo)
        await refreshIntroEligibility()
        Log.app.info("Purchase via RevenueCat product \(product.id, privacy: .public), pro=\(self.isPro, privacy: .public)")
        return isPro
    }

    /// Direct-StoreKit purchase — the no-API-key fallback path.
    private func purchaseViaStoreKit(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreError.failedVerification
            }
            await transaction.finish()
            await refreshEntitlement()
            Log.app.info("Purchase succeeded: \(transaction.productID, privacy: .public)")
            return isPro
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Restore = ask the store to re-deliver, then re-read entitlements.
    func restore() async {
        if RevenueCatConfig.isConfigured, Purchases.isConfigured {
            if let info = try? await Purchases.shared.restorePurchases() {
                applyCustomerInfo(info)
                await refreshIntroEligibility()
                return
            }
        }
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: Entitlement

    func refreshEntitlement() async {
        if RevenueCatConfig.isConfigured, Purchases.isConfigured {
            if let info = try? await Purchases.shared.customerInfo() {
                applyCustomerInfo(info)
                if !products.isEmpty { await refreshIntroEligibility() }
                return
            }
            // RevenueCat unreachable (offline, outage): fall through to StoreKit
            // rather than silently downgrading a paying user to free.
        }
        var pro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID), transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
        // Entitlement changes (purchase, restore, refund) can flip trial
        // eligibility — re-ask rather than trust a stale yes.
        if !products.isEmpty { await refreshIntroEligibility() }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        isPro = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
    }

    /// Renewals, refunds, Ask-to-Buy resolutions and family sharing arrive here.
    /// RevenueCat's stream supersedes `Transaction.updates` when configured —
    /// running both would double-finish transactions.
    private func listenForTransactions() async {
        if RevenueCatConfig.isConfigured, Purchases.isConfigured {
            for await info in Purchases.shared.customerInfoStream {
                applyCustomerInfo(info)
                if !products.isEmpty { await refreshIntroEligibility() }
            }
            return
        }
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    enum StoreError: LocalizedError {
        case productUnavailable
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return String(localized: "The store isn't reachable right now. Please try again.")
            case .failedVerification:
                return String(localized: "Your purchase couldn't be verified. Please try again.")
            }
        }
    }
}
