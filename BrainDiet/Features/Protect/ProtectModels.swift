import Foundation

// MARK: - Protect session models (spec-v2.3).
//
// "Protect [time] for [goal]" — the app's ONE owned action. On-demand blocking
// fused with intention: the user locks a block of protected time aimed at a
// specific goal, then goes and lives it. Same shield/session mechanic as before,
// reframed and pointed at the goal.

/// Selectable block length — three honest presets, nothing mocked.
struct SessionLength: Identifiable, Hashable {
    let id: String
    let label: String
    let minutes: Int

    static let presets: [SessionLength] = [
        .init(id: "25", label: "25m", minutes: 25),
        .init(id: "50", label: "50m", minutes: 50),
        .init(id: "90", label: "90m", minutes: 90)
    ]

    /// The preset closest to a target length (used to honour a step's suggested
    /// minutes without a custom picker).
    static func nearestPreset(to minutes: Int) -> SessionLength {
        presets.min { abs($0.minutes - minutes) < abs($1.minutes - minutes) } ?? presets[1]
    }

    /// An exact length for a plan step — the step's duration IS the session
    /// duration (Menu rebuild 2026-07-19: the duration chips are gone).
    static func exact(_ minutes: Int) -> SessionLength {
        presets.first { $0.minutes == minutes }
            ?? SessionLength(id: "exact-\(minutes)", label: "\(minutes)m", minutes: minutes)
    }
}

/// The states the Reclaim flow moves between.
enum ProtectState {
    case idle
    case active
    /// The calm full-screen completion moment after a block runs its course.
    case completed
}
