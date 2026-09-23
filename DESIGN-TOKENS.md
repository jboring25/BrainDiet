# BrainDiet Design Tokens — THE APPETITE SYSTEM (2026-07-18, Jack-approved)

**The implementation values. This document MAY change on redesigns; `DESIGN-BIBLE.md` may not.**
In-code mirror: `BrainDiet/DesignSystem/DesignSystem.swift` (single source of truth for Swift).
Spec of record: `design/plate-concepts/appetite-mockups.html` (build from its CSS, never prose).

## Canvas & text
| Token | Value | Use |
|---|---|---|
| `bdBackground` | `#FDF9F2` | flat warm-CREAM canvas (appetite; was `#FFFFFF`) |
| `bdSurface` | `#FFFFFF` | cards — white, lifted off the cream |
| `bdTextPrimary` | `#2A231A` | ink |
| `bdTextSecondary` | `#8A7E6F` | sub (mockup `--sub`) |
| `bdCardBorder` | `#EFE7DA` solid | card hairline (mockup `--line`) |
| `bdBarTrack` | `#F1EBE1` | slim-bar track on white cards |
| `bdTabMuted` | `#B9B0A2` | unselected tab / gear ink |
| `bdProgressTrack` | `#DDD9D2` | onboarding progress track |

## ⭐ Category colors (THE LAW — every chip/bar/tile/icon, ALL screens incl. Becoming)
| Category | Color | Tint | Text-safe |
|---|---|---|---|
| Learning (brain vegetables) | leaf `#3E7A4E` | `#E9F3EB` | leaf |
| Focus (brain protein) | salmon `#E8735A` | `#FBEAE5` | salmon |
| Creativity (brain fruit) | berry `#9C4368` | `#F6E7EE` | berry |
| Dessert (guilt-free) | honey `#D9A441` | `#FAF0DC` | `#8A6A2E` (`bdHoneyText`) |
| Slop (empty calories) | **gray `#9A948C` BY LAW** (honest-cost, never red) | `#EEECE8` | `#B5AFA6` (`bdSlopFaint`) |

## Accents & CTA
| Token | Value | Rule |
|---|---|---|
| CTA pill | leaf-deep `#2F5E3C` (`bdLeafDeep`), WHITE bold text | every primary CTA |
| `bdAccent` family | now leaf `#3E7A4E` / bright `#5F9268` / deep `#2F5E3C` | legacy call sites sweep to leaf |
| `bdSage*` | re-pointed to leaf tones | legacy names, prefer `bdLeaf*` |
| Salmon as display accent | `#E8735A` | Home headline's last word, Welcome line 2 |
| `bdGoldAccent` | `#B98F1F` | steam-spark gold + reclaimed-time number (unchanged) |
| `bdGoldText` | `#8A6A2E` | gold/honey-as-text, ≥4.5:1 |

## The gray world (onboarding hijack + timeLost arc)
| Token | Value | Use |
|---|---|---|
| `bdGrayCanvas` | `#F4F2EF` | gray-world canvas (mirror = vertical gradient gray 58% → cream) |
| `bdGrayInk` | `#5F5A52` | gray-world primary ink |
| `bdGrayTile` / border | `#FBFAF8` / `#E5E1DA` | hijacker tiles |
| `bdGrayChip` / selected | `#EDEAE4` / `#E3E0DA` | tile icon chips |
| `bdGrayFaint` | `#A9A29A` | captions ("the bottomless bowl") |
| Selected hijacker | slop tint + slop border + white "MUTED" badge on `#9A948C` | muting, not lighting up |

## Shape, type, iconography
- Cards: white + `#EFE7DA` hairline + soft warm shadow (`#2C2519` α0.10, r20, y10).
- Radii: 18 (Home compact cards + onboarding tiles) · 20–24 (elsewhere) · pill 999.
- Type: **Manrope** (ALL body/UI/labels/buttons) + **Young Serif** (OFL, single 400 weight)
  as the DISPLAY face — Welcome 40 / question titles 30 / mirror numerals 76 / Home 25 —
  via `BDFont.serif` / `.bdDisplay` / `.bdQuestionTitle` / `.bdInstrument`.
  Cabinet Grotesk RETIRED from display (files kept; `BDFont.grotesk` shims to serif).
- Icons: **Phosphor DUOTONE** (`PhosphorSwift` SPM), tinted category color on the tint chip
  (`BDPhIcon` + mappings in `DesignSystem/BDIcon.swift`). Never emoji; never SF on the same
  surface (system chrome chevron/gear/checkmark may stay SF).
- Chips: 34pt r11 (plate rows) / 42pt r13 (serving card) / 46pt r14 (onboarding tiles).
- Slim progress bars: 7pt tall, full radius, track = `bdBarTrack`.
- Tabs: **Home · Menu · Becoming** — Phosphor record / fork-knife / plant, leaf-deep selected.

## Motion values (the Bible owns the beats; these are the numbers)
- Springs: response 0.34/damping 0.82 (snappy) · 0.55/0.86 (plate & staged reveals).
- Serve fly-on: ~0.75s, slight overshoot (`cubic-bezier(.2,.85,.25,1.12)` equivalent).
- Plate bounce: 1.0 → 1.02 → 1.0.
- Steam: 2–3 wisps, 3.9–5.2s lives, phase-offset continuous time (no loop restart);
  white body + ~8% absolute RICH-gold base whisper (`bdGoldAccent #B98F1F` — the mockup's
  `--gold`; the sand tokens `bdGold`/`bdGoldDeep` read gray-tan smoke on white — never in
  vapor) so steam reads white+warm, never gray; `sin(π·p)` opacity envelope;
  TimelineView+Canvas, no per-frame allocations.
- Sparks: gold `#B98F1F` core + α.55 halo, hard-gated off below nourishment ≈0.35.
- Feedback order: haptic first, sound second (respects silent mode). Reduce Motion: static
  single faint wisp, no animation.

## Chrome (iOS 26 decisions of record)
- Liquid Glass toolbar/tab bar ignore appearance APIs → header lives in scroll content;
  custom `BDTabBar` (flat white, 1pt `#EDE7DF` top hairline, sage selected, no pill).
- Plate renders melt into the CREAM canvas via multiply + a CONSTANT brightness lift (never
  feathered masks; white backdrop × cream = cream). Mockup chain: `brightness(1.05–1.06)
  saturate(1.04–1.06)` — a backdrop clip, not a dim. Home adds the honey next-serving glow
  (radial `#D9A441` α.55 → 0) over the plate's empty region while completeness < 1.
- NEVER fake emptiness by filtering a full render — desaturation/opacity/brightness ramps
  read as a washed-out GRAY plate on device (Jack-rejected 2026-07-13). A render displays at
  FULL COLOR or not at all. Plate state changes are full-color asset swaps
  (`PlateEmpty` ↔ `PlateNourished` ↔ future per-state renders), crossfaded ~0.8s ease;
  the day arc is carried by headline + bars + the swap, never by graying the food.
