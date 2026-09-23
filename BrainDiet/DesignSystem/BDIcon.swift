import SwiftUI

// MARK: - BDIcon — the ONE icon family (Phosphor duotone, 2026-07-18).
//
// ⭐ ICON LAW: the app's own iconography is Phosphor DUOTONE, tinted with the
// category color and sitting on that category's tint chip. Never emoji, never
// SF Symbols on the same surface (system chrome glyphs — chevrons, gear,
// checkmarks — may stay SF). This file owns the law: the render helper + every
// icon mapping, so no view hand-picks icons ad hoc.
//
// 📦 VENDORED, not packaged (2026-07-31). We used to depend on the PhosphorSwift
// SPM package, which ships ~9,000 icons × 6 weights as one 167.7 MB asset
// catalog — 93% of our download size, to use 29 glyphs. Those 29 SVGs now live
// in `Assets.xcassets/PhosphorIcons` (23 KB total). Phosphor's duotone SVGs are
// `template-rendering-intent` with the backing shape at `opacity="0.2"`, so
// tinting a template image reproduces duotone exactly — same pixels, no package.
// ADDING AN ICON: copy `<kebab-name>-<weight>.svg` from the Phosphor repo into a
// new `ph-<kebab-name>-<weight>.imageset` (template + preserve vector), then add
// the case below. Never re-add the package.

/// The Phosphor glyphs BrainDiet actually uses.
enum BDPh: String {
    case barbell, bed, bell, bicycle, bookOpen, brain, cake, cookingPot, couch
    case dotsSixVertical, flowerLotus, footprints, forkKnife, gameController
    case graduationCap, guitar, hamburger, hammer, handSwipeRight, leaf, moon
    case record
    case plant
    case monitorPlay
    case newspaper
    case chatCircle
    case moonStars, palette, pencilLine, sneakerMove, sparkle, treeEvergreen, usersThree

    enum Weight: String { case duotone, fill }

    /// Asset-catalog name, e.g. `bookOpen` + `.duotone` → `ph-book-open-duotone`.
    func assetName(_ weight: Weight) -> String {
        let kebab = rawValue.reduce(into: "") { out, ch in
            if ch.isUppercase { out.append("-"); out.append(contentsOf: ch.lowercased()) }
            else { out.append(ch) }
        }
        return "ph-\(kebab)-\(weight.rawValue)"
    }
}

/// Renders one Phosphor icon at a fixed square size, tinted.
struct BDPhIcon: View {
    let icon: BDPh
    var size: CGFloat = 17
    var color: Color = .bdTextPrimary
    var weight: BDPh.Weight = .duotone

    var body: some View {
        Image(icon.assetName(weight))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

// MARK: - Category icons (chips, tray rows, serving card)

extension PlateCategory {
    /// The category's Phosphor icon (duotone, tinted `ink`, on the `wash` chip).
    var phIcon: BDPh {
        switch self {
        case .learning:      return .bookOpen
        case .focus:         return .barbell
        case .creativity:    return .palette
        case .entertainment: return .cake
        case .emptyCalories: return .hamburger   // junk food, worn in gray
        }
    }
}

// MARK: - Onboarding hijacker tiles (the gray world)

extension AttentionHijacker {
    var phIcon: BDPh {
        switch self {
        case .social:     return .usersThree      // Socials
        case .shortVideo: return .handSwipeRight   // Scrolling
        case .youtube:    return .monitorPlay      // Binge-watching
        case .games:      return .gameController   // Gaming
        case .news:       return .newspaper        // News spirals
        case .messaging:  return .chatCircle       // Group chats
        }
    }
}

// MARK: - Onboarding domain tiles (color returns)

extension ActivityDomain {
    var phIcon: BDPh {
        switch self {
        case .reading:  return .bookOpen
        case .fitness:  return .barbell
        case .music:    return .guitar
        case .building: return .hammer
        case .writing:  return .pencilLine
        case .learning: return .graduationCap
        case .outdoors: return .treeEvergreen
        case .creating: return .palette
        }
    }
}

// MARK: - Menu-tab activity tiles

extension Activity {
    /// Phosphor icon per catalog id (Menu tiles, Becoming rows).
    var phIcon: BDPh {
        switch id {
        case "read":     return .bookOpen
        case "lift":     return .barbell
        case "run":      return .sneakerMove
        case "build":    return .hammer
        case "study":    return .graduationCap
        case "create":   return .palette
        case "write":    return .pencilLine
        case "guitar":   return .guitar
        case "ride":     return .bicycle
        case "cook":     return .cookingPot
        case "connect":  return .usersThree
        case "walk":     return .footprints
        case "meditate": return .flowerLotus
        case "rest":     return .moonStars
        default:         return .sparkle
        }
    }

    /// The category color the activity's time lands in (the color LAW —
    /// Becoming's bars + icons wear it too).
    var categoryColor: Color {
        (PlateEngine.category(forActivityID: id) ?? .focus).ink
    }
}

#Preview("Icon law") {
    HStack(spacing: 14) {
        ForEach(PlateCategory.allCases) { cat in
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(cat.wash)
                .frame(width: 34, height: 34)
                .overlay(BDPhIcon(icon: cat.phIcon, size: 17, color: cat.ink))
        }
    }
    .padding()
    .background(Color.bdBackground)
}
