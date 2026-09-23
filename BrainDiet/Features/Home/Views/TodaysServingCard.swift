import SwiftUI

// MARK: - TODAY'S SERVING — Home's ONE recommendation card (vision v2).
//
// Reads the Plate Engine's single suggestion: 38pt category chip on its soft
// wash, the concrete activity title, "18 minutes · brain vegetables" subtitle,
// the screen's ONLY primary CTA ("Feed my brain"), and a quiet "Not now" that
// re-rolls to a DIFFERENT serving. Mockup source: screens-final.src.html.

struct TodaysServingCard: View {
    /// The engine's single suggestion. nil = plate complete, nothing needed.
    let serving: PlateServing?
    var onFeed: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mockup (appetite `.srv`): no eyebrow — the chip + concrete action
            // lead. 42pt category-tint chip, 16pt title, food word in its color.
            HStack(spacing: 12) {
                PlateCategoryChip(category: serving?.category ?? .learning,
                                  size: 42, iconSize: 20, cornerRadius: 13)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(BDFont.display(.extraBold, size: 16, relativeTo: .body))
                        .foregroundStyle(Color.bdTextPrimary)
                        .lineLimit(1)
                    subtitleText
                        .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            if let serving {
                // The screen's ONE primary CTA — the leaf-deep pill, white text.
                Button(action: onFeed) {
                    Text(serving.category.ctaTitle)
                        .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.bdLeafDeep))
                }
                .buttonStyle(.plain)
                .padding(.top, 11)

                Button(action: onNotNow) {
                    Text("Not now")
                        .font(BDFont.body(.semiBold, size: 13, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        serving?.title ?? String(localized: "Plate complete")
    }

    /// ⭐ THE FOOD WORD IS GONE (Jack, build 15 on device: the language "leans
    /// too much into the food motif and actually loses its meaning"). This read
    /// "10 minutes · brain vegetables" — the nutrition vocabulary he banned on
    /// 2026-08-14 as an asset-naming convention that must never surface as a UI
    /// label. Same defect as the Menu's "reading · vegetables", in a second
    /// place, on a surface that mirrors the shield.
    ///
    /// What replaces it is the thing the user actually needs at a glance: what
    /// this serving is FOR. The activity, in its own colour, still carries the
    /// category — the colour was always doing that work; the word was decoration.
    private var subtitleText: Text {
        guard let serving else {
            return Text(String(localized: "Nothing needed. Go live your evening."))
                .foregroundColor(Color.bdTextSecondary)
        }
        // `detail` is the goal this serving belongs to ("Read more"). It is
        // optional for off-plan blocks, which fall back to the plain minutes.
        guard let detail = serving.detail, !detail.isEmpty else {
            return Text(String(localized: "\(serving.minutes) minutes"))
                .foregroundColor(Color.bdTextSecondary)
        }
        return Text(String(localized: "\(serving.minutes) minutes · "))
            .foregroundColor(Color.bdTextSecondary)
            + Text(detail)
            .foregroundColor(serving.category.textInk)
            .fontWeight(.bold)
    }
}

// MARK: - PlateCategoryChip — the shared rounded icon chip on its tint wash.
//
// ICON LAW (2026-07-18): Phosphor DUOTONE tinted in the category ink, on the
// category tint chip — the one icon treatment for chips app-wide.

struct PlateCategoryChip: View {
    let category: PlateCategory
    var size: CGFloat = 30
    var iconSize: CGFloat = 13
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(category.wash)
            .frame(width: size, height: size)
            .overlay(
                BDPhIcon(icon: category.phIcon, size: iconSize, color: category.ink)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - SetPlateCard — Home's honest fresh state (no profile, no plan).
//
// HONESTY LAW: with no onboarding answers there is no real plan, so Home never
// dresses an engine default up as "today's serving." The card invites setup
// instead and routes back into onboarding (same shell as the serving card, so
// the screen's rhythm holds).

struct SetPlateCard: View {
    /// Routes into onboarding (the only place a real plan can come from).
    var onSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.bdLeafTint)
                    .frame(width: 42, height: 42)
                    .overlay(BDPhIcon(icon: .forkKnife, size: 20, color: .bdLeaf))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Let's set your plate")
                        .font(BDFont.display(.extraBold, size: 16, relativeTo: .body))
                        .foregroundStyle(Color.bdTextPrimary)
                        .lineLimit(1)
                    Text("A few questions put your first serving here.")
                        .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Button(action: onSetup) {
                Text("Set my plate")
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.bdLeafDeep))
            }
            .buttonStyle(.plain)
            .padding(.top, 11)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Suggestion") {
    ZStack {
        BDBackground()
        TodaysServingCard(
            serving: PlateServing(id: "p", title: "Finish a chapter", detail: "Read more",
                                  category: .learning, minutes: 18,
                                  goalID: nil, stepID: nil, activityID: "read"),
            onFeed: {}, onNotNow: {})
            .padding(18)
    }
}

#Preview("Complete") {
    ZStack {
        BDBackground()
        TodaysServingCard(serving: nil, onFeed: {}, onNotNow: {})
            .padding(18)
    }
}

#Preview("Set your plate") {
    ZStack {
        BDBackground()
        SetPlateCard(onSetup: {})
            .padding(18)
    }
}
