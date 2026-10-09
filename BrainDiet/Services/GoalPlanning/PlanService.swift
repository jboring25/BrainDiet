import Foundation

// MARK: - PlanService — the server planner (onboarding v2, Jack approved 2026-10-08).
//
// One POST with everything onboarding learned; the server answers with three
// steps written from the user's own words and, optionally, a shield line per
// goal. ANY failure (no network, timeout, non-200, bad JSON, empty steps)
// returns nil and the caller keeps the heuristic / on-device plan it already
// has. The server is never required for the app to work.
//
// The endpoint comes from Info.plist `BDPlanURL` when present, else the
// default below. DEBUG: `BD_PLAN_STUB=1` returns a canned plan, no network.

/// One step the server served, tagged with the goal it belongs to.
struct ServedStep: Sendable, Equatable {
    let domain: ActivityDomain
    let step: PlannedStep
    /// The server's one-line reason. Not persisted (GoalStep has no slot for it).
    let why: String
}

struct ServedPlan: Sendable, Equatable {
    let steps: [ServedStep]
    let shield: [ActivityDomain: ShieldLine]
}

// MARK: Wire format

struct PlanRequest: Encodable, Sendable {
    struct Domain: Encodable, Sendable {
        let domain: String
        let words: String
        let isPrimary: Bool
    }
    let domains: [Domain]
    let baseline: String
    let nextPiece: String
    let aspiration: String
    let minutesPerDay: Int
    let wake: String
    let busyStart: String?
    let busyEnd: String?
    let sleep: String
    let anchors: [String]
    let blocker: String
    let localHour: Int
}

private struct PlanResponse: Decodable {
    struct Step: Decodable {
        let domain: String
        let title: String
        let minutes: Int
        let cue: String?
        let why: String?
    }
    let steps: [Step]
    let shield: [String: ShieldLine]?
}

// MARK: Service

enum PlanService {

    static let defaultURL = "https://braindiet.netlify.app/.netlify/functions/plan"
    static let timeout: TimeInterval = 9

    static var endpoint: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BDPlanURL") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? defaultURL
        return URL(string: raw)
    }

    /// Build the request from the persisted profile. MainActor because
    /// UserProfile is a SwiftData model; the network leg is not.
    @MainActor
    static func request(for profile: UserProfile) -> PlanRequest {
        let words = profile.goalWords
        let ranked: [ActivityDomain] = {
            guard let p = profile.primaryDomain else { return profile.domains }
            return [p] + profile.domains.filter { $0 != p }
        }()
        return PlanRequest(
            domains: ranked.prefix(3).map {
                .init(domain: $0.rawValue, words: words[$0] ?? "", isPrimary: $0 == profile.primaryDomain)
            },
            baseline: profile.baselineRaw,
            nextPiece: profile.nextPiece,
            aspiration: profile.why,
            minutesPerDay: profile.minutesPerDay > 0 ? profile.minutesPerDay : 45,
            wake: DayClock.wire(profile.wakeMinutes >= 0 ? profile.wakeMinutes : 450),
            busyStart: profile.busyStartMinutes >= 0 ? DayClock.wire(profile.busyStartMinutes) : nil,
            busyEnd: profile.busyEndMinutes >= 0 ? DayClock.wire(profile.busyEndMinutes) : nil,
            sleep: DayClock.wire(profile.sleepMinutes >= 0 ? profile.sleepMinutes : 1410),
            anchors: profile.dayAnchors.map(\.label),
            blocker: profile.blockerRaw,
            localHour: Calendar.current.component(.hour, from: .now)
        )
    }

    /// The plan for this profile, or nil on any failure (caller falls back).
    @MainActor
    static func plan(for profile: UserProfile) async -> ServedPlan? {
        let body = request(for: profile)
        #if DEBUG
        if ProcessInfo.processInfo.environment["BD_PLAN_STUB"] == "1" {
            try? await Task.sleep(for: .seconds(1.2))
            return stub(for: body)
        }
        #endif
        return await fetch(body)
    }

    /// The network leg, raced against a hard 9s ceiling (URLRequest's timeout
    /// is an IDLE timeout, so a trickling response could outlive it).
    nonisolated static func fetch(_ body: PlanRequest) async -> ServedPlan? {
        guard let url = endpoint, let payload = try? JSONEncoder().encode(body) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios-1", forHTTPHeaderField: "X-BD-Client")
        req.httpBody = payload
        let request = req

        return await withTaskGroup(of: ServedPlan?.self) { group in
            group.addTask {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        Log.onboarding.error("PlanService: non-200")
                        return nil
                    }
                    return decode(data)
                } catch {
                    Log.onboarding.error("PlanService: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    nonisolated static func decode(_ data: Data) -> ServedPlan? {
        guard let r = try? JSONDecoder().decode(PlanResponse.self, from: data) else { return nil }
        let steps: [ServedStep] = r.steps.compactMap { s in
            guard let d = ActivityDomain(rawValue: s.domain) else { return nil }
            let title = s.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return ServedStep(
                domain: d,
                step: PlannedStep(title: title,
                                  cue: (s.cue ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                                  suggestedMinutes: min(max(s.minutes, 5), 120),
                                  kind: .oneoff),
                why: s.why ?? "")
        }
        guard !steps.isEmpty else { return nil }
        var shield: [ActivityDomain: ShieldLine] = [:]
        for (k, v) in r.shield ?? [:] {
            if let d = ActivityDomain(rawValue: k), !v.wish.isEmpty, !v.go.isEmpty { shield[d] = v }
        }
        return ServedPlan(steps: Array(steps.prefix(3)), shield: shield)
    }

    #if DEBUG
    /// The mockup's plan, for whichever of those goals the fixture has.
    static func stub(for body: PlanRequest) -> ServedPlan {
        let canned: [ActivityDomain: (String, Int, String)] = [
            .building: ("Finish the App Store listing", 20, "after your 3pm class"),
            .reading:  ("Read 15 pages of Dune", 25, "once you're in bed"),
            .fitness:  ("Upper body at the SDFC", 45, "before dinner"),
        ]
        let domains = body.domains.compactMap { ActivityDomain(rawValue: $0.domain) }
        let ordered = domains.contains(.building) ? [.building] + domains.filter { $0 != .building } : domains
        let steps = ordered.prefix(3).map { d -> ServedStep in
            let c = canned[d] ?? (d.stepSeeds[1].title, 20, d.stepCues[1])
            return ServedStep(domain: d,
                              step: PlannedStep(title: c.0, cue: c.2, suggestedMinutes: c.1, kind: .oneoff),
                              why: "")
        }
        return ServedPlan(steps: steps, shield: [
            .building: ShieldLine(wish: "You wanted to launch BrainDiet.", go: "Go finish the App Store listing."),
        ])
    }
    #endif
}

// MARK: - Merge a served plan into the plan the app already has.

extension GoalPlan {
    /// Each served step goes to the FRONT of its goal, so it is the next thing
    /// that goal asks for; the goal keeps the same number of steps (the tail
    /// drops) so a plan never grows past what the user can hold.
    func merging(_ served: ServedPlan) -> GoalPlan {
        var out = self
        for i in out.goals.indices {
            let mine = served.steps.filter { $0.domain == out.goals[i].domain }.map(\.step)
            guard !mine.isEmpty else { continue }
            let keep = max(out.goals[i].steps.count, mine.count)
            out.goals[i].steps = Array((mine + out.goals[i].steps).prefix(keep))
        }
        return out
    }
}
