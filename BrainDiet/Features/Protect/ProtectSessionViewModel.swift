import SwiftUI

// MARK: - Protect session (spec-v2.3) — the owned action's engine.
//
// "Protect [time] for [goal]." Drives the idle ↔ active flip and a real-ticking
// wall-clock countdown. When blocking is authorized (entitled build), `start()`
// applies a REAL ManagedSettings shield over the user's selected apps and
// `end()/complete()` clears it; the BlockingService also arms a DeviceActivity
// daily cap from the plan so the junk cap is enforced out-of-process (survives
// backgrounding/kill).
//
// In degraded mode the shield calls are safe no-ops — the session UI still runs.
//
// This is the same shield mechanic as before, now REFRAMED as protection pointed
// at a goal (on-demand blocking + intention fused) and surfaced from Home.
//
// NOTE (backgrounding): the in-app countdown is foreground-only (wall-clock
// anchored, accurate on resume). The DURABLE enforcement is the DeviceActivity
// daily cap, not this timer — that's the piece that persists out-of-process.

@MainActor
@Observable
final class ProtectSessionViewModel {

    var state: ProtectState = .idle

    // Length selection (idle)
    var selectedLength: SessionLength = SessionLength.presets[1] // default 50m

    // Activity selection (idle) — the reclaimed time's destination. The plan STEP
    // is now the primary unit of action (spec-v2.6); selecting one sets the aimed
    // activity + tags. The activity grid remains as the "something else" hatch.
    var recommended: [Activity] = []
    var others: [Activity] = ActivityCatalog.all
    var selectedActivity: Activity = ActivityCatalog.all[0]

    // Plan-step selection (spec-v2.6). When a step is chosen, the started
    // ProtectSession is TAGGED with these so invested time is attributable to a goal.
    var selectedGoalID: UUID? = nil
    var selectedStepID: UUID? = nil
    /// The step's title, for the "Reclaim [X]m → [step]" CTA. Empty = "something else".
    var selectedStepTitle: String = ""
    /// The selected goal's identity line ("You're becoming a reader.") for the
    /// completion moment. Empty for off-plan blocks.
    var selectedGoalIdentityLine: String = ""

    /// Choose a plan step: tag the block, aim it at the goal's activity, and
    /// default the block length to the step's suggested minutes.
    func selectStep(_ step: GoalStep, in goal: Goal) {
        selectedGoalID = goal.id
        selectedStepID = step.id
        selectedStepTitle = step.title
        selectedGoalIdentityLine = goal.identityLine
        if let domain = ActivityDomain(rawValue: goal.domain),
           let activity = ActivityCatalog.activity(id: domain.activityID) {
            selectedActivity = activity
        }
        // The step's duration IS the session duration (Menu law, 2026-07-19).
        selectedLength = SessionLength.exact(step.suggestedMinutes)
    }

    /// The "something else" escape hatch: an untagged block aimed at a raw activity.
    func selectActivity(_ activity: Activity) {
        selectedActivity = activity
        selectedGoalID = nil
        selectedStepID = nil
        selectedStepTitle = ""
        selectedGoalIdentityLine = ""
    }

    // Rest day — set from the engine. Softens framing; doesn't block start.
    var isRestDay: Bool = false

    // Blocked apps — the user's actual selected junk apps (from the profile).
    var restingApps: [JunkAppOption] = Array(JunkAppOption.mock.prefix(3))

    // The imperative verb for the active screen's release line ("go read").
    // Tracks the selected activity.
    var goalAction: String { selectedActivity.verb }

    /// Records the committed {activity, duration, startedAt, goalID, stepID} to
    /// SwiftData and RETURNS the persisted record so an early end can reconcile
    /// its minutes to actual elapsed time. Injected by the view.
    var persistSession: ((_ activityID: String, _ minutes: Int, _ startedAt: Date, _ goalID: UUID?, _ stepID: UUID?) -> ProtectSession?)?
    /// Saves the model context after a reconciliation edit. Injected by the view.
    var saveContext: (() -> Void)?

    /// The just-persisted session for the running block (for reconciliation).
    private var activeSession: ProtectSession?

    // Blocking — injected so the session can shield for real when authorized.
    private weak var blocking: BlockingService?
    /// Plan junk cap (minutes) used to arm the durable daily schedule.
    private var junkCapMinutes: Int = 0

    /// True when the active session is really shielding (vs. simulated).
    var isReallyShielding: Bool { blocking?.isShielding ?? false }
    /// Whether real blocking is available at all (drives honest status copy).
    var blockingAvailable: Bool { blocking?.isAvailable ?? false }
    var blockingAuthorized: Bool { blocking?.isAuthorized ?? false }
    var blockingStatusLine: String { blocking?.statusLine ?? "" }

    /// Feed the VM real context from the engine + profile + blocking service.
    func configure(from ctx: EngineContext, blocking: BlockingService) {
        self.blocking = blocking
        // Rest day = the plan's weekly rest weekday (softens framing only).
        isRestDay = Calendar.current.component(.weekday, from: .now) == BrainPlan.Rules.restWeekday

        // Surface the user's REAL onboarding goals first; pre-select the headline
        // goal's activity for one-tap speed (spec-v2.5).
        let goalIDs = ctx.profile?.goalIDs ?? []
        recommended = ActivityCatalog.recommended(for: goalIDs)
        others = ActivityCatalog.others(excluding: recommended)
        // Keep any selection the user already made; otherwise pre-select.
        if !(recommended + others).contains(selectedActivity) {
            selectedActivity = ActivityCatalog.preselected(for: goalIDs)
        }

        junkCapMinutes = ctx.plan.junkCapMinutes
        if let profile = ctx.profile, !profile.junkAppIDs.isEmpty {
            restingApps = JunkAppOption.mock.filter { profile.junkAppIDs.contains($0.id) }
        }
        // Load the persisted selection so the shield knows what to block.
        blocking.loadSelection(
            encoded: ctx.profile?.familySelectionData,
            mockIDs: ctx.profile?.junkAppIDs ?? []
        )
        // Arm the durable daily cap from the plan (no-op unless authorized).
        blocking.armDailyCap(minutes: junkCapMinutes)
    }

    // MARK: Active-session timing (wall-clock anchored)

    /// When the active session is scheduled to end. Source of truth for the ring.
    private(set) var endDate: Date = .now
    /// Total seconds for the active session (for ring fraction).
    private(set) var totalSeconds: Int = 0
    /// Live remaining seconds, refreshed by the view's timer tick.
    private(set) var remainingSeconds: Int = 0

    /// 0...1 elapsed fraction for the countdown ring.
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return min(max(elapsed / Double(totalSeconds), 0), 1)
    }

    var remainingDisplay: String {
        let s = max(remainingSeconds, 0)
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    /// Minutes remaining, rounded up — for the reframe + end-early copy.
    var remainingMinutes: Int { (max(remainingSeconds, 0) + 59) / 60 }

    // MARK: Lifecycle

    func start(reduceMotion: Bool) {
        let minutes = selectedLength.minutes
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        let startedAt = Date.now
        endDate = startedAt.addingTimeInterval(TimeInterval(totalSeconds))

        // KEYSTONE: record where this reclaimed time is going — a forward
        // intentional choice, persisted for Becoming's real invested hours,
        // tagged to the plan goal/step when one was chosen. We keep the handle
        // so an early end reconciles minutes to actual elapsed time.
        activeSession = persistSession?(selectedActivity.id, minutes, startedAt, selectedGoalID, selectedStepID)

        // Apply the REAL shield (no-op in degraded mode).
        blocking?.applyFocusShield()
        Log.app.info("Protect block started: \(self.selectedActivity.id, privacy: .public) for \(minutes, privacy: .public) min (shielding=\(self.isReallyShielding, privacy: .public))")

        let go = { self.state = .active }
        if reduceMotion { go() }
        else { withAnimation(Theme.Motion.snappy) { go() } }
    }

    /// Called on each timer tick while active. Recomputes from wall-clock so a
    /// brief foreground re-entry stays accurate.
    func tick() {
        guard state == .active else { return }
        remainingSeconds = max(Int(endDate.timeIntervalSinceNow.rounded(.up)), 0)
        if remainingSeconds == 0 { complete() }
    }

    // MARK: Completion moment — data the full-screen state reads

    /// The minutes the completed block actually ran (set on complete/end).
    private(set) var completedMinutes: Int = 0
    /// "You invested 50m in reading" — the completion headline.
    var completionHeadline: String {
        String(localized: "You invested \(completedMinutes)m in \(selectedActivity.gerund)")
    }
    /// "A SERVING OF READING · 50M" — the completion eyebrow (food voice).
    var completionEyebrow: String {
        String(localized: "A serving of \(selectedActivity.gerund) · \(completedMinutes)m")
            .uppercased(with: .current)
    }
    /// The identity line beneath — the plan goal's when tagged, else the activity's.
    var completionIdentityLine: String {
        selectedGoalIdentityLine.isEmpty ? selectedActivity.identityLine : selectedGoalIdentityLine
    }

    /// Early end: reconcile the persisted session's minutes to ACTUAL elapsed
    /// time (ceil to the minute, min 1), then return quietly to idle — the
    /// completion moment is reserved for a block that ran its course.
    func end(reduceMotion: Bool) {
        blocking?.clearFocusShield()
        let elapsedSeconds = max(0, totalSeconds - max(remainingSeconds, 0))
        let actualMinutes = max(1, Int((Double(elapsedSeconds) / 60).rounded(.up)))
        if let session = activeSession {
            session.minutes = actualMinutes
            saveContext?()
        }
        completedMinutes = actualMinutes
        activeSession = nil
        Log.app.info("Protect block ended early — reconciled to \(actualMinutes, privacy: .public)m")
        reset(reduceMotion: reduceMotion)
    }

    private func complete() {
        blocking?.clearFocusShield()
        completedMinutes = max(1, totalSeconds / 60)
        activeSession = nil
        Log.app.info("Protect block completed: \(self.completedMinutes, privacy: .public)m")
        withAnimation(Theme.Motion.smooth) { state = .completed }
        remainingSeconds = 0
    }

    /// The completion moment's single "Done" → back to idle.
    func acknowledgeCompletion(reduceMotion: Bool) {
        reset(reduceMotion: reduceMotion)
    }

    #if DEBUG
    /// Screenshot helper: jump straight to the completion moment.
    func debugEnterCompleted() {
        completedMinutes = 50
        state = .completed
    }

    /// Screenshot helper (`BD_SESSION_ACTIVE=1`): render the live active screen
    /// without persisting a session or arming the shield.
    func debugEnterActive() {
        totalSeconds = selectedLength.minutes * 60
        remainingSeconds = totalSeconds - 7 * 60   // mid-block, believable ring
        endDate = Date.now.addingTimeInterval(TimeInterval(remainingSeconds))
        state = .active
    }
    #endif

    private func reset(reduceMotion: Bool) {
        let go = { self.state = .idle }
        if reduceMotion { go() }
        else { withAnimation(Theme.Motion.snappy) { go() } }
        remainingSeconds = 0
        totalSeconds = 0
    }
}
