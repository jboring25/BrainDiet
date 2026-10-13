# BrainDiet · App Store submission kit (v1.0, rewritten 2026-10-13)

App Store Connect is the source of truth for the listing; this file only records
what is there and what is still manual. The July version of this file described
an app without Screen Time and was deleted, not kept.

## Done via API (2026-10-13)
- Description rewritten for the one-moonshot app (shield → goal → Do it now, schedules, first hour, passes in-app).
- App Review notes rewritten: Do it now DOES lock every app except Phone + the allow-list (with End early and an automatic release); Go to BrainDiet uses openParentalControlsApp (iOS 26.5+); AI data disclosed.
- Screenshots: 6 new 1290×2796 in `marketing/appstore-v2/` (old 5 backed up in `marketing/appstore-v1-backup/`).
- Build 63 attached. Export compliance: no non-exempt encryption.
- Privacy policy (braindietapp.com/privacy-policy.html) corrected 2026-10-13: lists exactly what goes to Claude.

## Manual (Jack, in the App Store Connect web UI; the API can't do these)
1. Agreements: Paid Apps agreement active (Business section).
2. App Privacy: collected, NOT linked to identity, NOT used for tracking, purpose App Functionality:
   - User Content → Other User Content (goal words, moonshot, typed "what I did", sent to Claude)
   - Purchases → Purchase History (RevenueCat)
   - Identifiers → User ID (RevenueCat's anonymous app user ID)
3. On the 1.0 version page, In-App Purchases and Subscriptions: add `braindiet.weekly` + `braindiet.lifetime` only (NOT pro.annual / pro.monthly).
4. Submit for Review.
