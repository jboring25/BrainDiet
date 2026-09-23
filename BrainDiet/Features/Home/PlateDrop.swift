import SwiftUI

// MARK: - PlateDrop — drag a serving you already did onto the plate.
//
// Spec of record: design/plating/index.html (approved 2026-08-20), including the
// motion spec panel — every duration and spring below comes from it rather than
// from prose.
//
// WHY THIS EXISTS. Sessions auto-plate, and that only ever recorded the people
// who need a timer to focus. Anyone who can lock in for hours doesn't open the
// app while doing it, so their best work was invisible and Becoming under-counted
// their actual life. Dragging is the report mechanism because it is one gesture
// with no form, and because the plate is the app's hero object — until now the
// user could only watch it fill.
//
// ⛔️ NO OUTLINE EVER TOUCHES THE DROP TARGET (Jack, 2026-08-20: the dashed gold
// halo "looks cheap"). Elevation carries the entire state — the row goes white,
// lifts, tilts and casts a DIRECTIONAL shadow, and its slot empties behind it.
// The plate answers by SETTLING: its contact shadow tightens and darkens, the
// read being a bowl bracing to take weight. References: Linktree's reorder and
// Craft both carry drag state on elevation alone; Shelf uses a quiet filled slot
// rather than a dashed one.
//
// ⭐ THE HERO RENDER IS NEVER ANIMATED IN CODE. The contact shadow is its own
// layer underneath the image. The plate's own change is the EXISTING asset ramp
// (PlateEmpty → PlateMorning → …), which is a crossfade between shipped renders.
// This is the [[feedback_no_handbuilt_animation]] rule and it is why the target
// acknowledges with a shadow rather than a scale-pop.

/// What is being dragged — enough to persist a session on drop.
struct PlateDraggable: Equatable {
    let title: String
    let subtitle: String
    let activityID: String
    let goalID: UUID?
    let stepID: UUID?
    let minutes: Int
    let icon: BDPh
    let tint: Color
    let ink: Color
}

@MainActor
@Observable
final class PlateDropController {

    /// The hero's rect in the Home coordinate space. Empty until it lands.
    var plateRect: CGRect = .zero
    /// The dragged payload, non-nil for the whole gesture.
    var payload: PlateDraggable?
    /// Where the lifted card sits, in the Home coordinate space.
    var cardOrigin: CGPoint = .zero
    var translation: CGSize = .zero
    /// True while the card's centre is inside the plate.
    var isOverPlate = false
    /// The row that vacated, so its slot can render as an empty recess.
    var liftedRowID: UUID?

    var isDragging: Bool { payload != nil }

    /// Card centre in Home space, mid-drag.
    private var cardCentre: CGSize { translation }

    func begin(_ item: PlateDraggable, rowID: UUID?, origin: CGPoint) {
        payload = item
        liftedRowID = rowID
        cardOrigin = origin
        translation = .zero
        isOverPlate = false
        let lift = UIImpactFeedbackGenerator(style: .light)
        lift.prepare(); lift.impactOccurred(intensity: 0.55)
    }

    /// Updates the drag and returns true when the target state CHANGED, so the
    /// caller can fire the entry haptic exactly once (spec: entry only, never
    /// on exit — leaving is not an event).
    @discardableResult
    func update(_ value: DragGesture.Value) -> Bool {
        translation = value.translation
        let centre = CGPoint(x: cardOrigin.x + value.translation.width,
                             y: cardOrigin.y + value.translation.height)
        // A generous inset: the bowl render is full-bleed and mostly empty at the
        // corners, so hit-testing the raw rect would accept drops over blank cream.
        let target = plateRect.insetBy(dx: plateRect.width * 0.14,
                                       dy: plateRect.height * 0.10)
        let now = !target.isEmpty && target.contains(centre)
        guard now != isOverPlate else { return false }
        isOverPlate = now
        if now {
            let tap = UIImpactFeedbackGenerator(style: .soft)
            tap.prepare(); tap.impactOccurred(intensity: 0.5)
        }
        return true
    }

    /// Ends the gesture. Returns the payload when it landed on the plate.
    func end() -> PlateDraggable? {
        defer { clear() }
        return isOverPlate ? payload : nil
    }

    func clear() {
        payload = nil
        liftedRowID = nil
        translation = .zero
        isOverPlate = false
    }
}

// MARK: - The lifted card — elevation, tilt, directional shadow.

struct PlateDragCard: View {
    let item: PlateDraggable
    /// Raised further while over the target.
    var near: Bool

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(item.tint)
                .frame(width: 34, height: 34)
                .overlay(BDPhIcon(icon: item.icon, size: 16, color: item.ink))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(BDFont.body(.bold, size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(BDFont.body(.medium, size: 11.5, relativeTo: .caption))
                    .foregroundStyle(Color.bdTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bdSurface)
        )
        // Directional — cast down and slightly back. A symmetric shadow reads as
        // a glow, which is the treatment that got rejected.
        .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
        .shadow(color: .black.opacity(near ? 0.34 : 0.30),
                radius: near ? 25 : 18, y: near ? 30 : 20)
        .scaleEffect(near ? 1.06 : 1.03)
        .accessibilityHidden(true)
    }
}

// MARK: - The plate's answer — a contact shadow that tightens.
//
// Sits UNDER the hero image, never on it. At rest it is wide and faint; braced
// it pulls in and darkens, which is what a real bowl's shadow does when weight
// arrives. Spec: alpha .12 → .32, width 190 → 158, 0.22s ease-out.

struct PlateContactShadow: View {
    var braced: Bool

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#3A2E1E").opacity(braced ? 0.32 : 0.12),
                             Color(hex: "#3A2E1E").opacity(braced ? 0.14 : 0.055),
                             Color(hex: "#3A2E1E").opacity(0)],
                    center: .center, startRadius: 0, endRadius: braced ? 84 : 100
                )
            )
            .frame(width: braced ? 158 : 190, height: braced ? 34 : 30)
            .animation(.easeOut(duration: 0.22), value: braced)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - The vacated slot.
//
// Opaque, not a tint. A translucent ghost leaves the original row visible and the
// lifted card then reads as a DUPLICATE rather than as a thing you picked up —
// that was the actual defect in the first pass of the mockup.

struct VacatedSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.bdBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Frame reporting

struct PlateRectKey: PreferenceKey {
    // Swift 6 concurrency: a mutable static on a non-isolated type is shared
    // global state. A computed property is the sanctioned form for PreferenceKey.
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty { value = next }
    }
}

extension View {
    /// Publishes this view's rect in the named Home space.
    func reportsPlateRect(in space: CoordinateSpace) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: PlateRectKey.self, value: geo.frame(in: space))
            }
        )
    }
}

// MARK: - PlateDragModifier — makes one goals-card row liftable.
//
// A long-press ARMS the drag (0.35s, spec) so an ordinary tap still starts the
// step and the gesture never fights the ScrollView pan — which is exactly what
// parked the plate's own drag-parallax back on 2026-07-11.
//
// ⛔️ NEVER DRAG-ONLY. Reduce Motion disables the gesture entirely, and every row
// carries an "I already did this" accessibility action regardless, the same law
// the onboarding plating moment ships under.

struct PlateDragModifier: ViewModifier {
    let row: YourGoalsCard.Row
    let drop: PlateDropController?
    let onReport: ((PlateDraggable) -> Void)?
    let reduceMotion: Bool

    @State private var origin: CGPoint = .zero
    private static let space = "homePlate"

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { origin = centre(geo) }
                        .onChange(of: geo.frame(in: .named(Self.space))) { _, _ in
                            origin = centre(geo)
                        }
                }
            )
            .gesture(dragGesture, isEnabled: !reduceMotion && drop != nil)
    }

    private func centre(_ geo: GeometryProxy) -> CGPoint {
        let f = geo.frame(in: .named(Self.space))
        return CGPoint(x: f.midX, y: f.midY)
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .onChanged { value in
                guard let drop else { return }
                switch value {
                case .second(true, let dragValue):
                    guard let dragValue else { return }
                    if !drop.isDragging, let item = YourGoalsCard.draggable(from: row) {
                        drop.begin(item, rowID: row.id, origin: origin)
                    }
                    drop.update(dragValue)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard let drop else { return }
                if let landed = drop.end() {
                    onReport?(landed)
                }
            }
    }
}
