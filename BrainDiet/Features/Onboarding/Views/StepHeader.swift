import SwiftUI

// MARK: - Shared header for onboarding question steps (title + optional subtitle).

struct StepHeader: View {
    let title: LocalizedStringResource
    var subtitle: LocalizedStringResource? = nil
    /// Smaller title for dense screens (the goal builder's scene list).
    var compact: Bool = false

    var body: some View {
        // Appetite voice: question titles in Young Serif (mockup `.q-h`, 30px),
        // the subtitle quiet Manrope beneath.
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(compact ? BDFont.serif(size: 23, relativeTo: .title2) : .bdQuestionTitle)
                .foregroundStyle(Color.bdTextPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(BDFont.body(.medium, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
