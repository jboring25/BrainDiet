import SwiftUI
import SwiftData

// MARK: - Mental Diet settings — adjust app categories after setup (spec-v2.1)
//
// The one-time categorization is done in onboarding; this is the OPTIONAL place
// to change your mind later. It edits the persisted UserProfile directly — still
// never a daily log, just a settings adjustment. Reuses the same three-way dot
// chooser vocabulary as the onboarding step so it feels like one system.

struct MentalDietSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: UserProfile

    /// Local working copy; committed to the profile on each change.
    @State private var categories: [String: AppCategory] = [:]

    /// The apps to show — everything the profile has categorized, plus the known
    /// catalog so nothing is missing.
    private var apps: [MonitoredAppOption] {
        var seen = Set<String>()
        var out: [MonitoredAppOption] = []
        for app in MonitoredAppOption.catalog where seen.insert(app.id).inserted {
            out.append(app)
        }
        for id in categories.keys where seen.insert(id).inserted {
            out.append(MonitoredAppOption(id: id, name: id.capitalized, symbol: "app.dashed"))
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        Text("Sorting your apps once keeps “Today's Mental Diet” accurate. Change anything here. It's never a daily task.")
                            .font(.bdBody)
                            .foregroundStyle(Color.bdTextSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: Theme.Space.lg) {
                            ForEach(AppCategory.allCases) { cat in
                                HStack(spacing: Theme.Space.xs) {
                                    Circle().fill(cat.color).frame(width: 8, height: 8)
                                    Text(cat.label).font(.bdCaption)
                                        .foregroundStyle(Color.bdTextSecondary)
                                }
                            }
                        }

                        VStack(spacing: Theme.Space.md) {
                            ForEach(apps) { app in
                                MentalDietAppRow(
                                    app: app,
                                    selected: categories[app.id] ?? .leisure
                                ) { newValue in
                                    categories[app.id] = newValue
                                    profile.appCategories = categories
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.screenX)
                    .padding(.top, Theme.Space.lg)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Mental Diet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bdAccentBright)
                }
            }
            .onAppear {
                categories = profile.appCategories
                // Backfill smart defaults for any known app not yet set.
                for app in MonitoredAppOption.catalog where categories[app.id] == nil {
                    categories[app.id] = AppCategoryCatalog.defaultCategory(forAppID: app.id)
                }
                profile.appCategories = categories
            }
        }
    }
}

// MARK: - Row (mirrors the onboarding chooser).

private struct MentalDietAppRow: View {
    let app: MonitoredAppOption
    let selected: AppCategory
    let onSelect: (AppCategory) -> Void

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: app.symbol)
                .font(.body)
                .foregroundStyle(Color.bdTextSecondary)
                .frame(width: 26)
            Text(app.name)
                .font(BDFont.body(.medium, size: 16, relativeTo: .body))
                .foregroundStyle(Color.bdTextPrimary)
            Spacer(minLength: Theme.Space.sm)
            HStack(spacing: Theme.Space.xs) {
                ForEach(AppCategory.allCases) { cat in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(Theme.Motion.snappy) { onSelect(cat) }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(selected == cat ? cat.softColor : Color.clear)
                                .frame(width: 34, height: 34)
                            if selected == cat {
                                Circle().fill(cat.color).frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(Color.black.opacity(0.22), lineWidth: 1))
                            } else {
                                Circle()
                                    .strokeBorder(Color.bdTextSecondary.opacity(0.35), lineWidth: 1.5)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(app.name): \(cat.label)")
                    .accessibilityAddTraits(selected == cat ? [.isSelected] : [])
                }
            }
        }
        .padding(.vertical, Theme.Space.sm)
        .padding(.horizontal, Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.bdSurface)
        )
    }
}
