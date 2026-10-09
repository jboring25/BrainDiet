import Foundation

// MARK: - DegradedScreenTimeGateway — manual-mode fallback.
//
// Used when the Family Controls capability/entitlement isn't present (simulator,
// un-entitled builds, denial). Every method is a safe no-op; the app runs fully
// in manual diary-logging mode. The UI shows honest "blocking unlocks once…"
// states rather than pretending to shield.

@MainActor
final class DegradedScreenTimeGateway: ScreenTimeGateway {
    var isAvailable: Bool { false }
    private(set) var mode: BlockingMode = .degraded
    var onModeChange: (() -> Void)?

    func requestAuthorization() async -> String? {
        // Nothing to authorize without the entitlement.
        mode = .degraded
        Log.app.info("Blocking: degraded mode (no Family Controls entitlement)")
        return String(localized: "This build can't use Screen Time.")
    }

    func presentPicker(current: BlockingSelection) async -> BlockingSelection? {
        // No system picker available — caller falls back to the mock app list.
        nil
    }

    func applyShield(_ selection: BlockingSelection) {
        Log.app.info("Blocking: applyShield no-op (degraded)")
    }
    func clearShield() {
        Log.app.info("Blocking: clearShield no-op (degraded)")
    }
    func applyPersistentShield(_ selection: BlockingSelection) {
        Log.app.info("Blocking: applyPersistentShield no-op (degraded)")
    }
    func clearPersistentShield() {
        Log.app.info("Blocking: clearPersistentShield no-op (degraded)")
    }
    func armDailyCap(minutes: Int, selection: BlockingSelection) {
        Log.app.info("Blocking: armDailyCap no-op (degraded)")
    }
    func disarmDailyCap() {
        Log.app.info("Blocking: disarmDailyCap no-op (degraded)")
    }
    func armFeedSchedule(_ window: FeedWindow, selection: BlockingSelection) {
        Log.app.info("Blocking: armFeedSchedule no-op (degraded)")
    }
    func startDoItNow(allow: BlockingSelection, endsAt: Date) {
        Log.app.info("Blocking: startDoItNow no-op (degraded)")
    }
    func endDoItNow() {
        Log.app.info("Blocking: endDoItNow no-op (degraded)")
    }
}
