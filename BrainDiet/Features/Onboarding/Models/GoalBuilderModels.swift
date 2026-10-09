import SwiftUI
import UIKit

// MARK: - ⭐ The guided goal builder (Jack approved 2026-10-09, design/goal-builder/mock4).
//
// Replaces domains → primaryDomain → goalWords → aspiration. The user pictures
// the person they want to be (scenes), then builds each goal as ONE sentence
// with up to three blanks, optionally takes a sharper AI version, and says why
// it matters. The finished sentence is that goal's `goalWords`, so PlanService
// and every downstream reader are unchanged.

/// "Picture the person you want to be" — the life-area group a scene sits in.
enum SceneGroup: CaseIterable, Identifiable, Sendable {
    case workSchool, bodyMind, growth, people

    var id: Self { self }

    var label: String {
        switch self {
        case .workSchool: return String(localized: "Work and school")
        case .bodyMind:   return String(localized: "Body and mind")
        case .growth:     return String(localized: "Growth")
        case .people:     return String(localized: "People")
        }
    }
}

/// One scene of the person a year from now. Copy is exact (mock4).
enum GoalScene: String, CaseIterable, Identifiable, Sendable {
    case launched, acing, wrote
    case strongest, calm, outside
    case readMonth, playSongs, makeThings, fluent
    case people

    var id: String { rawValue }

    var label: String {
        switch self {
        case .launched:   return String(localized: "I launched something people use")
        case .acing:      return String(localized: "I'm acing my classes without cramming")
        case .wrote:      return String(localized: "I finished something I wrote")
        case .strongest:  return String(localized: "I'm the strongest I've ever been")
        case .calm:       return String(localized: "I'm calm instead of wired")
        case .outside:    return String(localized: "I spend real time outside")
        case .readMonth:  return String(localized: "I read a book a month")
        case .playSongs:  return String(localized: "I can play songs start to finish")
        case .makeThings: return String(localized: "I make things I'm proud of")
        case .fluent:     return String(localized: "I'm fluent in another language")
        case .people:     return String(localized: "I have people I see every week")
        }
    }

    /// "launched something people use" — the label without its "I"/"I'm",
    /// for the "1 of 3 · …" chip.
    var shortLabel: String {
        for lead in ["I'm ", "I "] where label.hasPrefix(lead) {
            return String(label.dropFirst(lead.count))
        }
        return label
    }

    var domain: ActivityDomain {
        switch self {
        case .launched:   return .building
        case .acing:      return .learning
        case .wrote:      return .writing
        case .strongest:  return .fitness
        case .calm:       return .mindful
        case .outside:    return .outdoors
        case .readMonth:  return .reading
        case .playSongs:  return .music
        case .makeThings: return .creating
        case .fluent:     return .learning
        case .people:     return .social
        }
    }

    var group: SceneGroup {
        switch self {
        case .launched, .acing, .wrote:                     return .workSchool
        case .strongest, .calm, .outside:                   return .bodyMind
        case .readMonth, .playSongs, .makeThings, .fluent:  return .growth
        case .people:                                       return .people
        }
    }

    /// The scenes of a group in display order. "Acing my classes" leads Work
    /// and school when they said it gets them between classes.
    static func scenes(in group: SceneGroup, betweenClasses: Bool) -> [GoalScene] {
        let base = allCases.filter { $0.group == group }
        guard group == .workSchool, betweenClasses else { return base }
        return [.acing] + base.filter { $0 != .acing }
    }
}

// MARK: - Why it matters (goalWhy). Copy exact.

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

// MARK: - The sentence template (goalSentence).

/// One chip for a blank. `lead`/`trail` override the blank's default words
/// around the fill so every combination reads as English ("and have it live"
/// vs "and get 100 people using it").
struct BlankOption: Hashable, Sendable {
    let chip: String
    var fill: String? = nil
    var lead: String? = nil
    var trail: String? = nil
    /// What "Go get back to ___." says for this pick (first blank only).
    var short: String? = nil

    var fillText: String { fill ?? chip }
}

struct SentenceBlank: Sendable {
    /// "WHAT WOULD COUNT?"
    let prompt: String
    /// The faded word in the unfilled blank ("when").
    let placeholder: String
    var lead: String = " "
    var trail: String = ""
    let options: [BlankOption]
    var isWhen: Bool = false
}

/// What the user put in a blank.
enum BlankChoice: Equatable, Sendable {
    case option(Int)
    case typed(String)
}

/// One goal's in-progress sentence.
struct GoalDraft: Equatable, Sendable {
    var choices: [BlankChoice?]
    /// The blank the chips are answering. Nil once every blank is filled.
    var active: Int?

    init(blankCount: Int) {
        choices = Array(repeating: nil, count: blankCount)
        active = 0
    }

    init(choices: [BlankChoice?], active: Int?) {
        self.choices = choices
        self.active = active
    }

    var isComplete: Bool { choices.allSatisfy { $0 != nil } }
}

/// A rendered piece of the sentence card.
enum SentencePiece: Equatable {
    enum BlankState { case filled, current, future }
    case text(String)
    case blank(index: Int, text: String, state: BlankState)
}

struct SentenceTemplate: Sendable {
    let opening: String
    let blanks: [SentenceBlank]
    /// Domains whose first blank is a thing they own ("your app").
    let nounObject: Bool
    /// "Go get back to ___." when nothing more specific applies.
    let fallbackShort: String

    // MARK: Rendering

    private func parts(_ blank: SentenceBlank, _ choice: BlankChoice?) -> (lead: String, fill: String, trail: String)? {
        switch choice {
        case .option(let i)?:
            guard blank.options.indices.contains(i) else { return nil }
            let o = blank.options[i]
            return (o.lead ?? blank.lead, o.fillText, o.trail ?? blank.trail)
        case .typed(let raw)?:
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if blank.isWhen, Self.startsWithPreposition(t) { return (" ", t, "") }
            return (blank.lead, t, blank.trail)
        case nil:
            return nil
        }
    }

    private static func startsWithPreposition(_ s: String) -> Bool {
        let l = s.lowercased()
        return ["by ", "in ", "this ", "within ", "before ", "next ", "end of", "the end"].contains { l.hasPrefix($0) }
    }

    func pieces(for draft: GoalDraft) -> [SentencePiece] {
        var out: [SentencePiece] = [.text(opening)]
        for (i, blank) in blanks.enumerated() {
            let choice = draft.choices.indices.contains(i) ? draft.choices[i] : nil
            if let p = parts(blank, choice) {
                out.append(.text(p.lead))
                out.append(.blank(index: i, text: p.fill, state: draft.active == i ? .current : .filled))
                if !p.trail.isEmpty { out.append(.text(p.trail)) }
            } else {
                out.append(.text(blank.lead))
                out.append(.blank(index: i, text: blank.placeholder,
                                  state: draft.active == i ? .current : .future))
                if !blank.trail.isEmpty { out.append(.text(blank.trail)) }
            }
        }
        out.append(.text("."))
        return out
    }

    /// The finished sentence, or nil while a blank is open.
    func sentence(for draft: GoalDraft) -> String? {
        guard draft.isComplete else { return nil }
        var s = opening
        for (i, blank) in blanks.enumerated() {
            guard let p = parts(blank, draft.choices[i]) else { return nil }
            s += p.lead + p.fill + p.trail
        }
        return s + "."
    }

    /// "BrainDiet", "your app", "training" — what the shield sends them back to.
    func shortGoal(for draft: GoalDraft) -> String {
        guard let first = draft.choices.first ?? nil, let blank = blanks.first else { return fallbackShort }
        switch first {
        case .option(let i):
            guard blank.options.indices.contains(i) else { return fallbackShort }
            let o = blank.options[i]
            return o.short ?? (nounObject ? Self.yours(o.fillText) : fallbackShort)
        case .typed(let raw):
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return nounObject && !t.isEmpty ? Self.yours(t) : fallbackShort
        }
    }

    /// "my app" → "your app"; "a story" → "your story"; "BrainDiet" stays.
    static func yours(_ s: String) -> String {
        for lead in ["my ", "a ", "an ", "the ", "My ", "A ", "An ", "The "] where s.hasPrefix(lead) {
            return "your " + s.dropFirst(lead.count)
        }
        return s
    }
}

// MARK: - The templates, per domain (Jack's brief, 2026-10-09).

extension SentenceBlank {
    static let when = SentenceBlank(
        prompt: String(localized: "By when?"),
        placeholder: String(localized: "when"),
        lead: " by ",
        options: [
            BlankOption(chip: String(localized: "this month"), lead: " "),
            BlankOption(chip: String(localized: "this semester"), lead: " "),
            BlankOption(chip: String(localized: "by summer"), fill: String(localized: "summer")),
            BlankOption(chip: String(localized: "in a year"), fill: String(localized: "a year"), lead: " within "),
        ],
        isWhen: true)

    fileprivate static func what(_ prompt: String, _ placeholder: String, _ options: [BlankOption]) -> SentenceBlank {
        SentenceBlank(prompt: prompt, placeholder: placeholder, options: options)
    }
}

extension ActivityDomain {
    /// This goal's sentence. `scene` reorders the first blank so the
    /// language scene leads with "learn a language".
    func sentenceTemplate(for scene: GoalScene? = nil) -> SentenceTemplate {
        let whatCounts = String(localized: "What would count?")
        let what = String(localized: "what")
        switch self {
        case .building:
            return SentenceTemplate(
                opening: String(localized: "I want to launch"),
                blanks: [
                    .what(String(localized: "What are you launching?"), what, [
                        BlankOption(chip: String(localized: "my app")),
                        BlankOption(chip: String(localized: "a business")),
                        BlankOption(chip: String(localized: "a YouTube channel")),
                        BlankOption(chip: String(localized: "a podcast")),
                    ]),
                    SentenceBlank(prompt: whatCounts, placeholder: String(localized: "how many"),
                                  lead: " and get ", trail: " using it", options: [
                        BlankOption(chip: String(localized: "it's live"), fill: String(localized: "it live"),
                                    lead: " and have ", trail: ""),
                        BlankOption(chip: String(localized: "100 people")),
                        BlankOption(chip: String(localized: "first $100"), lead: " and make my ", trail: ""),
                        BlankOption(chip: String(localized: "first customer"), lead: " and land my ", trail: ""),
                    ]),
                    .when,
                ],
                nounObject: true, fallbackShort: String(localized: "building"))
        case .reading:
            return SentenceTemplate(
                opening: String(localized: "I want to read"),
                blanks: [
                    .what(String(localized: "How much?"), String(localized: "how much"), [
                        BlankOption(chip: String(localized: "12 books")),
                        BlankOption(chip: String(localized: "a book a month")),
                        BlankOption(chip: String(localized: "the books I own")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "your book"))
        case .fitness:
            return SentenceTemplate(
                opening: String(localized: "I want to"),
                blanks: [
                    .what(whatCounts, what, [
                        BlankOption(chip: String(localized: "get stronger")),
                        BlankOption(chip: String(localized: "run a 5k"), short: String(localized: "your running")),
                        BlankOption(chip: String(localized: "lose 10 pounds")),
                        BlankOption(chip: String(localized: "train 4 days a week")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "training"))
        case .learning:
            var options = [
                BlankOption(chip: String(localized: "ace my classes"), short: String(localized: "your classes")),
                BlankOption(chip: String(localized: "learn a language"), short: String(localized: "your language")),
                BlankOption(chip: String(localized: "learn to code"), short: String(localized: "your code")),
                BlankOption(chip: String(localized: "master one skill"), short: String(localized: "your skill")),
            ]
            if scene == .fluent { options.swapAt(0, 1) }
            return SentenceTemplate(
                opening: String(localized: "I want to"),
                blanks: [.what(whatCounts, what, options), .when],
                nounObject: false, fallbackShort: String(localized: "learning"))
        case .writing:
            return SentenceTemplate(
                opening: String(localized: "I want to finish"),
                blanks: [
                    .what(String(localized: "What are you finishing?"), what, [
                        BlankOption(chip: String(localized: "a story")),
                        BlankOption(chip: String(localized: "a screenplay")),
                        BlankOption(chip: String(localized: "my essays")),
                        BlankOption(chip: String(localized: "a journal habit"), short: String(localized: "your journal")),
                    ]),
                    .when,
                ],
                nounObject: true, fallbackShort: String(localized: "your writing"))
        case .music:
            return SentenceTemplate(
                opening: String(localized: "I want to play"),
                blanks: [
                    .what(whatCounts, what, [
                        BlankOption(chip: String(localized: "3 full songs")),
                        BlankOption(chip: String(localized: "a song for someone")),
                        BlankOption(chip: String(localized: "by ear")),
                        BlankOption(chip: String(localized: "every day")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "your music"))
        case .creating:
            return SentenceTemplate(
                opening: String(localized: "I want to make"),
                blanks: [
                    .what(String(localized: "What are you making?"), what, [
                        BlankOption(chip: String(localized: "a body of work"), short: String(localized: "your work")),
                        BlankOption(chip: String(localized: "a short film")),
                        BlankOption(chip: String(localized: "10 drawings"), short: String(localized: "your drawings")),
                        BlankOption(chip: String(localized: "something I sell"), short: String(localized: "what you're making")),
                    ]),
                    .when,
                ],
                nounObject: true, fallbackShort: String(localized: "your work"))
        case .mindful:
            return SentenceTemplate(
                opening: String(localized: "I want to be"),
                blanks: [
                    .what(whatCounts, what, [
                        BlankOption(chip: String(localized: "calmer")),
                        BlankOption(chip: String(localized: "present with people"), short: String(localized: "the people around you")),
                        BlankOption(chip: String(localized: "off my phone at night"), short: String(localized: "your night")),
                        BlankOption(chip: String(localized: "sleeping better"), short: String(localized: "bed")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "the present"))
        case .outdoors:
            return SentenceTemplate(
                opening: String(localized: "I want to"),
                blanks: [
                    .what(whatCounts, what, [
                        BlankOption(chip: String(localized: "walk every day")),
                        BlankOption(chip: String(localized: "hike once a month")),
                        BlankOption(chip: String(localized: "run outside")),
                        BlankOption(chip: String(localized: "get outside daily")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "the outdoors"))
        case .social:
            return SentenceTemplate(
                opening: String(localized: "I want to"),
                blanks: [
                    .what(whatCounts, what, [
                        BlankOption(chip: String(localized: "see friends weekly"), short: String(localized: "your friends")),
                        BlankOption(chip: String(localized: "meet new people"), short: String(localized: "people")),
                        BlankOption(chip: String(localized: "call family weekly"), short: String(localized: "your family")),
                        BlankOption(chip: String(localized: "host something monthly")),
                    ]),
                    .when,
                ],
                nounObject: false, fallbackShort: String(localized: "your people"))
        }
    }

    /// The domain hue taken dark enough to read as TEXT on white (mock4's
    /// building ink #3E6E96 from #7CA7CE: same hue, saturation ×1.47,
    /// brightness ×0.73). Derived, never a second hand-kept table.
    var builderInk: Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(min(1, s * 1.47)), brightness: Double(b * 0.73))
    }
}

// MARK: - Display helpers for a built sentence.

enum GoalSentenceText {
    /// "I want to launch my app and …." → "Launch my app and …" for surfaces
    /// that put the goal in a slot of their own (mirror, paywall, hero pills).
    static func display(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("i want to ") { s = String(s.dropFirst("i want to ".count)) }
        if s.hasSuffix(".") { s = String(s.dropLast()) }
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - The echo chip ("3h a day · feeling behind").

extension AfterFeeling {
    /// The short form the goalScenes echo chip carries. Nil for "fine".
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
