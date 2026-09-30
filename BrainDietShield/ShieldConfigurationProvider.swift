import Foundation

// MARK: - BrainDiet ShieldConfiguration extension — THE INTERCEPT (spec-v2.4).
//
// The category-defining surface. When a rested app is opened, iOS asks this
// extension how to draw the shield — and instead of the punitive OS default we
// render THE BRIDGE AT THE FORK: the user's own identity, a short protected
// block, and the easy one-tap choice to spend the time on real life.
//
// GATED like the rest of the Family Controls stack: builds only when the
// entitlement + flag are present. It reads its identity-framed copy from the
// shared App Group (written by the app via ShieldContent) so it never needs the
// app's models. Colors mirror the appetite design system (warm off-black canvas,
// leaf primary with white label, warm off-white ink).
//
// IMPORTANT (Apple-side setup — see the deliverable checklist):
//   • This file belongs to a ShieldConfiguration app-extension target
//     ("BrainDietShieldConfig") the USER creates in Xcode (extension point
//     com.apple.ManagedSettingsUI.shield-configuration-service).
//   • The target needs: Family Controls capability, the SAME App Group
//     (group.com.jackboring.braindiet.shared), the granted family-controls entitlement,
//     and the -D BRAINDIET_FAMILY_CONTROLS Swift flag.
//   • The App-Group keys below MUST match ShieldContent.Keys in the app.

#if canImport(ManagedSettingsUI) && BRAINDIET_FAMILY_CONTROLS
import ManagedSettingsUI
import ManagedSettings
import UIKit

// Mirrors ShieldContent.Keys in the app (separate target → duplicated on purpose,
// exactly like MonitorConfig for the DeviceActivityMonitor).
// Mirrors InterceptPass in the app (separate target → duplicated on purpose,
// exactly like MonitorConfig). Keep the key strings identical.
private enum PassKeys {
    static let allowance = 3
    static let day   = "pass.day"
    static let spent = "pass.spent"

    /// The pass button's label, or nil when none may be offered.
    ///
    /// ⭐ RETURNING NIL DRAWS NO BUTTON, AND THAT IS THE POINT. Build 15 on
    /// device: a secondary button that could not do its job read as broken.
    /// A shield action can only answer `.close` or `.defer`, so there is no way
    /// to render a refusal that looks deliberate. The button therefore exists
    /// only while it works, and disappears when the allowance is spent.
    static func label() -> String? {
        guard let d = UserDefaults(suiteName: ShieldKeys.suite) else { return nil }
        var cal = Calendar.current
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: Date())
        let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let used = d.string(forKey: day) == key ? d.integer(forKey: spent) : 0
        let left = allowance - used
        guard left > 0 else { return nil }
        return left == 1 ? "Let me in · last pass today"
                         : "Let me in · \(left) passes left"
    }
}

private enum ShieldKeys {
    static let suite     = "group.com.jackboring.braindiet.shared"
    static let headline  = "shield.headline"
    static let body      = "shield.body"
    static let primary   = "shield.primary"
    static let secondary = "shield.secondary"
    static let symbol    = "shield.symbol"
    static let variants  = "shield.variants"
    static let cursor    = "shield.cursor"
}

// Design-system colors, duplicated as UIColors for the extension (no SwiftUI here).
private enum ShieldPalette {
    static let background = UIColor(red: 0x17/255, green: 0x13/255, blue: 0x0F/255, alpha: 1)     // warm off-black
    static let ink        = UIColor(red: 0xF2/255, green: 0xED/255, blue: 0xE4/255, alpha: 1)     // warm off-white
    static let inkSoft     = UIColor(red: 0x9C/255, green: 0x93/255, blue: 0x84/255, alpha: 1)    // warm taupe
    // Appetite palette (2026-07-18): leaf replaces the superseded sage family.
    static let sage        = UIColor(red: 0x3E/255, green: 0x7A/255, blue: 0x4E/255, alpha: 1)    // leaf #3E7A4E
    static let onSage      = UIColor.white                                                        // white on leaf (CTA law)
}

final class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    // All four shielded contexts route to the same identity-framed bridge.
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        bridge()
    }
    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        bridge()
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        bridge()
    }
    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        bridge()
    }

    // MARK: The bridge — built from the App-Group copy the app synced.

    private func bridge() -> ShieldConfiguration {
        let d = UserDefaults(suiteName: ShieldKeys.suite)

        var headline  = d?.string(forKey: ShieldKeys.headline)  ?? "You wanted your time back."
        var body      = d?.string(forKey: ShieldKeys.body)      ?? "There's still time today. Here's 20 minutes, protected. Go spend it on you."

        // One goal per interrupt, rotated by the action extension's cursor.
        if let variants = d?.array(forKey: ShieldKeys.variants) as? [[String: String]],
           !variants.isEmpty {
            let v = variants[max(0, d?.integer(forKey: ShieldKeys.cursor) ?? 0) % variants.count]
            headline = v["headline"] ?? headline
            body     = v["body"] ?? body
        }
        let primary   = d?.string(forKey: ShieldKeys.primary)   ?? "Feed my brain"
        let secondary = d?.string(forKey: ShieldKeys.secondary) ?? "Not now"
        let symbolName = d?.string(forKey: ShieldKeys.symbol)   ?? "sparkles"

        // Doctrine: the shield carries NO marketing copy — "Your brain eats too."
        // lives only on the PlanShareCard. The subtitle is the bridge, nothing else.
        let subtitleText = body

        // ⭐ THE ATTRACTION LAW (Jack, 2026-07-18 — supersedes the gray slop
        // card): the shield shows what the user COULD HAVE, never what they're
        // avoiding. `PlateInviteCard` is the nearly-complete midday plate baked
        // as a rounded card on white (from the aligned PlateMidday render),
        // designed to sit on the warm off-black shield bg — the beautiful meal,
        // one serving from done. The old `PlateSlopCard` asset stays on disk,
        // unused (same precedent as BDBrainMark/PlateSlop). It lives in this
        // extension target's own asset catalog (BrainDietShield/Assets.xcassets)
        // since the extension has no access to the app's catalog. Defensive
        // fallback to the synced SF Symbol if the asset is somehow unavailable.
        let icon = UIImage(named: "PlateInviteCard")
            ?? UIImage(systemName: symbolName)?
                .withTintColor(ShieldPalette.sage, renderingMode: .alwaysOriginal)

        // ⭐ THE SECONDARY BUTTON IS BACK, CONDITIONALLY (Jack, 2026-08-27).
        // It was removed in build 15 for being a dead control. It returns only
        // because it now DOES something: it lifts this app's shield for a few
        // minutes. `PassKeys.label()` is nil once the day's passes are gone, and
        // a nil label means the button is never drawn — so the rule that killed
        // it the first time is still enforced, by construction.
        let passLabel = PassKeys.label()

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: ShieldPalette.background.withAlphaComponent(0.92),
            icon: icon,
            title: .init(text: headline, color: ShieldPalette.ink),
            subtitle: .init(text: subtitleText, color: ShieldPalette.inkSoft),
            primaryButtonLabel: .init(text: primary, color: ShieldPalette.onSage),
            primaryButtonBackgroundColor: ShieldPalette.sage,
            secondaryButtonLabel: passLabel.map { .init(text: $0, color: ShieldPalette.inkSoft) }
            // ⛔️ THE RULE THAT KILLED THE FIRST SECONDARY BUTTON STILL STANDS.
            // Build 15, on device: "the button at the bottom that says Not now,
            // I don't know why that's there, because when I click it, nothing
            // happens." A shield action can only answer `.close` or `.defer`,
            // so a button that merely declines is indistinguishable from a
            // broken one, and `.close` just duplicates the primary.
            //
            // The old "Not now" had no outcome to give. The pass does: the
            // action extension lifts this app's token out of the junk store, so
            // `.defer` dismisses onto an app that is genuinely open. The moment
            // that stops being true — the allowance is spent — `label()` returns
            // nil and the button is not drawn at all. **Never render a shield
            // button that cannot do the thing it says.**
        )
    }
}
#else
// ⭐ 2026-08-13. If you are reading this in a compiler error: the target is
// missing BRAINDIET_FAMILY_CONTROLS (or the SDK), which compiles this whole
// file to NOTHING and ships a signed, embedded, EMPTY .appex. iOS then cannot
// instantiate the principal class and silently falls back to its own grey
// shield — which is exactly what builds 12 and 13 did. Fix the flag; never
// delete this guard.
#error("BrainDiet shield extension built without BRAINDIET_FAMILY_CONTROLS — it would ship empty.")
#endif
