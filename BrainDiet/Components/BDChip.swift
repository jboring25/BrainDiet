import SwiftUI

// MARK: - Selectable chip (multi-select onboarding options).
//
// Selected = emerald-soft wash + emerald border + bright label.
// Unselected = raised surface, secondary label. Min 44pt touch height.

struct BDChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                .foregroundStyle(isSelected ? Color.bdAccent : Color.bdTextSecondary)
                .padding(.horizontal, Theme.Space.lg)
                .frame(minHeight: Theme.Size.minTouch)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.bdAccentSoft : Color.bdSurface)
                )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
    }
}

// MARK: - Flow layout so chips wrap naturally across lines.

struct BDFlowLayout: Layout {
    var spacing: CGFloat = Theme.Space.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, !(rows.last?.isEmpty ?? true) {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(size)
            rowWidth += size.width + spacing
        }
        let height = rows.reduce(0) { acc, row in
            acc + (row.map(\.height).max() ?? 0) + spacing
        } - spacing
        return CGSize(width: maxWidth, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ZStack {
        BDBackground()
        BDFlowLayout {
            BDChip(title: "Read more", isSelected: true) {}
            BDChip(title: "Build a business", isSelected: false) {}
            BDChip(title: "Get in shape", isSelected: true) {}
            BDChip(title: "Learn a skill", isSelected: false) {}
        }
        .padding(Theme.Space.screenX)
    }
}
