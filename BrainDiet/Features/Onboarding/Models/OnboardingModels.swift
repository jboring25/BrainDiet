import Foundation
import SwiftUI

// MARK: - Onboarding step machine (Opal mapping pass, 2026-07-18).
//
// Six fast questions (mostly tap-to-select, one short free-text) become the raw
// material for a DERIVED goal plan (see GoalPlanner). Goals are no longer chosen
// live in the tab — they're generated once here and listed as an actionable plan.
//
// Structure follows the Jack-approved Opal mapping
// (~/Athena/projects/brain-diet-app/2026-07-18-opal-onboarding-mapping.md):
// questions → interstitial breath → Screen Time permission (at peak curiosity)
// → building ("reading your day") → mirror (loss THEN gain) → commit →
// reveal → ONE-screen paywall → trial-cancel reminder (ONLY if a trial really
// started) → first-serving win moment, which finishes straight into Home (the
// bridge step was deleted 2026-07-22 — the "Served." payoff IS the hand-off).
// Deliberately ABSENT (spec rows 3/6/10): age/segmentation
// questions and an account gate — no purpose, no backend, no invented numbers.

enum OnboardingStep: Int, CaseIterable, Comparable {
    case welcome         // 0 — hook
    case hijack          // 1 — what hijacks your attention (multi) → junk to cut
    /// ⭐ ONBOARDING V3 PAIN SWEEP (Jack approved 2026-10-09: "the pain points
    /// are still not being driven like they were in the video"). Problem first:
    /// the moment it gets you, how much, how it feels after, what already
    /// failed, and why it failed, all BEFORE any goal or solution is named.
    case whenItGets      // v3 — the moments (multi): wake, between classes, at the desk…
    case timeLost        // 2 — hours-a-day scrubber (Opal's self-quantification ask)
    case feelAfter       // v3 — how it feels after (single)
    case triedBefore     // v3 — failed fixes (multi)
    /// v3 — replaces the old `interstitial` beat (same layout): why the fixes
    /// they just named never stuck. Blocking frees the time; nothing fills it.
    case emptyTimeInsight
    case domains         // 3 — what to pour time into (multi) → goal seeds
    case primaryDomain   // 4 — which matters most (single) → primary anchor
    /// ⭐ ONBOARDING V2 (Jack approved 2026-10-08). The goal in the user's own
    /// words, one field per goal, REQUIRED. Replaces the object half of the
    /// retired `specifics` step: a noun ("Dune") told the planner what, never
    /// how far or by when. "Finish Dune, then read 12 books by next summer" does.
    case goalWords
    /// v2 — where they are with the primary goal today. Sizes the first step.
    case baseline
    case aspiration      // who are you becoming → identity raw material
    /// v2 — real minutes per day + the real shape of the day (wake, class or
    /// work, sleep) + the existing DayAnchor chips. Replaces the anchors half of
    /// the retired `specifics` step; the planner stops guessing when they are free.
    case timeAndDay
    /// v3 — the implementation-intention beat (Gollwitzer & Sheeran 2006), right
    /// after they describe their day: why every step hangs on a moment in it.
    case cueInsight
    case blocker         // 6 — what's stopped you (single) → step difficulty
    /// 8 — ⭐ SHOW THE MECHANIC BEFORE ASKING FOR THE KEYS (Jack, 2026-08-11,
    /// from his Opal teardown). Opal spends a whole screen on "Unblock apps when
    /// you need to · A short pause helps keep it intentional" — a headline, one
    /// line, and a phone showing the thing happening — and only THEN asks for
    /// Screen Time. We asked for the most invasive permission in the OS having
    /// never once shown what we do with it. Deliberately sits immediately before
    /// `screenAccess`; moving it later would defeat the entire point.
    case pause
    case screenAccess    // 9 — Screen Time permission: "your mirror needs to see the damage"
    /// 10 — ⭐ PICK THE APPS (Jack, 2026-08-13). The step that never existed:
    /// `FamilyPickerView` was written and never presented, so no selection was
    /// ever stored and NO APP WAS EVER SHIELDED on any build. Must come after
    /// `screenAccess` — the system picker returns empty without authorization —
    /// and is SKIPPED when access was denied (nothing to pick).
    case pickApps
    /// v2 — the "Do it now" allow-list and when the standing feed block runs.
    /// Collected and persisted only; enforcement is a later pass.
    case reachAndSchedule
    case building        // 9 — loading theater (runs the planner): "Reading your day…"
    case mirror          // 10 — THE MIRROR: loss in gray, then the GAIN in color
    case commit          // 11 — press-and-hold the plate to commit
    /// ⚠️ NOT ROUTED since onboarding v2 (2026-10-08): the plan is now served
    /// AFTER the paywall by `menuHero`. The case and view stay so nothing that
    /// references them breaks; `OnboardingViewModel.isRouted` skips it.
    case planReveal
    case onboardingPaywall // 13 — ONE-screen Pro paywall (soft close)
    /// 14 — the trial-cancel reminder. SKIPPED (Jack, 2026-07-22) unless the
    /// user actually STARTED A FREE TRIAL at the paywall — promising "before
    /// your free trial ends" to a monthly or free-tier user is a false promise.
    case dinnerBell
    /// v2 — the hero after the paywall (or its dismissal; nothing is gated):
    /// the user's words feed the brain while the plan is fetched, then the
    /// three steps are served out of it.
    case menuHero
    // ⭐ `firstServing` DELETED 2026-08-13 (Jack: "the plate moment happens
    // twice, remove the second one"). It and `commit` were the same beat with
    // different nouns — identical layout, identical empty plate, identical
    // drag-onto-it gesture, identical "or tap" fallback, four steps apart. The
    // commit step keeps the moment because it lands on the user's own identity
    // sentence, which is the stronger thing to plate. Onboarding now finishes
    // when the flow runs out of steps (see `advance()`), so the payoff is Home
    // itself rather than a second rehearsal of the same gesture.

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Steps that show the progress indicator (welcome/building/reveal are moments).
    /// ⭐ WHERE THE BAR IS DRAWN — a SUBSET of what it measures. See
    /// `countsTowardProgress` for why those are two different lists.
    ///
    /// `pause`, `screenAccess` and `pickApps` were added 2026-09-16: they are
    /// steps the user must act on, and they are the ones sitting between the
    /// old end-of-bar and the mirror. The payoff sequence that follows
    /// (mirror → commit → reveal → paywall) keeps its chrome-free staging —
    /// those are designed moments, and a back chevron does not belong on them.
    var showsProgress: Bool {
        switch self {
        case .hijack, .whenItGets, .timeLost, .feelAfter, .triedBefore,
             .domains, .primaryDomain, .goalWords, .baseline,
             .aspiration, .timeAndDay, .blocker,
             .pause, .screenAccess, .pickApps, .reachAndSchedule: return true
        default: return false
        }
    }

    /// ⭐ THE DENOMINATOR — every step the user must act through to reach the
    /// paywall. Deliberately LARGER than `showsProgress` (2026-09-16).
    ///
    /// These used to be the same list, and that is precisely how the bar came to
    /// lie: it measured itself against the seven steps it was drawn on, hit
    /// **100% at `.blocker`**, and then the user still had pause, Screen Time,
    /// app-picking, the mirror, the commit, the reveal and the paywall ahead of
    /// them. A bar that starts empty merely under-promises. A bar that fills
    /// completely and keeps going breaks a promise it already made — and it did
    /// it at the exact moment we turn around and ask for Screen Time access and
    /// money.
    ///
    /// Excluded are the four steps the user does not ACT on: the welcome hook,
    /// the held-breath interstitial, the loading theatre, and the post-purchase
    /// trial reminder.
    var countsTowardProgress: Bool {
        switch self {
        case .welcome, .emptyTimeInsight, .cueInsight, .building, .dinnerBell,
             .planReveal, .menuHero: return false
        default: return true
        }
    }

    /// 1-based position among the steps that count toward progress.
    var progressIndex: Int {
        OnboardingStep.allCases.filter(\.countsTowardProgress).firstIndex(of: self).map { $0 + 1 } ?? 0
    }

    static var progressTotal: Int {
        OnboardingStep.allCases.filter(\.countsTowardProgress).count
    }
}

// MARK: - Q1 · Attention hijackers — the junk to cut.

enum AttentionHijacker: String, CaseIterable, Identifiable, Sendable {
    // Case order = the gray-world grid order (appetite mockup, screen 2).
    case social, shortVideo, youtube, games, news, messaging

    var id: String { rawValue }

    var label: String {
        switch self {
        case .news:       return String(localized: "News spirals")
        case .social:     return String(localized: "Socials")
        case .shortVideo: return String(localized: "Scrolling")
        case .youtube:    return String(localized: "Binge-watching")
        case .games:      return String(localized: "Gaming")
        case .messaging:  return String(localized: "Group chats")
        }
    }

    /// The one-line caption under the tile — the pull, in plain words.
    var caption: String {
        switch self {
        case .social:     return String(localized: "one more swipe")
        case .shortVideo: return String(localized: "no bottom to it")
        case .youtube:    return String(localized: "one more episode")
        case .games:      return String(localized: "just one more round")
        case .news:       return String(localized: "doom scrolling")
        case .messaging:  return String(localized: "picking up the phone")
        }
    }

    var symbol: String {
        switch self {
        case .news:       return "newspaper.fill"
        case .social:     return "person.2.fill"
        case .shortVideo: return "play.rectangle.fill"
        case .youtube:    return "film.fill"
        case .games:      return "gamecontroller.fill"
        case .messaging:  return "bubble.left.and.bubble.right.fill"
        }
    }

    /// Color-coded tile hue — cooler + desaturated ("the feed you're setting aside").
    var tint: Color {
        switch self {
        case .news:       return .bdHijNews
        case .social:     return .bdHijSocial
        case .shortVideo: return .bdHijShortVideo
        case .youtube:    return .bdHijYoutube
        case .games:      return .bdHijGames
        case .messaging:  return .bdHijMessaging
        }
    }

    /// Representative junk-app IDs (JunkAppOption/AppCategoryCatalog) so the shield
    /// selection + Mental Diet categorisation keep working in degraded mode.
    var junkAppIDs: [String] {
        switch self {
        case .news:       return ["reddit", "x"]
        case .social:     return ["instagram"]
        case .shortVideo: return ["tiktok"]
        case .youtube:    return ["youtube"]
        case .games:      return []
        case .messaging:  return ["snapchat"]
        }
    }
}

// MARK: - v3 pain sweep (Jack approved 2026-10-09). Copy is exact; the raw
// values are the wire + storage format, never shown.

/// When does it get you? (multi, ≥ 1)
enum PullMoment: String, CaseIterable, Identifiable, Sendable {
    case wake, betweenClasses, sitDownToWork, waiting, withPeople, bedtime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wake:           return String(localized: "Right when I wake up")
        case .betweenClasses: return String(localized: "Between classes or meetings")
        case .sitDownToWork:  return String(localized: "When I sit down to work")
        case .waiting:        return String(localized: "When I'm waiting somewhere")
        case .withPeople:     return String(localized: "When I'm with people")
        case .bedtime:        return String(localized: "In bed at night")
        }
    }
}

/// How do you feel after? (single)
enum AfterFeeling: String, CaseIterable, Identifiable, Sendable {
    case wasted, behind, drained, numb, fine

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wasted:  return String(localized: "Like I wasted the time")
        case .behind:  return String(localized: "Behind on what I wanted to do")
        case .drained: return String(localized: "Anxious or drained")
        case .numb:    return String(localized: "Numb")
        case .fine:    return String(localized: "Honestly, fine")
        }
    }
}

/// What have you tried to stop it? (multi, ≥ 1). `nothing` is exclusive.
enum TriedFix: String, CaseIterable, Identifiable, Sendable {
    case screenTimeLimits, blockerApp, deletedApps, willpower, nothing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .screenTimeLimits: return String(localized: "Screen Time limits")
        case .blockerApp:       return String(localized: "A blocker app")
        case .deletedApps:      return String(localized: "Deleting the apps")
        case .willpower:        return String(localized: "Just willpower")
        case .nothing:          return String(localized: "Nothing yet")
        }
    }
}

// MARK: - Q2 · Time lost — reuse ShortFormBand (below) for baseline + step sizing.

// MARK: - Q3/Q4 · Activity domains — the goal seeds.
//
// Each domain maps to the existing Activity catalog + legacy goal keys, and carries
// the identity language + base step seeds the HeuristicGoalPlanner turns into a plan.

enum ActivityDomain: String, CaseIterable, Identifiable, Sendable {
    case reading, fitness, music, building, writing, learning, outdoors, creating, social, mindful

    var id: String { rawValue }

    /// Chip label (Q3/Q4).
    var label: String {
        switch self {
        case .reading:  return String(localized: "Reading")
        case .fitness:  return String(localized: "Fitness")
        case .music:    return String(localized: "Music")
        case .building: return String(localized: "Building")
        case .writing:  return String(localized: "Writing")
        case .learning: return String(localized: "Learning")
        case .outdoors: return String(localized: "Outdoors")
        case .creating: return String(localized: "Creating")
        case .social:   return String(localized: "Social")
        case .mindful:  return String(localized: "Mindful")
        }
    }

    var symbol: String {
        switch self {
        case .reading:  return "book.fill"
        case .fitness:  return "dumbbell.fill"
        case .music:    return "guitars.fill"
        case .building: return "hammer.fill"
        case .writing:  return "square.and.pencil"
        case .learning: return "graduationcap.fill"
        case .outdoors: return "figure.hiking"
        case .creating: return "paintbrush.pointed.fill"
        case .social:   return "person.2.fill"
        case .mindful:  return "figure.mind.and.body"
        }
    }

    /// Color-coded tile hue — VIBRANT ("your life in color"). One hue per domain.
    var tint: Color {
        switch self {
        case .reading:  return .bdDomReading
        case .fitness:  return .bdDomFitness
        case .music:    return .bdDomMusic
        case .building: return .bdDomBuilding
        case .writing:  return .bdDomWriting
        case .learning: return .bdDomLearning
        case .outdoors: return .bdDomOutdoors
        case .creating: return .bdDomCreating
        case .social:   return .bdDomSocial
        case .mindful:  return .bdDomMindful
        }
    }

    // MARK: Appetite category colors (⭐ the color LAW, 2026-07-18) — each
    // domain tile wears its plate-category color: leaf / salmon / berry —
    // derived from the plate engine, never a second hand-kept table.

    /// ⭐ THE DISPLAY CATEGORY (2026-07-22) — ONE source for everything a domain
    /// wears on screen: its color, its tint, its food word, and the dish art on
    /// the plan card. Before this, the color switch, the tint switch and the
    /// food-word switch were three hand-maintained lists and they DRIFTED
    /// (Building printed "protein" while Fitness printed "brain protein";
    /// Outdoors printed "fresh air", a word in no other surface's vocabulary).
    ///
    /// ⭐ RESOLVED 2026-07-22 (Athena ruling, Jack delegated): the display layer
    /// no longer keeps its own table. `PlateEngine.category(forDomain:)` is the
    /// single source of truth per PLATE-ENGINE.md ("no screen calculates these
    /// independently"), so DISPLAY DERIVES FROM THE ENGINE and the two can never
    /// drift again. The user must never be told a serving is one thing while
    /// completing it feeds another.
    ///
    /// This corrected two disagreements the old hand-maintained display table
    /// carried: OUTDOORS now reads focus / brain protein (was leaf / vegetables)
    /// and MUSIC now reads creativity / brain fruit (was honey / dessert — the
    /// appetite mockup's "music on the dessert shelf" is superseded). No domain
    /// maps to entertainment; dessert is earned by rest/leisure, not by a chosen
    /// growth domain.
    var displayCategory: PlateCategory { PlateEngine.category(forDomain: self) }

    /// The domain's category color (icon + selected border).
    var categoryColor: Color { displayCategory.ink }

    /// The tint wash behind a selected tile.
    var categoryTint: Color { displayCategory.wash }

    /// The category color as TEXT (honey drops to its contrast-safe ink).
    var categoryTextInk: Color { displayCategory.textInk }

    /// The food-language subtitle (appetite mockup, screen 3). Qualified food
    /// vocabulary ONLY — "brain vegetables / brain protein / brain fruit /
    /// dessert, guilt-free" — matching Home's plate card and the Menu rows.
    var foodSubtitle: String {
        switch displayCategory {
        case .learning:      return String(localized: "brain vegetables")
        case .focus:         return String(localized: "brain protein")
        case .creativity:    return String(localized: "brain fruit")
        case .entertainment: return String(localized: "dessert, guilt-free")
        case .emptyCalories: return ""
        }
    }

    /// The plan-row goal title.
    var goalTitle: String {
        switch self {
        case .reading:  return String(localized: "Read more")
        case .fitness:  return String(localized: "Get stronger")
        case .music:    return String(localized: "Play music")
        case .building: return String(localized: "Build something")
        case .writing:  return String(localized: "Write more")
        case .learning: return String(localized: "Keep learning")
        case .outdoors: return String(localized: "Get outside")
        case .creating: return String(localized: "Make things")
        case .social:   return String(localized: "Be more social")
        case .mindful:  return String(localized: "Be more mindful")
        }
    }

    /// "You're becoming a reader." — the identity this goal grows.
    // ⭐ THE GERUND, NOT A DECLARATION (Jack 2026-09-04).
    //
    // Two rejected versions are worth keeping in view, because the reason each
    // failed is different and the second one is easy to walk back into.
    //
    //   "You're becoming a reader."  — the app assigns a label, in the third
    //   person, about the user. Slop.
    //
    //   "I read every night."  — first person, per the identity research
    //   (Patrick & Hagtvedt 2012 on "I don't" vs "I can't"). Correct for a RULE
    //   the user sets, which is why "I don't scroll at night" works on the Menu.
    //   Wrong here: as a headline the app renders back at you it is a
    //   declaration, and on day one it claims something that is not yet true.
    //
    // The gerund is the resolution. "Reading every night." names what is
    // happening in the user's own chosen words, needs no pronoun, and over-claims
    // nothing — the evidence below the headline is what earns it.
    //
    // This is the FALLBACK. When the user picked an aspiration at onboarding,
    // `identityClaim(for:)` returns their own sentence instead.
    var identityLine: String {
        switch self {
        case .reading:  return String(localized: "Reading more.")
        case .fitness:  return String(localized: "Training.")
        case .music:    return String(localized: "Playing more.")
        case .building: return String(localized: "Building.")
        case .writing:  return String(localized: "Writing.")
        case .learning: return String(localized: "Learning on purpose.")
        case .outdoors: return String(localized: "Getting outside.")
        case .creating: return String(localized: "Making things.")
        case .social:   return String(localized: "Showing up for people.")
        case .mindful:  return String(localized: "Paying attention.")
        }
    }

    /// The THIRD-PERSON wording `aspirationOptions` used before 2026-09-04, in
    /// the same order. Profiles written before that date stored one of these
    /// verbatim, so without this map the Becoming header would render "Someone
    /// who reads every night." in a slot that is now first person. Migration
    /// bridge only — nothing new is ever written from here.
    var legacyAspirations: [String] {
        switch self {
        case .reading:
            return [String(localized: "Someone who reads every night."),
                    String(localized: "Someone who finishes what they start."),
                    String(localized: "Someone who's interesting to talk to."),
                    String(localized: "Someone who knows things worth knowing.")]
        case .fitness:
            return [String(localized: "Someone who trains, not someone who tries."),
                    String(localized: "Someone who keeps promises to their own body."),
                    String(localized: "Someone with the energy to show up."),
                    String(localized: "Someone who'll still be strong at 60.")]
        case .music:
            return [String(localized: "Someone who plays every day."),
                    String(localized: "Someone who finally got good at it."),
                    String(localized: "Someone people ask to play something."),
                    String(localized: "Someone who makes the sound in their head real.")]
        case .building:
            return [String(localized: "Someone who ships."),
                    String(localized: "Someone who finishes what they start."),
                    String(localized: "Someone whose ideas leave their head."),
                    String(localized: "Someone who built something people use.")]
        case .writing:
            return [String(localized: "Someone who writes every day."),
                    String(localized: "Someone who finished the thing."),
                    String(localized: "Someone who says what they mean."),
                    String(localized: "Someone whose words reached someone.")]
        case .learning:
            return [String(localized: "Someone who's always learning something."),
                    String(localized: "Someone who follows through on curiosity."),
                    String(localized: "Someone worth learning from."),
                    String(localized: "Someone who got genuinely good at one thing.")]
        case .outdoors:
            return [String(localized: "Someone who gets outside every day."),
                    String(localized: "Someone who chooses air over a screen."),
                    String(localized: "Someone who takes people with them."),
                    String(localized: "Someone who knows their own city on foot.")]
        case .creating:
            return [String(localized: "Someone who makes things."),
                    String(localized: "Someone who finishes what they start."),
                    String(localized: "Someone whose work makes people feel something."),
                    String(localized: "Someone who has a body of work.")]
        case .social, .mindful:
            // Added 2026-09-30, after the third-person wording was retired —
            // no profile ever stored a legacy sentence for these.
            return []
        }
    }

    /// The user's stored aspiration as a first-person claim. Returns it
    /// unchanged when it is one of the current options, translates it when it is
    /// one of the pre-2026-09-04 third-person ones, and nil when it is neither
    /// (free text, or an unrecognised profile) — the caller then falls back to
    /// `identityLine` rather than putting a sentence about the user in a slot
    /// where the user is speaking.
    func identityClaim(for aspiration: String) -> String? {
        let needle = aspiration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let same: (String) -> Bool = {
            $0.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let i = aspirationOptions.firstIndex(where: same) { return aspirationOptions[i] }
        if let i = legacyAspirations.firstIndex(where: same) { return aspirationOptions[i] }
        return nil
    }

    // MARK: - ⭐ ASPIRATION OPTIONS (2026-08-06) — the identity answer, as buttons.
    //
    // WHAT CHANGED. Q5 used to be a free-text box with four suggestion chips that
    // were IDENTICAL for everyone (domain tuning was deliberately dropped
    // 2026-07-20). So someone who had just answered "Fitness" on the previous
    // screen was offered "Someone who lives in the moment", and the text box
    // existed mainly to paper over that mismatch. Now the options are DERIVED
    // FROM THE DOMAIN they already picked, and the box is gone (Jack 2026-08-06:
    // "only buttons"). Longer, personal detail moved to a bounded surface that
    // does not block onboarding — see `UserProfile.dreamDetails`.
    //
    // ⭐ WHY FOUR, AND WHY THESE FOUR. Each option is anchored to a different
    // INTRINSIC aspiration domain, so whichever one gets tapped is real signal
    // about WHY this person wants the thing — not a style preference. Kasser &
    // Ryan's Aspiration Index (1996, PSPB 22(3)) factors life goals into seven
    // domains; the four intrinsic ones (growth, relationships, health,
    // community) predict wellbeing and the three extrinsic ones (wealth, fame,
    // image) do not. Two people both pick "Fitness" — one for health, one for
    // how they'll look — and the data says those go different places. All four
    // options here are intrinsic, deliberately.
    //
    // The four columns are held CONSTANT across domains so answers are
    // comparable between users:
    //   [0] MASTERY        — becoming genuinely good at the thing
    //   [1] SELF-RESPECT   — keeping the promise you made yourself
    //   [2] PRESENCE       — having something left over for other people
    //   [3] CONTRIBUTION   — the thing that outlasts the session
    //
    // ORDER IS FIXED, never shuffled: a rotating list makes the answer a
    // coin-flip instead of a choice.
    //
    // The tapped string flows into `OnboardingAnswers.aspiration` exactly as the
    // typed one did, and `HeuristicGoalPlanner.identityLine` ships it verbatim —
    // no downstream consumer changes. The later on-device-model pass slots in
    // behind this same interface: it replaces these four strings with four
    // personalised ones and nothing else moves.
    var aspirationOptions: [String] {
        switch self {
        case .reading:
            return [String(localized: "Reading every night."),
                    String(localized: "Finishing what I start."),
                    String(localized: "Being interesting to talk to."),
                    String(localized: "Knowing things worth knowing.")]
        case .fitness:
            return [String(localized: "Training, not trying."),
                    String(localized: "Keeping promises to my own body."),
                    String(localized: "Having the energy to show up."),
                    String(localized: "Still strong at 60.")]
        case .music:
            return [String(localized: "Playing every day."),
                    String(localized: "Finally getting good at it."),
                    String(localized: "Being the one people ask to play."),
                    String(localized: "Making the sound in my head real.")]
        case .building:
            return [String(localized: "Shipping."),
                    String(localized: "Finishing what I start."),
                    String(localized: "Getting ideas out of my head."),
                    String(localized: "Building something people use.")]
        case .writing:
            return [String(localized: "Writing every day."),
                    String(localized: "Finishing the thing."),
                    String(localized: "Saying what I mean."),
                    String(localized: "Reaching someone with my words.")]
        case .learning:
            return [String(localized: "Always learning something."),
                    String(localized: "Following through on curiosity."),
                    String(localized: "Being worth learning from."),
                    String(localized: "Getting genuinely good at one thing.")]
        case .outdoors:
            return [String(localized: "Getting outside every day."),
                    String(localized: "Choosing air over a screen."),
                    String(localized: "Taking people with me."),
                    String(localized: "Knowing my own city on foot.")]
        case .creating:
            return [String(localized: "Making things."),
                    String(localized: "Finishing what I start."),
                    String(localized: "Making something people feel."),
                    String(localized: "Building a body of work.")]
        case .social:
            return [String(localized: "Talking to anyone, anywhere."),
                    String(localized: "Saying yes when I'd rather hide."),
                    String(localized: "Being present with the people I'm with."),
                    String(localized: "Being someone people are glad they met.")]
        case .mindful:
            return [String(localized: "Noticing where I actually am."),
                    String(localized: "Keeping my attention for myself."),
                    String(localized: "Being fully there with people."),
                    String(localized: "Staying calm when it counts.")]
        }
    }

    /// v2 goalWords placeholder — an example of a SPECIFIC goal, never a mood.
    var goalPlaceholder: String {
        switch self {
        case .reading:  return String(localized: "e.g. finish Dune, then 12 books by summer")
        case .fitness:  return String(localized: "e.g. bench 225 by May, or run a 5k")
        case .music:    return String(localized: "e.g. play Blackbird all the way through")
        case .building: return String(localized: "e.g. launch my app and get 100 users")
        case .writing:  return String(localized: "e.g. finish a short story by December")
        case .learning: return String(localized: "e.g. hold a conversation in Spanish")
        case .outdoors: return String(localized: "e.g. hike every trail in the county")
        case .creating: return String(localized: "e.g. fill a sketchbook this semester")
        case .social:   return String(localized: "e.g. host one dinner a month")
        case .mindful:  return String(localized: "e.g. ten quiet minutes every morning")
        }
    }

    /// The Activity catalog id this domain protects time toward — keeps
    /// ProtectSession + Becoming's per-activity aggregation working.
    var activityID: String {
        switch self {
        case .reading:  return "read"
        case .fitness:  return "lift"
        case .music:    return "guitar"
        case .building: return "build"
        case .writing:  return "write"
        case .learning: return "study"
        case .outdoors: return "walk"
        case .creating: return "create"
        case .social:   return "connect"
        case .mindful:  return "meditate"
        }
    }

    /// Legacy goal key (GoalCatalog) for the reframe engine + shield copy.
    var legacyGoalID: String {
        switch self {
        case .reading:  return "read"
        case .fitness:  return "fitness"
        case .music:    return "skill"
        case .building: return "business"
        case .writing:  return "create"
        case .learning: return "skill"
        case .outdoors: return "fitness"
        case .creating: return "create"
        case .social:   return "people"
        case .mindful:  return "mindful"
        }
    }

    /// Base step seeds (title, kind). The planner sizes minutes + tailors the
    /// opener to the user's blocker. First seed is a concrete "do X once" starter.
    /// ⭐ THE CUE — the "if" half of an implementation intention, one per step seed
    /// (same order, same count). Gollwitzer & Sheeran's meta-analysis (2006, 94
    /// tests, N > 8,000) puts if-then plans at d = 0.65 on goal attainment, and the
    /// effect comes from naming WHEN and WHERE — not from the action being small.
    /// So every cue anchors to an EXISTING reliable daily event the user already
    /// performs (brushing teeth, closing the laptop), never to a clock time they'd
    /// have to remember. Phrased second-person and lowercase so it reads as the
    /// tail of a sentence: "Read a few pages · after you brush your teeth."
    var stepCues: [String] {
        switch self {
        case .reading:
            return [String(localized: "when you get home today"),
                    String(localized: "after you brush your teeth"),
                    String(localized: "once you're in bed")]
        case .fitness:
            return [String(localized: "before you shower tonight"),
                    String(localized: "when you close your laptop"),
                    String(localized: "after you change out of work clothes")]
        case .music:
            return [String(localized: "next time you walk past it"),
                    String(localized: "after you clear the table"),
                    String(localized: "when the dishes are done")]
        case .building:
            return [String(localized: "before you open anything else"),
                    String(localized: "when you sit down at your desk"),
                    String(localized: "after your first coffee")]
        case .writing:
            return [String(localized: "before you check your phone"),
                    String(localized: "with your first coffee"),
                    String(localized: "once the house goes quiet")]
        case .learning:
            return [String(localized: "when you finish reading this"),
                    String(localized: "after you eat lunch"),
                    String(localized: "when you sit down after dinner")]
        case .outdoors:
            return [String(localized: "before you sit down today"),
                    String(localized: "when you finish work"),
                    String(localized: "after breakfast")]
        case .creating:
            return [String(localized: "next time you're waiting on something"),
                    String(localized: "after you clear the table"),
                    String(localized: "when you'd normally open a feed")]
        case .social:
            return [String(localized: "when you walk into a room today"),
                    String(localized: "before you put your headphones in"),
                    String(localized: "when you're waiting in line")]
        case .mindful:
            return [String(localized: "when you sit down on the train"),
                    String(localized: "before you open your laptop"),
                    String(localized: "when you get into bed")]
        }
    }

    var stepSeeds: [(title: String, kind: GoalStepKind)] {
        switch self {
        case .reading:
            return [("Pick your next book", .oneoff),
                    ("Read a few pages", .recurring),
                    ("Finish a chapter", .recurring)]
        case .fitness:
            return [("Lay out your gym clothes", .oneoff),
                    ("Do a short workout", .recurring),
                    ("Train a full session", .recurring)]
        case .music:
            return [("Tune your instrument", .oneoff),
                    ("Practice one scale", .recurring),
                    ("Learn part of a song", .recurring)]
        case .building:
            return [("Write the idea down", .oneoff),
                    ("Ship one small piece", .recurring),
                    ("Do a focused build block", .recurring)]
        case .writing:
            return [("Open a blank page", .oneoff),
                    ("Write a paragraph", .recurring),
                    ("Draft for a while", .recurring)]
        case .learning:
            return [("Choose what to learn", .oneoff),
                    ("Do one lesson", .recurring),
                    ("Study a full session", .recurring)]
        case .outdoors:
            return [("Plan a route", .oneoff),
                    ("Take a short walk", .recurring),
                    ("Get a real session outside", .recurring)]
        case .creating:
            return [("Set out your materials", .oneoff),
                    ("Make something small", .recurring),
                    ("Do a real creative session", .recurring)]
        case .social:
            return [("Text someone you miss", .oneoff),
                    ("Start one conversation", .recurring),
                    ("Make plans with someone", .recurring)]
        case .mindful:
            return [("Take your AirPods out", .oneoff),
                    ("Sit with nothing for a few minutes", .recurring),
                    ("Take a walk without your phone", .recurring)]
        }
    }
}

// MARK: - Q6 · Blocker — tailors step difficulty + wording.

enum Blocker: String, CaseIterable, Identifiable, Sendable {
    case noTime, noEnergy, dontKnowStart, distracted

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noTime:        return String(localized: "No time")
        case .noEnergy:      return String(localized: "No energy")
        case .dontKnowStart: return String(localized: "Don't know where to start")
        case .distracted:    return String(localized: "I keep getting distracted")
        }
    }
}

// MARK: - v2 · Baseline — where they are with the primary goal today.

enum GoalBaseline: String, CaseIterable, Identifiable, Sendable {
    case notStarted, stalled, inconsistent, mostDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted:   return String(localized: "Haven't started")
        case .stalled:      return String(localized: "Started, then stalled")
        case .inconsistent: return String(localized: "Doing it, not consistently")
        case .mostDays:     return String(localized: "Doing it most days")
        }
    }

    /// One word for the hero chip ("stalled").
    var shortLabel: String {
        switch self {
        case .notStarted:   return String(localized: "not started")
        case .stalled:      return String(localized: "stalled")
        case .inconsistent: return String(localized: "on and off")
        case .mostDays:     return String(localized: "most days")
        }
    }
}

// MARK: - v2 · When the standing feed block runs.

enum FeedSchedule: String, CaseIterable, Identifiable, Sendable {
    case always, weekdays9to5, nights, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always:       return String(localized: "Always")
        case .weekdays9to5: return String(localized: "Weekdays 9–5")
        case .nights:       return String(localized: "Nights 10pm–8am")
        case .custom:       return String(localized: "Custom")
        }
    }
}

// MARK: - v2 · Clock helpers. Times are stored as minutes after midnight.

enum DayClock {
    /// "7:30", "12:30", "9:00".
    static func label(_ minutes: Int) -> String {
        let h = ((minutes / 60) % 12 == 0) ? 12 : (minutes / 60) % 12
        return String(format: "%d:%02d", h, minutes % 60)
    }

    /// A range without the zero minutes: "9 – 3", "8:30 – 4".
    static func rangeLabel(_ start: Int, _ end: Int) -> String {
        func short(_ m: Int) -> String { m % 60 == 0 ? "\(((m / 60) % 12 == 0) ? 12 : (m / 60) % 12)" : label(m) }
        return "\(short(start)) – \(short(end))"
    }

    /// "07:30" — the wire format PlanService sends.
    static func wire(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: (minutes / 60) % 24, minute: minutes % 60,
                              second: 0, of: .now) ?? .now
    }

    static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - OnboardingAnswers — the judged inputs the planner interprets.

struct OnboardingAnswers: Sendable {
    var hijackers: [AttentionHijacker]
    var timeLost: ShortFormBand
    var domains: [ActivityDomain]       // ordered; primary first when built
    var primaryDomain: ActivityDomain
    var aspiration: String
    var blocker: Blocker
    /// ⭐ 2026-08-06 — the user's own words about what they actually want, in a
    /// BOUNDED set (see `DreamDetails`). Empty for everyone who never opens the
    /// surface, and every consumer must treat it that way: this is enrichment
    /// for the on-device planner, never a required input.
    var dreamDetails: [String] = []
    /// ⭐ The anchors that actually happen in this person's day. Cues are
    /// attached to these instead of to a fixed per-domain guess — see
    /// `DayAnchor` and the note in OnDeviceGoalPlanner's prompt.
    var dailyAnchors: [String] = []

    // MARK: v2 (2026-10-08) — every field defaulted so older call sites compile.
    /// The goal in their words, per domain (the goalWords step).
    var goalWords: [ActivityDomain: String] = [:]
    var baseline: GoalBaseline? = nil
    /// "What's the next real piece?" — optional.
    var nextPiece: String = ""
    /// Honest minutes a day they can give it. Caps every step's length.
    var minutesPerDay: Int? = nil
    /// Minutes after midnight.
    var wakeMinutes: Int? = nil
    var busyStartMinutes: Int? = nil
    var busyEndMinutes: Int? = nil
    var sleepMinutes: Int? = nil

    // MARK: v3 pain sweep (2026-10-09).
    var whenItGets: [PullMoment] = []
    var feelAfter: AfterFeeling? = nil
    var triedBefore: [TriedFix] = []
}

// MARK: - ⭐ DayAnchor — the fixed points a cue can hang on (2026-09-15).
//
// An implementation intention only fires if its anchor exists in the person's
// day. The app used to hand every reader "after you brush your teeth" — a guess,
// and a wrong guess does not weaken the effect, it removes it. These are the
// events common enough to offer as taps and specific enough to be useful.
//
// Deliberately things that happen TO you, not things you decide to do: a cue
// tied to another decision is two decisions.

enum DayAnchor: String, CaseIterable, Identifiable, Sendable {
    case morningCoffee, commute, deskSitDown, lunch, schoolRun
    case leaveWork, dinner, dishes, gym, bedtime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morningCoffee: return String(localized: "First coffee")
        case .commute:       return String(localized: "The commute")
        case .deskSitDown:   return String(localized: "Sitting down at my desk")
        case .lunch:         return String(localized: "Lunch break")
        case .schoolRun:     return String(localized: "School run")
        case .leaveWork:     return String(localized: "Closing the laptop")
        case .dinner:        return String(localized: "Cooking dinner")
        case .dishes:        return String(localized: "Clearing up after dinner")
        case .gym:           return String(localized: "The gym")
        case .bedtime:       return String(localized: "Getting into bed")
        }
    }

    /// How the model should speak about it inside a cue.
    var phrase: String {
        switch self {
        case .morningCoffee: return "their first coffee of the day"
        case .commute:       return "their commute"
        case .deskSitDown:   return "sitting down at their desk"
        case .lunch:         return "their lunch break"
        case .schoolRun:     return "the school run"
        case .leaveWork:     return "closing the laptop at the end of work"
        case .dinner:        return "cooking dinner"
        case .dishes:        return "clearing up after dinner"
        case .gym:           return "going to the gym"
        case .bedtime:       return "getting into bed"
        }
    }

    var symbol: String {
        switch self {
        case .morningCoffee: return "cup.and.saucer.fill"
        case .commute:       return "tram.fill"
        case .deskSitDown:   return "laptopcomputer"
        case .lunch:         return "fork.knife"
        case .schoolRun:     return "figure.and.child.holdinghands"
        case .leaveWork:     return "door.left.hand.closed"
        case .dinner:        return "frying.pan.fill"
        case .dishes:        return "sink.fill"
        case .gym:           return "dumbbell.fill"
        case .bedtime:       return "bed.double.fill"
        }
    }
}

// MARK: - ⭐ DreamDetails — the bounded "in your own words" surface (2026-08-06).
//
// Onboarding's identity answer is now four buttons (see `aspirationOptions`),
// which is right for a flow that has to stay fast. But some people have a
// specific, concrete dream that no four-option roster can hold, and the planner
// gets meaningfully better output when it has that raw material. Jack's ask:
// "a place where the user can give a LIMITED NUMBER of more detailed responses
// about their wants and dreams so the AI can output actionable responses in the
// meal plan/menu."
//
// ⭐ WHY IT IS BOUNDED, and not just a big open notes field:
//   • A blank unbounded box is the thing we just removed from onboarding. Three
//     labelled slots are a PROMPT, and a prompt beats a blank page — the same
//     reason the plan card ships a concrete step instead of "do your best"
//     (Locke & Latham 2002: specific beats "do your best").
//   • Three, because the plan itself tops out at 2–3 goals ("a plan you can
//     actually hold", HeuristicGoalPlanner). More detail than the plan can
//     express is detail we would silently drop, which is a lie by omission.
//   • 140 characters, because the field feeds a prompt whose useful content is
//     ONE concrete want. A paragraph makes the model summarise instead of act,
//     and long free text is exactly what produces vague output.
//
// This surface is NEVER in the onboarding path. It lives behind Settings →
// Adjust plan, where saving re-runs the planner, so writing something here has
// a visible consequence: the menu changes.
enum DreamDetails {
    /// Max entries the user can add. See the header for why three.
    static let maxCount = 3
    /// Max characters per entry. See the header for why 140.
    static let maxLength = 140

    /// The slot prompts, in order. Each asks for something the planner can act
    /// on — a thing, a timeframe, an obstacle — never "tell us about yourself".
    /// Kept SHORT enough to fit one line at the default text size: the first
    /// draft read "One thing you want to have done a year from now" and
    /// truncated mid-word in the field, so the ask itself was unreadable
    /// (design/aug06-verify/adjust-details, first pass).
    static let placeholders: [String] = [
        String(localized: "What you want done a year from now"),
        String(localized: "Something you keep meaning to start"),
        String(localized: "The part you always get stuck on")
    ]

    /// Trim, cap, and drop empties — the one place entries are normalised, so
    /// storage, the planner prompt and the UI can never disagree about bounds.
    static func normalise(_ raw: [String]) -> [String] {
        raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { String($0.prefix(maxLength)) }
            .prefix(maxCount)
            .map { $0 }
    }
}

// MARK: - Q2 self-assessment buckets for daily short-form hours.
//
// The timeLost step now captures WHOLE HOURS via the scrubber (Opal mapping row
// 2); the band survives as the planner's sizing input, derived from the hours.

enum ShortFormBand: String, CaseIterable, Identifiable {
    case under1 = "Under 1 hr"
    case oneToTwo = "1–2 hrs"
    case twoToFour = "2–4 hrs"
    case fourPlus = "4+ hrs"

    var id: String { rawValue }

    /// The band whose baseline sits nearest the scrubbed hours — keeps the
    /// planner's step sizing working off the new continuous answer.
    static func nearest(toHours hours: Int) -> ShortFormBand {
        let minutes = hours * 60
        return allCases.min {
            abs($0.baselineMinutes - minutes) < abs($1.baselineMinutes - minutes)
        } ?? .oneToTwo
    }
}

// MARK: - Junk / monitored app catalogs (retained; used by blocking + Mental Diet).

/// A junk / short-form app row. MOCK list — real picker comes via Family Controls.
struct JunkAppOption: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String

    static let mock: [JunkAppOption] = [
        .init(id: "tiktok",    name: "TikTok",    symbol: "play.rectangle.fill"),
        .init(id: "instagram", name: "Instagram", symbol: "camera.fill"),
        .init(id: "youtube",   name: "YouTube Shorts", symbol: "film.fill"),
        .init(id: "x",         name: "X",         symbol: "bubble.left.fill"),
        .init(id: "reddit",    name: "Reddit",    symbol: "text.bubble.fill"),
        .init(id: "snapchat",  name: "Snapchat",  symbol: "bolt.fill")
    ]
}

/// A monitored app to categorize in the one-time Mental Diet setup (spec-v2.1).
struct MonitoredAppOption: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String

    static let catalog: [MonitoredAppOption] = [
        .init(id: "tiktok",    name: "TikTok",     symbol: "play.rectangle.fill"),
        .init(id: "instagram", name: "Instagram",  symbol: "camera.fill"),
        .init(id: "youtube",   name: "YouTube",    symbol: "film.fill"),
        .init(id: "x",         name: "X",          symbol: "bubble.left.fill"),
        .init(id: "reddit",    name: "Reddit",     symbol: "text.bubble.fill"),
        .init(id: "spotify",   name: "Spotify",    symbol: "music.note"),
        .init(id: "kindle",    name: "Kindle",     symbol: "book.fill"),
        .init(id: "duolingo",  name: "Duolingo",   symbol: "character.book.closed.fill")
    ]

    static func named(_ id: String) -> MonitoredAppOption? {
        catalog.first { $0.id == id }
    }
}
