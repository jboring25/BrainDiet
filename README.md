# BrainDiet

**Turn the hours you lose to scrolling into hours spent on what you actually want.**

BrainDiet is an iOS app that blocks distracting apps — and then does the part
blockers skip. It takes the time it gave back and spends it on one concrete step
toward a goal you set, then shows you what that time bought.

*You feed your body well. Your brain eats too.*

Most screen-time apps end at the block. You get a grey shield, a number that goes
down, and no idea what the reduction was *for*. BrainDiet treats the recovered
time as a budget: every intercepted open becomes a prompt to do one small,
already-planned thing, and the Becoming tab totals what you have converted.

Built solo for the [RevenueCat Shipaton 2026](https://shipaton.com) Next Gen Award.

---

## How it works

**Menu — the block.** You pick the apps that cost you time. BrainDiet shields
them through Apple's Family Controls framework, so the block holds at the OS
level rather than inside the app. Hold an app tile to release it for three
minutes; hold again to re-block it.

**The intercept.** Opening a shielded app does not show a wall. It names the
person you said you wanted to be, and gives you one thing you can do from
wherever you are standing:

> **You wanted to be social.** Go talk to a stranger.
> **You wanted to get stronger.** Go touch some iron.
> **You wanted to become more mindful.** Take your AirPods out. Look around.

Each time you take the way out, the next interrupt speaks to your next goal, so
the shield rotates through everything you picked instead of repeating one line.
Three passes a day exist for the times the answer really is *not now*.

**Becoming — the point.** A running total of hours converted from scrolling into
goal work, drawn from two sources: measured usage via DeviceActivity, and what
you report yourself. A week recap on Sunday shows the trade — time that used to
go to the feed, and where it went instead — and moves the projected date of your
next milestone forward or back based on the pace you actually held.

## Personalization without a chatbot

The plan you get is not generic and is not a chat window. Onboarding asks what
you want to become and one concrete object question per domain ("which book?"),
and every step is written around that answer. The daily list is capped at three
items — finish them and you get three more — scored by goal urgency, hour of
day, and a skip ledger that stops re-offering a step you keep declining.

This runs deterministically on-device, so it works on every phone with no network
call. The on-device model only refines wording; it never decides what you do.
That was a deliberate line: the failure mode of AI goal apps is that users end up
talking about their goals instead of doing them.

## Design principles

- **Make the nourishing choice beautiful, never make distractions ugly.** Shame
  is not a retention strategy.
- **Identity, first person.** "I don't scroll at night", not "The reader" —
  following Patrick & Hagtvedt on *I don't* versus *I can't*.
- **Boredom is fine.** BrainDiet never competes to be the more interesting feed.
- **Show, don't tell.** If a screen needs a paragraph to be understood, the
  screen is wrong.

## Tech

| | |
|---|---|
| Language | Swift 6, SwiftUI |
| Minimum | iOS 26 |
| Blocking | FamilyControls, ManagedSettings, DeviceActivity |
| Extensions | `BrainDietMonitor` (DeviceActivityMonitor), `BrainDietShield` (ShieldConfiguration + ShieldAction) |
| Purchases | [RevenueCat](https://www.revenuecat.com) `purchases-ios-spm` |
| Persistence | App Group shared container, UserDefaults |
| Dependencies | One. RevenueCat. |

**Architecture note.** Family Controls does not run in the Simulator, and
`Label(ApplicationToken)` is system-rendered — an app's name and icon are opaque
to the host app by design. Every screen showing blocked apps is built around that
constraint rather than fighting it.

### RevenueCat

One version of the app, no feature tiers. A 3-day free trial, then **$4.99 a
week** or **$19.99 once**, for people who are tired of subscriptions.

- Products live in a RevenueCat **Offering** (`default`) with `$rc_weekly` and
  `$rc_lifetime` packages, both unlocking one entitlement, `pro`.
- The paywall reads its prices from the Offering at runtime
  (`package.storeProduct.localizedPriceString`), so a price change in App Store
  Connect never needs an app update, and every currency shows correctly.
- Purchases go through `Purchases.shared.purchase(package:)`; restore and the
  entitlement check are RevenueCat's too. The trial copy only appears on the
  recurring plan, so the lifetime button never promises a trial it can't give.

See [`StoreService.swift`](BrainDiet/Services/Store/StoreService.swift) and
[`RevenueCatConfig.swift`](BrainDiet/Services/Store/RevenueCatConfig.swift).

## Building

```bash
git clone <this repo>
cd BrainDiet
open BrainDiet.xcodeproj
```

You will need to set your own team and bundle identifiers, and request the
[Family Controls distribution entitlement](https://developer.apple.com/contact/request/family-controls-distribution)
from Apple. **Screen Time features require a physical device** — they are
unavailable in the Simulator.

`scripts/ship-testflight.sh "notes"` archives, uploads, and attaches release
notes in one command. It reads `ASC_KEY_ID` and `ASC_ISSUER_ID` from the
environment; the private `.p8` is never stored in this repo.

## Repository layout

```
BrainDiet/            App target
  App/                Entry point, RevenueCat configuration
  Features/           Home · Menu · Becoming · Onboarding · Paywall
  Services/           Blocking, goal planning, personalization, store
  Models/             Goal, PlannedStep, UserProfile
BrainDietMonitor/     DeviceActivityMonitor extension — usage thresholds
BrainDietShield/      ShieldConfiguration extension — the intercept screen
scripts/              TestFlight ship pipeline
```

`design/` (mockups and motion studies) is excluded — it is 1.2 GB of source
media and is not needed to build the app.

## License

[MIT](LICENSE)
