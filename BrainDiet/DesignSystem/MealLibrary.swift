import Foundation

// MARK: - MealLibrary — the food roster (2026-07-19).
//
// Eight geometry-locked meal renders (1024×559, aligned to PlateNourished) live
// in the asset catalog as the app's food library. Category mapping is LAW:
//   Learning / vegetables  → MealMedGrain, MealGreenSalad
//   Focus / protein        → MealSalmonRice, MealSushi, MealMisoRamen
//   Creativity / fruit     → MealAcai, MealBlueberryYogurt
//   Entertainment / dessert→ MealChocBerries
//
// This is the single source for meal-asset names — no view hand-picks a render.
// Picks are DETERMINISTIC (seeded), never random per frame, so a surface shows
// the same dish across relaunches within the same day/step.

enum MealLibrary {

    /// Asset-catalog names per plate category. Slop has no dish by design —
    /// junk is never illustrated as food (attraction law).
    static let meals: [PlateCategory: [String]] = [
        .learning:      ["MealMedGrain", "MealGreenSalad"],
        .focus:         ["MealSalmonRice", "MealSushi", "MealMisoRamen"],
        .creativity:    ["MealAcai", "MealBlueberryYogurt"],
        .entertainment: ["MealChocBerries"]
    ]

    // HERO ROSTER removed 2026-10-09: its only caller (onboarding commit) now
    // drags into the particle brain, and the MealHero* assets were deleted.

    /// A deterministic dish for a category. `seed` (e.g. a stable hash of a
    /// step id, or the day ordinal) rotates variety without randomness.
    static func meal(for category: PlateCategory, seed: Int = 0) -> String? {
        guard let options = meals[category], !options.isEmpty else { return nil }
        let index = abs(seed) % options.count
        return options[index]
    }

    // MARK: - THUMBNAIL ROSTER (2026-07-22, the plan card's dish art)
    //
    // At 44pt the renders have to be told apart in a GLANCE, and the hero-sized
    // picks don't survive the shrink: MealGreenSalad carries a salmon fillet, so
    // next to MealSalmonRice it reads as the same dish (Jack, plan-card review).
    // This roster re-orders each category to LEAD with its most graphically
    // distinct render — warm speckled grains / pink sushi slabs / white-and-blue
    // yogurt / dark chocolate — so four stacked rows never blur together. Same
    // assets, same category law; only the small-size priority differs.

    static let thumbnailMeals: [PlateCategory: [String]] = [
        .learning:      ["MealMedGrain", "MealGreenSalad"],
        .focus:         ["MealSushi", "MealSalmonRice", "MealMisoRamen"],
        .creativity:    ["MealBlueberryYogurt", "MealAcai"],
        .entertainment: ["MealChocBerries"]
    ]

    /// A thumbnail dish for a category, skipping `excluding` (the dish the row
    /// above already used) so two adjacent rows never wear the same plate.
    /// Deterministic: the roster's lead render, and on a collision the LAST one
    /// — the far end of the roster is the most visually distant render in the
    /// category (focus: sushi → miso ramen, not sushi → salmon rice, which read
    /// as the same pink-on-white dish at 44pt).
    static func thumbnail(for category: PlateCategory, excluding: String? = nil) -> String? {
        guard let options = thumbnailMeals[category], !options.isEmpty else { return nil }
        guard options[0] == excluding else { return options[0] }
        return options.last
    }
}
