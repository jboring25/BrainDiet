import SwiftUI

// MARK: - v2 · One served step on the menu hero.
//
// The compact card from Home's TodaysFocusCard (DayStatsRow.swift) — same tile,
// serif title, meta line, radius, border and raised shadow — minus the parts
// that only make sense on Home (grabber, timer, drag).

struct ServedStepCard: View {
    let served: ServedStep

    private var meta: String {
        let m = "\(served.step.suggestedMinutes)m"
        return served.step.cue.isEmpty ? m : "\(m) · \(served.step.cue)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(served.domain.categoryTint)
                .frame(width: 42, height: 42)
                .overlay {
                    BDPhIcon(icon: served.domain.phIcon, size: 19, color: served.domain.categoryColor)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(served.step.title)
                    .font(BDFont.serif(size: 18, relativeTo: .title3))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta)
                    .font(BDFont.body(.regular, size: 12.5, relativeTo: .footnote))
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: Color.bdLeafDeep.opacity(0.12), radius: 12, y: 7)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        BDBackground()
        ServedStepCard(served: ServedStep(
            domain: .building,
            step: PlannedStep(title: "Finish the App Store listing", cue: "after your 3pm class",
                              suggestedMinutes: 20, kind: .oneoff),
            why: ""))
        .padding(Theme.Space.screenX)
    }
}
