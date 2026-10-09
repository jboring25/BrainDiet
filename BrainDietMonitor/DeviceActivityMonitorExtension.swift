import DeviceActivity
import ManagedSettings
import Foundation

// MARK: - BrainDiet DeviceActivityMonitor extension (Functional M2).
//
// Out-of-process enforcement: this runs in a system extension, so the junk-app
// cap keeps working even when the main app is backgrounded or killed. When the
// daily junk threshold is reached, it shields the selected apps via a
// ManagedSettingsStore; at the start of each daily interval it clears the shield
// so the user gets a fresh budget.
//
// IMPORTANT (Apple-side setup required — see the app's checklist):
//   • This file belongs to a DeviceActivityMonitor app-extension target
//     ("BrainDietMonitor") that the USER must create in Xcode.
//   • The extension target needs: the Family Controls capability, the SAME App
//     Group as the app (group.com.jackboring.braindiet.shared), and the granted
//     com.apple.developer.family-controls entitlement.
//   • The shared identifiers below MUST match BlockingConfig in the app.

// These constants mirror BlockingConfig in the main app (the extension is a
// separate target, so they're duplicated here intentionally).
private enum MonitorConfig {
    static let appGroup = "group.com.jackboring.braindiet.shared"
    static let capStoreName = "BrainDietCap"
    static let junkCapEvent = "junkCapReached"
    static let kSelectionData = "blocking.selectionData"
    // Automatic usage meter (mirrors BlockingConfig).
    static let usageMeterEventPrefix = "usageMeter."
    static let usageMeterStepMinutes = 5
    // Per-nutrition-class Mental Diet meter (mirrors BlockingConfig).
    static let dietMeterEventPrefix = "dietMeter."

    // Feed schedule + Do it now (mirrors BlockingConfig, 2026-10-08).
    static let dailyCapActivity = "BrainDietDailyCap"
    static let junkStoreName = "BrainDietJunk"
    static let feedActivityPrefix = "BrainDietFeed."
    static let doItNowActivity = "BrainDietDoItNow"
    static let doItNowStoreName = "BrainDietDoItNow"
    static let kFeedWindow = "blocking.feedWindow"
    static let kAllowSelectionData = "blocking.allowSelectionData"
    static let kDoItNowEndsAt = "doItNow.endsAt"
    static let kDoItNowTitle = "doItNow.title"

    /// Per-day flagged-minute total key for the given date (mirrors BlockingConfig).
    static func dailyUsageKey(for day: Date) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return String(format: "usage.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Per-day, per-class Mental-Diet key (mirrors BlockingConfig).
    static func dailyCategoryUsageKey(for day: Date, category: String) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return String(format: "usage.%@.%04d-%02d-%02d", category, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Mirrors `FeedWindow` in the app (decodes the same JSON). Keep `contains`
/// identical to the app's.
private struct MonitorFeedWindow: Decodable {
    let schedule: String
    let start: Int
    let end: Int
    let weekdays: [Int]

    func contains(_ date: Date) -> Bool {
        if schedule == "always" { return true }
        let c = Calendar.current.dateComponents([.weekday, .hour, .minute], from: date)
        let w = c.weekday ?? 1
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if end > start { return weekdays.contains(w) && m >= start && m < end }
        let previous = w == 1 ? 7 : w - 1
        return (weekdays.contains(w) && m >= start) || (weekdays.contains(previous) && m < end)
    }
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init(MonitorConfig.capStoreName))
    private let junkStore = ManagedSettingsStore(named: .init(MonitorConfig.junkStoreName))
    private let doItNowStore = ManagedSettingsStore(named: .init(MonitorConfig.doItNowStoreName))
    private var defaults: UserDefaults? { UserDefaults(suiteName: MonitorConfig.appGroup) }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let name = activity.rawValue
        if name.hasPrefix(MonitorConfig.feedActivityPrefix) { syncFeedShield(); return }
        if name == MonitorConfig.doItNowActivity { reapplyDoItNowIfLive(); return }
        // New day → clear yesterday's cap shield; the user starts fresh. The new
        // day's usage total starts absent and accrues as meter thresholds fire.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue
        if name.hasPrefix(MonitorConfig.feedActivityPrefix) { syncFeedShield(); return }
        if name == MonitorConfig.doItNowActivity { releaseDoItNowIfOver() }
    }

    // MARK: Feed schedule — the junk shield follows the window.

    /// ⭐ ASK THE WINDOW, DON'T TRUST THE EDGE. Callbacks can land a little
    /// early or late, an overnight window is split at midnight, and
    /// `stopMonitoring` during a re-arm can fire an end mid-window. Checking
    /// two minutes ahead answers all three: an edge at 11:59pm inside a 10pm
    /// to 8am window keeps the shield, and an 8am end that lands at 7:59:58
    /// still clears it.
    private func syncFeedShield() {
        guard let d = defaults else { return }
        let window = d.data(forKey: MonitorConfig.kFeedWindow)
            .flatMap { try? JSONDecoder().decode(MonitorFeedWindow.self, from: $0) }
        let inside = window?.contains(Date().addingTimeInterval(120)) ?? true
        guard inside else {
            junkStore.shield.applications = nil
            junkStore.shield.applicationCategories = nil
            return
        }
        guard let data = d.data(forKey: MonitorConfig.kSelectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        junkStore.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        junkStore.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    // MARK: Do it now — released here so it ends even if the app is gone.

    private var doItNowEndsAt: Date? {
        guard let t = defaults?.double(forKey: MonitorConfig.kDoItNowEndsAt), t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private func reapplyDoItNowIfLive() {
        guard let ends = doItNowEndsAt, ends > Date() else { return }
        let allowed = defaults?.data(forKey: MonitorConfig.kAllowSelectionData)
            .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }?
            .applicationTokens ?? []
        doItNowStore.shield.applicationCategories = .all(except: allowed)
        doItNowStore.shield.webDomainCategories = .all()
    }

    /// A stop from a NEW lock (the app re-arming) must not release it, so only
    /// clear when the stored lock is genuinely over or gone.
    private func releaseDoItNowIfOver() {
        if let ends = doItNowEndsAt, ends > Date().addingTimeInterval(60) { return }
        doItNowStore.shield.applicationCategories = nil
        doItNowStore.shield.webDomainCategories = nil
        defaults?.removeObject(forKey: MonitorConfig.kDoItNowEndsAt)
        defaults?.removeObject(forKey: MonitorConfig.kDoItNowTitle)
        // Junk apps keep drawing their last configuration ("Do it now.")
        // until the store changes; re-assign to redraw the normal copy.
        let apps = junkStore.shield.applications
        junkStore.shield.applications = nil
        junkStore.shield.applications = apps
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        let name = event.rawValue

        // AUTOMATIC USAGE METER: each meter threshold = one step of flagged-app
        // time. When one fires, bump today's running total by the step. This is
        // what feeds the app's automatic "reclaimed time" — no manual logging.
        if name.hasPrefix(MonitorConfig.usageMeterEventPrefix) {
            recordUsageStep()
            return
        }

        // MENTAL DIET METER: each per-class threshold = one step of time on that
        // nutrition class of app. Event name is "dietMeter.<class>.<n>"; we parse
        // the class and bump that class's running daily total. This is what feeds
        // "Today's Mental Diet" — automatic, no logging.
        if name.hasPrefix(MonitorConfig.dietMeterEventPrefix) {
            let parts = name.dropFirst(MonitorConfig.dietMeterEventPrefix.count).split(separator: ".")
            if let category = parts.first { recordDietStep(category: String(category)) }
            return
        }

        guard name == MonitorConfig.junkCapEvent else { return }

        // Cap reached → shield the selected junk apps for the rest of the day.
        guard
            let defaults = UserDefaults(suiteName: MonitorConfig.appGroup),
            let data = defaults.data(forKey: MonitorConfig.kSelectionData),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    /// Adds one meter-step of minutes to today's flagged-app total in the App
    /// Group. Thresholds are cumulative-per-day, so the Nth meter firing means
    /// N × step minutes have elapsed — we set the total to that value.
    private func recordUsageStep() {
        guard let defaults = UserDefaults(suiteName: MonitorConfig.appGroup) else { return }
        let key = MonitorConfig.dailyUsageKey(for: Date())
        let current = defaults.integer(forKey: key)
        defaults.set(current + MonitorConfig.usageMeterStepMinutes, forKey: key)
    }

    /// Adds one meter-step to today's total for a single nutrition class — feeds
    /// "Today's Mental Diet." Same cumulative-threshold model as the usage meter.
    private func recordDietStep(category: String) {
        guard let defaults = UserDefaults(suiteName: MonitorConfig.appGroup) else { return }
        let key = MonitorConfig.dailyCategoryUsageKey(for: Date(), category: category)
        let current = defaults.integer(forKey: key)
        defaults.set(current + MonitorConfig.usageMeterStepMinutes, forKey: key)
    }
}

// FamilyActivitySelection lives in FamilyControls; imported transitively via the
// capability. Declared import here for clarity in the extension target.
import FamilyControls
