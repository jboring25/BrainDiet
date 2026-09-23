# BrainDiet Design Bible

**This is the canon. Every build pass, mockup, copy change, and sub-agent dispatch is measured
against this document — not against intuition, memory, or the last conversation. If work
contradicts the Bible, the work is wrong or the Bible gets amended first (Jack's call only).**

Source of truth hierarchy: this file (WHY) → `PLATE-ENGINE.md` (WHAT HAPPENS — the behavior
spec every screen implements) → `DESIGN-TOKENS.md` (exact values) →
`~/Athena/projects/brain-diet-app/product-vision-v2.md` (full constitution + addenda) →
repo `CLAUDE.md` (build mechanics).

**Governance:** the design director questions assumptions and audits against the vision ·
Jack makes product decisions · Claude/Fable executes and maintains · this Bible — not chat
history — is the source of truth. Audit findings land as amendments here (Jack approves),
never as chat sentiment.

---

## 0 · The Laws (immutable)

**Law Zero — BrainDiet sells a worldview, not a utility.**
Every feature must reinforce this belief:
> **Your attention is something you consume, not merely spend.**
If a feature doesn't strengthen that belief, it probably doesn't belong. This test precedes
every other test in this document.

**Law One — BrainDiet is not about food.**
The food metaphor exists to make invisible attention VISIBLE. Users are never optimizing
meals; they're optimizing their lives. If a feature becomes more about food than attention,
it's drift. (This law is what kills silver domes and fries animations before they're built.)

**Law Two — Never require users to maintain the metaphor.**
The user speaks in activities ("I read"). BrainDiet speaks in nutrition ("vegetables").
The translation is OUR job, never theirs. Never ask "what vegetable did you eat?"

**Law Three — The product becomes smarter over time.**
Every recommendation should become more personal with use: "Continue Atomic Habits — you're
on chapter 6," never a generic "Read." If BrainDiet could have known something from previous
behavior, it never asks again. Static suggestions are drift.

**Law Four — The app should disappear.**
The highest compliment: *"I forgot BrainDiet existed... but I finished three books."*
Feature test: does this reduce the time spent inside BrainDiet? If yes — good.

**The company sentence:**
> BrainDiet should feel less like installing software and more like adopting a healthier
> way of thinking.

---

## 1 · What BrainDiet is

BrainDiet is not a productivity app, a screen-time tracker, or a habit tracker.
**BrainDiet teaches people to think about information the way they already think about food.**
Short-form content is mental junk food. Books, focus, creating are nourishing meals.

The mindset shift IS the product: from *"I have 30 free minutes"* to
*"What should I feed my brain right now?"*

**The founding insight:** people count calories and follow meal plans as proof of dedication to
fitness goals — yet completely disregard what they feed their brains for life goals.

### The three drift tests (run on EVERY screen, feature, and line of copy)
1. **"Does this make the user think about attention as nutrition?"** No → it doesn't belong.
2. **"Could this screen exist in Opal?"** Yes → too generic, redesign.
3. **"Does this feel like analytics software or like preparing a nourishing meal?"**
   Analytics → redesign.
4. **"Would someone repeat this phrase in conversation?"** A great consumer product invents
   vocabulary that escapes the app. Pass: "Feed your brain." / "That's empty calories." /
   "My brain is hungry." / "Today's serving." Fail: "protected focus session," "growth
   score," a raw minute-count with no meaning attached.

### The app wins by attraction, never shame
Never guilt. Never lecture. Never "you failed." The temptation BrainDiet sells is not
resisting Instagram — it's **the temptation of becoming the person you want to be.**

---

## 2 · The ritual (the emotional sequence)

We design **rituals, not features**. Every interaction follows:

**Craving → Choice → Preparation → Satisfaction → Reflection**

NEVER: Task → Progress → Dashboard → Chart.

The daily loop (total in-app time < 1 minute on a good day):
- **Morning:** open → today's plate + ONE serving suggestion → leave.
- **Day:** protection quietly holds; the user lives. The app's job is to not exist.
- **The fork** (junk app opened): the almost-complete plate intercepts. One glowing gap.
- **The return** (serving completed): THE REVEAL — food flies onto the plate. This is the
  dopamine moment of the entire product.
- **Evening:** glance at the finished plate. Feel it. Close.

**A successful user barely uses the app.** Optimize for: minutes protected, nourishing choices,
completed plates, empty-calorie reduction. NEVER for taps, DAU minutes, or in-app engagement.

---

## 3 · Language law

**The worldview is the hero; language is its sharpest instrument.** The plate, the blocker,
the animations — everything serves "attention is nutrition." Language is where the worldview
becomes contagious: what sticks in people's heads is "Your brain is hungry." / "Feed your
brain." / "Today's serving." / "Complete today's meal." / "Empty calories." Copy the words
without the worldview and you still don't have BrainDiet.

### Vocabulary
| Say | Never say |
|---|---|
| plate, serving, meal, nourishment | goals, tasks, sessions |
| feed your brain | focus session, productivity |
| empty calories, fries | blocked, restricted, screen time exceeded |
| today's serving | to-do, recommendation engine |
| the table is held for you | timer started |
| balanced, craving, diet | efficiency, score, streak-freeze |

### Categories — activity FIRST, food explains (never the reverse)
| Category (primary) | Food (explanation) |
|---|---|
| Learning (reading, articles, podcasts, lectures) | brain vegetables |
| Focus | brain protein |
| Creativity | brain fruit |
| Entertainment | dessert — guilt-free, on the menu by design |
| (junk) | empty calories / fries — muted, never alarming |

Users must never decode food→activity. "Finish Chapter 6 · Learning · brain vegetables."
The category holds MULTIPLE valid servings (see `PLATE-ENGINE.md` §3) — "brain vegetables"
is never just one activity.

### Voice = thoughtful nutrition coach (never parent, never corporate)
- "Your plate could use another serving." (never "You failed your goal")
- "Looks like you reached for dessert first." (never "Screen time exceeded")
- "Your brain just got a little stronger." (never "Task completed")
- Dynamic by time of day — Home NEVER lies: morning "Your brain is hungry." /
  afternoon "Nicely fed." / evening "Well nourished."

### Time is an ingredient, never the reward
Always translate: "2h 20m · enough for 2 chapters." / "43m protected · enough for one workout."
A raw duration with no meaning attached is a defect.

### The emotion layer
Completing a serving must FEEL like finishing a great meal. Tiny copy moments, zero friction:
"Served." / "Nice choice. Your brain got a serving of reading." / "Today's meal is balanced."

---

## 4 · One metaphor (the cloche rule)

**Nutrition is the ONLY metaphor.** Fresh ingredients, plates, meals, servings, cravings.

The cautionary tale: interpreting "serving" literally produced a silver restaurant dome —
a second metaphor (restaurant service) that fought the first. It was killed on sight.
**Never import props, language, or imagery from adjacent metaphors** (restaurants, gyms,
pharmacies, kitchens-as-industry). When in doubt: does a home-cooked healthy meal have one?

---

## 5 · The plate

**The plate is the REWARD, not a progress bar.** The celebration is the ANIMATION,
not the final image. It must feel like cooking, not a checklist.

**Never ask "how many PNG states do we need?" Ask "what emotional beat happens when a
serving is completed?"** The implementation can change later; the emotion must not.

- **Three display states only:** morning (mostly empty) · midday (coming together) ·
  evening (finished). Not seven. Not thirty-five.
- **THE ANIMATION RULE (codified): matter belongs in assets; motion belongs in code.**
  Assets: plate, food, ingredients. Code: slide, bounce, fade, steam, completion, timing.
  Static assets NEVER contain steam, glow, sparkle, or any ephemeral effect (frozen motion
  reads dead). **Don't bake emotion into renders. Bake emotion into animation.** This is
  also what keeps the app cheap to evolve — swap a render, keep the feel.
- Current assets: near-real Gemini renders on pure white (`PlateNourished` + the 4-render
  set specced in `design/plate-concepts/gemini-render-prompts.md`, incl. the greens cutout =
  the flyable layer).
- The plate must EVOLVE (day arc now; identity cuisines later — Founder→Japanese,
  Writer→Italian, Athlete→high-protein, Artist→Mediterranean, Language learner→bento).
  If the plate is static for months, users stop seeing it.

### The serve sequence (the signature animation, spec)
serving completed → plate scale-bounces (≈1.0→1.02→1.0, spring) → the food group FLIES on
(from above, ~0.75s, slight overshoot, settles) → steam begins (2–3 blurred wisps,
phase-offset continuous-time so loops never pop; white body + ~8% deep-gold inner whisper so
vapor reads on white) → "Served." toast → soft haptic first, chime second (respects silent
mode) → title updates ("Nicely fed."). **No confetti. No fireworks. Apple-level restraint.**

---

## 6 · Visual principles (durable — exact values live in `DESIGN-TOKENS.md`)

The Bible survives redesigns; tokens don't. Philosophy-level rules only:
- **Color comes from content, never atmosphere.** The canvas is quiet; food, categories,
  and earned moments carry the color.
- **One primary CTA per screen.** Gold fires only on earned moments — never ambient.
- **Attraction palette:** junk is muted, never alarm-red. Nothing on screen shames.
- **One icon language, no emoji in UI.** One type system, display face reserved for the
  biggest earned numerals.
- Header carries the wordmark + share + settings. No streak chip (streaks serve the app;
  share serves the user). The retired pink brain stays retired.
- Every hex, radius, stroke width, spacing value, and font size: `DESIGN-TOKENS.md`
  (+ `DesignSystem.swift` as the in-code mirror).

---

## 7 · Screen charters

**All four screens read from ONE object — the Plate Engine (`PLATE-ENGINE.md`). No screen
computes its own recommendation or state.**

**HOME — "What should I feed my brain next?"**
Plate dominates (hero, with live layers). One qualitative state line (time-of-day honest,
last word sage). One ingredient line (time→meaning). ONE serving card with the app's single
primary CTA ("Feed my brain"). Today's Plate card (three rows: activity + food subtitle +
slim bar + minutes; junk row muted). One quiet protection line. Nothing else. No score,
no stats, no charts.

**FEED — choose nourishment, not restriction.**
"What should your brain eat?" Menu of servings: activity title first ("Finish Chapter 6"),
food as subtitle, duration chip; suggested serving highlighted. Picking a serving holds the
table (starts protection) automatically — no timers to babysit. Dessert is on the menu.

**GROWTH — storytelling, not measuring.**
The month's plate (the screenshot moment) + ONE sentence: "You replaced 18 hours of scrolling
with 4 books." No bar charts, no servings math, no analytics. If it looks like Apple Health,
it's wrong.

**THE FORK (blocker) — the most important interaction.**
Solves "choose what to consume instead," not "pause." Shows TODAY'S PLATE ~85–95% complete
with ONE glowing missing section + the serving that completes it + "Feed my brain" /
quiet "Continue anyway." Nothing else — no headers, no fries icon, no lecture. The incomplete
meal IS the tension. Proactive when context allows ("11 free minutes before class — perfect
timing"). The REVEAL fires on return, not at the fork.

**THE WIDGET (approved exploration — direction, not yet canon).**
The ambient home-screen surface: literally today's plate, filling as the day feeds it —
morning mostly empty, evening nearly complete. It exists so the ritual stays alive without
opening the app (Law Four in physical form): the 9:30 PM "I should finish today's plate"
moment lives in a glance, never a notification. **Hard caution: it must never read as
another progress ring — rings are Apple's territory.** It is a plate with today's servings
on it, a place setting waiting to be filled. If a squint makes it a ring, it's drift.

---

## 8 · Process law (how we build)

1. **Spec before screens; experiences before screens.** Builders receive the ritual (the
   movie: what the user feels beat by beat), not a feature list. Static mockups only prove
   layout; interaction prototypes prove the product.
2. **Build from mockup SOURCE values** (the CSS/spec), never from prose descriptions of a
   mockup. Prose is how the cloche happens.
3. **Screenshot self-check against the governing mockup/spec, every pass** — including the
   FRESH-INSTALL default state and every mode of a touched screen. The seeded happy path is
   what the developer sees; the fresh path is what the user sees.
4. **Judge motion from video frames**, never stills.
5. **One mockup round max** before building; galleries don't converge.
6. Drift check before shipping any surface: run the three tests in §1.
7. Big lessons → `~/Athena/projects/brain-diet-app/build-journal.md` (after the fact).

---

---

## 9 · Hypothesis, not law (the long-term artifact)

**The worldview is stable law; the long-term emotional mechanic is a HYPOTHESIS** — it stays
one until real users (~100) have lived with the product. Do not lock it early because the
philosophy feels coherent.

**Open question on record:** *What is the long-term emotional artifact BrainDiet users
become attached to — what does a lapsed user MISS?*

Candidates on file (NONE are canon; all are experiments to be tested in usage):
- **The Table** — month-grid of completed daily plates (accumulating artifact).
- **"Your Diet"** — the identity framing ("I've been eating healthier"): diet shift shown
  as a before/after story, not an archive of plates.
- **The month's meal** — ONE illustration composed from everything the month consumed
  (already the direction of the Growth charter); year version = the shareable recap.

Design compass while testing: **design toward a dinner table (nourishment), not a GitHub
graph (consistency).** What accumulates must be identity ("I feed my brain well"), not a
visual streak. The GitHub/Duolingo analogies explain the psychology; they must never
dictate the form.

---

*Amendments: Jack only. 2026-07-13 (audit #2): Laws One–Four added, the company sentence added, worldview>language hierarchy corrected, visual tokens split out to DESIGN-TOKENS.md. 2026-07-13 (audit #3): widget accepted as approved exploration (§7, with the no-progress-ring caution); The Table / daily plate archive / GitHub analogy explicitly NOT canonized — §9 records the long-term artifact as a hypothesis to be answered by real usage. 2026-07-13 (audit #4): the Plate Engine behavior spec adopted as `PLATE-ENGINE.md` (the WHAT-HAPPENS layer); category "Reading" widened to "Learning" (brain vegetables = many servings, not one activity).*
