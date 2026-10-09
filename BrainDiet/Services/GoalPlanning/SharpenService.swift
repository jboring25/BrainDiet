import Foundation

// MARK: - SharpenService — "Sharper versions" for one built goal (goal builder, 2026-10-09).
//
// Same plan server, new mode. One POST with the sentence the user just built
// and the pain-sweep context; the server answers up to two tighter rewrites.
// ANY failure (no network, 6s ceiling, non-200, bad JSON, nothing usable)
// returns [] and the goalSharpen screen is skipped silently: their own
// sentence stands. DEBUG: `BD_PLAN_STUB=1` returns canned options.

struct SharpenRequest: Encodable, Sendable {
    struct Context: Encodable, Sendable {
        let timeLost: Int?
        let whenItGets: [String]
        let feelAfter: String
        let baseline: String?
    }
    var mode = "sharpen"
    let domain: String
    let sentence: String
    let context: Context
}

private struct SharpenResponse: Decodable {
    let options: [String]
}

enum SharpenService {

    static let url = URL(string: "https://braindietapp.com/.netlify/functions/plan")
    static let timeout: TimeInterval = 6

    /// Up to two rewrites that differ from `body.sentence`, or [] on any failure.
    static func sharpen(_ body: SharpenRequest) async -> [String] {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["BD_SHARPEN_FAIL"] == "1" {
            try? await Task.sleep(for: .seconds(0.8))
            return []
        }
        if env["BD_PLAN_STUB"] == "1" {
            try? await Task.sleep(for: .seconds(1.0))
            return stub(for: body)
        }
        #endif
        return await fetch(body)
    }

    /// The network leg, raced against a hard 6s ceiling (URLRequest's timeout
    /// is an idle timeout).
    nonisolated static func fetch(_ body: SharpenRequest) async -> [String] {
        guard let url, let payload = try? JSONEncoder().encode(body) else { return [] }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios-1", forHTTPHeaderField: "X-BD-Client")
        req.httpBody = payload
        let request = req
        let mine = body.sentence

        return await withTaskGroup(of: [String]?.self) { group in
            group.addTask {
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        Log.onboarding.error("SharpenService: non-200")
                        return []
                    }
                    return clean(decode(data), against: mine)
                } catch {
                    Log.onboarding.error("SharpenService: \(error.localizedDescription, privacy: .public)")
                    return []
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
    }

    nonisolated static func decode(_ data: Data) -> [String] {
        (try? JSONDecoder().decode(SharpenResponse.self, from: data))?.options ?? []
    }

    /// Trim, drop empties + anything equal to theirs, dedupe, cap at two.
    nonisolated static func clean(_ raw: [String], against mine: String) -> [String] {
        let key: (String) -> String = {
            $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        }
        var seen: Set<String> = [key(mine)]
        var out: [String] = []
        for o in raw {
            let t = o.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t.count <= 140, seen.insert(key(t)).inserted else { continue }
            out.append(t)
            if out.count == 2 { break }
        }
        return out
    }

    #if DEBUG
    static func stub(for body: SharpenRequest) -> [String] {
        let canned: [String: [String]] = [
            "building": ["Get 100 ASU students using BrainDiet by May 1",
                         "Launch BrainDiet on the App Store by Nov 15"],
            "reading":  ["Finish Dune, then read 12 books by next summer",
                         "Read 20 pages every night before bed"],
            "fitness":  ["Bench 225 by May, training upper body twice a week",
                         "Train 4 days a week until summer"],
        ]
        return clean(canned[body.domain] ?? ["\(GoalSentenceText.display(body.sentence)), one small step a day"],
                     against: body.sentence)
    }
    #endif
}
