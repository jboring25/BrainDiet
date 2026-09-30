import Foundation

// MARK: - The line under every serving (Jack, 2026-08-16).
//
// ⭐ WHY THIS EXISTS. The menu used to caption each row with "reading ·
// vegetables" — the domain plus a food word. That did two things wrong at once:
// it put the nutrition vocabulary on screen (banned 2026-08-14 — it is an asset
// naming convention, never a UI label), and it described the row's CATEGORY when
// the user needs a reason.
//
// So every serving now carries an argument instead of a classification. Not
// "what kind of thing is this" but "why is this worth ten minutes of your
// evening". Once every row has one, the menu stops listing tasks and starts
// making a case — which is the screen doing the product's job rather than just
// navigating to it.
//
// VOICE: short, plain, no em dashes, no hype, no shame. A true sentence a
// friend would say. Never promise an outcome the app cannot deliver.
//
// Lines are keyed by DOMAIN × COURSE rather than by step title, because titles
// are user-personalisable ("Make this mine") and a lookup on them would silently
// go blank the moment someone rewrote their own step.

enum MenuWhy {

    /// Which end of the menu a serving sits at. Mirrors `ProtectIdleView.MenuCourse`
    /// (quick < 20m · full 20–45m · main 50+) without depending on it, so this
    /// table stays readable on its own.
    enum Course {
        case quick, full, main

        static func forMinutes(_ m: Int) -> Course {
            if m < 20 { return .quick }
            if m <= 45 { return .full }
            return .main
        }
    }

    /// The reason this serving is worth doing. Falls back through course and then
    /// domain, so a personalised step or a new domain never renders an empty line.
    static func line(domain: ActivityDomain, minutes: Int) -> String {
        let course = Course.forMinutes(minutes)
        return specific[Key(domain: domain, course: course)]
            ?? generic[course]
            ?? String(localized: "Small and done still counts as done.")
    }

    private struct Key: Hashable {
        let domain: ActivityDomain
        let course: Course
    }

    // MARK: The table.
    //
    // QUICK lines argue against the activation cost — the reason people skip a
    // ten-minute thing is never the ten minutes, it is starting. FULL lines argue
    // for the depth you only reach with a runway. MAIN lines argue that the long
    // version is the one that actually moves anything.

    private static let specific: [Key: String] = [
        // Reading
        .init(domain: .reading, course: .quick):
            String(localized: "One decision tonight, so tomorrow doesn't need one."),
        .init(domain: .reading, course: .full):
            String(localized: "Long enough to fall back in."),
        .init(domain: .reading, course: .main):
            String(localized: "This is where a book stops being a thing you own."),

        // Fitness
        .init(domain: .fitness, course: .quick):
            String(localized: "The hard part of a workout is the first two minutes."),
        .init(domain: .fitness, course: .full):
            String(localized: "Short and real beats long and someday."),
        .init(domain: .fitness, course: .main):
            String(localized: "You have never once regretted finishing one of these."),

        // Building
        .init(domain: .building, course: .quick):
            String(localized: "An idea you don't write down is just an idea you had."),
        .init(domain: .building, course: .full):
            String(localized: "Small and shipped beats big and someday."),
        .init(domain: .building, course: .main):
            String(localized: "Long enough to get past the boring middle."),

        // Writing
        .init(domain: .writing, course: .quick):
            String(localized: "A bad first line still beats a blank page."),
        .init(domain: .writing, course: .full):
            String(localized: "Most of writing is just staying in the chair."),
        .init(domain: .writing, course: .main):
            String(localized: "This is the length where the real sentence shows up."),

        // Music
        .init(domain: .music, course: .quick):
            String(localized: "Ten minutes a day is how anyone got good at this."),
        .init(domain: .music, course: .full):
            String(localized: "Long enough to work the part you keep avoiding."),
        .init(domain: .music, course: .main):
            String(localized: "The session where it finally sounds like the record."),

        // Learning
        .init(domain: .learning, course: .quick):
            String(localized: "One thing understood today is one you keep."),
        .init(domain: .learning, course: .full):
            String(localized: "Long enough to get past the part that felt confusing."),
        .init(domain: .learning, course: .main):
            String(localized: "Depth is the only thing a feed can never give you."),

        // Outdoors
        .init(domain: .outdoors, course: .quick):
            String(localized: "Ten minutes outside changes the rest of the evening."),
        .init(domain: .outdoors, course: .full):
            String(localized: "No screen out there. That is the whole point."),
        .init(domain: .outdoors, course: .main):
            String(localized: "Far enough that the day stops following you."),

        // Creating
        .init(domain: .creating, course: .quick):
            String(localized: "Start it badly. That is allowed."),
        .init(domain: .creating, course: .full):
            String(localized: "Long enough to stop judging it and just make it."),
        .init(domain: .creating, course: .main):
            String(localized: "This is the stretch where something actually finishes."),

        // Social
        .init(domain: .social, course: .quick):
            String(localized: "One conversation is enough to change the day."),
        .init(domain: .social, course: .full):
            String(localized: "Long enough to get past small talk."),
        .init(domain: .social, course: .main):
            String(localized: "Real time with real people. A feed can't do this."),

        // Mindful
        .init(domain: .mindful, course: .quick):
            String(localized: "A few quiet minutes resets the whole afternoon."),
        .init(domain: .mindful, course: .full):
            String(localized: "Long enough for your head to go quiet."),
        .init(domain: .mindful, course: .main):
            String(localized: "Nothing to scroll. Just where you are.")
    ]

    private static let generic: [Course: String] = [
        .quick: String(localized: "Small and done still counts as done."),
        .full:  String(localized: "Long enough to properly get into it."),
        .main:  String(localized: "The version that actually moves something.")
    ]
}
