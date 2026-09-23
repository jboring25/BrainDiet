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

    /// The deterministic plan — its reclaimed-hours figure feeds the gain rows.
    private var plan: BrainPlan { vm.makePlan() }

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
                    .padding(.top, 22)
                    .padding(.bottom, 4)
                    .opacity(stage >= 2 ? 1 : 0)

                // 2 — a year.
                stanza(
                    number: "\(reduceMotion ? mirror.daysPerYear : yearCount)",
                    unit: "days a year.",
                    shown: stage >= 2
                )

                // 3 — a decade. Prose; the loss phrase carries the slop gray.
                decadeLine
                    .padding(.top, 26)
                    .opacity(stage >= 3 ? 1 : 0)
                    .offset(y: stage >= 3 || reduceMotion ? 0 : 10)

                // The closing beat of the loss — a forward hook, still on the
                // gray, still part of stage 3. It recedes with the numbers when
                // the pivot arrives.
                Text("Imagine how much closer your dreams would be.")
                    .font(BDFont.serif(size: 20, relativeTo: .title3))
                    .foregroundStyle(Color.bdGrayInk)
                    .lineSpacing(4)
                    .frame(maxWidth: 320, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
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

                // THE GAIN (Opal mapping row 8): after the pivot, what the plan
                // gives BACK — in the category colors, on the returned cream.
                // Numbers derive from their own answer (baseline − cap); the
                // domain line comes from their chosen primary. Loss then gain,
                // gray then color.
                gainBlock

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
            "\(mirror.dayValue) \(mirror.dayUnit) a day. That's \(mirror.daysPerYear) days a year. Every decade, \(mirror.decadePhrase), fed to the feed. Imagine how much closer your dreams would be. You won't have to imagine that. Become closer, day by day. \(outcomeDomains.map { outcomePhrase(for: $0) }.joined(separator: ". "))."
        )
    }

    // MARK: The gain block — one future-self outcome per chosen domain, each in
    // its own category color (the color returns, domain by domain).

    /// The domains the gain rows render — the user's selection (cap 4), or the
    /// primary alone if somehow empty.
    private var outcomeDomains: [ActivityDomain] {
        vm.selectedDomains.isEmpty
            ? [vm.primaryDomain ?? .reading]
            : Array(vm.selectedDomains.prefix(4))
    }

    private var gainBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm + 2) {
            ForEach(outcomeDomains, id: \.self) { domain in
                gainRow(text: outcomePhrase(for: domain), color: domain.categoryTextInk)
            }
        }
        .accessibilityHidden(true)   // carried by the container's label
    }

    private func gainRow(text: String, color: Color) -> some View {
        HStack(spacing: Theme.Space.sm + 2) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(BDFont.body(.bold, size: 16, relativeTo: .body))
                .foregroundStyle(color)
        }
    }

    // MARK: Derived gain numbers (2026-07-22) — the outcome per domain now comes
    // from the user's OWN reclaimed time, not fixed copy. Their daily reclaimed
    // hours × 30 = monthly reclaimed hours, split evenly across the chosen
    // outcome domains; each domain converts its share into an honest count via a
    // per-unit hours constant. Floored at 1 so nothing ever reads "0".

    /// Reclaimed hours/day the plan returns × 30 (a month's worth of returned time).
    private var monthlyReclaimedHours: Double { Double(plan.reclaimedHours) * 30 }

    /// Each domain's even share of the monthly reclaimed hours.
    private var perDomainMonthlyHours: Double {
        monthlyReclaimedHours / Double(max(1, outcomeDomains.count))
    }

    /// The future-self outcome for a domain — concrete, achievable, and DERIVED
    /// from their reclaimed time (honest projection). Pointed at who they're
    /// becoming, never what they're avoiding.
    private func outcomePhrase(for domain: ActivityDomain) -> String {
        let hours = perDomainMonthlyHours
        func count(per unit: Double) -> Int { max(1, Int((hours / unit).rounded())) }

        switch domain {
        case .reading:
            let n = count(per: 5)
            return n == 1 ? String(localized: "1 more book a month")
                          : String(localized: "\(n) more books a month")
        case .fitness:
            let n = count(per: 1)
            return n == 1 ? String(localized: "1 workout a month")
                          : String(localized: "\(n) workouts a month")
        case .outdoors:
            let n = count(per: 1.5)
            return n == 1 ? String(localized: "1 bike ride a month")
                          : String(localized: "\(n) bike rides a month")
        case .music:
            let n = count(per: 8)
            return n == 1 ? String(localized: "1 new song learned")
                          : String(localized: "\(n) new songs learned")
        case .writing:
            let n = count(per: 6)
            return n == 1 ? String(localized: "1 more chapter a month")
                          : String(localized: "\(n) more chapters a month")
        case .learning:
            let n = count(per: 12)
            return n == 1 ? String(localized: "1 new skill a month")
                          : String(localized: "\(n) new skills a month")
        case .creating:
            let n = count(per: 3)
            return n == 1 ? String(localized: "1 thing you actually made, a month")
                          : String(localized: "\(n) things you actually made, a month")
        case .building:
            // Weekly cadence: this domain's monthly share → weekly hours ÷ ~2.
            let weekly = hours / 4.345
            let n = max(1, Int((weekly / 2).rounded(.down)))
            return n == 1 ? String(localized: "1 big step toward your business, a week")
                          : String(localized: "\(n) big steps toward your business, a week")
        }
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
         + Text(", fed to the feed.")
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
            .font(BDFont.serif(size: 27, relativeTo: .title2))
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
