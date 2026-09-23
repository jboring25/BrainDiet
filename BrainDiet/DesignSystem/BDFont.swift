import SwiftUI
import CoreText

// MARK: - Brain Diet fonts (appetite pass, 2026-07-18)
//
// TWO voices, one discipline:
//   • Young Serif (OFL, single 400 weight) — the DISPLAY face. The warm
//     cookbook voice: hero headlines, the mirror numerals, Home's headline,
//     onboarding question titles. Character lives HERE, in the few big moments.
//   • Manrope (OFL) — ALL body / UI / labels / captions / buttons. The quiet
//     Linear / Apple Health workhorse. Never the hero.
//
// Cabinet Grotesk (FFL) stays bundled but is RETIRED from the display role
// (2026-07-18, Jack-approved appetite direction) — `grotesk(_:)` now resolves
// to Young Serif so every display call site migrated in one move.
//
// LICENSES: Resources/Fonts/OFL-Manrope.txt · OFL-YoungSerif.txt ·
// FFL-CabinetGrotesk.txt (retained with the retired files).
//
// Registered programmatically at launch (generated Info.plist; no UIAppFonts).
// SF Pro remains the system fallback only.
//
// The legacy `Display` enum still resolves to Manrope (it's used in LABEL
// contexts — the printed plan card, percents). The true display face routes
// through `serif(_:)` / the `bdDisplay` + `bdInstrument` tokens.

enum BDFont {

    // MARK: The DISPLAY face — Young Serif (one weight; that's the discipline).
    enum Serif: String {
        case regular = "YoungSerif-Regular"
    }

    // Legacy Cabinet Grotesk names (files retained; face retired 2026-07-18).
    enum Grotesk: String {
        case extrabold = "CabinetGrotesk-Extrabold"
        case bold      = "CabinetGrotesk-Bold"
    }

    // Legacy "display" shim — Manrope, used in printed-label/UI contexts.
    enum Display: String {
        case extraBold = "Manrope-ExtraBold"
        case bold      = "Manrope-Bold"
        case semiBold  = "Manrope-SemiBold"
        case medium    = "Manrope-Medium"
    }
    enum Body: String {
        case regular  = "Manrope-Regular"
        case medium   = "Manrope-Medium"
        case semiBold = "Manrope-SemiBold"
        case bold     = "Manrope-Bold"
    }

    private static let allFiles: [(name: String, ext: String)] = [
        ("Manrope-Regular", "ttf"), ("Manrope-Medium", "ttf"), ("Manrope-SemiBold", "ttf"),
        ("Manrope-Bold", "ttf"), ("Manrope-ExtraBold", "ttf"),
        ("YoungSerif-Regular", "ttf"),
        ("CabinetGrotesk-Extrabold", "otf"), ("CabinetGrotesk-Bold", "otf")
    ]

    /// Call once at launch. Idempotent (re-registration errors are harmless).
    static func registerAll() {
        for file in allFiles {
            guard let url = Bundle.main.url(forResource: file.name, withExtension: file.ext) else {
                Log.app.error("Missing bundled font: \(file.name, privacy: .public)")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: Builders — scale with Dynamic Type via relativeTo.

    /// The DISPLAY face (Young Serif) — hero numerals + headline moments only.
    static func serif(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(Serif.regular.rawValue, size: size, relativeTo: style)
    }
    /// Legacy display shim — Cabinet Grotesk call sites now resolve to Young
    /// Serif (the 2026-07-18 appetite migration; the weight argument is moot,
    /// Young Serif ships one weight by design).
    static func grotesk(_ face: Grotesk, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        _ = face
        return serif(size: size, relativeTo: style)
    }
    static func display(_ face: Display, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(face.rawValue, size: size, relativeTo: style)
    }
    static func body(_ face: Body, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(face.rawValue, size: size, relativeTo: style)
    }
}

// MARK: - Semantic type tokens (the rest of the app inherits these)
//
// Hierarchy is SIZE-led and deliberately wide: a confident display, a clear
// title, then a hard, calm drop to quiet body / caption / eyebrow. Weights stay
// restrained (SemiBold is the heaviest UI weight; only instruments go heavier).
// Pair these with generous `.lineSpacing(...)` on multi-line copy at the site.

extension Font {
    /// Hero display — onboarding hooks, reveal headlines. The DISPLAY face.
    static var bdDisplay: Font { BDFont.serif(size: 40, relativeTo: .largeTitle) }
    /// Onboarding question title — the serif voice at quiz scale (mockup: 30px).
    static var bdQuestionTitle: Font { BDFont.serif(size: 30, relativeTo: .title) }
    /// Screen title.
    static var bdTitle: Font { BDFont.display(.semiBold, size: 27, relativeTo: .title) }
    /// Section heading. Lets size do the work.
    static var bdHeadline: Font { BDFont.display(.semiBold, size: 19, relativeTo: .title3) }
    /// Eyebrow / label caption (uppercase tracking applied at the view).
    static var bdEyebrow: Font { BDFont.body(.semiBold, size: 11, relativeTo: .caption) }

    /// Body copy. Regular, with generous leading at the call site.
    static var bdBody: Font { BDFont.body(.regular, size: 16, relativeTo: .body) }
    /// Emphasized body.
    static var bdBodyStrong: Font { BDFont.body(.semiBold, size: 16, relativeTo: .body) }
    /// Button label.
    static var bdButton: Font { BDFont.body(.semiBold, size: 17, relativeTo: .headline) }
    /// Small caption.
    static var bdCaption: Font { BDFont.body(.medium, size: 13, relativeTo: .footnote) }

    // MARK: Instruments — the DISPLAY face (Young Serif) for the hero numerals:
    // score, timer, reclaimed time, the mirror numbers. Use `.monospacedDigit()`
    // at the call site for ticking numbers.

    /// The big hero instrument number (reclaimed hours, score, countdown).
    static func bdInstrument(_ size: CGFloat) -> Font {
        BDFont.serif(size: size, relativeTo: .largeTitle)
    }
}
