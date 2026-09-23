import Foundation

// MARK: - InterceptPass — the limited way in (Jack, 2026-08-27).
//
// ⭐ WHAT THIS IS. Opal's escape hatch: when the shield stops you, you can still
// get into the app. Jack's two conditions — there has to be a wait, and there
// has to be a limit, "or we should save it as emergency."
//
// ⭐ THE PLATFORM CONSTRAINT, STATED PLAINLY. A ShieldConfiguration extension
// draws an icon, a title, a subtitle and up to two buttons. It cannot render a
// countdown, cannot animate, and cannot host a hold gesture — so Opal's literal
// five-second timer is not reproducible inside the shield. What IS enforceable
// is the scarcity: a hard daily count, and a pass that expires on its own. That
// is the honest version of the same idea, and it is strictly harder to abuse
// than a wait anyone can sit through.
//
// ⭐ WHY THE BUTTON DISAPPEARS INSTEAD OF REFUSING. Build 15, on device: "the
// button at the bottom that says Not now, I don't know why that's there, because
// when I click it, nothing happens." A shield action can only answer `.close` or
// `.defer`, so a button that declines is indistinguishable from a broken one.
// The rule that came out of that still holds: **never render a shield button
// that cannot do the thing it says.** So the pass button is only drawn while
// passes remain, and vanishes once they are spent.
//
// Lives in the App Group because three processes touch it: the app (shows the
// ledger, re-arms the shield), the ShieldConfiguration extension (decides
// whether to draw the button), and the ShieldAction extension (spends a pass).

public enum InterceptPass {

    /// Passes per day. Three is enough for a genuine emergency and few enough
    /// that spending one is a decision rather than a reflex.
    public static let dailyAllowance = 3

    /// How long a spent pass keeps the app open. Short on purpose: the point is
    /// to let someone answer a message, not to reopen the feed for an evening.
    public static let windowMinutes = 3

    public static let suiteName = "group.com.jackboring.braindiet.shared"

    private enum Keys {
        static let day     = "pass.day"          // yyyy-MM-dd of the current count
        static let spent   = "pass.spent"        // Int, passes used that day
        static let expires = "pass.expiresAt"    // TimeInterval, 0 when none open
    }

    private static var store: UserDefaults? { UserDefaults(suiteName: suiteName) }

    private static func todayKey(_ now: Date = .now) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Reading

    /// Passes already spent today. Rolls over on its own at midnight — the count
    /// is stored WITH its date rather than reset by a timer, so a process that
    /// only ever wakes inside a shield still sees the correct day.
    public static func spentToday(_ now: Date = .now) -> Int {
        guard let d = store, d.string(forKey: Keys.day) == todayKey(now) else { return 0 }
        return d.integer(forKey: Keys.spent)
    }

    public static func remainingToday(_ now: Date = .now) -> Int {
        max(0, dailyAllowance - spentToday(now))
    }

    /// True while a spent pass is still open.
    public static func isOpen(_ now: Date = .now) -> Bool {
        guard let d = store else { return false }
        let expiry = d.double(forKey: Keys.expires)
        return expiry > now.timeIntervalSince1970
    }

    public static var expiresAt: Date? {
        guard let d = store else { return nil }
        let t = d.double(forKey: Keys.expires)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    // MARK: Writing

    /// Spend one pass. Returns the moment the window closes, or nil when the
    /// allowance is gone — callers must treat nil as "do not open anything".
    @discardableResult
    public static func spend(_ now: Date = .now) -> Date? {
        guard let d = store else { return nil }
        let key = todayKey(now)
        if d.string(forKey: Keys.day) != key {
            d.set(key, forKey: Keys.day)
            d.set(0, forKey: Keys.spent)
        }
        let spent = d.integer(forKey: Keys.spent)
        guard spent < dailyAllowance else { return nil }
        d.set(spent + 1, forKey: Keys.spent)
        let expiry = now.addingTimeInterval(TimeInterval(windowMinutes * 60))
        d.set(expiry.timeIntervalSince1970, forKey: Keys.expires)
        return expiry
    }

    /// Close an open window (called by the app once it has re-armed the shield).
    public static func clearWindow() {
        store?.set(0.0, forKey: Keys.expires)
    }

    // MARK: Copy

    /// The shield button's label, or nil when no pass may be offered. Returning
    /// nil is the signal to draw NO secondary button at all.
    public static func buttonLabel(_ now: Date = .now) -> String? {
        let left = remainingToday(now)
        guard left > 0 else { return nil }
        return left == 1
            ? "Let me in · last pass today"
            : "Let me in · \(left) passes left"
    }
}
