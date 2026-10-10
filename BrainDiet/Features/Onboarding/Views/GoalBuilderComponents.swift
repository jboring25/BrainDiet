import SwiftUI

// MARK: - Goal pieces (mock4 2026-10-09; reused by the moonshot screens, moon.png 2026-10-10).

/// "3h a day · feeling behind".
struct BuilderEchoChip: View {
    let text: String
    var ink: Color = .bdSalmonText
    var wash: Color = .bdSalmonWash

    var body: some View {
        Text(text)
            .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(wash, in: Capsule())
    }
}

/// Small uppercase label ("OTHERS HAVE WRITTEN", "THE ROAD THERE").
struct BuilderLabel: View {
    let text: String
    var color: Color = .bdTextTertiary
    var size: CGFloat = 10.5

    var body: some View {
        Text(text.uppercased())
            .font(BDFont.body(.extraBold, size: size, relativeTo: .caption2))
            .kerning(size * 0.12)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The shield as they will meet it, previewing their own reason + goal.
struct ShieldPreviewCard: View {
    let headline: String
    let line: String

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "When the feed pulls you in").uppercased())
                .font(BDFont.body(.extraBold, size: 10, relativeTo: .caption2))
                .kerning(1.2)
                .foregroundStyle(Color.bdShieldEyebrow)
            Text(headline)
                .font(BDFont.body(.semiBold, size: 16.5, relativeTo: .body))
                .foregroundStyle(Color.bdShieldInk)
                .padding(.top, 9)
                .contentTransition(.opacity)
            Text(line)
                .font(BDFont.body(.medium, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdShieldSub)
                .padding(.top, 3)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color.bdShieldGround, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        BDBackground()
        VStack(alignment: .leading, spacing: 14) {
            BuilderEchoChip(text: "3h a day · feeling behind")
            BuilderLabel(text: "Others have written")
            ShieldPreviewCard(headline: "You wanted to prove it to yourself.", line: "Go get BrainDiet launched.")
        }
        .padding(Theme.Space.screenX)
    }
}
