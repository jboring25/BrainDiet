import Foundation

// MARK: - Activity — what reclaimed time can BECOME (spec-v2.5).
//
// The Protect tab asks ONE question: "What do you want to become right now?"
// Activities are the answer — Read, Lift, Build, Study, Ride, Cook, Guitar…
// Choosing one, protecting a block, and leaving is the app's keystone action:
// a FORWARD intentional choice, never backward manual logging.
//
// Each activity carries the language Becoming reads back:
//   • `becoming` — the identity ("a reader") → "you're becoming a reader"
//   • `gerund`   — the noun form ("reading") → "12 hours protected for reading"
//   • `verb`     — the imperative ("read")   → "go read"
//   • `goalIDs`  — the onboarding goals this activity serves, so the user's REAL
//                  goals surface FIRST in the chooser for one-tap speed.
//
// The catalog is the single source of truth; ProtectSession stores only the id.

struct Activity: Identifiable, Hashable {
    let id: String
    let label: String        // chooser card title — "Read"
    let symbol: String       // SF Symbol (never emoji)
    let becoming: String     // identity — "a reader"
    let gerund: String       // "reading" (for "hours protected for reading")
    let verb: String         // imperative — "read" (for "go read")
    /// Onboarding goal ids this activity serves (surfaced first in the chooser).
    let goalIDs: Set<String>

    /// "Reading." — the gerund the catalog already carries. See the note on
    /// `ActivityDomain.identityLine` for why this is neither "You're becoming a
    /// reader." nor "I read."
    var identityLine: String {
        String(localized: "\(gerund.capitalized).")
    }
}

enum ActivityCatalog {

    /// The full catalog. Order here is the default "more activities" order.
    static let all: [Activity] = [
        .init(id: "read",     label: String(localized: "Read"),     symbol: "book.fill",
              becoming: String(localized: "a reader"),   gerund: String(localized: "reading"),
              verb: String(localized: "read"),           goalIDs: ["read"]),
        .init(id: "lift",     label: String(localized: "Lift"),     symbol: "dumbbell.fill",
              becoming: String(localized: "stronger"),   gerund: String(localized: "training"),
              verb: String(localized: "train"),          goalIDs: ["fitness"]),
        .init(id: "run",      label: String(localized: "Run"),      symbol: "figure.run",
              becoming: String(localized: "a runner"),   gerund: String(localized: "running"),
              verb: String(localized: "run"),            goalIDs: ["fitness"]),
        .init(id: "build",    label: String(localized: "Build"),    symbol: "hammer.fill",
              becoming: String(localized: "a builder"),  gerund: String(localized: "building"),
              verb: String(localized: "build"),          goalIDs: ["business", "money"]),
        .init(id: "study",    label: String(localized: "Study"),    symbol: "graduationcap.fill",
              becoming: String(localized: "sharper"),    gerund: String(localized: "studying"),
              verb: String(localized: "study"),          goalIDs: ["skill"]),
        .init(id: "create",   label: String(localized: "Create"),   symbol: "paintbrush.pointed.fill",
              becoming: String(localized: "a maker"),    gerund: String(localized: "creating"),
              verb: String(localized: "create"),         goalIDs: ["create"]),
        .init(id: "write",    label: String(localized: "Write"),    symbol: "square.and.pencil",
              becoming: String(localized: "a writer"),   gerund: String(localized: "writing"),
              verb: String(localized: "write"),          goalIDs: ["create"]),
        .init(id: "guitar",   label: String(localized: "Guitar"),   symbol: "guitars.fill",
              becoming: String(localized: "a musician"), gerund: String(localized: "playing"),
              verb: String(localized: "play"),           goalIDs: ["skill", "create"]),
        .init(id: "ride",     label: String(localized: "Ride"),     symbol: "bicycle",
              becoming: String(localized: "a rider"),    gerund: String(localized: "riding"),
              verb: String(localized: "ride"),           goalIDs: ["fitness"]),
        .init(id: "cook",     label: String(localized: "Cook"),     symbol: "fork.knife",
              becoming: String(localized: "someone who cooks"), gerund: String(localized: "cooking"),
              verb: String(localized: "cook"),           goalIDs: []),
        .init(id: "connect",  label: String(localized: "Connect"),  symbol: "person.2.fill",
              becoming: String(localized: "present for people"), gerund: String(localized: "connecting"),
              verb: String(localized: "be with people"), goalIDs: ["people"]),
        .init(id: "walk",     label: String(localized: "Walk"),     symbol: "figure.walk",
              becoming: String(localized: "someone who moves"), gerund: String(localized: "walking"),
              verb: String(localized: "walk"),           goalIDs: ["fitness", "sleep"]),
        .init(id: "meditate", label: String(localized: "Meditate"), symbol: "figure.mind.and.body",
              becoming: String(localized: "present"),    gerund: String(localized: "meditating"),
              verb: String(localized: "sit"),            goalIDs: ["sleep", "people"]),
        .init(id: "rest",     label: String(localized: "Rest"),     symbol: "moon.stars.fill",
              becoming: String(localized: "well-rested"),gerund: String(localized: "resting"),
              verb: String(localized: "rest"),           goalIDs: ["sleep"])
    ]

    private static let byID: [String: Activity] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func activity(id: String?) -> Activity? {
        guard let id else { return nil }
        return byID[id]
    }

    /// The activities that serve the user's onboarding goals — surfaced FIRST in
    /// the chooser, in the order the user ranked their goals (headline first).
    static func recommended(for goalIDs: [String]) -> [Activity] {
        var seen = Set<String>()
        var result: [Activity] = []
        for goal in goalIDs {
            for activity in all where activity.goalIDs.contains(goal) && !seen.contains(activity.id) {
                seen.insert(activity.id)
                result.append(activity)
            }
        }
        return result
    }

    /// Everything not already surfaced as a recommendation.
    static func others(excluding recommended: [Activity]) -> [Activity] {
        let ids = Set(recommended.map(\.id))
        return all.filter { !ids.contains($0.id) }
    }

    /// The pre-selected activity for the chooser: the headline goal's first
    /// matching activity, else the first activity overall (Read).
    static func preselected(for goalIDs: [String]) -> Activity {
        recommended(for: goalIDs).first ?? all[0]
    }
}
