import SwiftUI

// MARK: - The guided goal builder's state machine (Jack approved 2026-10-09).
//
// goalScenes → for each pick, in order: goalSentence → goalSharpen (only when
// the AI call came back with options) → goalWhy → … → baseline. The three
// per-goal steps are one enum case each; `builderIndex` says which goal.

/// The sharpen call for one goal, keyed to the sentence it was asked about so
/// an edited sentence never shows stale rewrites.
enum SharpenState: Equatable {
    case loading(String)
    case ready(String, [String])
    case failed(String)

    var sentence: String {
        switch self {
        case .loading(let s), .ready(let s, _), .failed(let s): return s
        }
    }
}

extension OnboardingViewModel {

    // MARK: Current goal

    var currentScene: GoalScene? {
        pickedScenes.indices.contains(builderIndex) ? pickedScenes[builderIndex] : nil
    }

    func template(for scene: GoalScene) -> SentenceTemplate {
        scene.domain.sentenceTemplate(for: scene)
    }

    func draft(for scene: GoalScene) -> GoalDraft {
        drafts[scene] ?? GoalDraft(blankCount: template(for: scene).blanks.count)
    }

    func builtSentence(for scene: GoalScene) -> String? {
        template(for: scene).sentence(for: draft(for: scene))
    }

    /// What the shield sends them back to: "Go get back to ___."
    func shortGoal(for scene: GoalScene) -> String {
        template(for: scene).shortGoal(for: draft(for: scene))
    }

    /// The goal as it now stands: the sharper version they took, else theirs.
    func goalText(for scene: GoalScene) -> String {
        let w = (goalWords[scene.domain] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return w.isEmpty ? (builtSentence(for: scene) ?? "") : w
    }

    /// The primary goal's reason as an identity line ("Proving it to myself.").
    var primaryAspiration: String {
        if let p = pickedScenes.first?.domain ?? primaryDomain, let r = goalReasons[p] {
            return r.aspiration
        }
        return aspiration
    }

    /// "3h a day · feeling behind" — their own earlier answers.
    var sceneEcho: String? {
        let parts = [timeLostHours.map { String(localized: "\($0)h a day") }, feelAfter?.echo].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: goalScenes

    /// Pick / unpick. Two scenes share Learning, and a goal is one per domain,
    /// so picking the second one SWAPS it into the first one's slot.
    func toggleScene(_ scene: GoalScene) {
        if let i = pickedScenes.firstIndex(of: scene) {
            pickedScenes.remove(at: i)
        } else if let i = pickedScenes.firstIndex(where: { $0.domain == scene.domain }) {
            pickedScenes[i] = scene
            goalWords[scene.domain] = nil
        } else if pickedScenes.count < Self.maxScenes {
            pickedScenes.append(scene)
        }
        syncDomainsFromScenes()
    }

    func syncDomainsFromScenes() {
        selectedDomains = pickedScenes.map(\.domain)
        primaryDomain = pickedScenes.first?.domain
    }

    // MARK: goalSentence

    /// Fill the open blank and move to the next empty one.
    func chooseBlank(_ choice: BlankChoice) {
        guard let scene = currentScene else { return }
        var d = draft(for: scene)
        guard let i = d.active, d.choices.indices.contains(i) else { return }
        d.choices[i] = choice
        let order = Array(d.choices.indices.dropFirst(i + 1)) + Array(d.choices.indices.prefix(i + 1))
        d.active = order.first { d.choices[$0] == nil }
        drafts[scene] = d
    }

    /// Tapping a filled word re-opens that blank.
    func reopenBlank(_ i: Int) {
        guard let scene = currentScene else { return }
        var d = draft(for: scene)
        guard d.choices.indices.contains(i) else { return }
        d.active = i
        drafts[scene] = d
    }

    // MARK: goalSharpen

    func sharpenRequest(scene: GoalScene, sentence: String) -> SharpenRequest {
        SharpenRequest(
            domain: scene.domain.rawValue,
            sentence: sentence,
            context: .init(timeLost: timeLostHours,
                           whenItGets: orderedWhenItGets.map(\.label),
                           feelAfter: feelAfter?.label ?? "",
                           baseline: baseline?.label))
    }

    /// Options for the current goal, when the call has answered for THIS sentence.
    var sharpenOptions: [String]? {
        guard let scene = currentScene, case .ready(let s, let o)? = sharpen[scene],
              s == builtSentence(for: scene) else { return nil }
        return o
    }

    var sharpenLoading: Bool {
        guard let scene = currentScene, case .loading(let s)? = sharpen[scene] else { return false }
        return s == builtSentence(for: scene)
    }

    /// nil = "Keep mine".
    func pickSharpen(_ index: Int?) {
        guard let scene = currentScene else { return }
        let options = sharpenOptions ?? []
        if let index, options.indices.contains(index) {
            sharpenPick[scene] = index
            goalWords[scene.domain] = options[index]
        } else {
            sharpenPick[scene] = nil
            goalWords[scene.domain] = builtSentence(for: scene)
        }
    }

    private func startSharpen(_ scene: GoalScene, sentence: String) {
        if let state = sharpen[scene], state.sentence == sentence {
            if case .failed = state {} else { return }   // a failure gets one retry
        }
        sharpen[scene] = .loading(sentence)
        let body = sharpenRequest(scene: scene, sentence: sentence)
        Task { @MainActor [weak self] in
            let options = await SharpenService.sharpen(body)
            guard let self, self.sharpen[scene] == .loading(sentence) else { return }
            self.sharpen[scene] = options.isEmpty ? .failed(sentence) : .ready(sentence, options)
            // Failure or timeout: skip the screen silently, their sentence stands.
            if options.isEmpty, self.step == .goalSharpen, self.currentScene == scene {
                withAnimation(Theme.Motion.snappy) { self.step = .goalWhy }
            }
        }
    }

    // MARK: goalWhy

    func setReason(_ reason: GoalReason) {
        guard let scene = currentScene else { return }
        goalReasons[scene.domain] = reason
        if builderIndex == 0 { aspiration = reason.aspiration }
    }

    // MARK: Navigation

    func advanceGoalBuilder() {
        let go: (OnboardingStep) -> Void = { s in withAnimation(Theme.Motion.snappy) { self.step = s } }
        switch step {
        case .goalScenes:
            syncDomainsFromScenes()
            builderIndex = 0
            go(.goalSentence)
        case .goalSentence:
            guard let scene = currentScene, let sentence = builtSentence(for: scene) else { return }
            // A changed sentence drops a sharper version picked for the old one.
            if sharpen[scene]?.sentence != sentence { sharpenPick[scene] = nil }
            if sharpenPick[scene] == nil { goalWords[scene.domain] = sentence }
            startSharpen(scene, sentence: sentence)
            if case .failed? = sharpen[scene] { go(.goalWhy) } else { go(.goalSharpen) }
        case .goalSharpen:
            go(.goalWhy)
        case .goalWhy:
            aspiration = primaryAspiration
            if builderIndex < pickedScenes.count - 1 {
                builderIndex += 1
                go(.goalSentence)
            } else if let next = nextRoutedStep(after: .goalWhy) {
                go(next)
            }
        default:
            break
        }
    }

    /// True when it handled the back tap.
    func backGoalBuilder() -> Bool {
        let go: (OnboardingStep) -> Void = { s in withAnimation(Theme.Motion.snappy) { self.step = s } }
        switch step {
        case .goalSentence:
            if builderIndex > 0 { builderIndex -= 1; go(.goalWhy) } else { go(.goalScenes) }
        case .goalSharpen:
            go(.goalSentence)
        case .goalWhy:
            go(sharpenOptions != nil || sharpenLoading ? .goalSharpen : .goalSentence)
        case .baseline:
            builderIndex = max(0, pickedScenes.count - 1)
            go(.goalWhy)
        default:
            return false
        }
        return true
    }

    // MARK: ⭐ The honest progress bar — builder screens counted per goal.

    /// 1-based position + total. Before scenes are picked the builder assumes
    /// the most it can be (3 goals); a skipped sharpen screen leaves the count.
    var progress: (current: Int, total: Int) {
        let goals = pickedScenes.isEmpty ? Self.maxScenes : pickedScenes.count
        var slots: [(OnboardingStep, Int)] = []
        for s in OnboardingStep.allCases where s.countsTowardProgress {
            if s == .goalSentence {
                for g in 0..<goals {
                    slots.append((.goalSentence, g))
                    let skipped: Bool = {
                        guard pickedScenes.indices.contains(g),
                              case .failed? = sharpen[pickedScenes[g]] else { return false }
                        return true
                    }()
                    if !skipped { slots.append((.goalSharpen, g)) }
                    slots.append((.goalWhy, g))
                }
            } else if !s.isPerGoal {
                slots.append((s, 0))
            }
        }
        let i = slots.firstIndex { $0.0 == step && (!step.isPerGoal || $0.1 == builderIndex) }
        return ((i ?? -1) + 1, slots.count)
    }

    #if DEBUG
    /// mock4's sentences: launch BrainDiet / 100 people / May.
    static func mockDraft(_ scene: GoalScene) -> GoalDraft {
        switch scene {
        case .launched:  return GoalDraft(choices: [.typed("BrainDiet"), .option(1), .typed("May")], active: nil)
        case .readMonth: return GoalDraft(choices: [.option(0), .option(2)], active: nil)
        default:         return GoalDraft(choices: [.option(0), .typed("May")], active: nil)
        }
    }
    #endif
}
