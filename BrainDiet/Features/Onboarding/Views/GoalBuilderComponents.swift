import SwiftUI

// MARK: - Goal builder pieces (design/goal-builder/mock4, Jack approved 2026-10-09).

/// "3h a day · feeling behind" / "1 of 3 · launched something people use".
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

/// Small uppercase label: group names on goalScenes, the blank's prompt.
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

/// "✓ This builds your daily plan." — what the answer changes.
struct BuilderHelperLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color.bdLeafDeep)
                .frame(width: 22, height: 22)
                .background(Color.bdLeafTint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(text)
                .font(BDFont.body(.medium, size: 12.5, relativeTo: .footnote))
                .foregroundStyle(Color.bdTextSecondary)
        }
    }
}

/// The serif sentence. Filled words in the domain ink, underlined and
/// tappable (re-opens that blank); the current blank on a domain wash; future
/// blanks faded with a dashed rule. One Text, so it wraps like prose.
struct GoalSentenceCard: View {
    let pieces: [SentencePiece]
    let domain: ActivityDomain
    var size: CGFloat = 22
    var onTapBlank: ((Int) -> Void)? = nil

    private var attributed: AttributedString {
        let ink = domain.builderInk
        var out = AttributedString()
        for piece in pieces {
            switch piece {
            case .text(let t):
                var r = AttributedString(t)
                r.foregroundColor = Color.bdTextPrimary
                out += r
            case .blank(let i, let text, let state):
                var r = AttributedString(state == .current ? "\u{2009}\(text)\u{2009}" : text)
                switch state {
                case .filled:
                    r.foregroundColor = ink
                    r.underlineStyle = Text.LineStyle(pattern: .solid, color: domain.tint)
                    if onTapBlank != nil { r.link = URL(string: "bdblank://\(i)") }
                case .current:
                    r.foregroundColor = ink
                    r.backgroundColor = domain.tint.opacity(0.18)
                    r.underlineStyle = Text.LineStyle(pattern: .solid, color: domain.tint)
                case .future:
                    r.foregroundColor = Color.bdTabMuted
                    r.underlineStyle = Text.LineStyle(pattern: .dash, color: Color.bdTabMuted)
                    if onTapBlank != nil { r.link = URL(string: "bdblank://\(i)") }
                }
                out += r
            }
        }
        return out
    }

    var body: some View {
        Text(attributed)
            .font(BDFont.serif(size: size, relativeTo: .title2))
            .lineSpacing(size * 0.3)
            .tint(domain.builderInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1)
            }
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "bdblank", let i = Int(url.host() ?? "") { onTapBlank?(i) }
                return .handled
            })
    }
}

/// A sharper-version row (goalSharpen): domain-tinted when chosen.
struct BuilderAltRow: View {
    let text: String
    let isSelected: Bool
    let domain: ActivityDomain
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(BDFont.body(.semiBold, size: 14.5, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(isSelected ? domain.tint.opacity(0.14) : Color.bdSurface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? domain.tint : Color.bdCardBorder, lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
    let pieces: [SentencePiece] = [
        .text("I want to launch"), .text(" "), .blank(index: 0, text: "my app", state: .filled),
        .text(" and get "), .blank(index: 1, text: "100 people", state: .current), .text(" using it"),
        .text(" by "), .blank(index: 2, text: "when", state: .future), .text("."),
    ]
    return ZStack {
        BDBackground()
        VStack(alignment: .leading, spacing: 14) {
            BuilderEchoChip(text: "3h a day · feeling behind")
            GoalSentenceCard(pieces: pieces, domain: .building) { _ in }
            BuilderHelperLine(text: "This builds your daily plan.")
            BuilderAltRow(text: "Keep mine", isSelected: true, domain: .building) {}
            ShieldPreviewCard(headline: "You wanted to prove it to yourself.", line: "Go get back to BrainDiet.")
        }
        .padding(Theme.Space.screenX)
    }
}
