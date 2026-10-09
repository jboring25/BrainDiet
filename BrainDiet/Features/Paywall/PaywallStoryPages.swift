import SwiftUI

// MARK: - PAYWALL STORY PAGES — the argument, told in pictures.
//
// ⭐ 2026-08-11, from Jack's Opal teardown. Our paywall said everything true and
// said it all in prose: a serif headline, a three-row text timeline, two text
// price rows, a two-line billing paragraph. Opal makes the SAME argument across
// five swipeable pages that are almost entirely image, with the price block
// pinned underneath the whole time.
//
// The pinned price is what makes this different from the 3-page pager we
// deleted in July. That pager was a gate — three screens standing between the
// user and the offer. Here the offer is on screen from the first frame and
// never leaves; the pages are an argument you can keep reading or ignore, and
// you can buy at any point in it. Same transparency wedge, no gate.
//
// HONESTY, page by page:
//   • the projection is computed from the user's OWN answers (their stated
//     baseline, the deterministic plan's reclaim figure) — never a stock curve
//   • the plan page shows the goals they actually chose
//   • the two product pages live inside `BDDeviceFrame`, which is what makes a
//     populated screen honest: framed content reads as "the app", not "you"
//   • ⛔️ NO INVENTED SOCIAL PROOF. Opal's plan cards carry "7k Relaxing",
//     "12k Swimming". We have no users yet, so we have no such number, and the
//     mapping's deliberate-absences list has banned fabricated counts since day
//     one. That page is rebuilt around the user's own plan instead.

// MARK: - Shared page chrome

private struct StoryHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(BDFont.serif(size: 27, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct StoryPage<Visual: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var visual: Visual

    var body: some View {
        VStack(spacing: 0) {
            // ⭐ THE HEADLINE NEVER CLIPS (2026-10-09). The proof row under
            // the offer took ~60pt from the carousel and pages 2-4 lost their
            // first headline line, because an over-tall VStack in a fixed page
            // clips at BOTH ends. Now the header takes its full size first and
            // the visual gets what is left, top-aligned and clipped at its
            // bottom edge (the device frames already fade out there).
            StoryHeader(title: title, subtitle: subtitle)
                .padding(.bottom, 14)
                .layoutPriority(1)
            visual
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        }
        // ⛔️ NO `maxHeight: .infinity` ON THE VISUAL. It had one, and combined
        // with the Spacer the stack over-expanded inside the TabView's fixed
        // page — which CLIPS. The device-frame pages are the tall ones, so they
        // were the ones that lost their headline entirely: two of five pages
        // shipped with only a subtitle and I only caught it in the screenshot.
        // The visual sizes itself; the Spacer does the pushing.
    }
}

// MARK: - Page 1 · the projection (their numbers, their curve)

struct PaywallProjectionPage: View {
    /// The personalised line ("Keep your 2 hours a day pointed at reading.") —
    /// the proven converter, so it stays the first thing read on page one.
    let title: String
    /// The user's stated baseline in minutes/day (the timeLost answer).
    let baselineMinutes: Int

    var body: some View {
        StoryPage(title: title,
                  subtitle: String(localized: "Here's where this goes.")) {
            ReclaimCurve(
                // ⭐ ONE NUMBER (2026-10-09). "Today" is their own timeLost
                // answer, the same figure the mirror counted. The end point
                // carries no target: the old "Your target 1h" came from the
                // heuristic reclaim and disagreed with everything around it.
                fromLabel: String(localized: "Today \(BDMealTray.display(baselineMinutes))"),
                toLabel: String(localized: "With BrainDiet")
            )
            .padding(.horizontal, 2)
        }
    }
}

/// The descending curve. Deliberately NOT a chart — there is no measured data
/// yet, and axes would imply there is. It's a shape with two honest labels.
private struct ReclaimCurve: View {
    let fromLabel: String
    let toLabel: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let start = CGPoint(x: w * 0.13, y: h * 0.20)
            let end = CGPoint(x: w * 0.84, y: h * 0.74)

            ZStack(alignment: .topLeading) {
                // Soft glow under the fall — the "weight coming off" feeling.
                // Masked on BOTH axes: filled to the baseline it read as a chart
                // area with a hard left axis and a hard floor, which implies
                // measured data on a screen that has none yet. Faded, it's a
                // shadow under a shape.
                curvePath(w: w, h: h, start: start, end: end, closed: true)
                    .fill(LinearGradient(
                        colors: [Color.bdLeaf.opacity(0.22), Color.bdLeaf.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
                    .mask(
                        LinearGradient(
                            stops: [.init(color: .black.opacity(0), location: 0),
                                    .init(color: .black, location: 0.22),
                                    .init(color: .black, location: 0.86),
                                    .init(color: .black.opacity(0), location: 1)],
                            startPoint: .leading, endPoint: .trailing)
                    )

                curvePath(w: w, h: h, start: start, end: end, closed: false)
                    .stroke(Color.bdLeaf, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                node(filled: false).position(start)
                node(filled: true).position(end)

                pill(fromLabel, emphasised: false)
                    .position(x: min(w * 0.30, w - 60), y: h * 0.20 + 34)
                pill(toLabel, emphasised: true)
                    .position(x: max(w * 0.62, 60), y: h * 0.74 - 34)
            }
        }
        // 214 → 160 (2026-10-09): the headline is now two lines (their goal +
        // "Keep the time it needs.") and the proof row sits under the offer;
        // at 214 the page clipped the first headline line away.
        .frame(height: 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fromLabel). \(toLabel).")
    }

    private func curvePath(w: CGFloat, h: CGFloat,
                           start: CGPoint, end: CGPoint, closed: Bool) -> Path {
        Path { p in
            p.move(to: start)
            p.addCurve(to: end,
                       control1: CGPoint(x: w * 0.42, y: h * 0.22),
                       control2: CGPoint(x: w * 0.50, y: h * 0.76))
            if closed {
                p.addLine(to: CGPoint(x: end.x, y: h))
                p.addLine(to: CGPoint(x: start.x, y: h))
                p.closeSubpath()
            }
        }
    }

    private func node(filled: Bool) -> some View {
        Circle()
            .fill(filled ? Color.bdLeafDeep : Color.bdSurface)
            .frame(width: 15, height: 15)
            .overlay(Circle().strokeBorder(Color.bdLeafDeep, lineWidth: 2.5))
    }

    private func pill(_ text: String, emphasised: Bool) -> some View {
        Text(text)
            .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
            .monospacedDigit()
            .foregroundStyle(emphasised ? Color.white : Color.bdTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(emphasised ? Color.bdLeafDeep : Color.bdSurface)
                    .overlay(Capsule().strokeBorder(
                        emphasised ? Color.clear : Color.bdCardBorder, lineWidth: 1))
            )
            .fixedSize()
    }
}

// MARK: - Page 2 · their own plan

struct PaywallPlanPage: View {
    /// The domains the user actually chose, primary first.
    let domains: [ActivityDomain]

    var body: some View {
        StoryPage(title: String(localized: "A step for every part of your day."),
                  subtitle: String(localized: "Built from what you just told us.")) {
            VStack(spacing: 9) {
                ForEach(Array(domains.prefix(3)), id: \.self) { domain in
                    planRow(domain)
                }
            }
            .padding(.top, 6)
        }
    }

    /// Each row leads with the domain's icon tile — the same rounded tint tile
    /// + glyph Home uses (no food photography, 2026-10-09).
    private func planRow(_ domain: ActivityDomain) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(domain.categoryTint)
                .frame(width: 46, height: 46)
                .overlay(BDPhIcon(icon: domain.phIcon, size: 21, color: domain.categoryColor))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(domain.identityLine)
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(domain.label.lowercased())
                    .font(BDFont.body(.bold, size: 11.5, relativeTo: .caption))
                    .foregroundStyle(domain.categoryTextInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 13)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.cardCompact, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.cardCompact,
                                          style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Page 3 · the block, shown

struct PaywallProtectPage: View {
    var body: some View {
        StoryPage(title: String(localized: "Apps wait their turn."),
                  subtitle: String(localized: "A pause, then the thing you actually wanted.")) {
            // ⭐ SIZED TO THE PAGE BOX, not to taste. At width 196 the framed
            // pages stood ~430pt tall in a ~336pt page, and a TabView page
            // CLIPS FROM BOTH EDGES — so the headline was pushed off the top and
            // two of five pages shipped with only a subtitle. A shorter reveal
            // costs nothing (the fade already implies the rest of the phone);
            // a missing headline costs the whole page.
            TriagePoster.framed(width: 176)
        }
    }
}

/// A static composition of the real triage screen — same components, same
/// copy. Inside the frame this reads as the product, which is exactly what it
/// is; it claims nothing about the user.
///
/// INTERNAL, not private: `PauseStepView` shows the same poster before the
/// Screen Time ask. One composition, so the screen a user is sold on in
/// onboarding is pixel-for-pixel the one the paywall shows them again.
struct TriagePoster: View {
    /// The poster in its device frame, at the caller's size — so both surfaces
    /// can't drift on bezel, fade or ratio.
    static func framed(width: CGFloat, visibleFraction: CGFloat = 0.60) -> some View {
        BDDeviceFrame(width: width, visibleFraction: visibleFraction) { TriagePoster() }
    }

    var body: some View {
        ZStack {
            Color.bdBackground
            VStack(spacing: 0) {
                BDPlateMark(nourishment: 0, steaming: false)
                    .frame(width: 92)
                    .padding(.top, 62)
                    .padding(.bottom, 14)
                Text("What's this really about?")
                    .font(BDFont.serif(size: 17, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                posterRow("I'm bored", "nothing feels interesting")
                posterRow("I'm anxious", "need to get out of my head")
                posterRow("Just habit", "my hands did it on their own")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
        }
    }

    private func posterRow(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(BDFont.body(.bold, size: 10.5, relativeTo: .caption2))
                .foregroundStyle(Color.bdTextPrimary)
            Text(sub)
                .font(BDFont.body(.regular, size: 8.5, relativeTo: .caption2))
                .foregroundStyle(Color.bdTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1))
        )
        .padding(.bottom, 7)
    }
}

// MARK: - Page 4 · the payoff, shown

struct PaywallComebackPage: View {
    var body: some View {
        StoryPage(title: String(localized: "See the hours come back."),
                  subtitle: String(localized: "And what they turned into.")) {
            BDDeviceFrame(width: 176, visibleFraction: 0.60) { ComebackPoster() }
        }
    }
}

/// The conversion card — Jack's stated essence of the product ("the amount of
/// time they saved by not scrolling and how that time was converted into
/// progress"). Framed, so the figures read as the product's, not a promise.
private struct ComebackPoster: View {
    var body: some View {
        ZStack {
            Color.bdBackground
            VStack(alignment: .leading, spacing: 0) {
                Text("YOU GOT BACK")
                    .font(BDFont.body(.bold, size: 8, relativeTo: .caption2))
                    .kerning(1.4)
                    .foregroundStyle(Color.bdTextSecondary)
                // ⭐ 26pt, ONE LINE. At 34 the number wrapped to "12h / 15m"
                // once the frame narrowed to 176 — and the wrap pushed the
                // conversion line ("10h 30m of it became reading…") down into
                // the fade. The page is titled "And what they turned into" and
                // you could not see what they turned into. `lineLimit(1)` is
                // the guard so a wider number can never do this again.
                Text("12h 15m")
                    .font(BDFont.serif(size: 26, relativeTo: .title))
                    .foregroundStyle(Color.bdTextPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 1)
                Text("this week, against the 3h a day you started at.")
                    .font(BDFont.body(.medium, size: 9, relativeTo: .caption2))
                    .foregroundStyle(Color.bdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Rectangle().fill(Color.bdCardBorder).frame(height: 1)
                    .padding(.vertical, 10)

                Text("10h 30m of it became reading, training and building.")
                    .font(BDFont.body(.bold, size: 9.5, relativeTo: .caption2))
                    .foregroundStyle(Color.bdLeafDeep)
                    .fixedSize(horizontal: false, vertical: true)

                weekStrip.padding(.top, 14)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            // 40, not 66 — the old inset was tuned for a 196pt frame and left
            // the payoff line sitting in the fade at 176.
            .padding(.top, 40)
        }
    }

    /// Seven days of plates — the week strip Apple Fitness's ring row taught us
    /// to put above the number so an honest screen never reads as empty.
    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(i < 5 ? Color.bdLeafTint : Color.bdCream)
                    .overlay(Circle().strokeBorder(
                        i < 5 ? Color.bdLeaf.opacity(0.55) : Color.bdCardBorder, lineWidth: 1.2))
                    .frame(height: 18)
            }
        }
    }
}

// MARK: - Page 5 · what actually happens (the transparency wedge, as a beat)

struct PaywallTimelinePage: View {
    /// True only when the CURRENT selection really carries a trial.
    let trialSelected: Bool

    var body: some View {
        StoryPage(
            title: trialSelected
                ? String(localized: "Free for \(PaywallPricing.trialDays) days.")
                : String(localized: "Everything on your plan."),
            subtitle: trialSelected
                ? String(localized: "Here's exactly what happens next.")
                : String(localized: "No first-step-only limits.")
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if trialSelected {
                    row(.leaf, .bdLeaf, .bdLeafTint, String(localized: "Today"),
                        String(localized: "Full access, free for \(PaywallPricing.trialDays) days."), true)
                    row(.bell, .bdLeaf, .bdLeafTint, String(localized: "Day \(PaywallPricing.trialDays - 1)"),
                        String(localized: "We remind you before you're charged."), true)
                    row(.sparkle, .bdHoneyText, .bdHoneyTint, String(localized: "Day \(PaywallPricing.trialDays)"),
                        String(localized: "Your plan begins, \(PaywallPricing.weeklyDisplay)/week."), false)
                } else {
                    row(.leaf, .bdLeaf, .bdLeafTint,
                        String(localized: "Every step on your plan"),
                        String(localized: "Not just the first step of each goal."), true)
                    row(.moon, .bdLeaf, .bdLeafTint,
                        String(localized: "Apps rest while you focus"),
                        String(localized: "As many sessions a day as you want."), true)
                    row(.sparkle, .bdHoneyText, .bdHoneyTint,
                        String(localized: "Your whole comeback, tracked"),
                        String(localized: "Every hour you take back, kept honest."), false)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 6)
        }
    }

    private func row(_ icon: BDPh, _ color: Color, _ tint: Color,
                     _ title: String, _ detail: String, _ connects: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint)
                    .frame(width: 36, height: 36)
                    .overlay(BDPhIcon(icon: icon, size: 18, color: color))
                if connects {
                    Rectangle().fill(Color.bdCardBorder).frame(width: 2, height: 14)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                Text(detail)
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
