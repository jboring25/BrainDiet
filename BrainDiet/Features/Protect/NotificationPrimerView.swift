import SwiftUI

// MARK: - NotificationPrimerView — the pre-prompt priming sheet (first win).
//
// Shown right before the FIRST system notification ask (session-completion path):
// a rendered preview of the ACTUAL 20:00 nudge the user will get, one honest line
// about frequency, and two buttons. "Enable reminders" fires the real system
// prompt; "Not now" defers WITHOUT burning the one system ask — we simply offer
// again at a later win. Transparency wedge: the preview copy is the real copy.

struct NotificationPrimerView: View {
    /// The plan's next step — the preview mirrors the real daily-nudge body.
    let stepTitle: String
    let stepMinutes: Int
    let onEnable: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            Text("Want a dinner bell?")
                .font(BDFont.display(.semiBold, size: 28, relativeTo: .title))
                .foregroundStyle(Color.bdTextPrimary)
                .padding(.top, Theme.Space.lg)

            // The preview — exactly what will land on their lock screen.
            mockBanner

            Text("One gentle nudge a day, plus a quiet streak-save only when your brain hasn't been fed. Nothing else, ever.")
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Space.sm)

            BDPrimaryButton(title: "Enable reminders", action: onEnable)

            Button(action: onNotNow) {
                Text("Not now")
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Space.screenX)
        .padding(.bottom, Theme.Space.sm)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationBackground(Color.bdSurface)
    }

    private var mockBanner: some View {
        DinnerBellPreviewBanner(stepTitle: stepTitle, stepMinutes: stepMinutes)
    }
}

// MARK: - DinnerBellPreviewBanner — the faithful, honest notification preview.
//
// Shared by this sheet AND onboarding's DinnerBellStepView (Opal mapping row
// 12) so the preview copy can never drift from the real 20:00 nudge.

struct DinnerBellPreviewBanner: View {
    let stepTitle: String
    let stepMinutes: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            // App-icon dot: the plate thumbnail (brain retired from the UI).
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.bdBackground)
                .frame(width: 38, height: 38)
                .overlay {
                    BDPlateMark(nourishment: 1)
                        .frame(width: 34)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("BRAINDIET")
                        .font(.bdEyebrow)
                        .kerning(1.5)
                        .foregroundStyle(Color.bdTextSecondary)
                    Spacer()
                    Text("8:00 PM")
                        .font(.bdCaption)
                        .foregroundStyle(Color.bdTextSecondary.opacity(0.7))
                }
                Text("Dinner for your brain")
                    .font(BDFont.body(.semiBold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                Text("\(stepTitle) · \(stepMinutes)m? The time is yours the moment you take it.")
                    .font(.bdCaption)
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Color.bdSurfaceHi)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Color.bdCardBorder, lineWidth: 1)
                )
                .shadow(color: Theme.Shadow.cardColor, radius: Theme.Shadow.cardRadius / 2, y: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview of the daily reminder: Dinner for your brain. \(stepTitle), \(stepMinutes) minutes? The time is yours the moment you take it.")
    }
}

#Preview {
    ZStack { BDBackground() }
        .sheet(isPresented: .constant(true)) {
            NotificationPrimerView(
                stepTitle: "Read a few pages",
                stepMinutes: 35,
                onEnable: {},
                onNotNow: {}
            )
        }
}
