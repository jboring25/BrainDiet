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
import DeviceActivity
import FamilyControls
import UserNotifications

// ⭐ TWO DOORS (Jack, 2026-10-12, design/block-screen/). Taken from Opal: the
// shield never lets you straight through. "Feed my brain" starts the step's
// Do it now lock right here; "Go to BrainDiet" sends a notification into the
// app (iOS gives a shield no way to open an app), where the goal is put in
// front of you and a pass can be spent. Passes are no longer on the shield.

private enum ShieldActionKeys {
    static let suite         = "group.com.jackboring.braindiet.shared"
    static let lastProtectAt = "shield.lastProtectAt"
    static let junkStore     = "BrainDietJunk"
    static let cursor        = "shield.cursor"
    // Mirrors BlockingConfig (separate target, duplicated on purpose).
    static let doItNowEndsAt = "doItNow.endsAt"
    static let doItNowTitle  = "doItNow.title"
    static let doItNowSession = "doItNow.session"
    static let doItNowStore  = "BrainDietDoItNow"
    static let doItNowActivity = "BrainDietDoItNow"
    static let allowSelection = "blocking.allowSelectionData"
    static let nextStep      = "shield.nextStep"
    static let facePendingAt = "face.pendingAt"
    static let faceToken     = "face.token"
}

/// Mirrors the app's `ShieldNextStep`.
private struct NextStep: Decodable {
    let title: String
    let domainRaw: String
    let goalID: UUID?
    let stepID: UUID?
    let minutes: Int
}

/// Mirrors the app's `DoItNowSession` field for field, so the app decodes it.
private struct LockSession: Encodable {
    let title: String
    let domainRaw: String
    let goalID: UUID?
    let stepID: UUID?
    let minutes: Int
    let startedAt: Date
    let endsAt: Date
    let shielded: Bool
}

final class ShieldActionProvider: ShieldActionDelegate {

    private var defaults: UserDefaults? { UserDefaults(suiteName: ShieldActionKeys.suite) }

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, token: try? JSONEncoder().encode(application), completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, token: nil, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, token: nil, completionHandler)
    }

    /// ⭐ BUILD 55 ON DEVICE: "Go to BrainDiet does not work." The response
    /// went back the instant the button was pressed, and iOS tears the
    /// extension down on `.close`, so the notification request (async) never
    /// landed. Now the response waits for the notification to be added.
    private func respond(_ action: ShieldAction, token: Data?,
                         _ done: @escaping (ShieldActionResponse) -> Void) {
        let d = defaults
        if (d?.double(forKey: ShieldActionKeys.doItNowEndsAt) ?? 0) > Date().timeIntervalSince1970 {
            done(.close)
            return
        }
        switch action {
        case .primaryButtonPressed:
            d?.set(Date().timeIntervalSince1970, forKey: ShieldActionKeys.lastProtectAt)
            rotateCopy()
            if startLock() { done(.close); return }
            markFacePending(token: token)
            notify(title: "Feed my brain",
                   body: "Tap to start your step. The timer starts when you open BrainDiet.") { done(.close) }
        case .secondaryButtonPressed:
            markFacePending(token: token)
            notify(title: "BrainDiet", body: "Your goal is waiting. Tap to open.") { done(.close) }
        @unknown default:
            done(.defer)
        }
    }

    // MARK: Feed my brain — the Do it now lock, started from the shield.

    /// Same lock the app starts: every app but the allow-list, a one-off
    /// interval so the monitor releases it. False = could not arm the release,
    /// so nothing is locked (a lock with no end would trap the phone).
    private func startLock() -> Bool {
        guard let d = defaults,
              let data = d.data(forKey: ShieldActionKeys.nextStep),
              let step = try? JSONDecoder().decode(NextStep.self, from: data)
        else { return false }
        let now = Date()
        let minutes = max(1, step.minutes)
        let ends = now.addingTimeInterval(TimeInterval(minutes * 60))

        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let start = min(now, ends.addingTimeInterval(-(15 * 60 + 30)))
        let activity = DeviceActivityName(ShieldActionKeys.doItNowActivity)
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])
        do {
            try center.startMonitoring(activity, during: DeviceActivitySchedule(
                intervalStart: cal.dateComponents(parts, from: start),
                intervalEnd: cal.dateComponents(parts, from: ends), repeats: false))
        } catch {
            return false
        }

        let session = LockSession(title: step.title, domainRaw: step.domainRaw, goalID: step.goalID,
                                  stepID: step.stepID, minutes: minutes, startedAt: now,
                                  endsAt: ends, shielded: true)
        d.set(try? JSONEncoder().encode(session), forKey: ShieldActionKeys.doItNowSession)
        d.set(ends.timeIntervalSince1970, forKey: ShieldActionKeys.doItNowEndsAt)
        d.set(step.title, forKey: ShieldActionKeys.doItNowTitle)

        let allowed = d.data(forKey: ShieldActionKeys.allowSelection)
            .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }?
            .applicationTokens ?? []
        let lock = ManagedSettingsStore(named: .init(ShieldActionKeys.doItNowStore))
        lock.shield.applicationCategories = .all(except: allowed)
        lock.shield.webDomainCategories = .all()
        return true
    }

    // MARK: Go to BrainDiet

    private func markFacePending(token: Data?) {
        defaults?.set(Date().timeIntervalSince1970, forKey: ShieldActionKeys.facePendingAt)
        if let token { defaults?.set(token, forKey: ShieldActionKeys.faceToken) }
        else { defaults?.removeObject(forKey: ShieldActionKeys.faceToken) }
    }

    /// Posts now, then calls `done` once iOS has the request (or after 2s).
    /// The outcome is written to the App Group so the app can log it.
    private func notify(title: String, body: String, done: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let lock = NSLock()
        var finished = false
        let finish = { (status: String) in
            lock.lock(); defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            self.defaults?.set(status, forKey: "face.notifyStatus")
            done()
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                finish("notAuthorized(\(settings.authorizationStatus.rawValue))")
                return
            }
            // A short trigger, not nil: a request added from a dying
            // extension with no trigger has been seen to drop.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            center.add(UNNotificationRequest(identifier: "bd.shield.face.\(Date().timeIntervalSince1970)",
                                             content: content, trigger: trigger)) { error in
                finish(error.map { "error: \($0.localizedDescription)" } ?? "ok")
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { finish("timeout") }
    }

    /// Next interrupt speaks the next line. Clearing first makes iOS redraw.
    private func rotateCopy() {
        let d = defaults
        d?.set((d?.integer(forKey: ShieldActionKeys.cursor) ?? 0) + 1, forKey: ShieldActionKeys.cursor)
        let store = ManagedSettingsStore(named: .init(ShieldActionKeys.junkStore))
        let apps = store.shield.applications
        store.shield.applications = nil
        store.shield.applications = apps
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
