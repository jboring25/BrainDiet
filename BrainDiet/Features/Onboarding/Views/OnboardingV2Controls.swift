import SwiftUI

// MARK: - Onboarding v2 controls (Jack approved 2026-10-08).
//
// The mockup (design/onboarding-v2/screens.html) was painted on the real
// onboarding screens, so these are the existing OBOptionRow vocabulary — white
// fill, card border, 16pt control radius — carrying the three things v2 adds:
// a section label, a text area, and a label/value row.

/// "READING", "WHEN DOES YOUR DAY RUN?" — mockup `.lab`: leaf, extra-bold, caps.
struct OBSectionLabel: View {
    let text: String
    var domain: ActivityDomain? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let domain {
                BDPhIcon(icon: domain.phIcon, size: 13, color: Color.bdLeaf)
            }
            Text(text)
                .font(BDFont.body(.bold, size: 12, relativeTo: .caption))
                .kerning(0.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.bdLeaf)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Multiline answer field — mockup `.field`.
struct OBTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minLines: Int = 2
    var maxLength: Int = 140
    var isFocused: Bool = false

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { text },
            set: { text = String($0.prefix(maxLength)) }
        ), axis: .vertical)
            .font(BDFont.body(.medium, size: 15, relativeTo: .body))
            .foregroundStyle(Color.bdTextPrimary)
            .lineLimit(minLines...5)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bdSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(isFocused ? Color.bdLeaf.opacity(0.6) : Color.bdCardBorder,
                                  lineWidth: isFocused ? 1.5 : 1)
            }
    }
}

/// "Up at ········ 7:30" — mockup `.row`: label left, serif leaf value right.
struct OBValueRow: View {
    let label: String
    let value: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack {
                Text(label)
                    .font(BDFont.body(.semiBold, size: 16, relativeTo: .body))
                    .foregroundStyle(Color.bdTextPrimary.opacity(0.9))
                Spacer()
                Text(value)
                    .font(BDFont.serif(size: 21, relativeTo: .title3))
                    .foregroundStyle(Color.bdLeafDeep)
                    .monospacedDigit()
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(minHeight: Theme.Size.minTouch + Theme.Space.sm)
            .background(Color.bdSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel("\(label), \(value)")
    }
}

/// Single-select capsule — mockup `.chips span` (selected = solid leaf).
struct OBPillChip: View {
    let label: String
    let isSelected: Bool
    /// Selected fill. Nil = leaf-deep; the goal builder passes the goal's
    /// domain hue (mock4).
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(isSelected ? Color.white : Color.bdTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? (tint ?? Color.bdLeafDeep) : Color.bdSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? (tint ?? Color.bdLeafDeep) : Color.bdCardBorder,
                                                lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The DayAnchor chip, moved verbatim from the retired SpecificsStepView.
struct DayAnchorChip: View {
    let anchor: DayAnchor
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: anchor.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? Color.bdLeafDeep : Color.bdTextSecondary)
                Text(anchor.label)
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(isOn ? Color.bdLeafDeep : Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Color.bdLeafTint : Color.bdSurface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isOn ? Color.bdLeafDeep.opacity(0.35) : Color.bdCardBorder,
                                  lineWidth: isOn ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ZStack {
        BDBackground()
        VStack(alignment: .leading, spacing: 10) {
            OBSectionLabel(text: "Reading", domain: .reading)
            OBTextArea(placeholder: "e.g. bench 225 by May, or run a 5k", text: .constant(""))
            OBValueRow(label: "Up at", value: "7:30") {}
            HStack { OBPillChip(label: "Always", isSelected: true) {}; OBPillChip(label: "Custom", isSelected: false) {} }
            DayAnchorChip(anchor: .morningCoffee, isOn: true) {}
        }
        .padding(Theme.Space.screenX)
    }
}
