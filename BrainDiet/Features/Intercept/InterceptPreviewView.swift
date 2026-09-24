import SwiftUI
import SwiftData

#if DEBUG
// DEBUG-ONLY: the real intercept ships as the entitlement-gated
// ShieldConfiguration extension; this in-app mirror exists purely for design
// review / marketing screenshots and never compiles into release.

// MARK: - InterceptPreviewView — THE ATTRACTION INTERCEPT (Jack, 2026-07-18).
//
// Spec of record: design/plate-concepts/intercept-attraction-mockup.html —
// built from its CSS values, never prose. The attraction law governs this
// surface: show what the user COULD HAVE, never what they're avoiding. The
// gray slop plate is GONE from the intercept (PlateSlop renders only in
// Becoming's week strip, as honest history).
//
// Slots, top to bottom (the law's five, nothing else):
//   1. TODAY'S REAL PLATE — the same full-color crossfade stack Home uses,
//      driven by actual engine completeness; a honey glow marks the empty
//      region while the plate is incomplete (the invitation, not an alarm).
//   2. one identity sentence (serif, goal-driven, last words salmon),
//   3. ONE concrete serving (the engine's highest-value suggestion),
//   4. primary CTA "Feed my brain" → the SAME stitched live-session path as
//      Home's CTA and the Menu's Start (critique ask #6),
//   5. quiet "Continue anyway".
//
// The OS ShieldConfiguration can't draw this layout (icon/title/subtitle/
// buttons only) — on-device it approximates with the PlateInviteCard icon +
// the possibility-voiced copy synced via ShieldContent.

struct InterceptPreviewView: View {

    let content: ShieldContent
    /// Called when the moment resolves (either choice) — dismisses the preview.
    var onResolve: () -> Void = {}
    /// Loop stitching (critique ask #6): the primary choice lands in the SAME
    /// live session flow as Home's CTA and the Menu's Start. nil = pure
    /// preview (Settings).
    var onProtect: (() -> Void)? = nil

    /// The one state object — plate render, caption, and serving all read from
    /// it (PLATE-ENGINE.md: no surface computes its own recommendation).
    @Environment(PlateEngine.self) private var plate
    @Query private var goals: [Goal]

    /// Measured render width — drives the glow geometry (mockup fractions).
    @State private var plateWidth: CGFloat = 437

    // Mockup metrics (intercept-attraction-mockup.html).
    private enum M {
        /// `.body{padding:0 26px 22px}`
        static let screenX: CGFloat = 26
        /// `.plate{width:128%;margin:0 -14%}` → overhang beyond the padding.
        static let plateOverhang: CGFloat = 48
    }

    var body: some View {
        ZStack {
            Color.bdBackground.ignoresSafeArea()   // the cream canvas, full bleed

            VStack(spacing: 0) {
                // "YOUR PLATE TODAY" removed 2026-09-24 (Jack): the plate is not
                // the object on this screen, the brain is.

                plateBlock

                // `.cap` — the honey truth caption, engine-derived.
                Text(caption)
                    .font(BDFont.display(.extraBold, size: 11, relativeTo: .caption2))
                    .kerning(1.4)
                    .foregroundStyle(Color.bdHoneyText)
                    .padding(.top, -4)

                headline

                if let serving {
                    servingCard(serving)
                }

                Spacer(minLength: Theme.Space.md)

                // `.cta` — the leaf-deep pill; straight into the live session.
                // Serving-aware (same law as Home's card): dessert is SERVED.
                BDPrimaryButton(title: LocalizedStringResource(stringLiteral: primaryTitle)) {
                    onProtect?()
                    onResolve()
                }

                // `.ghost` — the quiet escape hatch.
                Button { onResolve() } label: {
                    Text("Continue anyway")
                        .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Size.buttonHeight)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, M.screenX)
            .padding(.bottom, 10)
        }
    }

    // MARK: 1 · Today's REAL plate — the crossfade stack at actual completeness.

    private var plateBlock: some View {
        BDPlateMark(nourishment: plate.completeness)
            .overlay {
                // `.glow` — honey radial over the still-empty region. The
                // invitation: only while the plate is PARTIALLY complete.
                // Jack's standing glow ruling (2026-07-18, re-verified on this
                // surface's fresh shot): on fully-empty porcelain the glow
                // reads as a STAIN, not an invitation — the caption carries
                // the fresh-plate invitation instead.
                if plate.completeness > 0, plate.completeness < 1 {
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [Color.bdHoney.opacity(0.5), Color.bdHoney.opacity(0)],
                            center: .center, startRadius: 0, endRadius: plateWidth * 0.149))
                        .frame(width: plateWidth * 0.298, height: plateWidth * 0.211)
                        .blur(radius: 2)
                        .offset(x: plateWidth * 0.082, y: plateWidth * 0.029)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, -M.plateOverhang)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { plateWidth = $0 }
            .accessibilityElement()
            .accessibilityLabel("Today: \(plate.balanceWord())")
    }

    /// The honey caption tells the plate's TRUTH — derived from the engine,
    /// never asserted ("one serving away" only when it is).
    private var caption: String {
        if plate.completeness >= 1 {
            return String(localized: "TODAY'S PLATE IS COMPLETE")
        }
        if plate.doneCount == 0 {
            return String(localized: "YOUR FIRST SERVING IS WAITING")
        }
        let missing = plate.planCount - plate.doneCount
        if missing == 1 { return String(localized: "ONE SERVING AWAY FROM COMPLETE") }
        if missing == 2 { return String(localized: "TWO SERVINGS AWAY FROM COMPLETE") }
        return String(localized: "\(missing) SERVINGS AWAY FROM COMPLETE")
    }

    // MARK: 2 · The identity sentence — serif, last words salmon (`.h1 em`).

    /// ⭐ THE HEADLINE FOLLOWS THE STEP (fixed 2026-09-21). The headline used to
    /// come from `content.goalID` (the profile's headline goal) while the serving
    /// came from `plate.suggestion` — two sources, so the shield could say
    /// "You're a reader." above "Lay out your gym clothes." The serving stays
    /// the engine's pick (this view must not recommend on its own), so the
    /// identity is taken FROM the serving's goal. Falls back to the synced goal
    /// only when the serving belongs to no goal (an off-plan activity).
    private var headlineGoalID: String? {
        if let id = serving?.goalID,
           let goal = goals.first(where: { $0.id == id }),
           let domain = ActivityDomain(rawValue: goal.domain) {
            return domain.legacyGoalID
        }
        return content.goalID
    }

    private var headline: some View {
        let parts = GoalCatalog.becameWishParts(for: headlineGoalID)
        return (Text(parts.prefix).foregroundColor(Color.bdTextPrimary)
                + Text(verbatim: "\n")
                + Text(parts.emphasis).foregroundColor(Color.bdSalmon))
            .font(BDFont.serif(size: 29, relativeTo: .title))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 14)
    }

    // MARK: 3 · ONE serving — the engine's highest-value suggestion (`.srv`).

    private var serving: PlateServing? {
        plate.suggestion ?? PlateEngine.buildCatalog(goals: []).first
    }

    /// The CTA speaks the VISIBLE serving's verb (PlateCategory.ctaTitle — the
    /// one shared source with Home's card): "Serve dessert" when the plate is
    /// complete and dessert is the suggestion, "Feed my brain" otherwise.
    private var primaryTitle: String {
        serving?.category.ctaTitle ?? content.primary
    }

    private func servingCard(_ s: PlateServing) -> some View {
        HStack(spacing: 12) {
            PlateCategoryChip(category: s.category, size: 40, iconSize: 20, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title)
                    .font(BDFont.display(.extraBold, size: 15.5, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                Text("\(s.minutes) minutes")   // food word cut 2026-08-18 — see PlanCard
                    .font(BDFont.body(.bold, size: 12, relativeTo: .footnote))
                    .foregroundStyle(s.category.textInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.bdSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
                )
        )
        .padding(.top, 18)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Reader") {
    let engine = PlateEngine()
    let _ = engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    InterceptPreviewView(content: ShieldContentBuilder.make(goalID: "read"))
        .environment(engine)
}

#Preview("Fitness") {
    let engine = PlateEngine()
    let _ = engine.sync(goals: [], sessions: [], junkMinutes: 0, junkAppCount: 0)
    InterceptPreviewView(content: ShieldContentBuilder.make(goalID: "fitness"))
        .environment(engine)
}

#Preview("Fallback") {
    InterceptPreviewView(content: .fallback)
        .environment(PlateEngine())
}
#endif
