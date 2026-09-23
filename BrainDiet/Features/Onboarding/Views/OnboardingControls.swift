import SwiftUI

// MARK: - Shared onboarding selection controls (spec-v2.6).
//
// Fast, tappable selection primitives used across the six judged-question steps:
// an icon CARD for the visual multi/single grids, and a plain ROW for short
// single-select lists. Selected = emerald-soft wash + emerald border + bright label.

/// Icon-over-label card for grid selection (hijackers, domains, primary domain).
///
/// COLOR-CODED (2026-07-08): every tile carries its OWN `tint` — a richer filled
/// icon in that hue + a same-hue tint wash on the card. This is the biggest
/// "alive" win: the quiz reads as a palette, not a two-tone grid.
///   • SELECTED   = full hue icon + brighter hue wash + colored 1.5pt border +
///                  a soft hue lift (raised).
///   • UNSELECTED = the hue still PRESENT (dimmer/desaturated icon + a faint
///                  hue wash) so the grid stays alive; label ~0.9 for legibility.
struct OBOptionCard: View {
    let symbol: String
    let label: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Space.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(isSelected ? tint : tint.opacity(0.55))
                    .frame(height: 30)
                    // A soft hue glow off the icon on selection — the tile lights up.
                    .shadow(color: isSelected ? tint.opacity(0.5) : .clear, radius: 10)
                Text(label)
                    .font(BDFont.body(.medium, size: 14, relativeTo: .subheadline))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? Color.bdTextPrimary : Color.bdTextPrimary.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.bdSurface)
                    // The same-hue tint wash — present but faint when unselected,
                    // richer when selected, so color-coding reads at a glance.
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(tint.opacity(isSelected ? 0.18 : 0.06))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(isSelected ? tint.opacity(0.8) : Color.bdCardBorder,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
            // The selected tile floats a touch — a soft hue-tinted lift.
            .shadow(color: isSelected ? tint.opacity(0.28) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)   // light tap on select
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Full-width row for short single-select lists (time lost, blocker).
/// `grayWorld` restyles it for the gray canvas (the hijack/timeLost arc):
/// selection mutes into the slop tint instead of lighting up leaf — in the
/// feed's world, choosing something never earns color.
struct OBOptionRow: View {
    let label: String
    var symbol: String? = nil
    var grayWorld: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body)
                        .foregroundStyle(isSelected ? selectedAccent : Color.bdTextSecondary)
                        .frame(width: 26)
                }
                Text(label)
                    .font(BDFont.body(.semiBold, size: 16, relativeTo: .body))
                    .foregroundStyle(labelColor)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(selectedAccent)
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(minHeight: Theme.Size.minTouch + Theme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)   // light tap on select
    }

    private var selectedAccent: Color { grayWorld ? .bdGrayInk : .bdLeaf }
    private var labelColor: Color {
        if grayWorld { return isSelected ? .bdTextPrimary : .bdGrayInk }
        return isSelected ? .bdTextPrimary : Color.bdTextPrimary.opacity(0.9)
    }
    private var fillColor: Color {
        if grayWorld { return isSelected ? .bdSlopTint : .bdGrayTile }
        return isSelected ? .bdLeafTint : .bdSurface
    }
    private var borderColor: Color {
        if grayWorld { return isSelected ? .bdSlopGray : .bdGrayTileBorder }
        return isSelected ? .bdLeaf : .bdCardBorder
    }
}

// MARK: - Gray-world hijacker tile (appetite mockup, screen 2).
//
// The feed's snacks, already drained of color: warm-gray tile, a 46pt gray icon
// chip (Phosphor duotone in gray-ink), the app label, and the food-language
// caption ("the bottomless bowl"). Selecting one doesn't light it up — it MUTES
// it: slop-tint fill, slop border, and a small "MUTED" badge. The reward is
// what leaves your day, not what you tapped.

struct HijackTile: View {
    let hijacker: AttentionHijacker
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.bdGrayChipSel : Color.bdGrayChip)
                    .frame(width: 46, height: 46)
                    .overlay(
                        BDPhIcon(icon: hijacker.phIcon, size: 24, color: .bdGrayInk)
                            .opacity(isSelected ? 0.9 : 0.7)
                    )
                    .padding(.bottom, 7)
                Text(hijacker.label)
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(isSelected ? Color.bdTextPrimary : Color.bdGrayInk)
                Text(hijacker.foodCaption)
                    .font(BDFont.body(.semiBold, size: 11.5, relativeTo: .caption))
                    .foregroundStyle(Color.bdGrayFaint)
            }
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.bdSlopTint : Color.bdGrayTile)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.bdSlopGray : Color.bdGrayTileBorder,
                                  lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Text("MUTED")
                        .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                        .kerning(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.bdSlopGray))
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(hijacker.label), \(hijacker.foodCaption)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Color-return domain tile (appetite mockup, screen 3).
//
// Where the color comes back: white tile, the domain's Phosphor icon in its
// CATEGORY color (the LAW: leaf / salmon / berry / honey), the label, and the
// food-language subtitle. Selected = the category's tint wash + colored border.

struct DomainTile: View {
    let domain: ActivityDomain
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                BDPhIcon(icon: domain.phIcon, size: 27, color: domain.categoryColor)
                    .opacity(isSelected ? 1 : 0.85)
                    .padding(.bottom, 6)
                Text(domain.label)
                    .font(BDFont.display(.extraBold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                Text(domain.foodSubtitle)
                    .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption))
                    .foregroundStyle(isSelected ? domain.categoryTextInk : Color.bdTextSecondary)
            }
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            // Tighter than the hijack tiles: 8 domains must fit 4 rows + the
            // "color comes back" footer above the fold.
            .padding(.vertical, 13)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? domain.categoryTint : Color.bdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? domain.categoryColor : Color.bdCardBorder,
                                  lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(domain.label), \(domain.foodSubtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Two-column grid used by the visual selection steps.
enum OBGrid {
    static let columns = [GridItem(.flexible(), spacing: Theme.Space.md),
                          GridItem(.flexible(), spacing: Theme.Space.md)]
}

#Preview("Hijack tiles (gray world)") {
    ZStack {
        Color.bdGrayCanvas.ignoresSafeArea()
        LazyVGrid(columns: OBGrid.columns, spacing: 12) {
            HijackTile(hijacker: .social, isSelected: true) {}
            HijackTile(hijacker: .games, isSelected: false) {}
        }
        .padding(Theme.Space.screenX)
    }
}

#Preview("Domain tiles (color returns)") {
    ZStack {
        BDBackground()
        LazyVGrid(columns: OBGrid.columns, spacing: 12) {
            DomainTile(domain: .reading, isSelected: true) {}
            DomainTile(domain: .fitness, isSelected: true) {}
            DomainTile(domain: .music, isSelected: false) {}
            DomainTile(domain: .creating, isSelected: false) {}
        }
        .padding(Theme.Space.screenX)
    }
}
