import SwiftUI

// MARK: - Render the branded share frame to a crisp UIImage.

@MainActor
enum PlanShareRenderer {
    /// Renders PlanShareCard at the device's screen scale (≈3x) so it's crisp
    /// for posting. Returns nil only if rendering fails.
    static func image(for plan: BrainPlan, servings: [PlanServing] = []) -> UIImage? {
        let renderer = ImageRenderer(content: PlanShareCard(plan: plan, servings: servings))
        // Render at 3x for a crisp, post-ready image. (UIScreen.main is
        // deprecated in iOS 26 and the share image isn't tied to a window, so we
        // pin a high fixed scale rather than chase the active scene's scale.)
        renderer.scale = 3
        renderer.isOpaque = true               // dark bg baked in, not transparent
        return renderer.uiImage
    }
}

// MARK: - Reusable "Share my plan" affordance.
//
// Secondary by design — never competes with a screen's primary CTA.
// Uses ShareLink over the pre-rendered image so it's a true system share sheet
// (Messages / Instagram / Save to Photos).

struct PlanShareButton: View {
    let plan: BrainPlan
    /// The daily servings printed on the shared document.
    var servings: [PlanServing] = []
    /// `prominent` = a bordered pill (under-card); `compact` = a toolbar icon.
    var style: Style = .prominent
    /// Compact icon tint (Home's header pairs it with the settings gear).
    var iconColor: Color = .bdAccentDeep

    enum Style { case prominent, compact }

    var body: some View {
        if let image = PlanShareRenderer.image(for: plan, servings: servings) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("My BrainDiet plan", image: Image(uiImage: image))
            ) {
                label
            }
            .accessibilityLabel("Share my plan")
        }
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .prominent:
            // Quiet text link — no boxed second button competing with the CTA.
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Share my plan")
            }
            .font(BDFont.body(.medium, size: 15, relativeTo: .subheadline))
            .foregroundStyle(Color.bdTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.minTouch)
        case .compact:
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
        }
    }
}

#Preview {
    ZStack {
        BDBackground()
        PlanShareButton(plan: .mock(goalNoun: "your book", why: "I want to write my book"))
            .padding(Theme.Space.screenX)
    }
}
