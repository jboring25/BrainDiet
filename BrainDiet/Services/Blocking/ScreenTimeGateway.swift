import Foundation

// MARK: - ScreenTimeGateway — the boundary around Apple's Screen Time APIs.
//
// Everything FamilyControls / ManagedSettings / DeviceActivity is hidden behind
// this protocol so the rest of the app never imports those frameworks and never
// crashes when the entitlement isn't granted. Two implementations:
//
//   • RealScreenTimeGateway      — compiled ONLY when BRAINDIET_FAMILY_CONTROLS
//     is defined (set the flag once the Family Controls capability is added in
//     Xcode). Uses the real APIs.
//   • DegradedScreenTimeGateway  — the default. No-ops + "unavailable" so the
//     app runs fully in manual mode (simulator, un-entitled builds).
//
// `BlockingService` picks the right one at launch; screens talk only to it.

/// Authorization / capability state surfaced to the UI.
enum BlockingMode: Equatable {
    case degraded        // framework/entitlement unavailable — manual mode
    case notDetermined   // entitled, not yet asked
    case authorized      // good to go — real shielding active
    case denied          // user said no in Settings
}

/// Opaque, Codable handle to the user's chosen apps. In the real gateway this
/// wraps a FamilyActivitySelection; in degraded mode it carries the mock IDs so
/// the rest of the app keeps working identically.
struct BlockingSelection: Equatable {
    /// Encoded FamilyActivitySelection (real) — nil in degraded mode.
    var encoded: Data?
    /// Human-facing app IDs (mock list) for degraded-mode display + counts.
    var mockAppIDs: [String]

    var isEmpty: Bool { (encoded == nil) && mockAppIDs.isEmpty }
    static let empty = BlockingSelection(encoded: nil, mockAppIDs: [])
}

@MainActor
protocol ScreenTimeGateway: AnyObject {
    /// Whether the real Screen Time stack is even available (entitled build).
    var isAvailable: Bool { get }
    /// Current authorization state.
    var mode: BlockingMode { get }

    /// Called whenever `mode` changes for a reason the caller did not start —
    /// most importantly the system's own status arriving after launch. See
    /// `RealScreenTimeGateway.init` for why that is not optional.
    var onModeChange: (() -> Void)? { get set }

    /// Request individual authorization. Updates `mode`. No-op in degraded mode.
    /// Returns a reason a person can read when it FAILED, nil when it worked —
    /// a failure that only reaches the log is a failure nobody on a real device
    /// can ever see, which is how "the button does nothing" went undiagnosed.
    func requestAuthorization() async -> String?

    /// Present the system app picker, returning the user's selection.
    /// In degraded mode this is unsupported (the caller uses the mock list).
    func presentPicker(current: BlockingSelection) async -> BlockingSelection?

    /// Apply a shield over the selection (Focus session). No-op if unavailable.
    func applyShield(_ selection: BlockingSelection)

    /// ⭐ The ALWAYS-ON shield (2026-08-13). Separate from `applyShield`, which
    /// is scoped to a running protect session. This is what makes tapping a junk
    /// app show BrainDiet at any hour — the behaviour the product has always
    /// claimed ("Reaching for a scroll? Tap here first") and never had.
    func applyPersistentShield(_ selection: BlockingSelection)
    func clearPersistentShield()
    /// Clear the Focus-session shield.
    func clearShield()

    /// Arm the out-of-process daily junk-cap schedule (DeviceActivity).
    func armDailyCap(minutes: Int, selection: BlockingSelection)
    /// Disarm the daily cap schedule.
    func disarmDailyCap()
}
