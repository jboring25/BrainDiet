import SwiftUI
import SwiftData

// MARK: - ⭐ THE FINISH LINE MOVES (Jack approved 2026-10-12, design/milestone/).
//
// "As soon as they reach a goal there should be a next step to that. The
// finish line moves and I want to make that apparent." Tapping "I hit it"
// marks the current milestone done, asks the plan server (mode "extend") for
// ONE new stop at the end of the road so three stay ahead, and rebuilds the
// daily steps around the new current milestone. When the road ahead is empty
// the next stop IS the moonshot; reaching that asks (mode "bigger") for a
// bigger one the user types over, and lays a fresh road for it.
//
// Every AI leg fails soft: no network = no new stop / an empty field. The
// milestone is still marked and the steps still rebuild.

enum FinishLineService {

    private struct ExtendRequest: Encodable {
        struct M: Encodable { let title: String; let by: String }
        var mode = "extend"
        let moonshot: String
        let finish: String
        let done: [M]
        let ahead: [M]
    }
    private struct ExtendResponse: Decodable, Sendable { let atFinish: Bool?; let title: String?; let by: String? }

    private struct BiggerRequest: Encodable { var mode = "bigger"; let moonshot: String }
    private struct BiggerResponse: Decodable, Sendable { let moonshot: String? }

    /// The new last stop, or nil (at the finish, or any failure).
    static func extend(moonshot: String, finish: String, road: [Milestone]) async -> Milestone? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_PLAN_STUB"] == "1" {
            try? await Task.sleep(for: .seconds(1.2))
            return Milestone(title: "Get 100,000 people using it", by: "Dec 1")
        }
        #endif
        let m = { (x: Milestone) in ExtendRequest.M(title: x.title, by: x.by) }
        let body = ExtendRequest(moonshot: moonshot, finish: finish,
                                 done: road.filter(\.done).map(m),
                                 ahead: road.filter { !$0.done }.map(m))
        guard let r: ExtendResponse = await post(body), r.atFinish != true else { return nil }
        let title = (r.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80 else { return nil }
        return Milestone(title: title, by: (r.by ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A bigger moonshot to prefill, or nil.
    static func bigger(than moonshot: String) async -> String? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_PLAN_STUB"] == "1" {
            try? await Task.sleep(for: .seconds(1.2))
            return "Build an app that 10 million people use"
        }
        #endif
        let r: BiggerResponse? = await post(BiggerRequest(moonshot: moonshot))
        let s = (r?.moonshot ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    /// POST to the plan server, raced against RoadService's 8s ceiling.
    private static func post<B: Encodable, R: Decodable & Sendable>(_ body: B) async -> R? {
        guard let url = RoadService.url, let payload = try? JSONEncoder().encode(body) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: RoadService.timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios-1", forHTTPHeaderField: "X-BD-Client")
        req.httpBody = payload
        let request = req
        return await withTaskGroup(of: R?.self) { group in
            group.addTask {
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                return try? JSONDecoder().decode(R.self, from: data)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(RoadService.timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

// MARK: - The rebuild Adjust plan and the finish line share.

@MainActor
enum PlanRebuild {
    /// Replace the persisted plan with one aimed at the profile's CURRENT
    /// milestone. Reads everything from the profile, so write edits first.
    static func run(profile: UserProfile, context: ModelContext, details: [String]? = nil) async {
        let domain = profile.primaryDomain ?? profile.domains.first ?? .building
        let moonshot = profile.moonshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let answers = OnboardingAnswers(
            hijackers: profile.hijackers,
            timeLost: ShortFormBand.allCases.first { $0.baselineMinutes == profile.baselineJunkMinutes } ?? .oneToTwo,
            domains: [domain],
            primaryDomain: domain,
            aspiration: profile.why,
            blocker: profile.blocker ?? .distracted,
            dreamDetails: DreamDetails.normalise([moonshot, profile.milestones.current?.title ?? ""]
                                                 + (details ?? profile.dreamDetails))
        )
        var plan = MoonshotPlan.focus(HeuristicGoalPlanner.plan(from: answers), moonshot: moonshot, short: "")
        if let served = await PlanService.plan(for: profile) {
            plan = plan.merging(served)
            profile.shieldLines = served.shield
        }
        for g in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] { context.delete(g) }
        for s in (try? context.fetch(FetchDescriptor<GoalStep>())) ?? [] { context.delete(s) }
        plan.persist(into: context)
        profile.planIdentityLine = plan.identityLine.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }
}

// MARK: - Profile reads

extension UserProfile {
    /// The road's final row: the stored finish phrase, else the moonshot.
    var finishLabel: String {
        let f = moonshotFinish.trimmingCharacters(in: .whitespacesAndNewlines)
        return f.isEmpty ? GoalSentenceText.display(moonshotText) : f
    }

    /// Every milestone is done: the next stop is the moonshot itself.
    var isAtMoonshot: Bool { hasMoonshot && milestones.current == nil }
}
