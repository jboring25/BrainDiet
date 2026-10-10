import SwiftUI

// MARK: - CommitStepView · the drag, the drop, the commit.
//
// Mirrors Home's `TodaysFocusCard` gesture and drives the shared
// `PlateDropController` (morph, outline hit-test, brain-unit drop point). See
// the header in CommitStepView.swift for the full contract.

extension CommitStepView {

    /// Touch lifts at once; a 0.16s hold arms the drag (Home's exact gesture).
    var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.16)
            .onChanged { _ in
                guard !committed, !drop.isDragging else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            }
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .updating($pressing) { value, state, _ in
                switch value {
                case .first(true), .second(true, _): state = true
                default: break
                }
            }
            .onChanged { value in
                guard !committed, case .second(true, let d?) = value else { return }
                if !drop.isDragging { pickUp(at: d.startLocation) }
                drop.update(d)
            }
            .onEnded { _ in release() }
    }

    /// The card starts exactly where it rests: position = rest + translation,
    /// and the drag origin is the finger, so nothing jumps on pickup.
    func pickUp(at finger: CGPoint) {
        if !cardRect.isEmpty {
            grabAnchor = UnitPoint(
                x: min(1, max(0, (finger.x - cardRect.minX) / cardRect.width)),
                y: min(1, max(0, (finger.y - cardRect.minY) / cardRect.height)))
        }
        drop.begin(payload, rowID: nil, origin: finger, haptic: false)
    }

    func release() {
        guard drop.isDragging, !committed else { return }
        if drop.isOverPlate, let p = drop.brainPoint(for: drop.point) {
            commit(at: p)
        } else {
            springHome()
        }
    }

    /// Outside the brain: the ball rides back with the card and re-forms it.
    func springHome() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            drop.point = drop.cardOrigin
            drop.clear()
        }
    }

    /// A cancelled gesture (system interruption, a second finger) never reaches
    /// `onEnded`, but `pressing` always resets. Checked a turn later so a real
    /// release has already been handled.
    func recoverIfStranded() {
        DispatchQueue.main.async {
            if drop.isDragging, !committed { springHome() }
        }
    }

    /// `at`: the drop spot in brain units, or nil for the tap / a11y path, which
    /// sends the serving in from the default entry like before.
    func commit(at point: CGPoint?) {
        guard !committed else { return }
        committed = true
        debugLift = false

        let landing = UINotificationFeedbackGenerator()
        landing.prepare()
        landing.notificationOccurred(.success)
        ServeSound.shared.play(.serve)

        if let point {
            culture.feed(at: point)
            // By the outline the card is already ~fully the ball; this only
            // hands the ball to the brain's own serving at the same spot.
            withAnimation(.easeOut(duration: 0.12)) { cardGone = true }
        } else {
            culture.feed()
            withAnimation(.easeOut(duration: 0.28)) { cardGone = true }
        }

        // The served-from-edge path travels in first, so it waits a beat longer.
        let wait = settleDelay + (point == nil ? 500 : 0)
        guard !holdOnCommit else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(wait))
            vm.advance()
        }
    }

    private var payload: PlateDraggable {
        PlateDraggable(title: identityLine, subtitle: "who you're becoming",
                       activityID: domain.activityID, goalID: nil, stepID: nil,
                       minutes: 0, icon: domain.phIcon,
                       tint: domain.categoryTint, ink: domain.categoryColor)
    }

    /// DEBUG / ad seams never auto-advance, so the end state can be captured.
    private var holdOnCommit: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["BD_COMMIT_STATE"] != nil || AdMode.isEnabled
        #else
        return AdMode.isEnabled
        #endif
    }

    #if DEBUG
    /// BD_COMMIT_STATE=committed holds the end state. BD_COMMIT_STATE=drag plays
    /// a miss (spring home) then a drop, through the same controller as a finger.
    /// BD_AD_SHOT=commit: the tap path on a timer.
    func seedForScreenshots() {
        let env = ProcessInfo.processInfo.environment
        if AdMode.isEnabled, AdMode.shot == .commit {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1400))
                commit(at: nil)
            }
            return
        }
        switch env["BD_COMMIT_STATE"] {
        case "committed":
            // After the brain's own onAppear seed (seed() clears any serving),
            // and late enough that a recording sees the tap path's feed.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(2600))
                commit(at: nil)
            }
        case "drag": Task { @MainActor in await autoplay() }
        default: break
        }
    }

    private func autoplay() async {
        try? await Task.sleep(for: .milliseconds(2600))
        guard !cardRect.isEmpty, !drop.cultureRect.isEmpty else { return }
        let grab = CGPoint(x: cardRect.midX + 40, y: cardRect.midY)
        let brain = CGPoint(x: drop.cultureRect.midX, y: drop.cultureRect.midY + 10)

        // 1 · a miss: stop just under the brain and let go.
        await fly(from: grab, to: CGPoint(x: brain.x + 90, y: drop.cultureRect.maxY + 70), frames: 40)
        release(); debugLift = false
        try? await Task.sleep(for: .milliseconds(1100))

        // 2 · the drop: into the brain, slightly off-centre.
        await fly(from: grab, to: CGPoint(x: brain.x - 30, y: brain.y), frames: 55)
        release()
    }

    private func fly(from a: CGPoint, to b: CGPoint, frames: Int) async {
        debugLift = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        try? await Task.sleep(for: .milliseconds(160))
        pickUp(at: a)
        for i in 1...frames {
            let t = Double(i) / Double(frames)
            let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            drop.update(translation: CGSize(width: (b.x - a.x) * e, height: (b.y - a.y) * e))
            try? await Task.sleep(for: .milliseconds(16))
        }
        try? await Task.sleep(for: .milliseconds(120))
    }
    #endif
}

// MARK: - The morph — card → serving ball, driven only by drag state.
//
// No implicit animation touches these: position must track the finger exactly.
// Only the spring-home (an explicit withAnimation) ever eases them.

struct CommitMorph: ViewModifier {
    let drop: PlateDropController
    let anchor: UnitPoint
    let gone: Bool

    /// The commit card travels ~450pt (Home's ~150pt), so a linear morph has it
    /// half-dissolved mid-flight. Ease-in keeps it a card until it nears the brain.
    static func eased(_ m: CGFloat) -> CGFloat { m * m }

    func body(content: Content) -> some View {
        let m = CommitMorph.eased(drop.morph)
        // Home's tilt: a hint of lean in the direction of travel, gone as it morphs.
        let tilt = drop.isDragging ? max(-2, min(2, Double(drop.translation.width) * 0.02)) : 0
        content
            .scaleEffect(1 - 0.9 * m, anchor: anchor)
            .blur(radius: m * 5)
            .opacity(gone ? 0 : Double(max(0, 1 - m * 1.5)))
            .rotationEffect(.degrees(tilt * Double(1 - m)), anchor: anchor)
            .offset(drop.translation)
    }
}

// MARK: - The identity card — the user's own line.

struct CommitIdentityCard: View {
    let domain: ActivityDomain
    let line: String
    /// Touch-down lift: 1.025 + deeper shadow, the same as Home's focus card.
    var lifted: Bool

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(domain.categoryTint)
                .frame(width: 36, height: 36)
                .overlay(BDPhIcon(icon: domain.phIcon, size: 17, color: domain.categoryColor))

            VStack(alignment: .leading, spacing: 1) {
                Text(line)
                    .font(BDFont.body(.bold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("who you're becoming")
                    .font(BDFont.body(.bold, size: 11, relativeTo: .caption2))
                    .foregroundStyle(domain.categoryTextInk)
            }

            Spacer(minLength: Theme.Space.sm)

            BDPhIcon(icon: .dotsSixVertical, size: 15, color: .bdTabMuted)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(minHeight: Theme.Size.minTouch + 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.bdCardBorder, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: Color(hex: "#2F5E3C").opacity(lifted ? 0.22 : 0.08),
                radius: lifted ? 18 : 8, y: lifted ? 12 : 4)
        .scaleEffect(lifted ? 1.025 : 1)
        // Scoped to the lift only — the morph/offset above this view are never eased.
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: lifted)
    }
}

#Preview {
    CommitIdentityCard(domain: .reading, line: "Reading every night.", lifted: true)
        .padding()
}
