# The Plate Engine — behavior specification

**The Bible says WHY (`DESIGN-BIBLE.md`). This document says WHAT HAPPENS. Tokens say what it
looks like (`DESIGN-TOKENS.md`).** Builders implement this spec; they do not invent interactions.

**The Plate is BrainDiet's central state object.** Every screen reads from it; every meaningful
action writes to it. The user interacts with ONE living object throughout the app, not separate
screens.

---

## 1 · The state object

Five categories:

| Category | Nutrition name | Recommended? |
|---|---|---|
| Learning (reading, articles, educational podcasts, saved lectures) | brain vegetables | yes |
| Focus (deep work) | brain protein | yes |
| Creativity (making things) | brain fruit | yes |
| Entertainment | dessert | yes — guilt-free, on the menu by design |
| Empty Calories | fries | **never** — observed only |

Each recommendable category holds `today` (minutes/servings so far) and a **soft, inferred
serving plan** (see §6 — NOT a per-category quota). Empty Calories holds only `today`; it has
no target and the engine never recommends it.

**The attraction law (SUPERSEDES the 2026-07-17 "honest-cost" gray-slop rendering — Jack,
2026-07-18; intercept rebuilt to it 2026-07-19).** BrainDiet wins by making nourishing choices
BEAUTIFUL, never by making distractions ugly. Never make the user look at something
intentionally disgusting. The intercept is an ATTRACTION surface: when the user reaches for a
distraction, it shows today's REAL plate (the same full-color crossfade Home renders) with the
missing serving glowing honey — what they COULD have, never what they're avoiding — plus the
identity sentence, ONE engine serving, "Feed my brain," and a quiet escape (spec:
`design/plate-concepts/intercept-attraction-mockup.html`; shield icon = the `PlateInviteCard`
nearly-complete plate). Copy persuades with possibility, never disappointment. The `PlateSlop`
render survives in EXACTLY ONE place: Becoming's week strip, marking junk-heavy days — that is
honest HISTORY, not persuasion. Everywhere else it stays on disk, unrendered (the `PlateSlopCard`
shield asset and `BDBrainMark` share the precedent). What SURVIVES from honest-cost: junk is
still never REWARDED (no streaks/points/cheerful color for Empty Calories, the engine never
recommends it) — we just don't punish the eyes either. Healthy plate states remain always
full-color real renders (the anti-dimming law stands).

The engine constantly answers four questions:
1. What is today's plate missing?
2. What should the user do next?
3. How balanced is today's plate?
4. What insight should be shown?

**No screen calculates these independently. Every recommendation, everywhere, comes from the
Plate Engine.** (This is also a bug-prevention law: three screens computing their own state is
how the ring+brain fresh-install bug happened.)

---

## 2 · Consumers

- **HOME** asks for the single highest-value serving. Never multiple recommendations. One card:
  activity title ("Read Chapter 6"), duration, nutrition subtitle ("brain vegetables"), one CTA.
- **FEED** is the menu: EVERY possible serving, sorted by usefulness, re-sorted through the day.
  If Learning is already fed, its servings drop and another category becomes Suggested.
- **THE FORK (blocker)** asks: "what single serving would most improve today's plate?" It never
  says "Instagram is blocked," never invents activities. It shows today's plate with one missing
  section + that one serving + Feed My Brain / Continue Anyway.
- **GROWTH** renders from historical plates.
- **Future surfaces** (widget, Watch, monthly recap, AI layer) render from or query the engine.
  **Expansion law: if a feature does not update or reference the Plate Engine, question whether
  it belongs in BrainDiet.**

---

## 3 · Selection policy

- **Concrete actions, never categories.** Bad: "Learning." Good: "Read Chapter 6 of Atomic
  Habits." The nutrition metaphor EXPLAINS the recommendation; it never replaces it.
- **Non-deterministic variety.** If Learning is low every day, do not always say "read" first.
  Each category holds multiple valid servings (a book, an article, a podcast, a lecture); choose
  among them weighted by category deficit × available-time fit × the user's acceptance history.
  Variety is what makes a coach; determinism makes a rules engine.
- **Stable within the moment.** The suggestion must NOT reshuffle every time the user glances at
  the app — that reads as random and erodes trust. Re-roll only on: serving completed, serving
  explicitly declined, a new time-of-day block, or a new day. Between those events the answer is
  sticky.

---

## 4 · The completion celebration (signature interaction)

On detected/confirmed completion, in order:
1. The sequence plays for ~800 ms as an uninterrupted beat — but the UI is never hard-locked;
   a navigation tap during it completes the state change instantly and defers only the visuals.
2. Plate scale-bounces to ~102% and settles (spring, tokens file).
3. The missing food group flies onto the plate from above, slight overshoot, settles.
4. Steam begins rising (continuous-time wisps, tokens file).
5. Soft haptic FIRST.
6. Small chime SECOND (respects silent mode).
7. Toast: "Served." or "Your brain got a serving of learning."
8. Home headline updates (e.g. "Your brain is hungry." → "Nicely fed.").

**The reward is the animation. Not a badge. Not XP. Not points.**

*Daily-win upgrade (Jack, 2026-07-19 — matches onboarding's firstServing):* the beat is now
`.success` haptic first → plate crossfades UP to its new real state (0.8s ramp) with a steam
BURST + ONE gold flare (~1.5s) → "Served." toast; ≤ 2.5s total, never input-locked. Reduce
Motion: crossfade + haptic + toast only. The fly-on (step 3) remains a disabled seam awaiting
the cutout renders.

---

## 5 · The daily arc

The user feels the day progress through the plate — never through timers or progress bars.

| Time | Plate | Headline |
|---|---|---|
| Morning | mostly empty | "Your brain is hungry." |
| Afternoon | partially complete | "Nicely fed." |
| Evening | complete | "Well nourished." |

---

## 6 · Balance is qualitative (guard-rail)

The daily plan is a small set of servings (2–4) inferred from the user's goals and history —
NOT five category quotas. Never show per-category percentages or five mini-meters; that is
"close your rings" analytics wearing a plate (drift test #3). "Balanced" surfaces as words and
as the plate's visual state. The single meal-completeness meter on the Fork is the one
sanctioned number.

---

## 7 · Adaptation (Law Three made concrete)

The engine learns; recommendations become increasingly personal. Target feeling:
*"This app knows how I actually live."*

- Always reads after dinner → reading suggestions move later.
- Ignores podcasts every day → podcasts stop leading.
- Builds on Saturdays → creative work leads Saturdays.
- Halfway through a book → "Continue Atomic Habits — you're on chapter 6," never generic "Read."
- If the engine could have known it from behavior, it never asks.

**Ship order (reuses the proven GoalPlanner tiering already in the codebase):**
v1 = deterministic heuristic floor + weighted-variety selection (no ML, ships everywhere) →
on-device refinement (Apple Foundation Models, auto-fallback) → remote seam (not built).
Adaptation learns only from signals we actually have: in-app confirmations, declines,
time-of-day/weekday patterns, Screen Time categories. It never pretends to know what it can't
observe.

---

*Adopted 2026-07-13 from the design director's behavior spec, Jack-approved. Deviations from
the spec as written (argued by Athena, recorded in the decision log): no hard input lock during
the celebration (§4.1); soft inferred plan instead of per-category targets (§6); sticky-moment
rule added to non-determinism (§3).*
