import SwiftUI

// MARK: - Step 7 — THE MIRROR (the loss-aversion aha — appetite pass 2026-07-18).
//
// Full-screen, built from THEIR answers: the time-lost band's midpoint becomes a
// staged count-up — a day, a year, a decade — quiet, damning, then hopeful. The
// numbers do the work; no shame words, ever. GRAY carries the loss: slop-gray
// Young Serif numerals on the gray canvas ("All of it gray."), and the canvas
// itself returns to cream at the bottom where the pivot lives — "Yours can be
// in color." in leaf. Spec: design/plate-concepts/appetite-mockups.html (screen 4).
//
// Reduce Motion: fully static — all lines + pivot + CTA present, no count-up.
//
// ⭐ 2026-07-22 CONTRAST PASS: the whole loss block was gray-on-cream and failed
// WCAG. Loss stays SEMANTICALLY drained (that's the gray→color pivot) but is now
// legible against the mirror's gray→cream canvas (worst case = the gray stop
// #F4F2EF): "That's" #A9A29A 2.26:1 → #6F6860 4.91:1 · the decade phrase
// #9A948C 2.69:1 → #6F6860 4.91:1 · the 76pt numerals #9A948C 2.69:1 → #7F776E
// 3.94:1 (large text, 3:1 floor) · the block's 0.7 recede-on-pivot moved OFF
// the prose (it broke AA) onto the numerals alone at 0.85 → 3.08:1.
// The colored gain rows (leaf 4.88:1, berry 5.86:1, honey 4.78:1) stay clearly
// more vivid, so the gray→color contrast still lands.

struct MirrorStepView: View {
    @Bindable var vm: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0          // 0 nothing · 1 day · 2 year · 3 decade · 4 pivot
    @State private var dayCount = 0
    @State private var yearCount = 0

    /// Built straight from the scrubbed hours (honest — no band rounding).
    private var mirror: MirrorNumbers { MirrorNumbers(minutesPerDay: vm.baselineJunkMinutes) }

    var body: some View {
        // TOP-ANCHORED (fix-v2): eyebrow pinned at a single top inset (~14% of
        // height), the three staged beats flow DOWN from it, the pivot + CTA
        // anchor the bottom. .topLeading fill stops the container's maxHeight from
        // centering the block (the iteration-1 "floating" dead top third).
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR MIRROR")
                .font(.bdEyebrow)
                .kerning(1.5)
                .foregroundStyle(Color.bdTextSecondary)
                .opacity(stage >= 1 ? 1 : 0)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 0) {
                // 1 — a day.
                stanza(
                    number: "\(reduceMotion ? mirror.dayValue : dayCount)",
                    unit: mirror.dayUnit + " a day.",
                    shown: stage >= 1
                )

                // "That's" — the quiet hinge line (mockup `.m-that`).
                // The hinge. Was bdGrayFaint (#A9A29A, 2.26:1) — now the
                // legible loss ink (#6F6860, 4.91:1 on the gray canvas).
                Text("That's")
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdSlopGrayText)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                    .opacity(stage >= 2 ? 1 : 0)

                // 2 — a year.
                stanza(
                    number: "\(reduceMotion ? mirror.daysPerYear : yearCount)",
                    unit: "days a year.",
                    shown: stage >= 2
                )

                // 3 — a decade. Prose; the loss phrase carries the slop gray.
                decadeLine
                    .padding(.top, 16)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 || reduceMotion ? 0 : 10)

                // ⭐ V3 (Jack approved 2026-10-09): the cost lands against THEIR
                // goals, in their own words, not a generic "imagine your
                // dreams". Still stage 3, still on the gray.
                spentOnBlock
                    .padding(.top, 16)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 || reduceMotion ? 0 : 10)
            }
            // (The recede-on-pivot opacity used to sit HERE, on the whole loss
            // block, at 0.7 — it dragged every text run under its contrast
            // floor. It now lives on the big NUMERALS alone, where large-text
            // 3:1 still holds; the prose stays at full strength.)

            Spacer(minLength: Theme.Space.lg)

            // The pivot — the way back, on the cream returning beneath the gray.
            VStack(alignment: .leading, spacing: 18) {
                pivotLine
                    .fixedSize(horizontal: false, vertical: true)

                // (The per-domain projection rows — "2 more books a month" —
                // were cut 2026-10-09: the goal lines above already say what
                // the time is for, in the user's words, and a stock projection
                // under them repeated it less honestly.)

                BDPrimaryButton(title: "Show me the way back") {
                    vm.advance()
                }
            }
            .opacity(stage >= 4 ? 1 : 0)
            .offset(y: stage >= 4 || reduceMotion ? 0 : 12)
            .padding(.bottom, Theme.Space.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await orchestrate() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(mirror.dayValue) \(mirror.dayUnit) a day. That's \(mirror.daysPerYear) days a year. Every decade, \(mirror.decadePhrase), lost to the feed. That's time you could have spent on: \(spentOnLines.joined(separator: ". ")). You won't have to imagine that. Become closer, day by day."
        )
    }

    // MARK: What the time was for — their own goal words (v3, 2026-10-09).

    /// The user's words for their top goals (primary first), falling back to
    /// the goal title for any goal with no words (jumped/edge states only:
    /// the goalWords step requires them).
    private var spentOnLines: [String] {
        let domains = vm.goalWordDomains.isEmpty
            ? [vm.primaryDomain ?? .reading] : vm.goalWordDomains
        return domains.map { d in
            let w = (vm.goalWords[d] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return w.isEmpty ? d.goalTitle : GoalSentenceText.display(w)
        }
    }

    private var spentOnBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("That's time you could have spent on:")
                .font(BDFont.body(.semiBold, size: 17, relativeTo: .body))
                .foregroundStyle(Color.bdGrayInk)
            ForEach(spentOnLines, id: \.self) { line in
                Text(line)
                    .font(BDFont.serif(size: 17.5, relativeTo: .title3))
                    .foregroundStyle(Color.bdLeaf)
                    .lineSpacing(0)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 330, alignment: .leading)
        .accessibilityHidden(true)   // carried by the container's label
    }

    // MARK: Stanzas — slop-gray Young Serif numerals (mockup `.m-num`).

    private func stanza(number: String, unit: String, shown: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
            Text(number)
                .font(.bdInstrument(76))
                .monospacedDigit()
                // 76pt = large text (3:1 floor). Was bdSlopGray (2.69:1);
                // bdSlopGrayDisplay is 3.94:1 and still visibly drained next
                // to the colored gain rows (leaf 4.88, berry 5.86).
                .foregroundStyle(Color.bdSlopGrayDisplay)
                // The numbers recede a breath when hope arrives (3.08:1 — still
                // over the large-text floor).
                .opacity(stage >= 4 ? 0.85 : 1)
                .contentTransition(.numericText())
            Text(unit)
                .font(BDFont.body(.bold, size: 21, relativeTo: .title3))
                .foregroundStyle(Color.bdGrayInk)
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : 10)
    }

    private var decadeLine: some View {
        (Text("Every decade, ")
            .foregroundStyle(Color.bdGrayInk)
         + Text(mirror.decadePhrase)
            .fontWeight(.heavy)
            // Body-size emphasis → 4.5:1. Was bdSlopGray (2.69:1).
            .foregroundStyle(Color.bdSlopGrayText)
         + Text(", lost to the feed.")
            .foregroundStyle(Color.bdGrayInk))
            .font(BDFont.body(.semiBold, size: 19, relativeTo: .title3))
            .lineSpacing(6)
            .frame(maxWidth: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Serif pivot (mockup `.m-pivot`): hope arrives, and it arrives in LEAF.
    private var pivotLine: some View {
        (Text("You won't have to imagine that. ")
            .foregroundColor(Color.bdTextPrimary)
         + Text("Become closer, day by day.")
            .foregroundColor(Color.bdLeaf))
            .font(BDFont.serif(size: 25, relativeTo: .title2))
            .lineSpacing(4)
    }

    // MARK: Orchestration — quiet, damning, then hopeful.

    private func orchestrate() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_MIRROR_STAGE"] == "pivot" {
            dayCount = mirror.dayValue; yearCount = mirror.daysPerYear
            stage = 4
            return
        }
        #endif
        guard !reduceMotion else {
            dayCount = mirror.dayValue
            yearCount = mirror.daysPerYear
            stage = 4
            return
        }

        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { stage = 1 }
        await countUp(to: mirror.dayValue, over: 0.9) { dayCount = $0 }
        softTick(intensity: 0.4)

        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { stage = 2 }
        await countUp(to: mirror.daysPerYear, over: 0.9) { yearCount = $0 }
        // The hinge — the "days a year" number is the gut-punch. It lands harder.
        softTick(intensity: 0.9)

        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { stage = 3 }
        softTick(intensity: 0.4)

        // The beat. Let it sit. Then hope — the pivot rises on the cream.
        try? await Task.sleep(for: .milliseconds(1500))
        withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) { stage = 4 }
    }

    private func countUp(to total: Int, over duration: Double, _ set: @escaping (Int) -> Void) async {
        guard total > 0 else { set(0); return }
        let steps = min(total, 24)
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) / steps))
            withAnimation(.easeOut(duration: 0.08)) {
                set(Int((Double(total) / Double(steps) * Double(i)).rounded()))
            }
        }
    }

    private func softTick(intensity: CGFloat = 0.5) {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.impactOccurred(intensity: intensity)
    }
}

// MARK: - MirrorNumbers — their band's midpoint, projected honestly.

struct MirrorNumbers {
    let minutesPerDay: Int

    /// The primary path since the hours scrubber (2026-07-18): the user's own
    /// minutes, no band midpoint.
    init(minutesPerDay: Int) {
        self.minutesPerDay = max(0, minutesPerDay)
    }

    init(band: ShortFormBand) {
        switch band {
        case .under1:    minutesPerDay = 45
        case .oneToTwo:  minutesPerDay = 90
        case .twoToFour: minutesPerDay = 180
        case .fourPlus:  minutesPerDay = 300
        }
    }

    /// The big day numeral: whole hours when they divide cleanly, else minutes.
    var dayValue: Int { minutesPerDay % 60 == 0 ? minutesPerDay / 60 : minutesPerDay }
    var dayUnit: String {
        minutesPerDay % 60 == 0
            ? (minutesPerDay / 60 == 1 ? String(localized: "hour") : String(localized: "hours"))
            : String(localized: "minutes")
    }

    /// Full days lost per year (minutes × 365 ÷ 1440).
    var daysPerYear: Int { minutesPerDay * 365 / 1440 }

    /// The decade phrase — honest per band (45m ≈ 114d … 5h ≈ 760d per decade).
    var decadePhrase: String {
        let days = daysPerYear * 10
        switch days {
        case ..<240:  return String(localized: "months of your life")
        case ..<365:  return String(localized: "the better part of a year of your life")
        case ..<730:  return String(localized: "over a year of your life")
        default:      return String(localized: "over two years of your life")
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.timeLostHours = 3
    return ZStack {
        BDBackground()
        MirrorStepView(vm: vm).padding(.horizontal, Theme.Space.screenX)
    }
}
