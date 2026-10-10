import SwiftUI

// MARK: - ⭐ ONE MOONSHOT — the state machine (Jack approved 2026-10-10).
//
// moonshotWrite → moonshotRoad → moonshotWhy → baseline. Leaving moonshotWrite
// starts the road call (keyed to the text it was asked about, so an edited
// moonshot asks again); moonshotRoad shows skeleton rows until it answers, or
// one empty editable row when it fails. Leaving moonshotWhy writes the single
// goal into the per-domain maps every downstream screen already reads.

extension OnboardingViewModel {

    // MARK: Derived

    var trimmedMoonshot: String {
        moonshot.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The one goal's domain: the AI's read of the moonshot, else Building.
    var moonshotDomain: ActivityDomain { roadDomain ?? .building }

    /// "3h a day · feeling behind" — their own earlier answers.
    var sceneEcho: String? {
        let parts = [timeLostHours.map { String(localized: "\($0)h a day") }, feelAfter?.echo].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var roadLoading: Bool {
        if case .loading(let s) = road, s == trimmedMoonshot { return true }
        return false
    }

    /// The timeline's last row: the server's finish phrase, else its short
    /// phrase, else the moonshot itself.
    var moonshotFinish: String {
        for c in [roadFinish, moonshotShort] where !c.isEmpty {
            return c.prefix(1).uppercased() + c.dropFirst()
        }
        return GoalSentenceText.display(trimmedMoonshot)
    }

    // MARK: The road

    func roadRequest() -> RoadRequest {
        RoadRequest(moonshot: trimmedMoonshot,
                    context: .init(timeLost: timeLostHours,
                                   whenItGets: orderedWhenItGets.map(\.label),
                                   feelAfter: feelAfter?.label ?? "",
                                   triedBefore: orderedTriedBefore.map(\.label)))
    }

    /// Ask for the road unless THIS moonshot already has one (or is loading).
    func startRoad() {
        let text = trimmedMoonshot
        switch road {
        case .loading(let s) where s == text, .ready(let s) where s == text: return
        default: break
        }
        road = .loading(text)
        milestones = []
        let body = roadRequest()
        Task { @MainActor [weak self] in
            let result = await RoadService.road(body)
            guard let self, self.road == .loading(text) else { return }
            self.applyRoad(result, for: text)
        }
    }

    func applyRoad(_ result: Road?, for text: String) {
        withAnimation(Theme.Motion.smooth) {
            if let result {
                roadDomain = result.domain
                moonshotShort = result.short
                roadFinish = result.finish
                milestones = result.milestones
                road = .ready(text)
            } else {
                // Failure: one empty row they can type into, or skip.
                roadDomain = nil
                moonshotShort = ""
                roadFinish = ""
                milestones = [Milestone(title: "", by: "")]
                road = .failed(text)
            }
        }
    }

    // MARK: Editing a milestone (tap a row → inline edit)

    func updateMilestone(_ id: UUID, title: String? = nil, by: String? = nil) {
        guard let i = milestones.firstIndex(where: { $0.id == id }) else { return }
        if let title { milestones[i].title = String(title.prefix(80)) }
        if let by { milestones[i].by = String(by.prefix(24)) }
    }

    // MARK: Why

    func setReason(_ reason: GoalReason) {
        moonshotReason = reason
        aspiration = reason.aspiration
    }

    /// ⭐ THE ONE GOAL. Written into the per-domain maps the planner, mirror,
    /// paywall, hero chips and shield already read, so none of them change.
    func syncMoonshotGoal() {
        let d = moonshotDomain
        selectedDomains = [d]
        primaryDomain = d
        goalWords = trimmedMoonshot.isEmpty ? [:] : [d: trimmedMoonshot]
        goalReasons = moonshotReason.map { [d: $0] } ?? [:]
        if let r = moonshotReason { aspiration = r.aspiration }
    }

    // MARK: Navigation

    func advanceMoonshot() {
        let go: (OnboardingStep) -> Void = { s in withAnimation(Theme.Motion.snappy) { self.step = s } }
        switch step {
        case .moonshotWrite:
            startRoad()
            go(.moonshotRoad)
        case .moonshotRoad:
            // A blank fallback row the user never typed into is not a milestone.
            milestones = milestones.filled
            syncMoonshotGoal()
            go(.moonshotWhy)
        case .moonshotWhy:
            syncMoonshotGoal()
            if let next = nextRoutedStep(after: .moonshotWhy) { go(next) }
        default:
            break
        }
    }

    /// Back from the road keeps a blank fallback row out of the way too.
    func backFromMoonshotWhy() {
        if milestones.isEmpty, case .failed = road { milestones = [Milestone(title: "", by: "")] }
    }

    // MARK: ⭐ The honest progress bar

    var progress: (current: Int, total: Int) {
        let slots = OnboardingStep.allCases.filter(\.countsTowardProgress)
        let i = slots.firstIndex(of: step)
        return ((i ?? -1) + 1, slots.count)
    }

    #if DEBUG
    /// Jack's mock answers (design/goal-builder/moon.png).
    static let mockMoonshot = "Build BrainDiet into the app that gets a million people off their phones"
    #endif
}
