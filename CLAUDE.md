# BrainDiet

> **⭐ MOCKUPS START FROM THE REAL APP (Jack, 2026-10-07, "make it permanent").**
> Any mockup of an existing screen is built ON a fresh screenshot of that screen
> (`design/_current/`, captured with ios-sim-review), never re-drawn from
> scratch. Paint out only what changes; reuse the real elements.
>
> **Onboarding v2 (approved 2026-10-08, built a51c7a5):** welcome → hijack → timeLost →
> domains → primaryDomain → goalWords (required, top 3 goals) → baseline → aspiration →
> timeAndDay → blocker → interstitial → pause → screenAccess → pickApps →
> reachAndSchedule → building → mirror → commit → onboardingPaywall → dinnerBell →
> menuHero. `specifics` deleted; `planReveal` unrouted. The menu is first seen AFTER the
> paywall. AI plan = PlanService → braindietapp.com/.netlify/functions/plan (Claude Haiku
> 4.5, tool-forced JSON, no chat); any failure falls back to the heuristic planner.
> Schedules + Do it now lock built 3897091 (FeedWindow → BrainDietMonitor; BrainDietDoItNow store). iOS can only exempt picked APPS (not Messages by default, not categories).
>
> ## ⭐ STATE OF THE APP — 2026-08-29
>
> **Read this block. Everything below it is history, and much of it is stale.**
>
> This file is 7,100 words, carries 69 inline dated decisions and 32
> superseded/retired/removed markers, and its longest single bullet is 1,293
> words. It stopped being a spec and became an archaeological record. On
> 2026-08-26 an agent built a whole mockup from the section describing the Menu
> tab — which had been replaced in code weeks earlier — and Jack had to send a
> screenshot of his own app to correct it. **If the code and this file disagree,
> the code is right.**
>
> **Tabs:** Home · Menu · Becoming.
>
> **Menu tab = the block list, nothing else.** `BlockedAppsView`. Three levels:
> (1) status word + one-line serif headline + two tappable rows; (2) the blocked
> apps with "Unblock" + "Add an app"; (3) passes, the only place a sentence of
> explanation is allowed. **No "Nourishing"/"Leisure" sections — picking good
> apps was cut 2026-08-26.** Real app covers via `Label(ApplicationToken)`.
> `ProtectIdleView`, `MenuStepRow`, the leader dots and `MenuCourse` are DEAD —
> the printed-menu look was retired 2026-08-26 for having no affordance.
>
> **No pinned CTA anywhere.** Retired 2026-08-26. Every block carries its own
> control.
>
> **No PRO gating.** Removed 2026-08-26: every step of every goal is free and
> servings are unlimited. StoreKit/RevenueCat stay for whatever gets charged for
> later.
>
> **Intercept pass:** 3/day, 3-minute window (`InterceptPass`). The shield's
> secondary button is drawn ONLY while passes remain.
>
> **Becoming:** carries the path line (days in · steps · next step) and the
> verified-vs-self-reported split. Self-report is capped at 60 min/day of credit.
>
> **KNOWN GAP:** Home does not carry the servings list. The Menu gave it up and
> Home has not absorbed it, so only the suggested serving is startable.
>
> **Shipped:** TestFlight build 19, 2026-08-28.


---

**History lives in `HISTORY.md`.** Every superseded decision, every retired
surface, every "stays on disk unused" note moved there on 2026-08-29. It is kept
because the reasoning is often still good — but it is not in the way any more.
Law 1: documents resolve, they never accumulate.
