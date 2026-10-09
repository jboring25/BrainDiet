import SwiftUI

// MARK: - Goal builder 2 · Make it yours (mock4, screen 2).
//
// Progressive, one blank at a time. The sentence is the hero; only the
// current blank's chips show, so it never overwhelms. A chip fills the blank
// and moves on; "type it…" opens inline entry; tapping a filled word re-opens
// it. The helper line says what this answer changes.

struct GoalSentenceStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        if let scene = vm.currentScene {
            content(scene)
        }
    }

    private func content(_ scene: GoalScene) -> some View {
        let template = vm.template(for: scene)
        let draft = vm.draft(for: scene)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GoalProgressChip(vm: vm, scene: scene)
                StepHeader(title: "Make it yours.").padding(.top, 10)

                GoalSentenceCard(pieces: template.pieces(for: draft), domain: scene.domain) { i in
                    typing = false
                    vm.reopenBlank(i)
                }
                .padding(.top, 14)

                if let i = draft.active, template.blanks.indices.contains(i) {
                    chips(template.blanks[i], choice: draft.choices[i], domain: scene.domain)
                        .id(i)
                        .transition(.opacity)
                }

                BuilderHelperLine(text: String(localized: "This builds your daily plan."))
                    .padding(.top, 16)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(Theme.Motion.snappy, value: draft)
        .animation(Theme.Motion.snappy, value: typing)
    }

    @ViewBuilder
    private func chips(_ blank: SentenceBlank, choice: BlankChoice?, domain: ActivityDomain) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BuilderLabel(text: blank.prompt, color: .bdLeaf, size: 11)
                .padding(.top, 18)
            FlowLayout(spacing: 7) {
                ForEach(Array(blank.options.enumerated()), id: \.offset) { idx, option in
                    OBPillChip(label: option.chip, isSelected: choice == .option(idx), tint: domain.tint) {
                        typing = false
                        vm.chooseBlank(.option(idx))
                    }
                }
                typeItChip(choice: choice)
            }
            .padding(.top, 9)

            if typing {
                typeField(blank)
                    .padding(.top, 10)
            }
        }
    }

    private func typeItChip(choice: BlankChoice?) -> some View {
        Button {
            if case .typed(let t)? = choice { typed = t } else { typed = "" }
            typing = true
            fieldFocused = true
        } label: {
            Text(String(localized: "type it…"))
                .font(BDFont.body(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.bdTextTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.bdSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.bdCardBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
        .buttonStyle(.plain)
    }

    private func typeField(_ blank: SentenceBlank) -> some View {
        HStack(spacing: 8) {
            TextField(blank.placeholder, text: Binding(get: { typed }, set: { typed = String($0.prefix(40)) }))
                .font(BDFont.body(.medium, size: 15, relativeTo: .body))
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(commitTyped)
            Button(action: commitTyped) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.bdLeafDeep, in: Circle())
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Done")
        }
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Color.bdLeaf.opacity(0.6), lineWidth: 1.5)
        }
    }

    private func commitTyped() {
        let t = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        typing = false
        fieldFocused = false
        vm.chooseBlank(.typed(t))
    }
}

/// "1 of 3 · launched something people use", in the goal's color.
struct GoalProgressChip: View {
    let vm: OnboardingViewModel
    let scene: GoalScene

    var body: some View {
        BuilderEchoChip(
            text: String(localized: "\(vm.builderIndex + 1) of \(vm.pickedScenes.count) · \(scene.shortLabel)"),
            ink: scene.domain.builderInk,
            wash: scene.domain.tint.opacity(0.15))
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.pickedScenes = [.launched, .readMonth, .strongest]
    return ZStack { BDBackground(); GoalSentenceStepView(vm: vm).padding(Theme.Space.screenX) }
}
