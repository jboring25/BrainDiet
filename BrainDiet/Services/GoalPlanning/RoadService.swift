import Foundation

// MARK: - RoadService — "That's the one. Here's the road." (moonshot, 2026-10-10).
//
// Same plan server, mode "road". One POST with the moonshot and the pain-sweep
// context; the server answers the domain the moonshot lives in, a short phrase
// for the shield ("BrainDiet launched" → "Go get BrainDiet launched."), and
// three dated milestones. ANY failure (no network, 8s ceiling, non-200, bad
// JSON, no milestones) returns nil: the screen shows one empty milestone row
// they can type into or skip. DEBUG: `BD_PLAN_STUB=1` returns a canned road;
// `BD_ROAD_FAIL=1` fails; `BD_ROAD_HOLD=1` holds the skeleton.

struct RoadRequest: Encodable, Sendable {
    struct Context: Encodable, Sendable {
        let timeLost: Int?
        let whenItGets: [String]
        let feelAfter: String
        let triedBefore: [String]
    }
    var mode = "road"
    let moonshot: String
    let context: Context
}

struct Road: Sendable, Equatable {
    let domain: ActivityDomain
    let short: String
    /// The timeline's last row ("1 million people"). Optional on the wire;
    /// falls back to `short`, then to the moonshot itself.
    var finish: String = ""
    let milestones: [Milestone]
}

private struct RoadResponse: Decodable {
    struct M: Decodable { let title: String; let by: String? }
    let domain: String?
    let short: String?
    let finish: String?
    let milestones: [M]
}

enum RoadService {

    static let url = URL(string: "https://braindietapp.com/.netlify/functions/plan")
    static let timeout: TimeInterval = 8

    static func road(_ body: RoadRequest) async -> Road? {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["BD_ROAD_HOLD"] == "1" {        // the skeleton, held for capture
            try? await Task.sleep(for: .seconds(60))
            return nil
        }
        if env["BD_ROAD_FAIL"] == "1" {
            try? await Task.sleep(for: .seconds(1.0))
            return nil
        }
        if env["BD_PLAN_STUB"] == "1" {
            try? await Task.sleep(for: .seconds(1.4))
            return stub
        }
        #endif
        return await fetch(body)
    }

    /// The network leg, raced against a hard 8s ceiling (URLRequest's timeout
    /// is an idle timeout).
    nonisolated static func fetch(_ body: RoadRequest) async -> Road? {
        guard let url, let payload = try? JSONEncoder().encode(body) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios-1", forHTTPHeaderField: "X-BD-Client")
        req.httpBody = payload
        let request = req

        return await withTaskGroup(of: Road?.self) { group in
            group.addTask {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        Log.onboarding.error("RoadService: non-200")
                        return nil
                    }
                    return decode(data)
                } catch {
                    Log.onboarding.error("RoadService: \(error.localizedDescription, privacy: .public)")
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

    nonisolated static func decode(_ data: Data) -> Road? {
        guard let r = try? JSONDecoder().decode(RoadResponse.self, from: data) else { return nil }
        let milestones = r.milestones.compactMap { m -> Milestone? in
            let t = m.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t.count <= 80 else { return nil }
            return Milestone(title: t, by: (m.by ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard !milestones.isEmpty else { return nil }
        return Road(domain: r.domain.flatMap(ActivityDomain.init(rawValue:)) ?? .building,
                    short: (r.short ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    finish: (r.finish ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    milestones: Array(milestones.prefix(3)))
    }

    #if DEBUG
    /// The mockup's road (design/goal-builder/moon.png).
    static let stub = Road(domain: .building, short: "BrainDiet launched",
                          finish: "1 million people", milestones: [
        Milestone(title: "Launch on the App Store", by: "Nov 15"),
        Milestone(title: "First 1,000 users", by: "Mar 1"),
        Milestone(title: "Paying users every week", by: "Jun 1"),
    ])
    #endif
}
