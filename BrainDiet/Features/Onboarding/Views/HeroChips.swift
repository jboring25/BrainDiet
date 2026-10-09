import SwiftUI

// MARK: - v2 · The words around the brain on the menu hero.
//
// Each pill is one thing the user told us (their goal words first, then the
// minutes and where they are). They appear, drift toward the brain, and each
// one is handed to the Culture model as a serving from the exact spot it
// stood, so the ball the existing animation draws is visibly THAT pill going in.
// No particle code here: `CultureCloudModel.feed(from:)` does the eating.

struct HeroChip: Identifiable, Equatable {
    let id: Int
    let text: String
    /// Where it sits, as a fraction of the stage.
    let anchor: CGPoint
    /// Goal words gate the end of phase 1; context chips do not.
    let isWord: Bool
    /// The mockup's last chip sits smaller and fainter, already "on its way".
    let isQuiet: Bool
}

enum HeroChipState { case hidden, shown, eaten }

@MainActor
@Observable
final class HeroChips {
    private(set) var items: [HeroChip] = []
    private var states: [Int: HeroChipState] = [:]

    /// Stage fractions for the pills, below and beside the brain (mockup HERO 1).
    private static let slots: [CGPoint] = [
        CGPoint(x: 0.25, y: 0.86), CGPoint(x: 0.72, y: 0.875), CGPoint(x: 0.26, y: 0.975),
        CGPoint(x: 0.77, y: 0.985), CGPoint(x: 0.88, y: 0.77),
    ]

    func state(of id: Int) -> HeroChipState { states[id] ?? .hidden }

    var wordsFed: Bool {
        !items.isEmpty && items.filter(\.isWord).allSatisfy { states[$0.id] == .eaten }
    }

    func load(from vm: OnboardingViewModel) {
        guard items.isEmpty else { return }
        var texts: [(String, Bool)] = vm.goalWordDomains.compactMap { d in
            vm.goalWords[d].map { (Self.short(GoalSentenceText.display($0)), true) }
        }
        texts.append(("\(vm.minutesPerDay >= 120 ? "2h+" : "\(vm.minutesPerDay) min") a day", false))
        if let b = vm.baseline { texts.append((b.shortLabel, false)) }
        items = texts.prefix(Self.slots.count).enumerated().map { i, t in
            HeroChip(id: i, text: t.0, anchor: Self.slots[i], isWord: t.1,
                     isQuiet: i == texts.count - 1 && !t.1)
        }
    }

    /// "Launch BrainDiet on the App Store…" → "Launch BrainDiet". Cut at the
    /// first comma or joining word, then at a word boundary under 26 characters.
    static func short(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = s.rangeOfCharacter(from: CharacterSet(charactersIn: ",.;:!?")) { s = String(s[..<r.lowerBound]) }
        let words = s.split(separator: " ")
        let joins: Set<String> = ["on", "and", "then", "by", "to", "at", "in", "for", "with", "before", "so"]
        var out: [Substring] = []
        for (i, w) in words.enumerated() {
            if i >= 2, joins.contains(w.lowercased()) { break }
            if (out + [w]).joined(separator: " ").count > 26 { break }
            out.append(w)
        }
        return out.isEmpty ? String(s.prefix(26)) : out.joined(separator: " ")
    }

    /// Appear, drift, then feed each pill to the brain one serving at a time
    /// (the model only carries one serving in flight).
    func choreograph(model: CultureCloudModel, in size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }
        while items.isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .milliseconds(250))
        for chip in items where states[chip.id] == nil {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { states[chip.id] = .shown }
            try? await Task.sleep(for: .milliseconds(160))
        }
        let toBrain = CultureCloudGeometry.transform(in: size).inverted()
        for chip in items where states[chip.id] != .eaten {
            try? await Task.sleep(for: .milliseconds(chip.id == 0 ? 450 : 200))
            while model.serving != nil {
                try? await Task.sleep(for: .milliseconds(60))
                if Task.isCancelled { return }
            }
            let p = HeroChipView.position(of: chip, in: size, drifted: true)
            withAnimation(.easeIn(duration: 0.28)) { states[chip.id] = .eaten }
            model.feed(from: p.applying(toBrain))
        }
    }
}

struct HeroChipView: View {
    let chip: HeroChip
    let state: HeroChipState
    let size: CGSize

    /// Resting point; once shown it has drifted a short way inward.
    static func position(of chip: HeroChip, in size: CGSize, drifted: Bool) -> CGPoint {
        let p = CGPoint(x: chip.anchor.x * size.width, y: chip.anchor.y * size.height)
        guard drifted else { return p }
        let c = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        return CGPoint(x: p.x + (c.x - p.x) * 0.08, y: p.y + (c.y - p.y) * 0.08)
    }

    var body: some View {
        Text(chip.text)
            .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
            .foregroundStyle(Color.bdTextPrimary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.bdSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.bdCardBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 7, y: 6)
            .scaleEffect(state == .shown ? (chip.isQuiet ? 0.82 : 1) : (state == .eaten ? 0.25 : 0.7))
            .opacity(state == .shown ? (chip.isQuiet ? 0.6 : 1) : 0)
            // The drift is slow and owns only the position; the pop-in and the
            // swallow keep their own springs.
            .animation(.easeInOut(duration: 2.6)) {
                $0.position(Self.position(of: chip, in: size, drifted: state != .hidden))
            }
            .accessibilityHidden(true)
    }
}
