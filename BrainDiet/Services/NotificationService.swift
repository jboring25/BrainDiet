import Foundation
import UserNotifications

// MARK: - NotificationService — two calm, identity-voiced nudges (v1.0).
//
// Permission is requested ONCE, right after the user's FIRST completed session
// (the win moment — they just felt the product work), never during onboarding.
//
//   (a) Daily plan nudge, 20:00 repeating — "Dinner for your brain: [step] · 25m?"
//   (b) Streak-save, 21:30 TONIGHT only if no session yet today — "Your brain
//       hasn't been fed today." Cancelled the moment a session starts,
//       re-evaluated on each app open.
//
// Voice: food + identity + invitation, never guilt.

enum NotificationService {

    private static let dailyNudgeID = "bd.notification.dailyNudge"
    private static let streakSaveID = "bd.notification.streakSave"
    private static let trialReminderID = "bd.notification.trialEndReminder"
    private static let didRequestKey = "bd.didRequestNotifications"

    /// Whether we've ever shown the system permission prompt.
    static var didRequest: Bool {
        UserDefaults.standard.bool(forKey: didRequestKey)
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Ask for permission at the FIRST completed session (the win moment). On
    /// later calls it just reports the current authorization.
    @discardableResult
    static func requestPermissionAfterFirstWin() async -> Bool {
        guard !didRequest else { return await isAuthorized() }
        UserDefaults.standard.set(true, forKey: didRequestKey)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        Log.app.info("Notification permission requested after first win: granted=\(granted, privacy: .public)")
        return granted
    }

    // MARK: (a) Daily plan nudge — 20:00, repeating

    /// Schedules (replacing any previous) the 20:00 daily nudge pointed at the
    /// plan's next step. Call on app open + after sessions so the copy stays
    /// fresh. Always the plain forward nudge (the slop-voiced variant was removed
    /// 2026-07-23 — every surface speaks the one possibility voice).
    static func scheduleDailyPlanNudge(stepTitle: String, minutes: Int) async {
        guard await isAuthorized() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dinner for your brain")
        content.body = String(localized: "\(stepTitle) · \(minutes)m? The time is yours the moment you take it.")
        content.sound = .default

        var comps = DateComponents()
        comps.hour = 20
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: dailyNudgeID, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: (b) Streak-save — 21:30 tonight, only when no session yet today

    /// Re-evaluates tonight's streak-save: clears any pending one, then schedules
    /// a single 21:30 nudge for TODAY only when no session has happened yet.
    static func refreshStreakSave(hasSessionToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakSaveID])
        guard !hasSessionToday, await isAuthorized() else { return }

        let cal = Calendar.current
        guard let fire = cal.date(bySettingHour: 21, minute: 30, second: 0, of: .now),
              fire > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your brain hasn't been fed today")
        content.body = String(localized: "One small serving before bed? Even 25m counts.")
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: streakSaveID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// A session just started — tonight's streak is safe, drop the nudge.
    static func cancelStreakSave() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [streakSaveID])
    }

    // MARK: (c) Trial-end reminder — the honest pre-charge nudge (Jack 2026-07-22)

    /// Schedules the pre-trial-end reminder `daysBefore` the 7-day free trial
    /// ends — i.e. (trialDays − daysBefore) days from now. Requires
    /// authorization; no-ops when denied (the chooser still advances).
    /// Transparency wedge: the user is never surprised by the first charge.
    static func scheduleTrialEndReminder(daysBefore: Int) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [trialReminderID])

        let cal = Calendar.current
        let fireInDays = max(1, PaywallPricing.trialDays - daysBefore)
        guard let base = cal.date(byAdding: .day, value: fireInDays, to: .now),
              let fire = cal.date(bySettingHour: 11, minute: 0, second: 0, of: base),
              fire > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your free trial ends soon")
        content.body = daysBefore <= 1
            ? String(localized: "Your BrainDiet trial ends tomorrow. Keep your plan, or cancel in 2 taps. Your call.")
            : String(localized: "\(daysBefore) days left in your free trial. Keep your plan, or cancel in 2 taps. Your call.")
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: trialReminderID, content: content, trigger: trigger)
        try? await center.add(request)
        Log.app.info("Trial-end reminder scheduled \(daysBefore, privacy: .public)d before end")
    }
}
