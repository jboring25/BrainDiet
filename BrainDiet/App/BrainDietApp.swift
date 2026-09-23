import SwiftUI
import SwiftData
import RevenueCat

// MARK: - App Entry Point (spec-v2: fully automatic, three surfaces).
//
// Gate: `hasCompletedOnboarding` (@AppStorage) decides Onboarding vs. Main.
//
// PERSISTENCE: SwiftData holds ONLY the UserProfile now (onboarding answers +
// baseline). The manual Diary is gone — reclaimed time is derived automatically
// from Screen Time / DeviceActivity via the UsageProvider (real when entitled,
// a graceful degraded/seeded state otherwise).

@main
struct BrainDietApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var router = AppRouter()
    /// THE one state object (PLATE-ENGINE.md) — every screen reads from it.
    @State private var plateEngine = PlateEngine()
    @State private var blocking = BlockingService()
    /// StoreKit 2 — the one monetization seam (isPro), injected app-wide.
    @State private var store = StoreService()

    /// The automatic reclaimed-time data source (real Screen Time when entitled,
    /// graceful degraded/seeded otherwise). Injected app-wide.
    private let usage: UsageProvider = UsageProviderFactory.make()

    /// DEBUG screenshot helper: force the onboarding flow to a given step.
    private var forceOnboarding: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BD_ONBOARDING_STEP"] != nil
        #else
        return false
        #endif
    }

    init() {
        BDFont.registerAll()
        // RevenueCat must be configured BEFORE StoreService's init task reads an
        // entitlement, or the first read races the SDK and reports free.
        // No key = skip entirely; StoreService falls back to pure StoreKit.
        if RevenueCatConfig.isConfigured {
            Purchases.logLevel = .warn          // never log purchase PII at .debug in a shipped build
            Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        }
        #if DEBUG
        if DemoSeed.isRequested {
            DemoSeed.seedIfRequested(modelContainer.mainContext)
        }
        if AdMode.isEnabled {
            AdSeed.seedIfRequested(modelContainer.mainContext)
        }
        #endif
    }

    /// Local-first store — the user profile + the Protect session history
    /// (the keystone record of where reclaimed time went) persist across launches.
    let modelContainer: ModelContainer = {
        // Pre-create Application Support so a truly-empty container doesn't log an
        // NSCocoaError 512 (create-then-recover) the first time the store is built.
        _ = try? FileManager.default.url(for: .applicationSupportDirectory,
                                         in: .userDomainMask,
                                         appropriateFor: nil,
                                         create: true)
        do {
            return try ModelContainer(for: UserProfile.self, ProtectSession.self, Goal.self, GoalStep.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// DEBUG ad capture: a standalone shot (brain-loop/commit/plan/green/endtag)
    /// replaces the whole surface; `open` and `unspin` run the real Home reveal
    /// (unspin lands it from a 260%/70° spin first).
    #if DEBUG
    // ⭐ CultureLabView + BD_CULTURE removed 2026-09-09. It was a harness for the
    // honeycomb and branch hero directions, both superseded by the cloud, and it
    // was the ONLY thing referencing them — 777 lines kept alive by a debug jump.
    private var adStandaloneShot: AdMode.Shot? {
        guard AdMode.isEnabled, AdMode.shot != .open, AdMode.shot != .unspin else { return nil }
        return AdMode.shot
    }
    #endif

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let shot = adStandaloneShot {
                    AdShotView(shot: shot)
                        .adWarmGrade(AdMode.appliesWarmGrade)
                } else {
                    rootContent
                        .modifier(AdUnspinEntrance(active: AdMode.isEnabled && AdMode.shot == .unspin))
                        .adWarmGrade(AdMode.appliesWarmGrade)
                }
                #else
                rootContent
                #endif
            }
            .environment(blocking)
            .environment(store)
            .environment(plateEngine)
            .environment(\.usageProvider, usage)
            .preferredColorScheme(.light)   // v7: warm-white theme — status bar + system chrome read dark-on-light
            .tint(Color.bdAccent)
            #if DEBUG
            .onAppear {
                if DemoSeed.isRequested || AdMode.isEnabled { hasCompletedOnboarding = true }
            }
            #endif
        }
        .modelContainer(modelContainer)
    }

    /// The production surface: onboarding gate → MainView.
    @ViewBuilder
    private var rootContent: some View {
        if hasCompletedOnboarding && !forceOnboarding {
            MainView()
                .environment(router)
        } else {
            OnboardingView(onComplete: {
                // The dismissible Pro paywall now lives INSIDE onboarding
                // (the .onboardingPaywall step after plan reveal), so we no
                // longer queue a second launch-time showing — that would
                // double-paywall the user. Clear any stale flag.
                UserDefaults.standard.set(false, forKey: "bd.pendingLaunchPaywall")
                hasCompletedOnboarding = true
            })
        }
    }
}

// MARK: - UsageProvider environment injection

private struct UsageProviderKey: EnvironmentKey {
    static let defaultValue: UsageProvider = DegradedUsageProvider()
}

extension EnvironmentValues {
    var usageProvider: UsageProvider {
        get { self[UsageProviderKey.self] }
        set { self[UsageProviderKey.self] = newValue }
    }
}
