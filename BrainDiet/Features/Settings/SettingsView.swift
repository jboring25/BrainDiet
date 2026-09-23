import SwiftUI
import SwiftData

// MARK: - Settings / Plan — secondary surface (reached via the gear on Home).
//
// Not a tab. A quiet place for your plan, the state of your protection, and the
// account/purchase entries the App Store requires once IAP ships.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BlockingService.self) private var blocking
    @Environment(StoreService.self) private var store
    @Environment(\.usageProvider) private var usageProvider
    @Environment(\.openURL) private var openURL

    @Query private var profiles: [UserProfile]
    @State private var showPlan = false
    @State private var showMentalDiet = false
    @State private var showAppPicker = false
    @State private var showIntercept = false
    /// DEBUG seam (2026-08-06): `BD_OPEN_ADJUST=1` presents Adjust plan on
    /// appear. Added because the sheet was unreachable from the screenshot
    /// harness — every other reviewable surface has an env jump, and a surface
    /// that can't be captured can't be held to the same bar as the rest.
    @State private var showAdjustPlan = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_OPEN_ADJUST"] != nil
        #else
        return false
        #endif
    }()
    @State private var showPaywall = false
    @State private var isRestoring = false

    /// The intercept copy, built from the user's real headline goal.
    private var interceptContent: ShieldContent {
        ShieldContentBuilder.make(goalID: profiles.first?.headlineGoalID)
    }

    private var plan: BrainPlan {
        EngineContext(profile: profiles.first, usage: usageProvider).plan
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BDBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.gutter) {

                        section(title: "Your protection") {
                            row(icon: "leaf.fill", title: "Your plan", value: nil) { showPlan = true }
                            statusRow
                            #if DEBUG
                            row(icon: "arrow.turn.up.right", title: "Preview the moment", value: nil) {
                                showIntercept = true
                            }
                            #endif
                        }

                        if let profile = profiles.first {
                            section(title: "Your plan") {
                                // Low-prominence, friction-gated goal editing (spec-v2.6).
                                row(icon: "slider.horizontal.3", title: "Adjust plan", value: nil) {
                                    showAdjustPlan = true
                                }
                            }
                            .sheet(isPresented: $showAdjustPlan) {
                                AdjustPlanView(profile: profile)
                            }

                            section(title: "Your mental diet") {
                                // ⭐ CHANGE THE BLOCKED APPS (2026-08-13). Until
                                // now the app had NO surface for this anywhere —
                                // the picker existed and was never presented, so
                                // a selection could not be made or revised.
                                row(icon: "hand.raised", title: "Apps that pull you in",
                                    value: blocking.hasSelection ? "Set" : "Not set") {
                                    showAppPicker = true
                                }
                                row(icon: "fork.knife", title: "App categories", value: nil) {
                                    showMentalDiet = true
                                }
                            }
                            .sheet(isPresented: $showMentalDiet) {
                                MentalDietSettingsView(profile: profile)
                            }
                            .sheet(isPresented: $showAppPicker) {
                                FamilyPickerView { selection in
                                    profile.familySelectionData = selection.encoded
                                    blocking.updateSelection(selection)
                                    blocking.applyStandingShield()
                                }
                            }
                        }

                        // ⭐ REPLAY ONBOARDING (Jack, 2026-08-05). Onboarding is
                        // where the plan, the identity line and the mirror are
                        // built — and it was a ONE-SHOT experience with no way
                        // back in. Clearing `hasCompletedOnboarding` returns the
                        // user to the top of the flow; the existing steps already
                        // overwrite the profile + plan on completion, so a replay
                        // rebuilds rather than duplicates.
                        section(title: "Start over") {
                            row(icon: "arrow.counterclockwise", title: "Replay onboarding", value: nil) {
                                replayOnboarding()
                            }
                        }

                        section(title: "Account") {
                            // The quiet Pro entry — the paywall's only standing home.
                            row(icon: "sparkles",
                                title: "BrainDiet Pro",
                                value: store.isPro ? String(localized: "Active") : nil) {
                                showPaywall = true
                            }
                            row(icon: "arrow.clockwise",
                                title: "Restore purchases",
                                value: isRestoring ? String(localized: "Restoring…") : nil) {
                                guard !isRestoring else { return }
                                Task {
                                    isRestoring = true
                                    await store.restore()
                                    isRestoring = false
                                }
                            }
                            row(icon: "hand.raised.fill", title: "Privacy policy", value: nil) {
                                if let url = URL(string: "https://braindiet.netlify.app/privacy-policy.html") {
                                    openURL(url)
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bdAccentBright)
                }
            }
            .sheet(isPresented: $showPlan) { YourPlanSheet(plan: plan) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            #if DEBUG
            .fullScreenCover(isPresented: $showIntercept) {
                InterceptPreviewView(content: interceptContent) { showIntercept = false }
            }
            .onAppear {
                // Screenshot helpers (combine with BD_SHOW_SETTINGS=1): the two
                // sub-sheets that were previously unreachable via env-jump.
                if ProcessInfo.processInfo.environment["BD_SHOW_ADJUST"] == "1" {
                    showAdjustPlan = true
                }
                if ProcessInfo.processInfo.environment["BD_SHOW_DIET_SETTINGS"] == "1" {
                    showMentalDiet = true
                }
            }
            #endif
        }
    }

    /// Send the user back to the start of onboarding. The flow rewrites the
    /// profile and plan when it completes, so this re-runs rather than clones.
    /// Dismiss first so Home isn't left mounted under the swap.
    private func replayOnboarding() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
    }

    @ViewBuilder

    private func section<Content: View>(title: LocalizedStringResource, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text(title)
                .font(.bdEyebrow)
                .kerning(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdTextSecondary)
            VStack(spacing: 0) { content() }
        }
    }

    private var statusRow: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: blocking.isAuthorized ? "checkmark.seal.fill" : "moon.zzz")
                .font(.system(size: 15))
                .foregroundStyle(blocking.isAuthorized ? Color.bdAccent : Color.bdTextSecondary)
                .frame(width: 24)
            Text(blocking.isAuthorized
                 ? String(localized: "Protection is running")
                 : String(localized: "Protection isn't active yet"))
                .font(BDFont.body(.regular, size: 16, relativeTo: .body))
                .foregroundStyle(Color.bdTextPrimary)
            Spacer()
        }
        .frame(minHeight: Theme.Size.minTouch)
    }

    private func row(icon: String, title: LocalizedStringResource, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.md) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(width: 24)
                Text(title)
                    .font(BDFont.body(.regular, size: 16, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                Spacer()
                if let value {
                    Text(value).font(.bdCaption).foregroundStyle(Color.bdTextSecondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.bdTextSecondary)
            }
            .frame(minHeight: Theme.Size.minTouch)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environment(BlockingService())
        .environment(StoreService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
