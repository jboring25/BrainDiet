import SwiftUI

// MARK: - Moonshot 1 · What's your moonshot? (Jack approved 2026-10-10, moon.png).
//
// "People need to dream big." Their pain echoed back in the salmon chip, then
// one big serif field with the keyboard already up. The examples beneath are
// faded and NOT tappable on purpose: they show the scale of answer the
// question wants, and a tappable example would get picked instead of written.

struct MoonshotWriteStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let echo = vm.sceneEcho {
                    BuilderEchoChip(text: echo).padding(.bottom, 10)
                }
                StepHeader(title: "What's your moonshot?",
                           subtitle: "The biggest thing you'd go after if you knew you wouldn't fail.",
                           compact: true)

                field.padding(.top, 16)

                BuilderLabel(text: String(localized: "Others have written"))
                    .padding(.top, 18)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(MoonshotExamples.lines, id: \.self) { line in
                        Text(line)
                            .font(BDFont.body(.semiBold, size: 13, relativeTo: .footnote))
                            .foregroundStyle(Color.bdTabMuted)
                    }
                }
                .padding(.top, 6)
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Space.lg)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task {
            // After the step's slide-in, so the keyboard rises on a settled screen.
            try? await Task.sleep(for: .milliseconds(350))
            typing = true
        }
    }

    private var field: some View {
        TextField("", text: Binding(
            get: { vm.moonshot },
            set: { vm.moonshot = String($0.prefix(MoonshotExamples.maxLength)) }
        ), axis: .vertical)
            .font(BDFont.serif(size: 21, relativeTo: .title3))
            .foregroundStyle(Color.bdTextPrimary)
            .tint(Color.bdLeafDeep)
            .lineSpacing(4)
            .lineLimit(3...8)
            .focused($typing)
            .accessibilityLabel(Text("Your moonshot"))
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Color.bdSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(typing ? Color.bdLeafDeep : Color.bdCardBorder, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .onTapGesture { typing = true }
            .animation(Theme.Motion.snappy, value: typing)
    }
}

#Preview {
    let vm = OnboardingViewModel()
    vm.timeLostHours = 3
    vm.feelAfter = .behind
    vm.moonshot = "Build BrainDiet into the app that gets a million people off their phones"
    return ZStack { BDBackground(); MoonshotWriteStepView(vm: vm).padding(Theme.Space.screenX) }
}
