import Foundation

// MARK: - Blocking configuration — shared identifiers (Functional M2).
//
// Constants shared between the main app and the (to-be-added) DeviceActivityMonitor
// extension. Kept in one place so the extension can reference identical values.

enum BlockingConfig {
    /// App Group — REQUIRED for the main app + DeviceActivity extension to share
    /// the FamilyActivitySelection + cap state. The user must create this group
    /// in the Apple Developer portal and add it to BOTH targets' entitlements.
    static let appGroup = "group.com.jackboring.braindiet.shared"

    /// ManagedSettingsStore name for the Focus-session (manual) shield.
    static let focusStoreName = "BrainDietFocus"
    /// ⭐ The ALWAYS-ON junk shield (Jack, 2026-08-13). Deliberately a SEPARATE
    /// store from the focus one: a protect session ending calls `clearShield()`,
    /// and if both lived in the same store, finishing one session would silently
    /// unblock the user's junk apps for the rest of the day. Two stores means
    /// the session shield and the standing shield can never clear each other.
    static let junkStoreName = "BrainDietJunk"
    /// ManagedSettingsStore name for the scheduled junk-cap shield (out-of-process).
    static let capStoreName = "BrainDietCap"

    /// DeviceActivity activity name for the daily junk-cap monitor.
    static let dailyCapActivity = "BrainDietDailyCap"
    /// DeviceActivityEvent name for "junk cap reached".
    static let junkCapEvent = "junkCapReached"
    /// DeviceActivityEvent name prefix for the automatic USAGE meters — a series
    /// of small thresholds the extension uses to accrue a per-day minute total.
    static let usageMeterEventPrefix = "usageMeter."
    /// Minutes each usage-meter threshold represents (the granularity of the
    /// automatic daily total). Smaller = finer/lag-lighter but more callbacks.
    static let usageMeterStepMinutes = 5
    /// How many meter thresholds to schedule (covers up to N × step minutes/day).
    static let usageMeterSteps = 96   // 96 × 5m = 8h/day of resolution

    // Shared-defaults keys (read by the extension via the App Group).
    static let kSelectionData = "blocking.selectionData"
    static let kJunkCapMinutes = "blocking.junkCapMinutes"

    /// Per-day flagged-app minute total key (written by the extension, read by
    /// RealUsageProvider). One key per calendar day: "usage.YYYY-MM-DD".
    static func dailyUsageKey(for day: Date) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return String(format: "usage.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// DeviceActivityEvent name prefix for the automatic MENTAL-DIET meters — one
    /// series of thresholds PER nutrition class (spec-v2.1). e.g.
    /// "dietMeter.nourishing.3". The extension groups the user's categorized app
    /// tokens by class and schedules a meter series for each present class.
    static let dietMeterEventPrefix = "dietMeter."

    /// Per-day, per-nutrition-class minute total key (written by the extension,
    /// read by RealUsageProvider). e.g. "usage.nourishing.2026-06-30".
    static func dailyCategoryUsageKey(for day: Date, category: String) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return String(format: "usage.%@.%04d-%02d-%02d", category, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Shared-defaults key: JSON map appID/token-hash → AppCategory.rawValue, so
    /// the extension knows each app's class. Written by the app after setup.
    static let kAppCategories = "blocking.appCategories"

    // MARK: - The Intercept (spec-v2.4) — shared shield content keys.
    //
    // The custom Family Controls shield ("the bridge at the fork") reads its
    // identity-framed copy from the App Group so the ShieldConfiguration /
    // ShieldAction extensions can render it without importing the app's models.
    // The app writes fully-rendered strings (ShieldContent.write); the extension
    // reads plain strings (constants duplicated in the extension, like MonitorConfig).
    static let kShieldHeadline  = "shield.headline"
    static let kShieldBody      = "shield.body"
    static let kShieldPrimary   = "shield.primary"
    static let kShieldSecondary = "shield.secondary"
    static let kShieldSymbol    = "shield.symbol"        // SF Symbol for the goal
    static let kShieldMinutes   = "shield.minutes"       // suggested protect length
    static let kShieldGoalID    = "shield.goalID"        // so the action can arm the right block
    /// Written by the ShieldAction extension when the user taps "Protect this time"
    /// at the fork — a timestamp the app can read to reflect the armed intent.
    static let kShieldLastProtectAt = "shield.lastProtectAt"

    /// The calm default protect length the shield offers at the fork. Short + low
    /// friction so choosing real life is the EASY default (spec-v2.4).
    static let shieldSuggestedMinutes = 20
}
