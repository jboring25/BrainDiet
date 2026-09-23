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
        static let annual = "braindiet.pro.annual"    // $39.99/yr
        static let monthly = "braindiet.pro.monthly"  // $7.99/mo
        static let all: Set<String> = [annual, monthly]
    }

    /// The one flag the app gates on.
    private(set) var isPro = false
    /// Live store products (annual first). Empty until loaded / when unavailable.
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    /// Real StoreKit intro-offer eligibility per product id, cached on load.
    /// ABSENT = unknown → we treat it as NOT eligible (never over-promise).
    private(set) var introOfferEligibility: [String: Bool] = [:]

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
            products = loaded.sorted { $0.id == ProductID.annual && $1.id != ProductID.annual }
            await refreshIntroEligibility()
        } catch {
            Log.app.error("StoreKit products failed to load: \(error.localizedDescription, privacy: .public)")
        }
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
        let id = plan == .annual ? ProductID.annual : ProductID.monthly
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
    /// assumes the annual trial so the shipping variant is screenshot-able on
    /// a simulator with no StoreKit configuration attached; `BD_TRIAL_INELIGIBLE=1`
    /// forces the returning-user variant.
    func hasFreeTrial(for plan: PaywallPlan) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_TRIAL_INELIGIBLE"] == "1" { return false }
        #endif
        guard let product = product(for: plan) else {
            #if DEBUG
            return plan == .annual
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
        guard let product = product(for: plan) else {
            throw StoreError.productUnavailable
        }

        guard RevenueCatConfig.isConfigured, Purchases.isConfigured else {
            return try await purchaseViaStoreKit(product)
        }

        let result = try await Purchases.shared.purchase(product: StoreProduct(sk2Product: product))
        if result.userCancelled { return false }
        applyCustomerInfo(result.customerInfo)
        await refreshIntroEligibility()
        Log.app.info("Purchase succeeded via RevenueCat: \(product.id, privacy: .public)")
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
