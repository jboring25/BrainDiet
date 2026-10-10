import SwiftUI

// MARK: - Adjust plan · the road editor (moonshot, 2026-10-10).
//
// Up to three milestones: title, "by" as plain text, and a done mark. Marking
// one done moves the daily steps on to the next (the plan server aims at the
// first milestone not done).

struct AdjustRoadEditor: View {
    @Binding var milestones: [Milestone]

    static let maxCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            ForEach($milestones) { $m in
                row($m)
            }
            if milestones.count < Self.maxCount {
                Button {
                    withAnimation(Theme.Motion.snappy) { milestones.append(Milestone(title: "", by: "")) }
                } label: {
                    Text("+ Add a milestone")
                        .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdLeafDeep)
                        .frame(minHeight: Theme.Size.minTouch)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ m: Binding<Milestone>) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(Theme.Motion.snappy) { m.wrappedValue.done.toggle() }
            } label: {
                Image(systemName: m.wrappedValue.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(m.wrappedValue.done ? Color.bdLeaf : Color.bdTabMuted)
                    .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(m.wrappedValue.done ? "Done" : "Not done")
            .accessibilityHint("Marks this milestone done")

            TextField(String(localized: "Milestone"), text: m.title)
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .strikethrough(m.wrappedValue.done, color: Color.bdTextSecondary)
            TextField(String(localized: "by when"), text: m.by)
                .font(BDFont.body(.semiBold, size: 12.5, relativeTo: .caption))
                .foregroundStyle(Color.bdTextSecondary)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
        }
        .padding(.trailing, 13)
        .frame(minHeight: Theme.Size.minTouch + 4)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.bdCardBorder, lineWidth: 1))
    }
}

#Preview {
    @Previewable @State var road = [Milestone(title: "Launch on the App Store", by: "Nov 15", done: true),
                                    Milestone(title: "First 1,000 users", by: "Mar 1")]
    AdjustRoadEditor(milestones: $road).padding()
}
