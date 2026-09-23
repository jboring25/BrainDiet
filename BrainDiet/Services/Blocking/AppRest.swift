import Foundation

// MARK: - AppRest — which chosen apps are resting RIGHT NOW, and which are out.
//
// ⭐ WHAT THIS ADDS. Until now "blocked" was one switch for the whole selection:
// the shield was up or it was down. The Menu's Split Plate needs per-app state —
// tap an app to put it to rest, press-and-hold to take one back — so this holds
// the exception list.
//
// ⭐ THE DIRECTION OF FRICTION IS THE WHOLE POINT. Resting an app is free and
// immediate. Taking one back SPENDS A PASS and lasts `InterceptPass.windowMinutes`,
// after which it rests again on its own. Nobody has to remember to re-block it —
// which is the failure mode of every "unblock for 5 minutes" button ever shipped.
//
// ⭐ ONE LEDGER, NOT TWO. The count of passes still lives in `InterceptPass`,
// because the shield extension and the shield action both read it and a second
// counter would drift from the first within a day. This only records WHICH app a
// spent pass was spent on, and when that window closes.
//
// Lives in the App Group so the shield extension can honour the exception once
// the entitled build wires it up.

enum AppRest {

    private static let key = "rest.released"        // [appID: expiry epoch]

    private static var store: UserDefaults? {
        UserDefaults(suiteName: InterceptPass.suiteName)
    }

    // MARK: Reading

    /// The apps currently out, with their expiry — stale entries pruned on read.
    static func released(_ now: Date = .now) -> [String: Date] {
        guard let raw = store?.dictionary(forKey: key) as? [String: Double] else { return [:] }
        let live = raw.compactMapValues { epoch -> Date? in
            let d = Date(timeIntervalSince1970: epoch)
            return d > now ? d : nil
        }
        if live.count != raw.count { write(live) }      // prune on the way past
        return live
    }

    static func isReleased(_ appID: String, _ now: Date = .now) -> Bool {
        released(now)[appID] != nil
    }

    /// Seconds left on an app's window, or nil when it is resting.
    static func remaining(_ appID: String, _ now: Date = .now) -> TimeInterval? {
        guard let until = released(now)[appID] else { return nil }
        return max(0, until.timeIntervalSince(now))
    }

    // MARK: Writing

    /// Take one app back. Spends a pass; nil when none are left.
    @discardableResult
    static func release(_ appID: String, _ now: Date = .now) -> Date? {
        guard InterceptPass.remainingToday(now) > 0 else { return nil }
        guard let until = InterceptPass.spend(now) else { return nil }
        var live = released(now)
        live[appID] = until
        write(live)
        return until
    }

    /// Put one app back to rest early. Free — the pass is already spent, and
    /// charging again for stopping would punish the good direction.
    static func rest(_ appID: String, _ now: Date = .now) {
        var live = released(now)
        live[appID] = nil
        write(live)
        // The global window is what the shield extension reads; close it only
        // when nothing at all is out, or an untouched app would come back too.
        if live.isEmpty { InterceptPass.clearWindow() }
    }

    static func restAll() {
        write([:])
        InterceptPass.clearWindow()
    }

    private static func write(_ live: [String: Date]) {
        store?.set(live.mapValues { $0.timeIntervalSince1970 }, forKey: key)
    }
}
