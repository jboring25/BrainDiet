import SwiftUI

// MARK: - Primary CTA — the one accent button (appetite pass 2026-07-18).
//
// Full-pill, SOLID leaf-deep fill (mockup `.cta`), WHITE bold label, a soft
// neutral lift shadow — NO ambient color glow (glow is reserved for earned
// milestones). Light haptic on press. ONE primary per screen. Disabled state
// dims to communicate "complete the step first."

struct BDPrimaryButton: View {
    let title: LocalizedStringResource
    /// Optional small trailing SF Symbol (e.g. "chevron.right" on commit CTAs).
    var trailingSymbol: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(BDFont.body(.bold, size: 16.5, relativeTo: .headline))
                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
                .foregroundStyle(Color.bdTextOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Size.buttonHeight)
                .background(
                    Color.bdLeafDeep,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                )
                .shadow(color: Color.black.opacity(isEnabled ? 0.18 : 0),
                        radius: 10, y: 5)
                .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, now in now }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { withAnimation(.easeOut(duration: 0.12)) { pressed = true } } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.18)) { pressed = false } }
        )
        .animation(Theme.Motion.smooth, value: isEnabled)
    }
}
