import SwiftUI

// MARK: - BDMealTray — "Today's Mental Diet" (v7 light variant-A).
//
// The signature 2-second dashboard surface, re-themed for the warm-white product:
// a white card (border + soft shadow define it) titled "Today's Mental Diet" with
// today's servings line, then three nutrition rows — each a rounded colored icon
// chip + category name + a slim category-color progress bar + the minutes. The
// glowing-vs-slop contrast now lives in COLOR (sage nourishing, gold leisure,
// muted grey slop) rather than a skeuomorphic bento tray, which could not sit on
// white. Wired to the same BrainEngine data (MentalDiet + JunkBudget).
//
// Empty/degraded: a single quiet line, never fake portions.

struct BDMealTray: View {

    /// Today's real category minutes. nil → the honest empty state.
    let diet: MentalDiet?
    /// The plan's slop allowance vs. today's slop minutes (nil omits the line).
    var junkBudget: JunkBudget? = nil
    /// "1 of 3 servings today" — the meal-plan tie-in (nil omits).
    var servingsLine: String? = nil
    /// Drives the rows' bars animating in when Home reveals the card.
    var animate: Bool = true
    /// Capture pacing multiplier (ad toolkit). 1.0 in production.
    var pace: Double = 1.0
    /// Delay before the bars grow in (stretched by `pace`).
    var startDelay: Double = 0.2
    /// The quiet emotional close ("Spend it well."), anchored to the card.
    var footer: String? = nil

    @State private var plated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: Bool { plated || reduceMotion || !animate }
    private var rows: [DietRow] { DietRow.from(diet) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header row — title LEFT, servings RIGHT, one line (mockup).
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Mental Diet")
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                Spacer(minLength: Theme.Space.sm)
                if let servingsLine {
                    Text(servingsLine)
                        .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }

            if diet == nil {
                // Honest empty state — never fake portions.
                Text(String(localized: "Nothing on the tray yet. It fills as your day does."))
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        dietRow(row, index: i)
                    }
                }
            }

            // The slop line stays quiet — surfaced ONLY on a heavy day.
            if let junkBudget, junkBudget.isOver { overBudgetLine(junkBudget) }

            if let footer {
                // "Spend it well." — quiet, italic, centered (mockup footerline).
                Text(footer)
                    .font(BDFont.body(.medium, size: 12, relativeTo: .caption))
                    .italic()
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 1)   // 10pt stack gap + 1 ≈ the mockup's 11pt
            }
        }
        .padding(.vertical, 14)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            guard animate, !reduceMotion, !plated else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay * pace) {
                withAnimation(.spring(response: 0.55 * pace, dampingFraction: 0.86)) {
                    plated = true
                }
            }
        }
    }

    // MARK: One nutrition row — 30pt chip · name · inline 7pt bar · minutes (mockup).

    private func dietRow(_ row: DietRow, index: Int) -> some View {
        let muted = row.category == .junk   // the doomscroll row reads deliberately quiet
        return HStack(spacing: 10) {
            // 30pt rounded icon chip on its soft wash.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(row.tint)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: row.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(row.ink)
                )

            Text(row.name)
                .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                .foregroundStyle(muted ? Color.bdSlopLight : Color.bdTextPrimary)
                .lineLimit(1)
                .frame(width: 88, alignment: .leading)

            // Slim inline progress bar — full radius, 7pt tall.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.bdCardBorder)
                    Capsule().fill(row.ink)
                        .frame(width: max(row.minutes > 0 ? 7 : 0,
                                          geo.size.width * (shown ? row.fraction : 0)))
                }
            }
            .frame(height: 7)

            Text(Self.display(row.minutes))
                .font(BDFont.body(.medium, size: 13, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(muted ? Color.bdSlopLight : Color.bdTextSecondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
    }

    // MARK: The heavy-day line — one quiet fact, then the reset. Small and kind.
    //
    // ⭐ "BUDGET" WAS CUT (2026-08-11). "Past the 90m slop budget" framed slop as
    // an ALLOWANCE — 90 minutes you were entitled to spend, and blowing it as an
    // overdraft. That is the same trap the Today's Plate rows avoid by refusing
    // to show a remainder for Slop. We now report what actually happened and say
    // nothing about permission: the number is the whole message.
    private func overBudgetLine(_ budget: JunkBudget) -> some View {
        Text(String(localized: "\(Self.display(budget.spentMinutes)) of slop today. Tomorrow's a fresh plate."))
            .font(BDFont.body(.regular, size: 12, relativeTo: .caption))
            .foregroundStyle(Color.bdTextSecondary)
            .monospacedDigit()
            .accessibilityLabel("\(budget.spentMinutes) minutes of slop today")
    }

    // MARK: Helpers

    /// "40m" / "3h 10m" — local so the component stays engine-free.
    static func display(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private var accessibilitySummary: String {
        guard diet != nil else { return String(localized: "Today's Mental Diet: empty so far.") }
        let parts = rows.filter { $0.minutes > 0 }
            .map { "\($0.name) \(Self.display($0.minutes))" }
        return "Today's Mental Diet: " + parts.joined(separator: ", ")
    }
}

// MARK: - DietRow — one category's row model (name, color, share of the day).

private struct DietRow: Identifiable {
    let category: AppCategory
    let minutes: Int
    /// Share of today's total minutes (bar width).
    let fraction: CGFloat

    var id: String { category.rawValue }

    /// The row voice — nourishing/leisure named plainly, junk reads "Doomscroll".
    var name: String {
        switch category {
        case .nourishing: return String(localized: "Nourishing")
        case .leisure:    return String(localized: "Leisure")
        case .junk:       return String(localized: "Doomscroll")
        }
    }

    var symbol: String {
        switch category {
        case .nourishing: return "book"
        case .leisure:    return "cup.and.saucer"
        case .junk:       return "iphone"
        }
    }

    /// Chip wash — the mockup's soft solid fills.
    var tint: Color {
        switch category {
        case .nourishing: return .bdSageSoft
        case .leisure:    return .bdGoldWash
        case .junk:       return .bdSlopSoft
        }
    }

    /// Icon + bar ink — mockup sage / gold / muted grey.
    var ink: Color {
        switch category {
        case .nourishing: return .bdSage
        case .leisure:    return .bdGoldAccent
        case .junk:       return .bdSlopLight
        }
    }

    /// Rows in nutrition order; bars are each category's share of the day.
    static func from(_ diet: MentalDiet?) -> [DietRow] {
        let order: [AppCategory] = [.nourishing, .leisure, .junk]
        guard let diet else {
            return order.map { DietRow(category: $0, minutes: 0, fraction: 0) }
        }
        let minutes = order.map { diet.minutes[$0] ?? 0 }
        let total = max(1, minutes.reduce(0, +))
        return order.enumerated().map { i, cat in
            DietRow(category: cat, minutes: minutes[i],
                    fraction: CGFloat(minutes[i]) / CGFloat(total))
        }
    }
}


#Preview("Populated") {
    ZStack {
        BDBackground(intensity: .standard)
        BDMealTray(
            diet: MentalDiet(
                minutes: [.nourishing: 190, .leisure: 60, .junk: 40],
                percents: [.nourishing: 65, .leisure: 21, .junk: 14],
                totalMinutes: 290
            ),
            junkBudget: JunkBudget(spentMinutes: 40, budgetMinutes: 90),
            servingsLine: "1 of 3 servings today",
            animate: false,
            footer: "Spend it well."
        )
        .padding(Theme.Space.screenX)
    }
}

#Preview("Empty") {
    ZStack {
        BDBackground(intensity: .standard)
        BDMealTray(diet: nil, animate: false, footer: "Tomorrow's yours.")
            .padding(Theme.Space.screenX)
    }
}

#Preview("Slop-heavy") {
    ZStack {
        BDBackground(intensity: .standard)
        BDMealTray(
            diet: MentalDiet(
                minutes: [.nourishing: 55, .leisure: 50, .junk: 120],
                percents: [.nourishing: 24, .leisure: 22, .junk: 54],
                totalMinutes: 225
            ),
            junkBudget: JunkBudget(spentMinutes: 120, budgetMinutes: 90),
            animate: false,
            footer: "Spend it well."
        )
        .padding(Theme.Space.screenX)
    }
}
