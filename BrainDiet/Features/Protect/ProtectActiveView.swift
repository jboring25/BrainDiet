import SwiftUI

// MARK: - Protect ACTIVE — "this time is yours, go do it" (spec-v2.3).
//
// A calm lock screen with a live countdown. The whole point is to push the user
// OUT: put the phone down and go do the goal. Copy is the goal-anchored release
// ("This time is yours — go read."), not a neutral focus timer.

struct ProtectActiveView: View {
    @Bindable var vm: ProtectSessionViewModel
    let onEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showEndConfirm = false

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            countdownRing

            releaseLine

            // Honesty: only claim resting apps when the shield is really up.
            if vm.blockingAuthorized { restingStatus }

            Spacer()

            // Finish early — intentionally subtle, never a tempting button.
            Button {
                showEndConfirm = true
            } label: {
                Text("Finish early")
                    .font(.bdBody)
                    .foregroundStyle(Color.bdTextSecondary)
                    .frame(minHeight: Theme.Size.minTouch)
                    .padding(.horizontal, Theme.Space.lg)
            }
            .buttonStyle(.plain)
            .padding(.bottom, Theme.Space.md)
        }
        .padding(.horizontal, Theme.Space.screenX)
        .confirmationDialog(
            "Come back early? \(vm.remainingMinutes) more minutes were yours.",
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish early", role: .destructive) { onEnd() }
            Button("Stay with it", role: .cancel) {}
        } message: {
            Text("This time is protected for you. You can pick it back up whenever you like.")
        }
    }

    // MARK: Countdown ring

    private var countdownRing: some View {
        let nearingWin = vm.progress >= 0.85
        return ZStack {
            BDProgressRing(
                progress: CGFloat(vm.progress),
                lineWidth: 6,
                active: nearingWin,
                animation: reduceMotion ? nil : .linear(duration: 0.3),
                gradient: .bdSageSweep
            )

            VStack(spacing: Theme.Space.sm) {
                Text(vm.remainingDisplay)
                    .font(.bdInstrument(70))
                    .monospacedDigit()
                    .kerning(-1)
                    .foregroundStyle(Color.bdTextPrimary)
                Text("THIS TIME IS YOURS")
                    .font(.bdEyebrow)
                    .kerning(2.5)
                    .foregroundStyle(Color.bdTextSecondary)
            }
        }
        .frame(width: 264, height: 264)
        .accessibilityElement()
        .accessibilityLabel("\(vm.remainingMinutes) minutes protected")
    }

    // MARK: The release — put the phone down and go do the goal.

    private var releaseLine: some View {
        Text(releasePromise)
            .font(BDFont.body(.regular, size: 18, relativeTo: .body))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }

    /// "Put the phone down. Go read." with the action breathing in sage.
    private var releasePromise: AttributedString {
        var s = AttributedString("Put the phone down. Go ")
        s.foregroundColor = Color.bdTextSecondary
        var action = AttributedString(vm.goalAction)
        action.foregroundColor = Color.bdAccent
        s.append(action)
        var end = AttributedString(".")
        end.foregroundColor = Color.bdTextSecondary
        s.append(end)
        return s
    }

    // MARK: Status — one warm, quiet line.

    private var restingStatus: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "leaf.fill")
                .font(.footnote)
                .foregroundStyle(Color.bdTextSecondary)
            Text("\(vm.restingApps.count) apps resting while you're gone")
                .font(.bdCaption)
                .foregroundStyle(Color.bdTextSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let vm = ProtectSessionViewModel()
    return ZStack {
        BDBackground()
        ProtectActiveView(vm: vm, onEnd: {})
            .onAppear { vm.start(reduceMotion: true) }
    }
}
