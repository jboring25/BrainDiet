import SwiftUI

// MARK: - MacroGlyph — the custom traffic-light marker (REPLACES emoji 🟢🟡🔴).
//
// A small filled "plate dot": a warm-colored disc with a soft inner sheen and a
// thin darker rim, so it reads as a designed token, not a system emoji. One
// glyph, used identically across Plan label, Dashboard macros, Diary, Insights.

enum MacroKind {
    case nourishing, neutral, junk

    var color: Color {
        switch self {
        case .nourishing: return .bdNourish
        case .neutral:    return .bdNeutral
        case .junk:       return .bdJunk
        }
    }
    var label: String {
        switch self {
        case .nourishing: return String(localized: "Nourishing")
        case .neutral:    return String(localized: "Easygoing")
        case .junk:       return String(localized: "Mindless")
        }
    }
}
