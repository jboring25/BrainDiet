import SwiftUI

// MARK: - Marketing constants

enum BrandLinks {
    /// Printed on the share card as text. TODO(marketing-url): swap to the
    /// App Store link once the app is live (this is the "get your own" CTA
    /// strangers read). Points at the hosted site meanwhile so it resolves.
    static let getYourOwnURL = "https://braindiet.netlify.app"
}

// MARK: - PlanShareCard — the standalone, branded share frame (art-direction v1).
//
// The cream nutrition label, plated on the warm-dark cinematic table, framed for
// a feed. NOT a screenshot: a composed graphic with the warm-dark base baked in
// (so it reads on any feed), the PlanCard signature artifact, and a footer CTA.
// Rendered to a UIImage via ImageRenderer (see PlanShareButton) at 3x.
//
// Sized to a portrait share frame (1080×1350 @3x — IG portrait ratio).

struct PlanShareCard: View {
    let plan: BrainPlan
    var servings: [PlanServing] = []

    var body: some View {
        VStack(spacing: Theme.Space.lg) {

            Spacer(minLength: Theme.Space.sm)

            BrandWordmark(tone: .onDark, size: 16)

            // Editorial hook in the display face.
            Text("Take your life back.")
                .font(BDFont.display(.bold, size: 26, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)

            // The meal-plan document (static — no animation in a render).
            PlanCard(plan: plan, servings: servings, animate: false)

            // ⭐ The brand sign-off. It used to be printed inside PlanCard; the
            // 2026-07-22 card rebuild closes on the "A FULL PLATE" total, so the
            // line moved OUT to the surface that actually gets shared.
            Text("Your brain eats too.")
                .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                .kerning(0.3)
                .foregroundStyle(Color.bdTextSecondary)

            // Footer CTA — self-contained.
            VStack(spacing: Theme.Space.xs) {
                Text("Get your own BrainDiet")
                    .font(.bdBodyStrong)
                    .foregroundStyle(Color.bdTextPrimary)
                Text(BrandLinks.getYourOwnURL.replacingOccurrences(of: "https://", with: ""))
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdGold)
            }

            Spacer(minLength: Theme.Space.sm)
        }
        .padding(Theme.Space.xl)
        .frame(width: 400, height: 680)   // taller portrait so the full document fits
        .background(
            ZStack {
                Color.bdBackground
                RadialGradient(
                    colors: [Color.bdAccent.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.5, y: 0.04), startRadius: 0, endRadius: 360)
                RadialGradient(
                    colors: [Color.bdGold.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.95, y: 0.95), startRadius: 0, endRadius: 320)
            }
        )
    }
}

#Preview {
    PlanShareCard(
        plan: .mock(goalNoun: "your book", why: "I want to write my book"),
        servings: [
            PlanServing(symbol: "book.fill", title: "Read more", count: 1,
                        minutes: 25, domain: .reading),
            PlanServing(symbol: "dumbbell.fill", title: "Get stronger", count: 1,
                        minutes: 50, domain: .fitness),
            PlanServing(symbol: "hammer.fill", title: "Build something", count: 1,
                        minutes: 50, domain: .building)
        ]
    )
}
