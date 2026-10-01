import Foundation

// MARK: - ShieldContent — THE INTERCEPT copy, at the fork (spec-v2.4).
//
// "Make choosing real life easier than choosing the feed." When a rested app is
// opened, the OS default block is replaced by a custom Family Controls shield
// that IS the bridge: it names who the user wanted to become, hands them a short
// protected block, and makes the good choice the easy one.
//
// This value type is the single source of the shield's words + the suggested
// length. The app BUILDS it from the user's real goal (ShieldContentBuilder),
// uses it to render the in-app PREVIEW, and SYNCS the rendered strings into the
// App Group so the ShieldConfiguration extension can show them on a real device.
// It is Foundation-only + self-contained (its own App-Group keys) so it stays
// trivially portable; the extension reads the same keys with local constants.
//
// Never punitive, never "you're blocked" — it's "here's the better thing you
// already said you wanted."

struct ShieldContent: Equatable {

    /// Identity-first headline — "You wanted to become a reader."
    let headline: String
    /// The bridge — "Here's 20 minutes, protected. Go read."
    let body: String
    /// Primary, one-tap easy default — "Protect this time".
    let primary: String
    /// Quieter escape hatch — "Not now".
    let secondary: String
    // NOTE: no brand line — "Your brain eats too." lives ONLY on the cream
    // PlanShareCard (doctrine: in-app + shield surfaces carry no marketing copy).
    /// SF Symbol representing the goal (book.fill, figure.run, …).
    let symbol: String
    /// The protected block length the primary action offers, in minutes.
    let minutes: Int
    /// Headline goal id — lets the ShieldAction arm the right block.
    let goalID: String?
    /// ⭐ ONE LINE PER GOAL, ROTATED (Jack, 2026-09-30). The Shipaton video has
    /// the shield speak to a different goal at each interrupt — mindful on the
    /// couch, social on the train, strength outside the gym. The extension shows
    /// `variants[cursor % count]` and the action extension advances the cursor
    /// each time the user takes the primary choice. Empty = headline/body only.
    var variants: [Variant] = []

    struct Variant: Equatable {
        let headline: String
        let body: String
        let symbol: String
    }

    /// A safe, on-brand fallback used before the app has synced anything (or if
    /// the read fails) — still identity-framed, never a bare error.
    static let fallback = ShieldContent(
        headline: String(localized: "You wanted your time back."),
        body: String(localized: "There's still time today. Here's 20 minutes, protected. Go spend it on you."),
        primary: String(localized: "Feed my brain"),
        secondary: String(localized: "Not now"),
        symbol: "sparkles",
        minutes: 20,
        goalID: nil
    )
}

// MARK: - App-Group persistence (app writes · extension reads)

extension ShieldContent {

    /// The App-Group suite + keys. Self-contained so the extension can mirror them
    /// with local constants (the same intentional-duplication pattern as the
    /// DeviceActivityMonitor's MonitorConfig).
    enum Keys {
        static let suite     = "group.com.jackboring.braindiet.shared"
        static let headline  = "shield.headline"
        static let body      = "shield.body"
        static let primary   = "shield.primary"
        static let secondary = "shield.secondary"
        static let symbol    = "shield.symbol"
        static let minutes   = "shield.minutes"
        static let goalID    = "shield.goalID"
        static let variants  = "shield.variants"
    }

    /// Write the rendered shield strings into the shared App Group. No-ops safely
    /// when the group isn't configured (un-entitled / simulator build).
    func writeToAppGroup() {
        guard let d = UserDefaults(suiteName: Keys.suite) else { return }
        d.set(headline, forKey: Keys.headline)
        d.set(body, forKey: Keys.body)
        d.set(primary, forKey: Keys.primary)
        d.set(secondary, forKey: Keys.secondary)
        // Clear any brand line a previous build synced — the shield must not
        // carry marketing copy.
        d.removeObject(forKey: "shield.brandLine")
        d.set(symbol, forKey: Keys.symbol)
        d.set(minutes, forKey: Keys.minutes)
        d.set(goalID ?? "", forKey: Keys.goalID)
        if variants.isEmpty {
            d.removeObject(forKey: Keys.variants)
        } else {
            d.set(variants.map { ["headline": $0.headline, "body": $0.body, "symbol": $0.symbol] },
                  forKey: Keys.variants)
        }
    }
}

// MARK: - ShieldContentBuilder — build the intercept from the user's real goal.

enum ShieldContentBuilder {

    /// Compose the intercept copy for a headline goal + suggested block length.
    /// Pulls identity + action from the canonical GoalCatalog so the shield speaks
    /// in the user's own goal, never a generic block screen. Pass the plate's
    /// real serving counts and the body speaks the plate's TRUTH.
    ///
    /// ⭐ COPY LAW (the attraction law, Jack 2026-07-18): emotion = POSSIBILITY,
    /// never disappointment or criticism of the current choice. The body names
    /// what the user COULD have ("one serving away from complete"), never what
    /// they're reaching for ("this feed is gray mush" = banned pattern). The
    /// slop-voiced ("enough slop for today") variant was REMOVED 2026-07-23 —
    /// every surface now speaks the one possibility voice.
    static func make(
        goalID: String?,
        domains: [ActivityDomain] = [],
        minutes: Int = BlockingConfig.shieldSuggestedMinutes,
        servingsDone: Int = 0,
        servingsPlanned: Int = 3,
        suggestedCategory: PlateCategory? = nil
    ) -> ShieldContent {
        // ⭐ THE SHIELD SPEAKS IN ACTIONS, NOT FOOD (Jack, build 15 on device:
        // "the language is leaning too much into the food motif and actually
        // loses its meaning... it reads off as, what the fuck am I reading, it's
        // a bunch of food shit. It should be more about doing the action").
        //
        // He is right and the metaphor rule already said so: food language only
        // where it ADDS. It was not adding here, and in one branch it actively
        // BROKE the sentence — "\(minutes) minutes to \(action) plates the next
        // serving" rendered on his phone as "20 minutes to build plates the next
        // serving", which is not English. The metaphor had eaten the verb.
        //
        // The shield is also the worst possible surface for it. The user is
        // standing at a door they just tried to open, with about two seconds of
        // patience. It has to say what they wanted and what they could do right
        // now, in plain words. The plate lives in the app, where it has room.
        let action = GoalCatalog.action(for: goalID)   // "read", "train", "build"…
        let body: String
        if servingsPlanned > 0, servingsDone >= servingsPlanned {
            body = String(localized: "You've already done what you set out to do today. This time is yours.")
        } else if servingsPlanned - servingsDone == 1 {
            body = goalID == nil
                ? String(localized: "One more and today is done. \(minutes) minutes is enough.")
                : String(localized: "One more and today is done. \(minutes) minutes is enough for a real \(GoalCatalog.unit(for: goalID).singular).")
        } else if servingsDone == 0 {
            body = String(localized: "You haven't started yet today. \(minutes) minutes is enough to \(action).")
        } else {
            body = String(localized: "There's still time today. \(minutes) minutes is enough to \(action).")
        }
        // ⭐ THE VIDEO IS THE SPEC (Jack, 2026-09-30: "If I say the video has
        // this feature then make it a reality"). "You wanted to be social. Go
        // talk to a stranger." One wish, one thing to do right now, in words a
        // person would say. This supersedes the present-tense "You're a
        // reader." headline (2026-09-21) on the shield only.
        // Always the "Go" line, even once the day's steps are done: build 40
        // on device swapped in "You've already done what you set out to do
        // today" and the shield lost the one thing it is for.
        let variants = domains.map { d in
            ShieldContent.Variant(headline: d.shieldWish, body: d.shieldGo, symbol: d.symbol)
        }
        return ShieldContent(
            headline: variants.first?.headline ?? GoalCatalog.becameWish(for: goalID),
            body: variants.first?.body ?? body,
            // Serving-aware (PlateCategory.ctaTitle, the ONE source shared
            // with Home's card + the in-app preview): when the plate is
            // complete and the engine suggests dessert, the shield serves it.
            primary: (suggestedCategory ?? .learning).ctaTitle,
            secondary: String(localized: "Not now"),
            symbol: GoalCatalog.symbol(for: goalID),
            minutes: minutes,
            goalID: goalID,
            variants: variants
        )
    }
}

// MARK: - The shield's words, per goal.

extension ActivityDomain {

    /// "You wanted to" + "be social." — split so the in-app preview can set
    /// the goal in the accent color. `shieldWish` joins them for the shield.
    var shieldWishParts: (prefix: String, emphasis: String) {
        let lead = String(localized: "You wanted to")
        switch self {
        case .reading:  return (lead, String(localized: "read more."))
        case .fitness:  return (lead, String(localized: "get stronger."))
        case .music:    return (lead, String(localized: "play more."))
        case .building: return (lead, String(localized: "build something."))
        case .writing:  return (lead, String(localized: "write more."))
        case .learning: return (lead, String(localized: "keep learning."))
        case .outdoors: return (lead, String(localized: "get outside."))
        case .creating: return (lead, String(localized: "make things."))
        case .social:   return (lead, String(localized: "be social."))
        case .mindful:  return (lead, String(localized: "become more mindful."))
        }
    }

    var shieldWish: String { shieldWishParts.prefix + " " + shieldWishParts.emphasis }

    /// The one thing to do right now, doable from wherever the shield caught
    /// you — a train, a sidewalk, a desk.
    var shieldGo: String {
        switch self {
        case .reading:  return String(localized: "Go read ten pages.")
        case .fitness:  return String(localized: "Go touch some iron.")
        case .music:    return String(localized: "Go pick it up and play.")
        case .building: return String(localized: "Go get back to it.")
        case .writing:  return String(localized: "Go write one paragraph.")
        case .learning: return String(localized: "Go do one lesson.")
        case .outdoors: return String(localized: "Go take a walk.")
        case .creating: return String(localized: "Go make something small.")
        case .social:   return String(localized: "Go talk to a stranger.")
        case .mindful:  return String(localized: "Take your AirPods out. Look around.")
        }
    }
}
