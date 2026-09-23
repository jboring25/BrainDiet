import SwiftUI

// MARK: - App-level navigation state (spec-v2.5: three surfaces by mindset).
//
// Home · Protect · Becoming — each tab answers ONE question:
//   • Home     — "How am I doing today?"
//   • Protect  — "What do I want my reclaimed time to become right now?" (the
//                core behavioral action; restored to its own tab)
//   • Becoming — "Is my life actually changing?"
// Home's recommendation routes INTO Protect. See → Choose → Become.

@MainActor
@Observable
final class AppRouter {

    enum Tab: Hashable {
        case home
        case protect
        case becoming
    }

    var selectedTab: Tab = {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["BD_TAB"] {
        case "protect", "focus", "feed":     return .protect
        case "becoming", "journey", "growth": return .becoming
        default:                             return .home
        }
        #else
        return .home
        #endif
    }()

    /// Home's "Feed my brain" hand-off: the Plate Engine's suggested serving,
    /// consumed by the protection flow (select the step + start). Set by Home,
    /// cleared by ProtectTabView the moment it's applied.
    var pendingServing: PlateServing?

    /// The route-by-why triage flow (2026-07-23) — presented over Home from the
    /// "Reaching for a scroll?" entry card (and, in DEBUG, the intercept). Fully
    /// in-app, no Family Controls entitlement needed. MainView owns the cover.
    var showTriage = false

    /// ⭐ A serving the Menu wants reported. Home performs it, so the celebration
    /// and the brain-feed happen where the brain is — the user taps on the Menu
    /// and lands on Home watching it get eaten (Jack, 2026-09-13).
    var pendingReport: PlateDraggable?
}
