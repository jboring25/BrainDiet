import Foundation

// MARK: - DoItNowSession — one step, the whole phone locked for its time.
//
// Jack, 2026-10-08: "I want the do it now feature to be something that blocks
// every single app on the phone except for emergency messages which can be
// picked in onboarding. There should be an expected time to complete the task
// and if clicked on should lock the entire phone."
//
// Persisted in the App Group so the lock outlives the app: on relaunch a live
// session re-opens the lock screen, and an expired one that was never answered
// opens it on "Time's up. Did you do it?". Answering removes it.

struct DoItNowSession: Codable, Equatable, Sendable {
    let title: String
    /// ActivityDomain.rawValue, so "I did it" can rebuild the same serving the
    /// drag would have produced.
    let domainRaw: String
    let goalID: UUID?
    let stepID: UUID?
    let minutes: Int
    let startedAt: Date
    let endsAt: Date
    /// True only when the system shield was really applied. Copy never claims
    /// a lock that is not there.
    var shielded: Bool

    init(title: String, domainRaw: String, goalID: UUID?, stepID: UUID?,
         minutes: Int, startedAt: Date = .now, shielded: Bool = false) {
        self.title = title
        self.domainRaw = domainRaw
        self.goalID = goalID
        self.stepID = stepID
        self.minutes = max(1, minutes)
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        self.shielded = shielded
    }

    func isOver(_ now: Date = .now) -> Bool { now >= endsAt }

    func remaining(_ now: Date = .now) -> TimeInterval { max(0, endsAt.timeIntervalSince(now)) }

    /// 1 → 0 across the session.
    func fractionLeft(_ now: Date = .now) -> Double {
        let total = endsAt.timeIntervalSince(startedAt)
        guard total > 0 else { return 0 }
        return min(1, max(0, remaining(now) / total))
    }

    // MARK: App Group persistence

    private static var defaults: UserDefaults? { UserDefaults(suiteName: BlockingConfig.appGroup) }

    static func load() -> DoItNowSession? {
        guard let data = defaults?.data(forKey: BlockingConfig.kDoItNowSession) else { return nil }
        return try? JSONDecoder().decode(DoItNowSession.self, from: data)
    }

    /// Saves the session and, while it runs, the two plain keys the shield
    /// extension reads.
    func save() {
        guard let d = Self.defaults else { return }
        d.set(try? JSONEncoder().encode(self), forKey: BlockingConfig.kDoItNowSession)
        if isOver() {
            Self.clearShieldCopy()
        } else {
            d.set(endsAt.timeIntervalSince1970, forKey: BlockingConfig.kDoItNowEndsAt)
            d.set(title, forKey: BlockingConfig.kDoItNowTitle)
        }
    }

    /// The shield goes back to its normal words; the session itself survives
    /// for the time's-up question.
    static func clearShieldCopy() {
        defaults?.removeObject(forKey: BlockingConfig.kDoItNowEndsAt)
        defaults?.removeObject(forKey: BlockingConfig.kDoItNowTitle)
    }

    static func remove() {
        defaults?.removeObject(forKey: BlockingConfig.kDoItNowSession)
        clearShieldCopy()
    }
}
