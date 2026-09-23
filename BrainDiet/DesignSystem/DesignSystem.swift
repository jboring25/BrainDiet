import SwiftUI

// MARK: - Brain Diet Design System — Art Direction v3 (CALM LUXURY)
//
// Calm confidence + luxury: Linear's quiet, Apple Health's clarity, Opal's
// restraint. A deep charcoal-navy base with subtly-lifted cards, ONE muted jade
// accent, generous whitespace, and depth through layering + soft shadows (not
// outlines). The cream nutrition label stays as the reserved share artifact.
//
// SINGLE SOURCE OF TRUTH for color, material, spacing, and shape tokens.
// (Type tokens live in BDFont.swift.) Views reference semantic tokens only —
// never raw hex, never magic numbers.
//
// Palette discipline:
//   • Charcoal-navy base; cards = tonal LIFT off the bg (depth via layering).
//   • ONE accent: muted jade — CTAs, score arc, key emphasis. NO standing gold.
//   • Traffic-light = small DESATURATED data markers only (sage / sand / clay).

// MARK: - Hex helper

extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Semantic palette

extension Color {

    // ⭐ APPETITE CANVAS (2026-07-18, Jack-approved — supersedes the flat-white v7
    // base). The canvas is warm CREAM (#FDF9F2, the mockup's --cream); cards stay
    // pure WHITE so they lift gently off it with the hairline + soft shadow. The
    // plate renders still melt in via multiply (white backdrop × cream = cream).
    // Spec of record: design/plate-concepts/appetite-mockups.html.
    static let bdBackground   = Color(hex: "#FDF9F2")   // cream canvas — appetite
    static let bdBackgroundDeep = Color(hex: "#F4EFE7")  // warm off-white floor
    static let bdBackgroundWarm = Color(hex: "#FBF7F0")  // warm lift
    static let bdSurface      = Color(hex: "#FFFFFF")   // cards = white (border + shadow define them)
    static let bdSurfaceHi     = Color(hex: "#FBF7F0")  // elevated surface (warm off-white)
    // Warm hairline stroke for the card edge (mockup --line).
    static let bdCardBorder   = Color(hex: "#EFE7DA")
    // A whisper-thin divider, used SPARINGLY.
    static let bdHairline     = Color(hex: "#2C2519", alpha: 0.06)
    // Slim-bar track on white cards (mockup .bar background).
    static let bdBarTrack     = Color(hex: "#F1EBE1")

    // ⭐ THE CATEGORY-COLOR LAW (2026-07-18): every chip/bar/tile/icon that stands
    // for a category wears its color, on EVERY screen (Becoming included):
    //   Learning = leaf · Focus = salmon · Creativity = berry ·
    //   Entertainment/dessert = honey · Junk/slop = GRAY (honest-cost: gray is
    //   junk's color by law — never red, never a spotlight).
    static let bdLeaf         = Color(hex: "#3E7A4E")   // Learning — brain vegetables
    static let bdLeafTint     = Color(hex: "#E9F3EB")
    static let bdLeafDeep     = Color(hex: "#2F5E3C")   // the CTA pill fill (white text)
    static let bdSalmon       = Color(hex: "#E8735A")   // Focus — brain protein (+ the appetite display accent)
    static let bdSalmonTint   = Color(hex: "#FBEAE5")
    static let bdHoney        = Color(hex: "#D9A441")   // Entertainment — dessert
    static let bdHoneyTint    = Color(hex: "#FAF0DC")
    static let bdHoneyText    = Color(hex: "#8A6A2E")   // honey-as-TEXT (contrast-safe)
    static let bdSlopGray     = Color(hex: "#9A948C")   // Junk — gray by law
    static let bdSlopTint     = Color(hex: "#EEECE8")
    static let bdSlopFaint    = Color(hex: "#B5AFA6")   // junk row's food-caption ink
    // ⭐ LEGIBLE LOSS-GRAY (2026-07-22 senior-UX contrast pass). `bdSlopGray`
    // is a FILL color (2.69:1 on the gray canvas) — it fails WCAG as text. Loss
    // copy stays gray BY LAW, it just has to be readable, so text uses these:
    //   • bdSlopGrayText — body-size loss ink. 4.91:1 on #F4F2EF (gray canvas),
    //     5.23:1 on #FDF9F2 (cream) → AA everywhere in the gray→cream arc.
    //   • bdSlopGrayDisplay — the 76pt Young Serif loss numerals (large text,
    //     3:1 floor). 3.94:1 on gray canvas, 4.20:1 on cream — still visibly
    //     drained next to the colored gain rows (leaf 4.88 / berry 5.86).
    static let bdSlopGrayText    = Color(hex: "#6F6860")
    static let bdSlopGrayDisplay = Color(hex: "#7F776E")

    // The GRAY WORLD (onboarding's hijack + timeLost arc — color drains, then
    // returns at domains).
    static let bdGrayCanvas   = Color(hex: "#F4F2EF")
    static let bdGrayInk      = Color(hex: "#5F5A52")
    static let bdGrayTile     = Color(hex: "#FBFAF8")   // gray-world tile fill
    static let bdGrayTileBorder = Color(hex: "#E5E1DA")
    static let bdGrayChip     = Color(hex: "#EDEAE4")   // unselected icon chip
    static let bdGrayChipSel  = Color(hex: "#E3E0DA")   // selected (muted) icon chip
    static let bdGrayFaint    = Color(hex: "#A9A29A")   // gray-world caption ink
    static let bdTabMuted     = Color(hex: "#B9B0A2")   // unselected tab / gear ink
    static let bdProgressTrack = Color(hex: "#DDD9D2")  // onboarding progress track

    // CREAM / paper — warm-white journal surface (used in more content moments now).
    // Soft shadow defines the edge — no border.
    static let bdCream        = Color(hex: "#F4EEE2")
    static let bdPaper        = Color(hex: "#FAF5EB")
    static let bdInk          = Color(hex: "#2C2519")   // ink (text on cream)
    static let bdInkSoft      = Color(hex: "#6B6051")   // muted secondary ink
    static let bdInkHairline  = Color(hex: "#2C2519", alpha: 0.12) // printed-label hairline

    // THE one BRAND accent — LEAF green (appetite pass 2026-07-18; was soft
    // sage). It owns the CHROME: CTAs, selection, nav tint, growth ring.
    static let bdAccent       = Color(hex: "#3E7A4E")   // leaf — CTA / chrome / growth ring
    static let bdAccentBright  = Color(hex: "#5F9268")  // a hair lighter — ring top / selected
    static let bdAccentDeep    = Color(hex: "#2F5E3C")  // leaf-deep — the CTA pill
    static let bdAccentSoft    = Color(hex: "#3E7A4E", alpha: 0.12)
    // Warm sand — gentle harmonious warmth (NOT a competing accent).
    static let bdGold         = Color(hex: "#D8B98C")   // warm sand
    static let bdGoldDeep     = Color(hex: "#C2A275")   // deeper sand — FILLS/icons (fails as text on white)
    static let bdGoldSoft     = Color(hex: "#D8B98C", alpha: 0.14)
    // Contrast-safe deep gold for GOLD TEXT on white (5.0:1 on #FFFFFF). The sand
    // tones above are for fills/icons only — they fail as text on the white theme.
    static let bdGoldText     = Color(hex: "#8A6A2E")

    // MARK: Semantic DATA colors (v6) — color = MEANING, like Apple Health rings.
    // Purposeful, never decorative. These carry the diary categories + charts +
    // the reclaimed-time hero. Muted/organic (Gentler Streak), NOT neon.
    //   • Emerald = reclaimed time (the hero metric)
    //   • Blue    = learning / nourishing content
    //   • Amber   = casual / easygoing
    //   • Coral   = mindless scroll
    static let bdEmerald      = Color(hex: "#57B894")   // reclaimed time — the hero
    static let bdEmeraldDeep   = Color(hex: "#3E9E7C")  // gradient base
    static let bdEmeraldSoft   = Color(hex: "#57B894", alpha: 0.16)
    static let bdBlue         = Color(hex: "#6AA6D9")   // learning / nourishing
    static let bdBlueSoft      = Color(hex: "#6AA6D9", alpha: 0.16)
    static let bdAmber        = Color(hex: "#E0B061")   // casual / easygoing
    static let bdAmberSoft      = Color(hex: "#E0B061", alpha: 0.16)
    static let bdCoral        = Color(hex: "#E08A70")   // mindless scroll
    static let bdCoralSoft      = Color(hex: "#E08A70", alpha: 0.16)

    // Nourishment markers now map to the SEMANTIC data palette (was monochrome):
    //   nourishing → blue (learning) · easygoing → amber · mindless → coral.
    // Emerald stays reserved for the reclaimed-time hero so it reads as THE win.
    static let bdNourish      = Color(hex: "#6AA6D9")   // blue — learning
    static let bdNeutral      = Color(hex: "#E0B061")   // amber — easygoing
    static let bdJunk         = Color(hex: "#E08A70")   // coral — mindless
    static let bdNourishSoft  = Color(hex: "#6AA6D9", alpha: 0.16)
    static let bdNeutralSoft  = Color(hex: "#E0B061", alpha: 0.16)
    static let bdJunkSoft      = Color(hex: "#E08A70", alpha: 0.16)

    // MARK: Onboarding TILE HUES (2026-07-08) — color-as-meaning makes the quiz
    // feel alive. Muted-but-rich EDITORIAL tones, never saturated crayon primaries.
    // Deliberate hierarchy: ASPIRATIONAL DOMAINS are VIBRANT ("your life in color");
    // HIJACKERS are COOLER + DESATURATED ("the feed you're setting aside is grey").
    // Each tile: its hue as the icon color + a same-hue tint wash + a colored border
    // + a soft hue lift when selected. Distinct from the semantic DATA colors so the
    // two systems never fight.

    // Aspiration domains — vibrant, warm-forward.
    static let bdDomReading   = Color(hex: "#E3B36B")  // warm amber / gold
    static let bdDomFitness   = Color(hex: "#5FBF98")  // emerald
    static let bdDomMusic     = Color(hex: "#E29089")  // warm rose-coral (NOT the brain pink)
    static let bdDomBuilding  = Color(hex: "#7CA7CE")  // steel-blue
    static let bdDomWriting   = Color(hex: "#B792CE")  // plum / violet
    static let bdDomLearning  = Color(hex: "#6FA8DB")  // blue
    static let bdDomOutdoors  = Color(hex: "#86B98F")  // forest-sage
    static let bdDomCreating  = Color(hex: "#E7A968")  // apricot / gold

    // Hijackers — cooler + one step MORE desaturated than the domains, so the
    // "junk to set aside" reads deliberately less alive than the goals.
    static let bdHijNews       = Color(hex: "#8B95A1")  // slate
    static let bdHijSocial     = Color(hex: "#C58A82")  // muted coral
    static let bdHijShortVideo = Color(hex: "#D07C73")  // dim red-coral (the worst offender)
    static let bdHijYoutube    = Color(hex: "#C39177")  // muted red-amber
    static let bdHijGames      = Color(hex: "#9989B1")  // muted violet
    static let bdHijMessaging  = Color(hex: "#7F98B4")  // muted blue

    // THE BRAIN — the one living object (soul pass, 2026-07-02). Rose-coral pink
    // is RESERVED for the brain mark + its glow; it appears nowhere else in the
    // UI. Two fill tones + one seam tone, nothing more.
    static let bdBrainPinkLight = Color(hex: "#F2A0B5")  // gradient top
    static let bdBrainPink      = Color(hex: "#DE5F80")  // gradient base / glow
    static let bdBrainPinkDeep  = Color(hex: "#B84163")  // lobe seams / tucked depth

    // "Slop" — the junk slice on the tray. Muted gray-brown: junk food for
    // the mind looks unappetizing, never a bright warning color.
    static let bdSlop           = Color(hex: "#6B5D4F")
    static let bdSlopDeep       = Color(hex: "#544737")   // slop mound base (matte depth)

    // THE MEAL TRAY (BDMealTray) — the ONE surface where food is VISUALIZED.
    // These tokens exist for the tray alone; food illustration anywhere else
    // stays banned (the metaphor lives in copy + mechanics everywhere else).
    static let bdTray            = Color(hex: "#2F2820")  // tray body, top-lit
    static let bdTrayDeep       = Color(hex: "#241E17")   // tray body base
    static let bdTrayWell      = Color(hex: "#141008")    // recessed compartment well
    // Nourishing portion — glowing warm golden-amber (the only glow on the card).
    static let bdPortionGoldLight = Color(hex: "#F3D9A0") // portion top sheen
    static let bdPortionGold      = Color(hex: "#E3B96E") // portion body
    static let bdPortionGoldDeep  = Color(hex: "#C2934A") // portion base
    // Leisure portion — pleasant matte amber, deliberately glow-free.
    static let bdPortionLeisure     = Color(hex: "#B08A50")
    static let bdPortionLeisureDeep = Color(hex: "#93713F")

    // Legacy mockup-era names, RE-POINTED to the appetite palette (2026-07-18)
    // so every existing call site sweeps to the new system in one move. New
    // code should prefer the bdLeaf/bdSalmon/bdBerry/bdHoney/bdSlopGray names.
    static let bdSage         = Color(hex: "#3E7A4E")   // → leaf (text/selected)
    static let bdSageSoft     = Color(hex: "#E9F3EB")   // → leaf tint
    static let bdSageFill     = Color(hex: "#3E7A4E")   // → leaf (bars + pulse dot)
    static let bdSageBorder   = Color(hex: "#CBDCC9")   // toast/suggested border on white
    static let bdGoldAccent   = Color(hex: "#B98F1F")   // steam-spark gold + reclaimed-time number (unchanged)
    static let bdGoldWash     = Color(hex: "#FAF0DC")   // → honey tint (dessert chip wash)
    static let bdMeat         = Color(hex: "#E8735A")   // → salmon (Focus — brain protein)
    static let bdMeatSoft     = Color(hex: "#FBEAE5")
    static let bdBerry        = Color(hex: "#9C4368")   // → berry (Creativity — brain fruit)
    static let bdBerrySoft    = Color(hex: "#F6E7EE")
    static let bdSlopLight    = Color(hex: "#9A948C")   // → slop gray (junk row ink)
    static let bdSlopSoft     = Color(hex: "#EEECE8")   // → slop tint (junk chip wash)

    // Text on the cream base — warm near-black + warm taupe (mockup --ink/--sub).
    static let bdTextPrimary   = Color(hex: "#2A231A")  // ink
    static let bdTextSecondary = Color(hex: "#8A7E6F")  // sub — mockup value
    static let bdTextOnAccent  = Color(hex: "#FFFFFF")  // white on the leaf-deep pill
}

// MARK: - Theme namespace (material, spacing, shape, motion)

enum Theme {

    // MARK: Spacing — 4 / 8 pt scale, opened up for calm-luxury whitespace.
    // `lg`/`xl` now carry inter-section breathing room; `gutter` is the big
    // between-block rhythm on scroll screens. Every block should breathe.
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        static let xxl: CGFloat = 64
        static let gutter: CGFloat = 40    // big Opal-style gap between sections
        static let screenX: CGFloat = 28   // wider page margins
        static let cardPad: CGFloat = 22   // generous interior card padding
    }

    // MARK: Shape — larger, softer radii (calm-luxury = 20–24).
    // RULE: cards = `card` (22). Primary buttons = `pill`. Chips/inputs = `control` (16).
    // The cream "label" reads as printed → slightly sharper `label` (14).
    enum Radius {
        static let control: CGFloat = 16
        static let label: CGFloat = 14     // cream nutrition-label artifact (printed feel)
        static let card: CGFloat = 22
        /// The mockup's compact Home card (plate-in-app variant A: 18pt).
        static let cardCompact: CGFloat = 18
        static let sheet: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Size {
        static let minTouch: CGFloat = 44
        static let buttonHeight: CGFloat = 56
    }

    enum Motion {
        static let snappy: Animation = .spring(response: 0.34, dampingFraction: 0.82)
        static let smooth: Animation = .easeInOut(duration: 0.25)
        /// "Plating" assembly — slightly looser for the staggered reveal.
        static let plate: Animation = .spring(response: 0.55, dampingFraction: 0.86)
    }

    // MARK: Shadows — soft, low-opacity, WARM-tinted. v6: cards FLOAT via a
    // subtle shadow + a hairline top edge. Depth returns, but stays premium.
    enum Shadow {
        // Soft WARM card-shadow (v7 white theme) — warm-tinted α, not black smudge.
        static let cardColor = Color(hex: "#2C2519", alpha: 0.10)
        static let cardRadius: CGFloat = 20
        static let cardY: CGFloat = 10
        // Soft paper-shadow under the cream artifact.
        static let paperColor = Color(hex: "#2C2519", alpha: 0.10)
        static let paperRadius: CGFloat = 34
        static let paperY: CGFloat = 20
        // Legacy lift token (kept so any reference resolves; matches card shadow).
        static let liftColor = Color(hex: "#2C2519", alpha: 0.08)
        static let liftRadius: CGFloat = 16
        static let liftY: CGFloat = 8
    }

    // MARK: Gradients — soft, never neon. A gentle diagonal top-light so buttons
    // and accent surfaces read dimensional, not flat.
    enum Gradient {
        /// Sage CTA fill — a soft top-lit sage, deeper at the base.
        static var accent: LinearGradient {
            LinearGradient(
                colors: [Color.bdAccentBright, Color.bdAccent, Color.bdAccentDeep],
                startPoint: .top, endPoint: .bottom)
        }
        /// Emerald hero fill (reclaimed-time ring) — the earned-win gradient.
        static var emerald: LinearGradient {
            LinearGradient(
                colors: [Color.bdEmerald, Color.bdEmeraldDeep],
                startPoint: .topTrailing, endPoint: .bottomLeading)
        }
    }
}

// MARK: - Materiality

/// Procedural paper grain — faint warm noise + two soft radial stains. Used on
/// cream "label" surfaces so they read as printed paper, not flat fill.
/// Honors Reduce Transparency (drops the grain, keeps the surface legible).
struct PaperGrain: View {
    var body: some View {
        if UIAccessibility.isReduceTransparencyEnabled {
            Color.clear
        } else {
            ZStack {
                // Two faint warm radial stains for organic unevenness.
                RadialGradient(
                    colors: [Color(hex: "#B08850", alpha: 0.05), .clear],
                    center: UnitPoint(x: 0.22, y: 0.12), startRadius: 0, endRadius: 300)
                RadialGradient(
                    colors: [Color(hex: "#C9897A", alpha: 0.04), .clear],
                    center: UnitPoint(x: 0.82, y: 0.92), startRadius: 0, endRadius: 320)
                // Fine speckle grain.
                Canvas { ctx, size in
                    var rng: UInt64 = 0x9E3779B97F4A7C15
                    func rand() -> Double {
                        rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17
                        return Double(rng % 10_000) / 10_000
                    }
                    let dots = Int((size.width * size.height) / 900)
                    for _ in 0..<dots {
                        let x = rand() * size.width
                        let y = rand() * size.height
                        let a = 0.015 + rand() * 0.03
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.0, height: 1.0)),
                            with: .color(Color(hex: "#2A1F16", alpha: a))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - App canvas (v9 — APPETITE CREAM, 2026-07-18)
//
// The approved appetite mockups run on a flat warm-cream canvas (#FDF9F2):
// color comes from the CONTENT (the plate render, the category colors), never
// from atmosphere. Plate renders keep melting in via multiply (white backdrop
// × cream = cream). The API (`intensity`, `tint`) and the GeometryReader
// structure are kept so every call site still compiles; they are inert.

enum CanvasIntensity {
    case hero, standard, calm
}

struct BDBackground: View {
    var intensity: CanvasIntensity = .standard
    /// Kept for API compatibility — unused on the flat white canvas.
    var tint: Color? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Flat pure white — the plate render's white bg melts in seamlessly.
                Color.bdBackground

                #if DEBUG
                // Screenshot seam (2026-08-14): `BD_BG=A|B` lays a candidate
                // background photo across the top of the canvas so a background
                // can be judged BEHIND THE REAL UI instead of as a photograph.
                // The two read completely differently — see the vineyard pass.
                // DEBUG-only; the shipped canvas is still flat cream.
                if let photo = Self.mockupPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width,
                               height: geo.size.width * photo.size.height / photo.size.width,
                               alignment: .top)
                        .clipped()
                        // Dissolve the lower third into the cream so the photo
                        // has no bottom edge — a hard line reads as a banner.
                        .mask(
                            LinearGradient(stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.62),
                                .init(color: .black.opacity(0), location: 1)
                            ], startPoint: .top, endPoint: .bottom)
                        )
                }
                #endif
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }

    #if DEBUG
    /// Loaded once — `UIImage(contentsOfFile:)` rather than `Image(_:)` because
    /// these live as loose bundle resources, not in the asset catalog.
    private static let mockupPhoto: UIImage? = {
        guard let tag = ProcessInfo.processInfo.environment["BD_BG"],
              let path = Bundle.main.path(forResource: "bd-bg-\(tag)", ofType: "jpg")
        else { return nil }
        return UIImage(contentsOfFile: path)
    }()
    #endif
}


// MARK: - BDProgressRing — the thin, elegant instrument ring (calm-luxury).
//
// The refined middle between v1's heavy bloom and v2's flat shapes: a THIN
// stroke, a faint track, a subtle jade gradient on the progress arc, and a soft
// restrained glow. Generous negative space inside the ring (content sits in the
// middle). Honors Reduce Transparency (drops the glow).
//
// `active` gates the soft glow so it only blooms on the earned beat (score hit,
// session nearing completion); otherwise the arc is elegant but calm.

struct BDProgressRing: View {
    var progress: CGFloat                 // 0...1
    var lineWidth: CGFloat = 2.5          // Apple-Watch-thin hairline arc (v4)
    var active: Bool = false              // earned-moment glow
    var animation: Animation? = nil
    /// Optional gradient sweep for the arc (v6). Defaults to the sage brand ring;
    /// pass `.emerald`/`.accent` for the hero rings so the fill reads dimensional.
    var gradient: AngularGradient? = nil
    var glowColor: Color = .bdAccent

    var body: some View {
        let reduce = UIAccessibility.isReduceTransparencyEnabled
        ZStack {
            // Barely-there track (warm hairline — visible on white).
            Circle()
                .stroke(Color.bdTextPrimary.opacity(0.08), lineWidth: lineWidth)

            // Progress arc — gradient sweep (or solid sage), soft round cap.
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    ringStyle,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                // Soft, restrained glow — only on the earned beat.
                .shadow(
                    color: (active && !reduce) ? glowColor.opacity(0.45) : .clear,
                    radius: active ? 12 : 0
                )
                .animation(animation, value: progress)
        }
    }

    private var ringStyle: AnyShapeStyle {
        if let gradient { return AnyShapeStyle(gradient) }
        return AnyShapeStyle(Color.bdAccent)
    }
}


// MARK: - ArcTipEffect — rides a view along a ring's centerline as progress animates.
//
// An animatable GeometryEffect: `progress` is the single source of truth (the same
// value driving the arc's `.trim(to:)`). Because `animatableData` interpolates it,
// `effectValue` recomputes the tip angle (startAngle + progress·sweep) every frame,
// so the bead leads the growing arc's endpoint frame-for-frame and settles exactly
// at the final position — never a pre-placed dot, never a straight-line chord.

private struct ArcTipEffect: GeometryEffect {
    /// 0…1 position around the ring. Interpolated by the same animation as the arc.
    var progress: Double
    /// Ring centerline radius (where the stroke is centered).
    var radius: CGFloat
    /// The arc starts at 12 o'clock and sweeps a full turn clockwise.
    var startAngle: Angle = .degrees(-90)
    var sweep: Angle = .degrees(360)

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = startAngle.radians + progress * sweep.radians
        let x = radius * CGFloat(cos(angle))
        let y = radius * CGFloat(sin(angle))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}

extension AngularGradient {
    /// Emerald hero sweep for the reclaimed-time ring.
    static var bdEmeraldSweep: AngularGradient {
        AngularGradient(
            colors: [Color.bdEmeraldDeep, Color.bdEmerald, Color.bdEmerald.opacity(0.85), Color.bdEmeraldDeep],
            center: .center, angle: .degrees(-90))
    }
    /// Sage sweep for chrome rings (Focus, etc.).
    static var bdSageSweep: AngularGradient {
        AngularGradient(
            colors: [Color.bdAccentDeep, Color.bdAccentBright, Color.bdAccent, Color.bdAccentDeep],
            center: .center, angle: .degrees(-90))
    }
}
