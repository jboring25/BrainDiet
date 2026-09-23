import SwiftUI

// MARK: - Q2 — How much of your day disappears to it? (Opal mapping row 2)
//
// Opal's first ask is self-quantification with a friction-free escape: a BIG
// number you own, not a multiple-choice band. Ours: a giant Young Serif hours
// numeral in the GRAY WORLD (the hours are loss — slop-gray by law), scrubbed
// by a horizontal drag on either the numeral or the rail, with a quiet
// "I don't know" escape that settles on the honest middle guess (3h). Continue
// is never blocked: an untouched scrubber commits the same default (the VM
// owns that).
//
// ⭐ 2026-07-22 UX audit:
//   • The − / + STEPPERS ARE GONE. The slider is the single input (Jack asked
//     for real dragging); duplicate on-screen controls for one value read as a
//     bug. VoiceOver keeps increment/decrement via accessibilityAdjustableAction
//     — accessibility is preserved without the second control.
//   • CONTRAST: the numeral was slop-gray (#9A948C = 2.69:1 on the gray canvas
//     #F4F2EF) at 0.45 opacity untouched (1.49:1) — unreadable. It now uses
//     `bdSlopGrayDisplay` (#7F776E, 3.94:1 — large text passes the 3:1 floor)
//     at 0.85 untouched (3.08:1, still passing). "I don't know" moved from
//     `bdGrayFaint` (#A9A29A, 2.26:1) to `bdGrayInk` (#5F5A52, 6.12:1). All
//     still gray — gray means loss by brand law; it just has to be legible.

struct TimeLostStepView: View {
    @Bindable var vm: OnboardingViewModel

    /// Live finger position (0...1 across the rail) WHILE dragging — nil at rest.
    /// Tracking a continuous fraction is what makes the thumb glide with the
    /// finger; the numeral snaps to whole hours off the same fraction.
    @State private var dragFraction: CGFloat? = nil
    /// The rail's committed fraction when a number-drag began (relative drag).
    @State private var dragBaseFraction: CGFloat? = nil
    /// The rail's measured width, so both gestures share one points-per-hour.
    @State private var railWidth: CGFloat = 0

    private static let range = 1...8
    private static let span = CGFloat(range.upperBound - range.lowerBound) // 7
    private static let thumbSize: CGFloat = 30

    /// Usable travel = rail width minus the thumb (so the thumb stays on-rail).
    private var usable: CGFloat { max(railWidth - Self.thumbSize, 1) }
    /// Resting thumb position for the committed hours.
    private var restingFraction: CGFloat {
        CGFloat(displayHours - Self.range.lowerBound) / Self.span
    }
    /// What the thumb currently shows — the live finger while dragging, else rest.
    private var thumbFraction: CGFloat { dragFraction ?? restingFraction }

    /// The number on screen — the committed answer, or the default shown faintly.
    private var displayHours: Int { vm.timeLostHours ?? OnboardingViewModel.defaultTimeLostHours }
    private var touched: Bool { vm.timeLostHours != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(
                title: "How much of your day disappears to them?",
                subtitle: "Drag the number until it feels true. A rough guess is fine."
            )

            // Fixed top inset, not an equal-flex Spacer — the number owns the
            // upper half of the screen; the slack collects at the bottom.
            scrubber
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.xxl)

            Spacer(minLength: Theme.Space.lg)

            // ⭐ "I don't know" REMOVED (Jack, 2026-08-05). The escape was
            // redundant: the slider already starts on the honest middle guess
            // (`defaultTimeLostHours`), so an untouched Continue commits the
            // exact same value the button did — it was a second door to the same
            // room, and it invited the user to skip the ONE self-quantification
            // beat the mirror is built from. No answer is lost by removing it.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: The scrubber — giant slop-gray serif numeral + a real drag rail.

    private var scrubber: some View {
        VStack(spacing: Theme.Space.lg) {
            // Numeral flanked by chevron hints so it reads as a draggable control.
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm + 2) {
                Image(systemName: "chevron.compact.left")
                    .font(.system(size: 30, weight: .semibold))
                    // Non-text UI indicator: 3:1 floor (1.4.11) — 0.9 α on the
                    // display gray composites to ~3.5:1.
                    .foregroundStyle(Color.bdSlopGrayDisplay)
                    .opacity(0.9)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }

                Text("\(displayHours)")
                    .font(.bdInstrument(76))
                    .monospacedDigit()
                    .foregroundStyle(Color.bdSlopGrayDisplay)
                    // Untouched = a suggestion, not yet an answer — but still
                    // legible: 0.85 composites to 3.08:1 (large-text AA floor).
                    .opacity(touched ? 1 : 0.85)
                    .contentTransition(.numericText())
                Text(displayHours == 1 ? "hour a day" : "hours a day")
                    .font(BDFont.body(.bold, size: 21, relativeTo: .title3))
                    .foregroundStyle(Color.bdGrayInk)
                    // 0.85 × #5F5A52 on #F4F2EF = 4.85:1 (body AA holds).
                    .opacity(touched ? 1 : 0.85)

                Image(systemName: "chevron.compact.right")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.bdSlopGrayDisplay)
                    .opacity(0.9)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
            }
            // The number itself is also draggable (relative drag).
            .frame(maxWidth: .infinity, minHeight: 96)
            .contentShape(Rectangle())
            .gesture(numberDrag)

            rail
        }
        .animation(Theme.Motion.snappy, value: displayHours)
        .animation(Theme.Motion.smooth, value: touched)
        .accessibilityElement()
        .accessibilityLabel("Hours a day lost to the feed")
        .accessibilityValue("\(displayHours) \(displayHours == 1 ? "hour" : "hours")")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(displayHours + 1)
            case .decrement: set(displayHours - 1)
            default: break
            }
        }
    }

    // MARK: The drag rail — the unmistakable "you drag this" affordance.

    private var rail: some View {
        let filledWidth = thumbFraction * usable + Self.thumbSize
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.bdGrayTile)
                .overlay(Capsule().strokeBorder(Color.bdGrayTileBorder, lineWidth: 1.5))
                .frame(height: 10)

            // The rail + thumb are the ONLY input now — they carry indicator
            // contrast (1.4.11, 3:1). bdSlopGray (2.69:1) was under the floor.
            Capsule()
                .fill(Color.bdSlopGrayDisplay.opacity(0.6))
                .frame(width: filledWidth, height: 10)

            Circle()
                .fill(Color.bdSlopGrayDisplay)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                .frame(width: Self.thumbSize, height: Self.thumbSize)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .offset(x: thumbFraction * usable)
        }
        .frame(height: Self.thumbSize)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width - 8 } action: { railWidth = $0 }
        .gesture(railDrag)
        // No animation on thumbFraction while dragging — it must track the finger.
        .animation(dragFraction == nil ? Theme.Motion.snappy : nil, value: thumbFraction)
        .accessibilityHidden(true)
    }

    /// Absolute drag on the rail: the thumb jumps to (and follows) the finger.
    private var railDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let f = min(max((value.location.x - Self.thumbSize / 2) / usable, 0), 1)
                dragFraction = f
                set(Int((f * Self.span).rounded()) + Self.range.lowerBound)
            }
            .onEnded { _ in
                withAnimation(Theme.Motion.snappy) { dragFraction = nil }
            }
    }

    /// Relative drag on the numeral, mapped through the same rail geometry so it
    /// feels identical to dragging the thumb.
    private var numberDrag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let base = dragBaseFraction ?? restingFraction
                if dragBaseFraction == nil { dragBaseFraction = base }
                let f = min(max(base + value.translation.width / usable, 0), 1)
                dragFraction = f
                set(Int((f * Self.span).rounded()) + Self.range.lowerBound)
            }
            .onEnded { _ in
                dragBaseFraction = nil
                withAnimation(Theme.Motion.snappy) { dragFraction = nil }
            }
    }

    private func set(_ hours: Int) {
        let clamped = min(max(hours, Self.range.lowerBound), Self.range.upperBound)
        guard clamped != vm.timeLostHours else { return }
        vm.timeLostHours = clamped
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }
}

#Preview {
    ZStack {
        Color.bdGrayCanvas.ignoresSafeArea()
        TimeLostStepView(vm: OnboardingViewModel()).padding(Theme.Space.screenX)
    }
}
