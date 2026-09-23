import Foundation

// MARK: - UsageProvider — the AUTOMATIC reclaimed-time data source.
//
// Mirrors the ScreenTimeGateway pattern: the rest of the app never imports
// DeviceActivity and never depends on the entitlement being granted. Two
// implementations, chosen at launch by the same compile-time flag as blocking:
//
//   • RealUsageProvider     — reads per-day flagged-app minutes that the
//     DeviceActivityMonitor extension writes into the shared App Group. Compiled
//     only when BRAINDIET_FAMILY_CONTROLS is defined AND the entitlement exists.
//   • DegradedUsageProvider — the default. Returns a graceful "not active yet"
//     state (no data) in release, and realistic seeded numbers in DEBUG so
//     screenshots/previews look alive. It is NOT a manual-logging fallback — the
//     app is automatic by design; when protection isn't active, Home shows a
//     calm degraded state, never a "log a meal" prompt.
//
// `hasLiveData` tells the UI whether it's showing genuine automatic data or the
// degraded state, so Home can render the honest "your protection isn't active
// yet" message when appropriate.

protocol UsageProvider: Sendable {
    /// Whether this provider is backed by real, automatic Screen Time data.
    /// False = degraded (entitlement/framework absent) → Home shows the calm
    /// "protection isn't active yet" state.
    var hasLiveData: Bool { get }

    /// Flagged-app usage for the last `days` days, oldest → today. One entry per
    /// day; `hasData == false` for days with nothing reported.
    ///
    /// `categories` is the one-time Mental Diet map (appID → nutrition class). When
    /// non-empty, each returned `DayUsage` also carries per-category minutes so the
    /// "Today's Mental Diet" panel can render — automatically, no daily logging.
    func usage(lastDays days: Int, baselineMinutes: Int,
               categories: [String: AppCategory], now: Date) -> [DayUsage]
}

extension UsageProvider {
    /// Convenience for a single day.
    func usage(on day: Date, baselineMinutes: Int,
               categories: [String: AppCategory] = [:], now: Date) -> DayUsage {
        usage(lastDays: 1, baselineMinutes: baselineMinutes,
              categories: categories, now: now).last ?? .empty(day)
    }
}

// MARK: - Provider selection

enum UsageProviderFactory {
    /// The provider the live app uses — real when entitled, degraded otherwise.
    /// Ad capture (BD_AD_MODE=1, DEBUG) pins the deterministic ad numbers.
    static func make(appGroup: String = BlockingConfig.appGroup) -> UsageProvider {
        #if DEBUG
        if AdMode.isEnabled { return AdUsageProvider() }
        // ⭐ 2026-08-09 — the seeded comeback curve must win over the real
        // provider when a screenshot asks for it.
        //
        // WHY THIS WAS ADDED: once BRAINDIET_FAMILY_CONTROLS was turned on, this
        // factory returned `RealUsageProvider` unconditionally — and on the
        // simulator its App Group is empty, so every day came back with no data.
        // `DegradedUsageProvider`'s BD_SEED_HISTORY curve became unreachable in
        // the only build configuration we actually ship, which meant the ONGOING
        // MIRROR ("you used to scroll 3h, this week 1h 52m") had never once been
        // seen in its populated state. Every review of that card was a review of
        // its empty branch, and nobody noticed because the empty branch is
        // deliberately graceful.
        if DemoSeed.isHistoryRequested { return DegradedUsageProvider() }
        #endif
        #if canImport(DeviceActivity) && BRAINDIET_FAMILY_CONTROLS
        return RealUsageProvider(appGroup: appGroup)
        #else
        return DegradedUsageProvider()
        #endif
    }
}
