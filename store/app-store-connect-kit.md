# BrainDiet — App Store Connect submission kit (v1.0)

Everything below is copy-paste ready for App Store Connect. I cannot log into ASC for you (it needs your Apple ID + 2FA), so this is the prepared content; you paste it. Honesty-law compliant throughout — behavior/time framing, zero health/cognitive claims (the Lumosity line).

## Hosting the two URLs (cheapest + simplest — my pick)
Files are ready in `store/`: `privacy-policy.html`, `support.html`.
**Simplest zero-cost path → a public Notion page**, or **GitHub Pages** if you want a cleaner URL:
- **Notion (fastest):** paste the text of each into its own Notion page → Share → Publish → copy the public link. Two links, done, free.
- **GitHub Pages (nicer URL, still free):** new public repo `braindiet-site`, drop both .html files in, enable Pages → you get `https://<you>.github.io/braindiet-site/privacy-policy.html`.
Either satisfies Apple. You do NOT need a real website. Update the two URLs in the app (`SettingsView.swift`, `PaywallView.swift` point at `braindiet.app/privacy|terms`) to whatever you host — or just set the ASC "Privacy Policy URL" field to the hosted link (that field is what Apple actually checks).

---

## App information
- **Name:** BrainDiet  *(if taken, fallbacks: "BrainDiet: Reclaim Focus", "BrainDiet – Beat the Scroll")*
- **Subtitle (30 char max):** `Fix why you scroll` (18) — alt: `Beat the scroll, feed your mind` (30)
- **Primary category:** Productivity  ·  **Secondary:** Health & Fitness
  - *Rationale: the category leaders (Opal, one sec) sit in Health & Fitness for discoverability, but that category draws heavier medical/health-claim review (Guideline 1.4.1). Productivity primary keeps scrutiny low and still fits "focus / attention / habits"; H&F secondary keeps discoverability. Never "Medical."*
- **Age rating:** 4+
- **Bundle ID:** com.jackboring.BrainDiet

## App Privacy questionnaire
- **Data collection: "Data Not Collected."** True — no analytics, no network, all local. (This is a real trust asset; the questionnaire will be one screen.)
- No tracking, no third-party SDKs.

## Promotional text (170 char, editable anytime without review)
`You've tried screen-time limits. The limit was never the problem. BrainDiet asks what you're really reaching for — and hands you something better than the scroll.`

## Description
```
Screen-time apps count how long you scroll. BrainDiet is about WHY you scroll.

You already know the feeling: you pick up your phone without deciding to. Not because you love the feed, but because you're bored, restless, or avoiding something, and the scroll is the closest quick fix. A timer doesn't touch that. The limit was never the problem.

BrainDiet treats your attention like a plate. Every day you get a small plan of "servings" — real things you actually want to do, built from goals you choose (read more, get stronger, make something, learn). You fill today's plate by doing them. It's the opposite of a blocker: instead of a locked door, you get a better meal.

And the moment you catch yourself reaching for a scroll, BrainDiet asks one question — what's this really about? Bored, anxious, just habit, or a real need — and hands you the right thing for that moment instead of the same wall every time. No shame. No lectures.

WHAT'S INSIDE
• Today's Plate — a simple daily plan of what to feed your mind
• The check-in — catch yourself reaching, and get matched to something better
• Becoming — watch what your reclaimed time actually turns into
• A plan built from who you want to become, in your own words

HONEST BY DESIGN
• No accounts. No ads. No trackers. Everything stays on your device.
• "Feeding your brain" is a way of thinking, not a medical claim.
• Cancel anytime in two taps.

BrainDiet Pro unlocks your full plan and is available as a subscription with a free trial. You can use BrainDiet free, one serving a day, forever.
```
*(Note the inoculating line "a way of thinking, not a medical claim" — keep it; it defuses the FTC/Lumosity + eating-disorder-adjacency risk.)*

## Keywords (100 char max, comma-separated, no spaces)
`focus,screen time,doomscroll,habit,attention,reading,productivity,digital wellbeing,intention,mindful`

## Subscriptions (Monetization → Subscriptions)
Create a subscription group "BrainDiet Pro" with two products:
| Product ID | Reference / Display Name | Duration | Price | Offer |
|---|---|---|---|---|
| `braindiet.pro.annual` | BrainDiet Pro (Annual) | 1 year | $59.99 | 7-day free trial (introductory offer) |
| `braindiet.pro.monthly` | BrainDiet Pro (Monthly) | 1 month | $9.99 | — |
- Annual localized description: `Your full daily plan, every goal, and your whole comeback tracked. 7 days free, then $59.99/year.`
- Monthly localized description: `Your full daily plan and every goal. $9.99/month.`
- Each needs a screenshot + review note; they're reviewed with the app.

## App Review notes (paste into "Notes" at submission)
```
BrainDiet is fully functional without any account or login — just launch and go through onboarding.

This version does NOT use Family Controls / Screen Time; on-device app-blocking is planned for a later update pending the Family Controls distribution entitlement. All core features (the daily plan, the "check-in" redirect flow, focus sessions, progress) work entirely on-device with no special permissions.

No data is collected or transmitted. To review Pro features, use the StoreKit sandbox; a 7-day free trial is offered on the annual plan.
```

## Screenshots
Pull from the sim (I can generate a polished set): Home (the plate + "Your brain is hungry"), the check-in / triage, the plan reveal, Becoming. 6.9" and 6.5" required sizes.

## Support & Marketing URLs  ✅ LIVE (hosted on Netlify, verified 200, 2026-07-27)
- **Support URL (REQUIRED):** `https://braindiet.netlify.app/support.html`
- **Privacy Policy URL (REQUIRED):** `https://braindiet.netlify.app/privacy-policy.html`
- Marketing URL: (optional — leave blank)

In-app links now point at these too (were dead `braindiet.app` links, fixed pre-archive):
- Settings → Privacy policy → the hosted policy
- Paywall → Privacy → the hosted policy · Paywall → Terms → Apple's standard EULA
  (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) since we supply no custom terms
- Share card "get your own" text → `braindiet.netlify.app` (TODO: swap to the App Store URL after approval)
