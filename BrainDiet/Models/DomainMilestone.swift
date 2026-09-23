import Foundation

// MARK: - DomainMilestone — ONE definition of "the first thing you finish".
//
// ⭐ 2026-08-18. Onboarding and Becoming were both projecting a milestone date,
// independently, with different math and DIFFERENT MILESTONES:
//
//   • Onboarding (`PlanProjection`): "At 35m a day, you'll finish your 10th
//     book by October 3" — the 10th book, sized to a 90-day horizon.
//   • Becoming (`BecomingViewModel.milestone`): "First book finished · 2 / 3 ·
//     August 29" — the FIRST book, sized by plan steps actually touched.
//
// So the app promised a tenth book in onboarding and then spent a month
// reporting progress toward a first one. A user who remembers the onboarding
// number finds the product contradicting itself, which is exactly the kind of
// invented-feeling number Becoming's own header rules out.
//
// This type is the single source both now read. Onboarding projects THIS
// milestone; Becoming reports progress toward THIS milestone and re-dates it
// from real behaviour. The promise and the payoff are the same sentence, and
// what changes between them is only the date — which is the point. The user
// watches a date they were given move because of what they did.

struct DomainMilestone: Equatable, Sendable {

    /// "First book finished" — the noun, identical on both surfaces.
    let title: String
    /// "your first book" — the possessive phrasing onboarding projects toward.
    let projectionPhrase: String
    /// Roughly what the milestone costs in protected minutes. Deliberately a
    /// round, defensible estimate rather than a precise claim: it sizes a
    /// forecast, and the forecast is restated as a projection, never a promise.
    let costMinutes: Int

    static func forDomain(_ domain: ActivityDomain) -> DomainMilestone {
        switch domain {
        case .reading:
            // ~5 hours of reading to finish a book (the estimate `PlanProjection`
            // has always used — kept so the numbers don't move under anyone).
            return .init(title: String(localized: "First book finished"),
                         projectionPhrase: String(localized: "finish your first book"),
                         costMinutes: 300)
        case .fitness:
            // Ten workouts at ~45 minutes.
            return .init(title: String(localized: "Ten workouts banked"),
                         projectionPhrase: String(localized: "bank your tenth workout"),
                         costMinutes: 450)
        case .music:
            return .init(title: String(localized: "First song learned"),
                         projectionPhrase: String(localized: "learn your first song"),
                         costMinutes: 360)
        case .building:
            return .init(title: String(localized: "First thing shipped"),
                         projectionPhrase: String(localized: "ship your first thing"),
                         costMinutes: 600)
        case .writing:
            return .init(title: String(localized: "First piece finished"),
                         projectionPhrase: String(localized: "finish your first piece"),
                         costMinutes: 420)
        case .learning:
            return .init(title: String(localized: "First course finished"),
                         projectionPhrase: String(localized: "finish your first course"),
                         costMinutes: 720)
        case .outdoors:
            return .init(title: String(localized: "First long trail"),
                         projectionPhrase: String(localized: "walk your first long trail"),
                         costMinutes: 300)
        case .creating:
            return .init(title: String(localized: "First thing made"),
                         projectionPhrase: String(localized: "make your first thing"),
                         costMinutes: 420)
        }
    }
}

extension ActivityDomain {
    /// The milestone this domain is working toward — shared by the onboarding
    /// projection and the Becoming screen.
    var milestone: DomainMilestone { DomainMilestone.forDomain(self) }
}
