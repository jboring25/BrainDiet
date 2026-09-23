import Foundation
import SwiftData

// MARK: - ProtectSession — the keystone record (spec-v2.5).
//
// Every time the user chooses an activity, picks a duration, and taps Protect, we
// persist {activity, duration, startedAt}. This is the truth of where reclaimed
// time went — captured via a FORWARD intentional choice, not backward manual
// logging. Becoming reads these to compute real invested hours per activity
// ("You've protected 12 hours for reading — you're becoming a reader").
//
// Honest by design: the app ENFORCES the block; it can't verify the activity
// happened. So everywhere this data surfaces we say time "protected / invested"
// for X — the strongest available signal, and a forward-looking one.
//
// Local-first (SwiftData), alongside UserProfile. One row per Protect session.

/// How a serving got onto the plate.
enum ProtectSessionSource: String, Codable, Sendable {
    /// The app held the block and we watched the clock run. Measured.
    case protected
    /// The user told us afterwards, by dragging it onto the plate. Real work,
    /// but our word for it is theirs — never mixed into a measured figure.
    case reported
}

@Model
final class ProtectSession {
    /// The chosen activity (ActivityCatalog id).
    var activityID: String
    /// The block length the user committed to, in minutes.
    var minutes: Int
    /// When the block started.
    var startedAt: Date
    /// The plan Goal this block was aimed at (spec-v2.6). Nil for "something else"
    /// blocks that aren't tied to a plan goal.
    var goalID: UUID?
    /// The specific GoalStep this block advances (spec-v2.6).
    var stepID: UUID?

    // MARK: - ⭐ WHERE THIS RECORD CAME FROM (2026-08-20)
    //
    // Jack: "as someone who can lock in for hours I do not check my phone during
    // that time. I only check at night while winding down and am not setting
    // timers or using sessions."
    //
    // That inverts the tracking model. Session-only capture records the people
    // who need a timer to focus and records NOTHING for the people already
    // focusing — the app was rewarding phone-opening and ignoring the three
    // hours somebody spent with the phone in another room. So work done
    // off-session is now dragged onto the plate and stored here too.
    //
    // ⚠️ The honesty law is intact and this field is what keeps it intact.
    // `Activity.swift` says "a FORWARD intentional choice, never backward manual
    // logging," and Becoming promises nothing is invented. The law is not "never
    // accept input" — it is NEVER PRESENT A CLAIM AS A MEASUREMENT. Becoming
    // already carries reclaimed (Screen Time) and invested (sessions) as two
    // separate numbers precisely because they are measured differently; a third,
    // labelled source is consistent with that, and an unlabelled one would not be.
    //
    // Stored raw with a default so existing rows migrate as `.protected` — every
    // session that existed before this field was one the app actually enforced.
    var sourceRaw: String = ProtectSessionSource.protected.rawValue

    var source: ProtectSessionSource {
        get { ProtectSessionSource(rawValue: sourceRaw) ?? .protected }
        set { sourceRaw = newValue.rawValue }
    }

    init(activityID: String, minutes: Int, startedAt: Date = .now, goalID: UUID? = nil,
         stepID: UUID? = nil, source: ProtectSessionSource = .protected) {
        self.activityID = activityID
        self.minutes = minutes
        self.startedAt = startedAt
        self.goalID = goalID
        self.stepID = stepID
        self.sourceRaw = source.rawValue
    }

    /// The resolved activity (nil if the id is unknown — e.g. a retired activity).
    var activity: Activity? { ActivityCatalog.activity(id: activityID) }
}
