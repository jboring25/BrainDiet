import Foundation

// MARK: - The shield → app hand-off (Jack, 2026-10-12, design/block-screen/).
//
// "Go to BrainDiet" on a shield stamps `face.pendingAt` (and the covered app's
// token) in the App Group and posts a notification. Tapping it, or simply
// opening the app soon after, shows the face screen. Taken once.

enum FaceRequest {
    /// How long a tap on the shield still means "show me my goal".
    static let window: TimeInterval = 10 * 60

    private static var defaults: UserDefaults? { UserDefaults(suiteName: BlockingConfig.appGroup) }

    /// True once per shield tap, inside the window.
    static func takePending(_ now: Date = .now) -> Bool {
        guard let d = defaults else { return false }
        let at = d.double(forKey: BlockingConfig.kFacePendingAt)
        guard at > 0 else { return false }
        d.removeObject(forKey: BlockingConfig.kFacePendingAt)
        return now.timeIntervalSince1970 - at < window
    }

    /// The app the shield was covering, if it was an app (not a site/category).
    static var token: Data? { defaults?.data(forKey: BlockingConfig.kFaceToken) }

    static func clearToken() { defaults?.removeObject(forKey: BlockingConfig.kFaceToken) }

    /// What the shield action reported when it tried to post the banner.
    static var lastNotifyStatus: String { defaults?.string(forKey: "face.notifyStatus") ?? "none" }
}

/// What the shield's "Feed my brain" starts. Mirrored in the shield action
/// extension (`NextStep`); keep the field names identical.
struct ShieldNextStep: Codable, Equatable {
    let title: String
    let domainRaw: String
    let goalID: UUID?
    let stepID: UUID?
    let minutes: Int

    init?(focus: TodaysFocus?) {
        guard let f = focus else { return nil }
        title = f.step.title
        domainRaw = f.domain.rawValue
        goalID = f.goal.id
        stepID = f.step.id
        minutes = f.step.suggestedMinutes
    }
}

extension Optional where Wrapped == ShieldNextStep {
    func write() {
        let d = UserDefaults(suiteName: BlockingConfig.appGroup)
        if let s = self { d?.set(try? JSONEncoder().encode(s), forKey: BlockingConfig.kShieldNextStep) }
        else { d?.removeObject(forKey: BlockingConfig.kShieldNextStep) }
    }
}
