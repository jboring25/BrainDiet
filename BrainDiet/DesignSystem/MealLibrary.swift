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

    // MARK: - ⭐ HERO ROSTER (2026-08-05) — SAME-VESSEL, for the plating moment.
    //
    // THE BUG THIS FIXES: the first-serving hero crossfades PlateEmpty → a dish.
    // PlateEmpty is a WHITE SPECKLED CERAMIC BOWL. When we regenerated the meal
    // art with cuisine-specific vessels (sushi on slate, ramen in a noodle bowl,
    // med-grain in TERRACOTTA), the hero moment started swapping the bowl mid-
    // animation: you drag a serving onto a white bowl and a clay bowl appears
    // holding the food. The whole choreography — halo, crossfade, steam, flare —
    // rests on "THIS bowl received YOUR serving", so the vessel swap collapsed
    // the illusion and read as one stock photo replacing another.
    //
    // The cuisine-vessel rule was right for the 44pt plan-card thumbnails, where
    // each row must look distinct. It was wrong for the hero, where CONTINUITY is
    // the point. So: two rosters chosen by context. These `MealHero*` assets are
    // the pre-vessel renders (restored from design/meal-art-backup-20260727),
    // every one plated in the SAME white speckled bowl as PlateEmpty and
    // geometry-locked to it (1024×559, aligned to PlateNourished).
    //
    // RULE: anything crossfading from PlateEmpty/PlateNourished uses `heroMeal`.
    // Anything rendering a standalone small dish uses `thumbnail`. Never mix.
    static let heroMeals: [PlateCategory: [String]] = [
        .learning:      ["MealHeroMedGrain", "MealHeroGreenSalad"],
        .focus:         ["MealHeroSushi", "MealHeroMisoRamen"],
        .creativity:    ["MealHeroAcai", "MealHeroBlueberryYogurt"],
        .entertainment: ["MealHeroChocBerries"]
    ]

    /// The same-vessel dish for a plate crossfade. Falls back to the standard
    /// roster only if a category has no hero render, so a missing asset degrades
    /// to "wrong vessel" rather than "no dish at all".
    static func heroMeal(for category: PlateCategory, seed: Int = 0) -> String? {
        if let options = heroMeals[category], !options.isEmpty {
            return options[abs(seed) % options.count]
        }
        return meal(for: category, seed: seed)
    }

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
