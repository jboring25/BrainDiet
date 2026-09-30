import Foundation

// MARK: - BrainDiet ShieldAction extension — the fork's response (spec-v2.4).
//
// Handles the taps on the intercept. The design makes real life the EASY default:
//   • PRIMARY ("Protect this time") → close the feed. The user leaves to go live
//     the goal; we stamp the App Group so the app can reflect the armed intent.
//   • SECONDARY ("Not now") → defer (dismiss the shield UI). A quiet escape, never
//     a fight — friction, not a wall.
//
// GATED like the rest of the Family Controls stack. Runs out-of-process when the
// system presents the shield.
//
// IMPORTANT (Apple-side setup — see the deliverable checklist):
//   • Belongs to a ShieldAction app-extension target ("BrainDietShieldAction")
//     the USER creates in Xcode (extension point
//     com.apple.ManagedSettings.shield-action-service).
//   • Same Family Controls capability + App Group + entitlement + the
//     -D BRAINDIET_FAMILY_CONTROLS Swift flag as the app.
//   • REAL LIMIT (flagged): a shield-action extension cannot itself start a timed
//     DeviceActivity block; it records intent + closes, and the app arms/confirms
//     the protected block on next foreground. See the report.

#if canImport(ManagedSettings) && BRAINDIET_FAMILY_CONTROLS
import ManagedSettings

private enum ShieldActionKeys {
    static let suite         = "group.com.jackboring.braindiet.shared"
    static let lastProtectAt = "shield.lastProtectAt"
    static let junkStore     = "BrainDietJunk"
    static let cursor        = "shield.cursor"
}

// Mirrors InterceptPass in the app (separate target → duplicated on purpose,
// exactly like MonitorConfig and ShieldKeys). Keep the key strings identical.
private enum PassKeys {
    static let allowance = 3
    static let window    = 3 * 60.0
    static let day       = "pass.day"
    static let spent     = "pass.spent"
    static let expires   = "pass.expiresAt"

    static func todayKey(_ now: Date = Date()) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Spend one pass, or return false when the day's allowance is gone.
    static func spend() -> Bool {
        guard let d = UserDefaults(suiteName: ShieldActionKeys.suite) else { return false }
        let key = todayKey()
        if d.string(forKey: day) != key { d.set(key, forKey: day); d.set(0, forKey: spent) }
        let used = d.integer(forKey: spent)
        guard used < allowance else { return false }
        d.set(used + 1, forKey: spent)
        d.set(Date().addingTimeInterval(window).timeIntervalSince1970, forKey: expires)
        return true
    }
}

final class ShieldActionProvider: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // ⭐ THE PASS (2026-08-27). The only context where we can actually open
        // the door, because only here do we hold the token to un-shield. The
        // extension owns the same ManagedSettingsStore the app writes, so
        // removing this one token IS the door opening; `.defer` then dismisses
        // the shield UI onto an app that is no longer blocked.
        if action == .secondaryButtonPressed {
            guard PassKeys.spend() else {
                // Allowance gone. The config extension stops drawing the button
                // once that happens, so this is only reachable in a race —
                // never leave the user pressing a control that does nothing.
                completionHandler(.close)
                return
            }
            let store = ManagedSettingsStore(named: .init(ShieldActionKeys.junkStore))
            var apps = store.shield.applications ?? []
            apps.remove(application)
            store.shield.applications = apps.isEmpty ? nil : apps
            completionHandler(.defer)
            return
        }
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    // MARK: Choice → response.

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // Chose real life: stamp the intent, then leave the feed.
            let d = UserDefaults(suiteName: ShieldActionKeys.suite)
            d?.set(Date().timeIntervalSince1970, forKey: ShieldActionKeys.lastProtectAt)
            // Next interrupt speaks to the next goal. Re-assigning the same
            // shield set asks iOS to redraw it rather than reuse the last one.
            d?.set((d?.integer(forKey: ShieldActionKeys.cursor) ?? 0) + 1,
                   forKey: ShieldActionKeys.cursor)
            let store = ManagedSettingsStore(named: .init(ShieldActionKeys.junkStore))
            store.shield.applications = store.shield.applications
            return .close
        case .secondaryButtonPressed:
            // Only reachable for web/category shields, where there is no
            // application token to lift. Nothing to open, so close cleanly
            // rather than deferring onto a screen that is still blocked.
            return .close
        @unknown default:
            return .defer
        }
    }
}
#else
// ⭐ 2026-08-13. If you are reading this in a compiler error: the target is
// missing BRAINDIET_FAMILY_CONTROLS (or the SDK), which compiles this whole
// file to NOTHING and ships a signed, embedded, EMPTY .appex. iOS then cannot
// instantiate the principal class and silently falls back to its own grey
// shield — which is exactly what builds 12 and 13 did. Fix the flag; never
// delete this guard.
#error("BrainDiet shield extension built without BRAINDIET_FAMILY_CONTROLS — it would ship empty.")
#endif
