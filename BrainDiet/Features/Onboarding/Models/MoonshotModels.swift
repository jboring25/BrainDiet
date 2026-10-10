import SwiftUI

// MARK: - ⭐ ONE MOONSHOT (Jack approved 2026-10-10, design/goal-builder/moon.png).
//
// "I need it to be 1 goal only... people need to dream big." Replaces the
// multi-goal builder (scenes → fill-in-the-blank sentence → sharpen → why per
// goal). The user types the biggest thing they would go after if they knew
// they wouldn't fail; the plan server turns it into a road of three dated
// milestones; they say why it matters. Exactly ONE goal from here on: its
// daily steps aim at the CURRENT milestone (the first one not done).
//
// Storage reuses the per-domain maps every downstream reader already knows:
// the single goal's domain keys `goalWords` (= the moonshot), `goalReasons`
// and `goalShorts`, so the mirror, paywall, hero chips and shield keep working.

/// One stop on the road. `by` is free text ("Nov 15"): the user edits it as
/// plain text, so it is never parsed into a date.
struct Milestone: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var by: String
    var done: Bool = false

    private enum CodingKeys: String, CodingKey { case title, by, done }

    init(title: String, by: String, done: Bool = false) {
        self.title = title
        self.by = by
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        by = (try? c.decode(String.self, forKey: .by)) ?? ""
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
    }

    var isBlank: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// JSON array, the wire and storage format.
    static func encode(_ list: [Milestone]) -> String {
        guard let data = try? JSONEncoder().encode(list) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ raw: String) -> [Milestone] {
        (try? JSONDecoder().decode([Milestone].self, from: Data(raw.utf8))) ?? []
    }
}

extension Array where Element == Milestone {
    /// The milestone the daily steps aim at: the first one not done.
    var current: Milestone? { first { !$0.done && !$0.isBlank } }
    /// Milestones with a title, in order (an empty fallback row is dropped).
    var filled: [Milestone] { filter { !$0.isBlank } }
}

/// The road call on moonshotRoad, keyed to the moonshot it was asked about so
/// an edited moonshot never shows a stale road.
enum RoadState: Equatable {
    case idle
    case loading(String)
    case ready(String)
    case failed(String)
}

/// "Run a sub-3 marathon" … the faded, non-tappable examples on moonshotWrite.
enum MoonshotExamples {
    static let lines: [String] = [
        String(localized: "Run a sub-3 marathon"),
        String(localized: "Publish a novel people can't put down"),
        String(localized: "Get into Stanford"),
        String(localized: "Start a company that hires my friends"),
    ]
    /// Continue unlocks at this many characters: a moonshot, not a word.
    static let minLength = 12
    static let maxLength = 140
}

// MARK: - Why it matters (moonshotWhy). Copy exact.

enum GoalReason: String, CaseIterable, Identifiable, Sendable {
    case prove, counting, years, tired

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prove:    return String(localized: "Prove it to myself")
        case .counting: return String(localized: "Someone's counting on me")
        case .years:    return String(localized: "I've wanted this for years")
        case .tired:    return String(localized: "Tired of watching others")
        }
    }

    /// The shield headline: "You wanted to prove it to yourself."
    var shieldWish: String {
        switch self {
        case .prove:    return String(localized: "You wanted to prove it to yourself.")
        case .counting: return String(localized: "You wanted to show up for them.")
        case .years:    return String(localized: "You wanted to stop waiting on this.")
        case .tired:    return String(localized: "You wanted to stop watching and start.")
        }
    }

    /// The first-person identity line anything that still reads `aspiration`
    /// gets (gerund, per `ActivityDomain.identityLine`).
    var aspiration: String {
        switch self {
        case .prove:    return String(localized: "Proving it to myself.")
        case .counting: return String(localized: "Showing up for the people counting on me.")
        case .years:    return String(localized: "Done waiting on what I've wanted for years.")
        case .tired:    return String(localized: "Doing it instead of watching.")
        }
    }
}

// MARK: - The shield's "Go get ___." line.

enum MoonshotShield {
    /// "Go get BrainDiet launched." from the server's short phrase; a quiet
    /// stock line when the road call never answered.
    static func goLine(short: String) -> String {
        let s = short.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? String(localized: "Go get your moonshot.") : String(localized: "Go get \(s).")
    }
}

extension ActivityDomain {
    /// "Go get back to ___." for legacy multi-goal profiles with no short.
    var shieldFallbackShort: String {
        switch self {
        case .building: return String(localized: "building")
        case .reading:  return String(localized: "your book")
        case .fitness:  return String(localized: "training")
        case .learning: return String(localized: "learning")
        case .writing:  return String(localized: "your writing")
        case .music:    return String(localized: "your music")
        case .creating: return String(localized: "your work")
        case .mindful:  return String(localized: "the present")
        case .outdoors: return String(localized: "the outdoors")
        case .social:   return String(localized: "your people")
        }
    }
}

// MARK: - Display helpers for a goal sentence.

enum GoalSentenceText {
    /// "I want to launch my app." → "Launch my app" for surfaces that put the
    /// goal in a slot of their own (mirror, paywall, hero pills).
    static func display(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("i want to ") { s = String(s.dropFirst("i want to ".count)) }
        if s.hasSuffix(".") { s = String(s.dropLast()) }
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - The echo chip ("3h a day · feeling behind").

extension AfterFeeling {
    /// The short form the moonshotWrite echo chip carries. Nil for "fine".
    var echo: String? {
        switch self {
        case .wasted:  return String(localized: "feeling it was wasted")
        case .behind:  return String(localized: "feeling behind")
        case .drained: return String(localized: "anxious after")
        case .numb:    return String(localized: "numb after")
        case .fine:    return nil
        }
    }
}

// MARK: - The plan holds exactly one goal: the moonshot.

enum MoonshotPlan {
    /// Keep the primary goal only and name it after the moonshot. Applied to
    /// every plan onboarding persists (server, on-device or heuristic), so a
    /// planner that still returns more than one goal can never put it back.
    static func focus(_ plan: GoalPlan, moonshot: String, short: String) -> GoalPlan {
        var p = plan
        let primary = p.goals.first(where: \.isPrimary) ?? p.goals.first
        p.goals = primary.map { [$0] } ?? []
        guard !p.goals.isEmpty else { return p }
        p.goals[0].isPrimary = true
        let m = moonshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !m.isEmpty { p.goals[0].title = GoalSentenceText.display(m) }
        return p
    }
}

extension Array where Element == Goal {
    /// ⭐ THE ONE GOAL: the primary (else the first by sort order), as a
    /// 0-or-1 element list. Every surface that serves steps reads through this,
    /// so a legacy multi-goal plan keeps its other goals on disk, unserved.
    var theOneGoal: [Goal] {
        Array(sorted { ($0.isPrimary ? 0 : 1, $0.sortIndex) < ($1.isPrimary ? 0 : 1, $1.sortIndex) }.prefix(1))
    }
}
