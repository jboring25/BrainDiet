import SwiftUI

// MARK: - The road's pieces (moon.png): a stop on the timeline, its row, the
// inline editor, and the skeleton shown while the road call runs.

enum RoadField: Hashable {
    case title(UUID)
    case by(UUID)
}

/// A dot on the leaf line + the row beside it. The first milestone's dot is
/// filled: that is where the daily steps start.
struct RoadStop<Row: View>: View {
    let lit: Bool
    let muted: Bool
    @ViewBuilder let row: () -> Row

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(lit ? Color.bdLeaf : Color.bdSurface)
                .overlay(Circle().strokeBorder(muted ? Color.bdCardBorder : Color.bdLeaf, lineWidth: 2))
                .frame(width: 12, height: 12)
                .frame(width: 16)
                .accessibilityHidden(true)
            row()
        }
    }
}

/// "Launch on the App Store ········ by Nov 15".
struct RoadRow: View {
    let title: String
    let trailing: String
    let first: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            if !trailing.isEmpty {
                Text(trailing)
                    .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(first ? Color.bdLeafTint : Color.bdSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(first ? Color.bdLeaf : Color.bdCardBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The row in edit mode: the title and the date as plain text fields.
struct RoadEditRow: View {
    let milestone: Milestone
    let first: Bool
    var focus: FocusState<RoadField?>.Binding
    let onTitle: (String) -> Void
    let onBy: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "First milestone"),
                      text: Binding(get: { milestone.title }, set: onTitle))
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .focused(focus, equals: .title(milestone.id))
                .submitLabel(.next)
                .onSubmit { focus.wrappedValue = .by(milestone.id) }
            TextField(String(localized: "by when"),
                      text: Binding(get: { milestone.by }, set: onBy))
                .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.trailing)
                .frame(width: 74)
                .focused(focus, equals: .by(milestone.id))
                .submitLabel(.done)
                .onSubmit { focus.wrappedValue = nil }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(first ? Color.bdLeafTint : Color.bdSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.bdLeafDeep, lineWidth: 1.5)
        }
    }
}

/// A placeholder row while the road is drawn: two quiet bars, breathing.
struct RoadSkeletonRow: View {
    let index: Int
    @State private var dim = false

    var body: some View {
        HStack {
            Capsule().fill(Color.bdCardBorder)
                .frame(width: [150, 120, 165, 100][index % 4], height: 10)
            Spacer()
            Capsule().fill(Color.bdCardBorder)
                .frame(width: 48, height: 9)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
        }
        .opacity(dim ? 0.55 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever().delay(Double(index) * 0.12)) { dim = true }
        }
        .accessibilityLabel("Drawing your road")
    }
}

#Preview {
    VStack(spacing: 8) {
        RoadStop(lit: true, muted: false) { RoadRow(title: "Launch on the App Store", trailing: "by Nov 15", first: true) }
        RoadStop(lit: false, muted: true) { RoadSkeletonRow(index: 1) }
    }
    .padding()
}
