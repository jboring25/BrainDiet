import SwiftUI

// MARK: - BlockingService — app-wide blocking coordinator (Functional M2).
//
// The single object screens talk to. Picks the real or degraded gateway at
// launch, tracks authorization `mode`, holds the current selection, and exposes
// shield/schedule actions. Injected via the environment.
//
// Screens never import FamilyControls — they read `mode`, `selectionCount`,
// `isActive`, and call `authorize() / applyFocusShield() / armCap()`.

@MainActor
@Observable
final class BlockingService {

    private let gateway: ScreenTimeGateway

    /// The user's current selection (encoded real tokens and/or mock IDs).
    private(set) var selection: BlockingSelection = .empty

    /// Whether a Focus shield is currently applied (real or simulated).
    private(set) var isShielding = false

    init(gateway: ScreenTimeGateway? = nil) {
        // Default selection: real gateway only when the flag is set AND available.
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        self.gateway = gateway ?? RealScreenTimeGateway()
        #else
        self.gateway = gateway ?? DegradedScreenTimeGateway()
        #endif
        self.mode = self.gateway.mode
        // The system's real status lands after launch; route it into the mirror.
        self.gateway.onModeChange = { [weak self] in self?.refreshMode() }
    }

    // MARK: Surface for the UI

    /// ⭐ STORED, NOT COMPUTED — AND THAT IS THE WHOLE BUG (Jack, 2026-09-21:
    /// "the connect screen time to make this real button is not working").
    ///
    /// This used to be `var mode: BlockingMode { gateway.mode }`. `@Observable`
    /// only tracks THIS object's stored properties; a computed property reading
    /// a plain, non-observable class (`RealScreenTimeGateway`) is invisible to
    /// SwiftUI. So the sequence was:
    ///
    ///   tap → system sheet → user approves → `gateway.mode = .authorized`
    ///   → **no view in the app ever re-renders**
    ///
    /// The authorization genuinely succeeded and every screen kept rendering the
    /// un-authorized state, including the "Connect Screen Time" button itself —
    /// which is indistinguishable from a dead button, and is why the whole
    /// Family Controls stack has never been testable.
    ///
    /// Mirroring the gateway's state into a stored property is the fix. Anything
    /// that changes `gateway.mode` must now call `refreshMode()`.
    private(set) var mode: BlockingMode = .notDetermined
    /// True when real shielding can actually happen.
    ///
    /// ⚠️ Reads `mode`, the observable mirror — NEVER `gateway.mode`. Build 29
    /// fixed `mode` and left this line reading the gateway, so the Menu's
    /// "Connect Screen Time" button (which checks `isAuthorized`) stayed exactly
    /// as blind as before. Every derived property here must go through `mode`.
    var isAuthorized: Bool { mode == .authorized }
    /// Why the last authorization attempt failed, in words. Nil when it worked
    /// or has not been tried. Rendered under the connect button.
    private(set) var authorizationError: String?
    /// True when the real stack exists at all (entitled build).
    var isAvailable: Bool { gateway.isAvailable }

    /// A short, on-brand status line describing the current blocking state.
    var statusLine: String {
        switch mode {
        case .authorized:    return String(localized: "Your protection is running.")
        case .notDetermined: return String(localized: "Turn on protection to start reclaiming your time.")
        case .denied:        return String(localized: "Protection is off. Re-enable Screen Time access in Settings.")
        case .degraded:      return String(localized: "Protection unlocks once Screen Time access is available.")
        }
    }

    // MARK: Authorization

    func authorize() async {
        authorizationError = await gateway.requestAuthorization()
        refreshMode()
    }

    /// Pull the gateway's state into the observable mirror.
    ///
    /// Call after anything that can change authorization — including returning
    /// from the background, since the user can grant or revoke Screen Time
    /// access in Settings while the app is suspended and we would otherwise
    /// keep rendering a stale mode until relaunch.
    func refreshMode() {
        let current = gateway.mode
        if current != mode { mode = current }
    }

    // MARK: Selection

    func updateSelection(_ new: BlockingSelection) {
        selection = new
    }

    /// Load a persisted selection from the profile on launch/onboarding.
    func loadSelection(encoded: Data?, mockIDs: [String]) {
        selection = BlockingSelection(encoded: encoded, mockAppIDs: mockIDs)
    }

    /// Count of selected apps for the UI ("N apps shielded"). Falls back to the
    /// mock-ID count in degraded mode so the number is always honest-for-the-mode.
    var selectionCount: Int {
        if !selection.mockAppIDs.isEmpty { return selection.mockAppIDs.count }
        // Encoded token counts aren't decodable here without FamilyControls; the
        // real gateway exposes them when shielding. Use a sentinel: >0 if encoded.
        return selection.encoded == nil ? 0 : max(1, encodedAppCount)
    }
    /// Set by the real gateway when it decodes the selection (kept simple here).
    var encodedAppCount: Int = 0

    // MARK: Shield (Focus)

    func applyFocusShield() {
        guard isAuthorized else { isShielding = false; return }
        gateway.applyShield(selection)
        isShielding = true
    }

    func clearFocusShield() {
        gateway.clearShield()
        isShielding = false
    }

    // MARK: The standing junk shield (always on)

    /// True once the user has actually chosen apps to block. Everything below is
    /// a no-op without it — and until 2026-08-13 this was ALWAYS false, because
    /// nothing in the app ever presented the picker.
    var hasSelection: Bool { !selection.isEmpty }

    /// ⭐ Arm the always-on shield (2026-08-13). Safe to call repeatedly — the
    /// gateway rewrites the same token set — so it can run on every launch and
    /// every foreground without tracking whether it's already armed.
    /// ⭐ Re-apply the standing shield leaving out whatever the user has taken
    /// back (see `AppRest`). Called every time an app is rested or released, so
    /// the shield and the Menu can never disagree about which apps are out.
    func applyStandingShield(excluding releasedIDs: Set<String>) {
        guard hasSelection else { clearStandingShield(); return }
        guard !releasedIDs.isEmpty else { applyStandingShield(); return }
        var reduced = BlockingSelection(
            encoded: selection.encoded,
            mockAppIDs: selection.mockAppIDs.filter { !releasedIDs.contains($0) })
        #if canImport(FamilyControls) && BRAINDIET_FAMILY_CONTROLS
        reduced = RealScreenTimeGateway.removing(releasedIDs, from: reduced)
        #endif
        // Everything out at once is the same as no shield at all — say so
        // plainly rather than shipping an empty token set to the store.
        if reduced.isEmpty { clearStandingShield() } else { gateway.applyPersistentShield(reduced) }
    }

    func applyStandingShield() {
        guard isAuthorized, hasSelection else { return }
        gateway.applyPersistentShield(selection)
    }

    func clearStandingShield() {
        gateway.clearPersistentShield()
    }

    // MARK: Scheduled daily cap

    func armDailyCap(minutes: Int) {
        guard isAuthorized else { return }
        gateway.armDailyCap(minutes: minutes, selection: selection)
    }

    func disarmDailyCap() {
        guard isAuthorized else { return }
        gateway.disarmDailyCap()
    }
}
