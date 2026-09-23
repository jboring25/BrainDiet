import Foundation

// MARK: - RealScreenTimeGateway — the real Screen Time integration.
//
// Compiled ONLY when BRAINDIET_FAMILY_CONTROLS is defined (set the flag after
// adding the Family Controls capability in Xcode and receiving the entitlement).
// Until then DegradedScreenTimeGateway is used and this file is excluded — so an
// un-entitled / simulator build is unaffected.
//
// Requires (Apple side — see the checklist in the deliverable):
//   • com.apple.developer.family-controls entitlement (granted by Apple)
//   • Family Controls capability on the app target
//   • App Group shared with the DeviceActivityMonitor extension
//   • The DeviceActivityMonitor extension target (BrainDietMonitor)

#if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class RealScreenTimeGateway: ScreenTimeGateway {

    var isAvailable: Bool { true }
    private(set) var mode: BlockingMode = .notDetermined

    private let center = AuthorizationCenter.shared
    private let focusStore = ManagedSettingsStore(named: .init(BlockingConfig.focusStoreName))
    /// The standing junk shield — its own store so a session ending can't clear it.
    private let junkStore = ManagedSettingsStore(named: .init(BlockingConfig.junkStoreName))
    private let activityCenter = DeviceActivityCenter()

    var onModeChange: (() -> Void)?
    private var statusSubscription: AnyCancellable?

    /// ⭐ LISTEN FOR THE STATUS — NEVER READ IT ONCE (Jack, 2026-09-21: "nothing
    /// pops up at all. I have seen it work before").
    ///
    /// `AuthorizationCenter.authorizationStatus` is filled in ASYNCHRONOUSLY. Read
    /// synchronously at launch it routinely reports `.notDetermined` for a user
    /// who approved weeks ago. This used to be a single `syncMode()` here and
    /// nothing else, so for anyone who had ever said yes:
    ///
    ///   launch → status read too early → `.notDetermined` → "Connect Screen Time"
    ///   → tap → iOS sees the existing approval → returns instantly, NO SHEET
    ///     (the system sheet is only ever shown once)
    ///   → and until build 29 the UI never re-rendered either
    ///
    /// A button that looks dead, on the one feature that has to work on stage.
    /// The publisher delivers the real value when it lands, and on every later
    /// change (a revoke in Settings, a grant from onboarding).
    init() {
        syncMode()
        statusSubscription = center.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let before = self.mode
                self.syncMode()
                if self.mode != before { self.onModeChange?() }
            }
    }

    /// ⭐ `.approvedWithDataAccess` IS APPROVED (2026-09-23). iOS 26 added a
    /// second approved state, for a grant that also allows reading detailed
    /// usage data. It was falling into `@unknown default` and being mapped to
    /// `.notDetermined` — so a user who HAD approved Screen Time read back as
    /// never having connected, and the connect button sat there looking dead.
    /// That is the exact symptom Jack reported on device.
    ///
    /// The `@unknown default` stays `.notDetermined` deliberately: a status this
    /// build has never seen must not be assumed to be a grant. But it now logs,
    /// because the silence is what let this one hide.
    private func syncMode() {
        switch center.authorizationStatus {
        case .notDetermined:          mode = .notDetermined
        case .approved:               mode = .authorized
        case .approvedWithDataAccess: mode = .authorized
        case .denied:                 mode = .denied
        @unknown default:
            Log.app.error("Blocking: UNKNOWN AuthorizationStatus \(String(describing: self.center.authorizationStatus), privacy: .public) — treating as notDetermined")
            mode = .notDetermined
        }
    }

    // MARK: Authorization

    func requestAuthorization() async -> String? {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            mode = .authorized
            Log.app.info("Blocking: authorization approved")
            return nil
        } catch {
            // Most commonly thrown when the entitlement isn't actually present
            // or the user declines.
            syncMode()
            if mode == .notDetermined { mode = .denied }
            Log.app.error("Blocking: authorization failed: \(String(describing: error), privacy: .public)")
            return Self.readable(error)
        }
    }

    /// What went wrong, in words someone holding the phone can act on. The raw
    /// case name stays in brackets so a single screenshot is enough to diagnose.
    private static func readable(_ error: Error) -> String {
        let raw = String(describing: error)
        let lower = raw.lowercased()
        let reason: String
        if lower.contains("cancel") {
            reason = String(localized: "The request was dismissed. Tap again and choose Continue.")
        } else if lower.contains("restricted") {
            reason = String(localized: "Screen Time is restricted on this phone. Check Settings ▸ Screen Time.")
        } else if lower.contains("passcode") || lower.contains("authenticationmethod") {
            reason = String(localized: "Screen Time needs a device passcode. Set one, then try again.")
        } else if lower.contains("network") {
            reason = String(localized: "Screen Time couldn't reach Apple. Check your connection.")
        } else if lower.contains("conflict") {
            reason = String(localized: "Another app is holding Screen Time access. Turn it off in Settings ▸ Screen Time.")
        } else {
            reason = String(localized: "Screen Time didn't connect.")
        }
        return "\(reason) [\(raw)]"
    }

    // MARK: Picker selection (encode/decode the FamilyActivitySelection)

    func presentPicker(current: BlockingSelection) async -> BlockingSelection? {
        // The picker itself is presented from SwiftUI (`.familyActivityPicker`).
        // This gateway only handles encoding; the view binds a selection and
        // calls `encode(_:)` on confirm. Returning nil here keeps the protocol
        // surface uniform — see FamilyPickerView for the real presentation.
        nil
    }

    /// Encode a live FamilyActivitySelection to our Codable BlockingSelection.
    static func encode(_ selection: FamilyActivitySelection) -> BlockingSelection {
        let data = try? JSONEncoder().encode(selection)
        return BlockingSelection(encoded: data, mockAppIDs: [])
    }

    /// Re-encode the selection WITHOUT the apps the user has taken back, so the
    /// standing shield can leave an exception open without forgetting the rest.
    /// Ids match `Tile.id` — the token's hashValue as a string — which is the
    /// only stable handle a token exposes.
    static func removing(_ ids: Set<String>, from selection: BlockingSelection) -> BlockingSelection {
        guard !ids.isEmpty else { return selection }
        var sel = decode(selection)
        sel.applicationTokens = sel.applicationTokens
            .filter { !ids.contains(String(describing: $0.hashValue)) }
        let data = try? JSONEncoder().encode(sel)
        return BlockingSelection(encoded: data, mockAppIDs: selection.mockAppIDs)
    }

    /// Decode our stored selection back into a FamilyActivitySelection.
    static func decode(_ selection: BlockingSelection) -> FamilyActivitySelection {
        guard let data = selection.encoded,
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return decoded
    }

    // MARK: Shield (Focus session — in-process while the app is foreground)

    func applyShield(_ selection: BlockingSelection) {
        let sel = Self.decode(selection)
        focusStore.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        focusStore.shield.applicationCategories = sel.categoryTokens.isEmpty
            ? nil
            : .specific(sel.categoryTokens)
        Log.app.info("Blocking: focus shield applied (\(sel.applicationTokens.count, privacy: .public) apps)")
    }

    func clearShield() {
        focusStore.shield.applications = nil
        focusStore.shield.applicationCategories = nil
        Log.app.info("Blocking: focus shield cleared")
    }

    // MARK: The standing junk shield (always on, survives sessions)

    /// ⭐ 2026-08-13. Also persists the selection into the App Group, because the
    /// ShieldConfiguration extension is a SEPARATE process that cannot see the
    /// app's memory — without this write the shield renders, but with the
    /// extension's fallback copy instead of the user's own goal.
    func applyPersistentShield(_ selection: BlockingSelection) {
        let sel = Self.decode(selection)
        guard !sel.applicationTokens.isEmpty || !sel.categoryTokens.isEmpty else {
            clearPersistentShield()
            return
        }
        junkStore.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        junkStore.shield.applicationCategories = sel.categoryTokens.isEmpty
            ? nil
            : .specific(sel.categoryTokens)
        if let defaults = UserDefaults(suiteName: BlockingConfig.appGroup) {
            defaults.set(selection.encoded, forKey: BlockingConfig.kSelectionData)
        }
        Log.app.info("Blocking: standing shield applied (\(sel.applicationTokens.count, privacy: .public) apps, \(sel.categoryTokens.count, privacy: .public) categories)")
    }

    func clearPersistentShield() {
        junkStore.shield.applications = nil
        junkStore.shield.applicationCategories = nil
        Log.app.info("Blocking: standing shield cleared")
    }

    // MARK: Scheduled daily junk cap (out-of-process via DeviceActivity)

    func armDailyCap(minutes: Int, selection: BlockingSelection) {
        // Persist selection + cap to the App Group so the extension can read them.
        if let defaults = UserDefaults(suiteName: BlockingConfig.appGroup) {
            defaults.set(selection.encoded, forKey: BlockingConfig.kSelectionData)
            defaults.set(minutes, forKey: BlockingConfig.kJunkCapMinutes)
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let apps = Self.decode(selection).applicationTokens
        let cats = Self.decode(selection).categoryTokens

        let event = DeviceActivityEvent(
            applications: apps,
            categories: cats,
            threshold: DateComponents(minute: max(1, minutes))
        )

        // AUTOMATIC USAGE METERS: a series of cumulative thresholds (step, 2×step,
        // 3×step, …). Each firing tells the extension another step of flagged-app
        // time has elapsed, so it can accrue today's total. This is the data feed
        // that makes reclaimed-time automatic (no manual logging).
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] =
            [.init(BlockingConfig.junkCapEvent): event]
        for i in 1...BlockingConfig.usageMeterSteps {
            let minutesAt = i * BlockingConfig.usageMeterStepMinutes
            events[.init("\(BlockingConfig.usageMeterEventPrefix)\(i)")] =
                DeviceActivityEvent(
                    applications: apps,
                    categories: cats,
                    threshold: DateComponents(minute: minutesAt)
                )
        }

        do {
            try activityCenter.startMonitoring(
                .init(BlockingConfig.dailyCapActivity),
                during: schedule,
                events: events
            )
            Log.app.info("Blocking: daily cap + usage meters armed at \(minutes, privacy: .public)m")
        } catch {
            Log.app.error("Blocking: armDailyCap failed: \(String(describing: error), privacy: .public)")
        }
    }

    func disarmDailyCap() {
        activityCenter.stopMonitoring([.init(BlockingConfig.dailyCapActivity)])
        Log.app.info("Blocking: daily cap disarmed")
    }
}
#endif
