import SwiftUI

// MARK: - AppCategory — the mental-nutrition class of an app (spec-v2.1).
//
// The heart of "Today's Mental Diet." Every monitored app is classified ONCE, at
// setup, into one of three nutrition classes — the same vocabulary as a food
// label. This is a one-time assignment with smart defaults, NEVER a daily log.
//
//   • nourishing — feeds your mind (reading, learning, language, long-form).
//   • leisure    — easygoing, fine in moderation (video, music, messaging).
//   • junk        — engineered to pull you in (short-form scroll, endless feeds).
//
// The three map onto the existing semantic data palette + MacroGlyph so the whole
// app speaks one visual language: emerald/nourish · amber/leisure · coral/junk.

enum AppCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case nourishing
    case leisure
    case junk

    var id: String { rawValue }

    /// The nutrition-label word (title-case for the panel).
    var label: String {
        switch self {
        case .nourishing: return String(localized: "Nourishing")
        case .leisure:    return String(localized: "Leisure")
        case .junk:       return String(localized: "Junk")
        }
    }

    /// A one-line human description used in the categorization setup step.
    var blurb: String {
        switch self {
        case .nourishing: return String(localized: "Feeds your mind")
        case .leisure:    return String(localized: "Fine in moderation")
        case .junk:       return String(localized: "Engineered to pull you in")
        }
    }

    /// Semantic color (color = meaning, like Apple Health rings).
    var color: Color {
        switch self {
        case .nourishing: return .bdEmerald   // the good input — the hero green
        case .leisure:    return .bdAmber
        case .junk:       return .bdCoral
        }
    }

    var softColor: Color {
        switch self {
        case .nourishing: return .bdEmeraldSoft
        case .leisure:    return .bdAmberSoft
        case .junk:       return .bdCoralSoft
        }
    }

    /// Bridges to the existing custom MacroGlyph (no literal emoji anywhere).
    var glyphKind: MacroKind {
        switch self {
        case .nourishing: return .nourishing
        case .leisure:    return .neutral
        case .junk:       return .junk
        }
    }

    /// Display order for the panel — nourishing first, junk last.
    var panelOrder: Int {
        switch self {
        case .nourishing: return 0
        case .leisure:    return 1
        case .junk:       return 2
        }
    }
}

// MARK: - Smart-default catalog
//
// The known-app defaults that make categorization a ONE-TAP confirm, not a chore.
// TikTok / Reels / Shorts → junk; YouTube / podcasts / music → leisure; Kindle /
// Duolingo / news-reading → nourishing. Unknown apps fall to leisure (the neutral
// middle) so we never wrongly shame an app we don't recognize.

enum AppCategoryCatalog {

    /// Smart default for a known app id (from JunkAppOption / onboarding catalog).
    static func defaultCategory(forAppID id: String) -> AppCategory {
        switch id {
        // Engineered short-form scroll.
        case "tiktok", "reels", "shorts", "snapchat":
            return .junk
        // Feed-based, endlessly scrollable — default junk, adjustable.
        case "instagram", "x", "reddit", "facebook":
            return .junk
        // Long-form / mixed video, music, messaging — easygoing.
        case "youtube", "netflix", "spotify", "podcasts", "music", "whatsapp", "messages", "twitch":
            return .leisure
        // Genuinely mind-feeding.
        case "kindle", "books", "duolingo", "audible", "news", "medium", "notion", "pocket":
            return .nourishing
        default:
            return .leisure
        }
    }
}
