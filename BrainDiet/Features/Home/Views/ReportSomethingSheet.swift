import SwiftUI

// MARK: - "Add something you did" — the off-plan report.
//
// Spec of record: design/plating/index.html, frame 1.
//
// The drag covers plan steps. This covers everything else — the walk, the chapter
// at a friend's house, the three hours of deep work done with the phone in another
// room. That last case is the whole reason self-report exists: session-only
// tracking recorded the people who need a timer and recorded nothing for the
// people already focusing.
//
// Deliberately ONE decision per screen. A duration picker was considered and cut:
// asking someone to estimate minutes at the end of a good day is the friction
// that makes logging apps get deleted. Each activity carries a sane default and
// the number is adjustable in one tap-and-hold gesture, not a required field.

struct ReportSomethingSheet: View {

    /// Activities the user's own plan already speaks for, surfaced first.
    let planActivityIDs: [String]
    var onReport: (PlateDraggable) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: [String: Int] = [:]

    private static let defaultMinutes = 30

    private var ordered: [Activity] {
        let plan = planActivityIDs.compactMap { ActivityCatalog.activity(id: $0) }
        let rest = ActivityCatalog.all.filter { a in !planActivityIDs.contains(a.id) }
        return plan + rest
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground(intensity: .standard)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What did you do?")
                            .font(BDFont.serif(size: 22, relativeTo: .title2))
                            .foregroundStyle(Color.bdTextPrimary)
                            .padding(.top, 4)
                        Text("It counts the same as a session. We just mark that you told us.")
                            .font(BDFont.body(.medium, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.bdTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 5)
                            .padding(.bottom, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, activity in
                                row(activity)
                                if index < ordered.count - 1 {
                                    Rectangle().fill(Color.bdCardBorder).frame(height: 1)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.bdSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(BDFont.body(.semiBold, size: 15, relativeTo: .body))
                        .foregroundStyle(Color.bdTextSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ activity: Activity) -> some View {
        let mins = minutes[activity.id] ?? Self.defaultMinutes
        let category = PlateEngine.category(forActivityID: activity.id) ?? .focus
        return Button {
            onReport(PlateDraggable(
                title: activity.label,
                subtitle: String(localized: "\(mins) minutes"),
                activityID: activity.id,
                goalID: nil,
                stepID: nil,
                minutes: mins,
                icon: activity.phIcon,
                tint: category.wash,
                ink: category.ink
            ))
            dismiss()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(category.wash)
                    .frame(width: 34, height: 34)
                    .overlay(BDPhIcon(icon: activity.phIcon, size: 16, color: category.ink))

                Text(activity.label)
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)

                Spacer(minLength: 8)

                // Minutes as a stepper you can ignore — never a required field.
                Text("\(mins)m")
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Color.bdTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.bdBarTrack))
                    .contentShape(Capsule())
                    .onTapGesture {
                        // 15 → 30 → 45 → 60 → 90 → 15. One tap cycles; no keyboard.
                        let ladder = [15, 30, 45, 60, 90]
                        let next = ladder.first(where: { $0 > mins }) ?? ladder[0]
                        minutes[activity.id] = next
                    }
                    .accessibilityLabel("\(mins) minutes")
                    .accessibilityHint("Tap to change the length")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Adds \(activity.label.lowercased()) to today's plate")
    }
}
