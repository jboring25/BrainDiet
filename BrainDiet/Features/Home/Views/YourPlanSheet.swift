import SwiftUI

// MARK: - Your Plan sheet — the re-viewable signature "Brain Facts" artifact.
//
// A quiet place to re-open the plan card (the shareable nutrition-label) and see
// what protection is holding for you. Reached from Home's protection line.

struct YourPlanSheet: View {
    let plan: BrainPlan
    /// The persisted goals' daily servings, printed on the document.
    var servings: [PlanServing] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground(intensity: .hero)
                ScrollView {
                    VStack(spacing: Theme.Space.gutter) {
                        PlanCard(plan: plan, servings: servings, animate: false)

                        PlanShareButton(plan: plan, servings: servings, style: .prominent)

                        Text("Nothing to log. Your time comes back on its own. BrainDiet just holds the door.")
                            .font(.bdBody)
                            .foregroundStyle(Color.bdTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Theme.Space.sm)
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.vertical, Theme.Space.xl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bdAccentBright)
                }
            }
        }
    }
}

#Preview {
    YourPlanSheet(plan: .mock(goalNoun: "your reading list", why: "I want to write my book"))
}
