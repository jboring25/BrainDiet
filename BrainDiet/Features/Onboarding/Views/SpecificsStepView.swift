import SwiftUI

// MARK: - Q6 — the specifics. The screen that makes the plan theirs.
//
// ⭐ WHY THIS EXISTS (Jack, 2026-09-15). The personalization audit put two real
// users side by side and found the planner reads four things — domain, blocker,
// time band, step index — and never reads the aspiration. Two people building two
// different businesses received a byte-identical plan. The app asked who they
// wanted to become and then threw the answer away.
//
// This screen collects the two inputs that fix that, and nothing else:
//
//   • THE THING. One optional line — "a landing page for my app", "finishing
//     Dune". Without it the model has nothing to be specific ABOUT, and a step
//     that says "do a focused build block" is a category, not a decision.
//
//   • THE ANCHORS. Which fixed points actually happen in their day. Cues attach
//     to these instead of to a per-domain guess. This is the higher-value half
//     and it costs only taps: a cue whose anchor does not exist does not weaken
//     the effect, it removes it.
//
// ⚠️ The text field is OPTIONAL and says so. A required keyboard in the middle of
// onboarding is how a flow loses people, and the anchors alone already make every
// cue in the plan real.

struct SpecificsStepView: View {

    @Bindable var vm: OnboardingViewModel
    @FocusState private var typing: ActivityDomain?

    private let columns = [GridItem(.adaptive(minimum: 148), spacing: 9)]

    /// ⭐ ONE CONCRETE QUESTION PER GOAL (2026-09-21), replacing the single
    /// "What are you actually working toward?" line. That line got a mood; the
    /// planner needs a NOUN, and the noun differs per goal — a book, an app, an
    /// instrument. "What are you reading?" gets "Dune". Capped at three because
    /// the plan holds at most three goals.
    private var domains: [ActivityDomain] { Array(vm.rankedDomains.prefix(3)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                StepHeader(
                    title: "Name the actual thing.",
                    subtitle: "Your plan uses these words. Tap one, or type your own."
                )

                ForEach(domains) { domain in
                    objectQuestion(domain)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Which of these happen most days?")
                        .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color.bdTextPrimary)
                    Text("We hang each step on something that already happens, so you don't have to remember it.")
                        .font(BDFont.body(.regular, size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.bdTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
                        ForEach(DayAnchor.allCases) { anchor in
                            chip(anchor)
                        }
                    }
                    .padding(.top, 3)
                }
                .padding(.top, 4)

                Spacer(minLength: 20)
            }
            .padding(.top, Theme.Space.sm)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(Theme.Motion.smooth, value: vm.dayAnchors)
    }

    // MARK: The thing itself, per goal

    private func objectQuestion(_ domain: ActivityDomain) -> some View {
        let cat = PlateEngine.category(forDomain: domain)
        let text = Binding(
            get: { vm.domainObjects[domain] ?? "" },
            set: { new in
                let capped = String(new.prefix(DreamDetails.maxLength))
                vm.domainObjects[domain] = capped.isEmpty ? nil : capped
            }
        )
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(cat.wash)
                    .frame(width: 28, height: 28)
                    .overlay(BDPhIcon(icon: domain.phIcon, size: 15, color: cat.ink))
                Text(domain.objectPrompt)
                    .font(BDFont.body(.bold, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.bdTextPrimary)
            }

            // Suggestions first, so a single tap is always enough.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(domain.objectSuggestions, id: \.self) { s in
                        objectChip(s, domain: domain, current: text.wrappedValue, tint: cat)
                    }
                }
                .padding(.horizontal, Theme.Space.screenX)
            }
            .padding(.horizontal, -Theme.Space.screenX)

            TextField("or type it: \(domain.objectPlaceholder)", text: text)
                .font(BDFont.body(.regular, size: 15, relativeTo: .body))
                .focused($typing, equals: domain)
                .submitLabel(.done)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(typing == domain ? Color.bdLeafDeep.opacity(0.45) : Color.bdCardBorder,
                                      lineWidth: typing == domain ? 1.5 : 1)
                }
        }
    }

    private func objectChip(_ s: String, domain: ActivityDomain, current: String,
                            tint: PlateCategory) -> some View {
        let on = current.caseInsensitiveCompare(s) == .orderedSame
        return Button {
            vm.domainObjects[domain] = on ? nil : s
            typing = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
        } label: {
            Text(s.prefix(1).uppercased() + s.dropFirst())
                .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                .foregroundStyle(on ? tint.textInk : Color.bdTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(on ? tint.wash : Color.bdSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? tint.ink.opacity(0.45) : Color.bdCardBorder,
                                                lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func chip(_ anchor: DayAnchor) -> some View {
        let on = vm.dayAnchors.contains(anchor)
        return Button {
            if on { vm.dayAnchors.remove(anchor) } else { vm.dayAnchors.insert(anchor) }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: anchor.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(on ? Color.bdLeafDeep : Color.bdTextSecondary)
                Text(anchor.label)
                    .font(BDFont.body(.bold, size: 13, relativeTo: .footnote))
                    .foregroundStyle(on ? Color.bdLeafDeep : Color.bdTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? Color.bdLeafTint : Color.bdSurface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? Color.bdLeafDeep.opacity(0.35) : Color.bdCardBorder,
                                  lineWidth: on ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
