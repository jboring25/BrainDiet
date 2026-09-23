import SwiftUI

// MARK: - Culture · the free-form cloud (Pantheon direction, approved 2026-09-02).
//
// A 1:1 port of design/culture-cloud/cloud.js. Everything below is in AUTHORED
// BRAIN UNITS (the 1167 × 1016 traced box) and transformed at draw time, so the
// simulation is resolution independent — the same numbers drive a 40pt thumbnail
// and a full-screen hero.
//
// ⭐ THE THREE THINGS THAT MAKE IT READ AS A VOLUME, not a scatter:
//   1. Every point carries a depth `z`. z drives radius, alpha AND tone.
//   2. Links form ONLY between points at similar depth (|za − zb| < 0.30).
//      Without this it collapses into a flat wire mesh instantly.
//   3. Nothing is drawn around it. The silhouette is implied purely by where
//      density falls off. Adding a border kills the free-form read.
//
// Deterministic: seeded RNG + a fixed 1/60 timestep. Same seed and same elapsed
// time always produce the same frame, which is what makes the filmstrip
// comparison against the web build meaningful.

/// mulberry32 — the same PRNG the web build uses, so point layouts match.
struct Mulberry32 {
    private var s: UInt32
    init(_ seed: UInt32) { s = seed }
    mutating func next() -> Double {
        s &+= 0x6D2B79F5
        var t = s
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ (t ^ (t >> 7)) &* (t | 61)
        return Double((t ^ (t >> 14)) & 0xFFFF_FFFF) / 4_294_967_296.0
    }
    mutating func next(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
}

final class CultureCloudModel {

    struct Site { var p: CGPoint; var tier: Int }        // 0 rim · 1 fold · 2 interior

    struct Dot {
        var siteIndex: Int
        var tier: Int            // 0 rim · 1 fold · 2 interior
        var home: CGPoint
        var pos: CGPoint
        var z: Double            // 0 far … 1 near
        var grade: Double        // size variance — kills the uniform-field read
        var phase: Double
        var amp: Double
        var drift: Double
        var born: Double         // -99 for points that were always there
    }

    struct Serving {
        var pos: CGPoint
        var target: CGPoint
        var radius: Double
        var age: Double
        var inside: Bool
        var yield: Int
    }

    // Tuning, in brain units (matched to cloud.js line for line).
    static let dt = 1.0 / 60.0
    static let nodeRadius: CGFloat = 5
    static let linkRadius: CGFloat = 64
    static let linkDepthWindow = 0.30
    static let waveSpeed: CGFloat = 2400          // units per second
    static let waveBand: CGFloat = 210
    static let waveLife = 1.6

    private(set) var sites: [Site] = []
    private(set) var dots: [Dot] = []
    private(set) var serving: Serving?
    private(set) var burst: (p: CGPoint, at: Double)?
    private(set) var t: Double = 0
    /// Wall-clock of the last frame. Lives here, NOT in @State: SwiftUI discards
    /// state writes made during body evaluation, which silently froze the sim.
    var lastTick: Double = 0
    /// Carries the sub-timestep remainder between frames. Without this the leftover
    /// is discarded each frame, and since real frame deltas hover right at 1/60 the
    /// comparison fails more often than it passes — the sim crawls at a few steps
    /// per second regardless of load. This is the whole fixed-timestep pattern.
    var accumulator: Double = 0
    private var rng = Mulberry32(3)

    private let centre: CGPoint

    init() {
        let box = CultureCloudGeometry.box
        centre = CGPoint(x: box.midX, y: box.midY)
        // ⭐ Sites are a STATIC. `@State private var m = Model()` re-runs this
        // initializer on every view-struct init, and building the site pool costs
        // ~6,000 point-in-polygon tests against a 544-segment path. Doing that per
        // frame pinned the whole view to about 1fps. Built once, shared forever.
        sites = Self.sharedSites
    }

    // MARK: Sites — rim and folds carry the density, the interior is sparse.

    private static let sharedSites: [Site] = buildSites()

    /// How many points the INTERIOR can hold — the rim is identity and never
    /// counts as progress. Home states this × growth as "connections", so the
    /// number under the headline is literally the dots drawn in the hero.
    static var fillSiteCount: Int { sharedSites.count { $0.tier != 0 } }

    private static func buildSites() -> [Site] {
        var r = Mulberry32(3)
        var out: [Site] = []
        // ⭐ THE EDGE IS THE SIMULATION. Every 3rd sample of the 6-unit outline
        // ≈ one every 18 units — three times the old density — and the jitter is
        // widened to ±20 so they scatter into a band instead of lining up. There
        // is no border layer anywhere: the contour is just where points crowd.
        // ⭐ Every 2nd sample of the 6-unit outline ≈ one every 12 units, and the
        // jitter is HALVED to ±10. At 18 units / ±20 the rim was a loose band,
        // which reads fine once the interior is full but reads as scatter when
        // the interior is empty — and the empty state is every user's first
        // impression. Tighter spacing plus tighter jitter is a contour you can
        // follow with your eye at any fill level.
        for (i, p) in CultureCloudGeometry.silhouette.enumerated() where i % 2 == 0 {
            out.append(Site(p: CGPoint(x: p.x + r.next(-10, 10), y: p.y + r.next(-10, 10)), tier: 0))
        }
        // ⭐ THE FOLDS ARE WHAT MAKES IT A BRAIN. At every 6th sample of the
        // 10-unit gyri — one every 60 units, jittered ±15 — consecutive fold
        // points were too far apart to read as a run, and they were rendered at
        // the same weight as the interior scatter, so the sheet had no folds in
        // it at all. It read as a cloud for exactly that reason. Every 2nd
        // sample (≈20 units) with the jitter halved keeps each ribbon reading as
        // one continuous ridge, and links form along it for free.
        for g in CultureCloudGeometry.gyri {
            for (i, p) in g.enumerated() where i % 2 == 0 {
                out.append(Site(p: CGPoint(x: p.x + r.next(-10, 10), y: p.y + r.next(-10, 10)), tier: 1))
            }
        }
        // interior: sparse, rejection-sampled inside the outline. Cut from 430
        // because at that count it competed with the folds instead of sitting
        // behind them.
        let box = CultureCloudGeometry.box
        var tries = 0
        var inner = 0
        while inner < 260 && tries < 6000 {
            tries += 1
            let p = CGPoint(x: box.minX + r.next() * box.width,
                            y: box.minY + r.next() * box.height)
            if CultureCloudGeometry.outline.contains(p) { out.append(Site(p: p, tier: 2)); inner += 1 }
        }
        return out
    }

    // MARK: Growth

    /// ⭐ THE RIM IS NOT PROGRESS — IT IS IDENTITY (Jack, 2026-09-13).
    ///
    /// This used to scale the WHOLE site pool by `fraction`, rim included. At a
    /// new user's density that left about four percent of everything, so the
    /// outline was forty scattered points and the screen read as confetti:
    /// *"what the fuck am I looking at? All I see is dots."* He is right, and
    /// the fix is not more dots everywhere — it is that **the contour is drawn
    /// in full from the first launch and never grows.** A brain is recognisable
    /// by its silhouette; the silhouette is the one thing that must never be
    /// partial.
    ///
    /// So growth now applies only to the folds and the interior: day one is a
    /// clean empty brain, and what fills in over time is the inside of it. That
    /// is also the better metaphor — you are not growing a brain, you are
    /// feeding one you already have.
    func seed(fraction: Double) {
        rng = Mulberry32(11)
        t = 0; serving = nil; burst = nil
        dots = []

        // 1 — the whole contour, always.
        let rim = sites.indices.filter { sites[$0].tier == 0 }
        // 2 — folds, then interior, scaled by what has been earned.
        var r = Mulberry32(7)
        let fill = sites.indices
            .filter { sites[$0].tier != 0 }
            .map { (i: $0, key: Double(sites[$0].tier) * 1.6 + r.next()) }
            .sorted { $0.key < $1.key }
            .map(\.i)
        let n = Int((Double(fill.count) * max(0, min(1, fraction))).rounded())

        dots.reserveCapacity(rim.count + n)
        for i in rim { add(i, bornNow: false, from: nil) }
        for k in 0..<min(n, fill.count) { add(fill[k], bornNow: false, from: nil) }
    }

    private func add(_ index: Int, bornNow: Bool, from: CGPoint?) {
        let site = sites[index]
        let rim = site.tier == 0
        // ⭐ TIER IS EXPRESSED THROUGH DEPTH, NEVER THROUGH A SEPARATE STYLE.
        // z already drives radius, alpha and tone, so pushing a tier near or far
        // is all the emphasis it needs — no extra layer, no second render pass,
        // and the free-form read survives. Rim and folds go near so they carry
        // the shape; the interior goes far so it becomes the atmosphere behind
        // them rather than a competing field of equal-weight dots.
        let z: Double
        switch site.tier {
        case 0:  z = 0.52 + rng.next() * 0.48
        case 1:  z = 0.50 + rng.next() * 0.50
        default: z = rng.next() * 0.55
        }
        let gradeBase = rim ? 0.72 : (site.tier == 1 ? 0.67 : 0.45)
        dots.append(Dot(
            siteIndex: index,
            tier: site.tier,
            home: site.p,
            pos: from ?? site.p,
            z: z,
            grade: gradeBase + pow(rng.next(), 1.7) * (rim ? 1.35 : 1.5),
            phase: rng.next() * 6.283,
            amp: (4 + rng.next() * 13) * (0.4 + z * 0.9),
            drift: (rng.next() - 0.5) * 0.5,
            born: bornNow ? t : -99
        ))
    }

    // MARK: Feeding

    /// Send a serving in from `origin` (brain units). Nil picks a point off the edge.
    func feed(from origin: CGPoint? = nil) {
        guard serving == nil else { return }
        let box = CultureCloudGeometry.box
        let start = origin ?? CGPoint(x: box.midX + cos(rng.next() * 6.283) * box.width * 0.75,
                                      y: box.midY + sin(rng.next() * 6.283) * box.height * 0.85)
        // aim at the nearest earned point so it always enters somewhere real
        var target = centre
        var best = Double.greatestFiniteMagnitude
        for d in dots {
            let dd = pow(d.pos.x - start.x, 2) + pow(d.pos.y - start.y, 2)
            if dd < best { best = dd; target = d.pos }
        }
        serving = Serving(pos: start, target: target, radius: 17, age: 0, inside: false, yield: 18)
    }

    // MARK: One fixed step

    func step() {
        t += Self.dt

        if var f = serving {
            f.age += Self.dt
            if !f.inside {
                f.pos.x += (f.target.x - f.pos.x) * 0.085
                f.pos.y += (f.target.y - f.pos.y) * 0.085
                if hypot(f.target.x - f.pos.x, f.target.y - f.pos.y) < 7 { f.inside = true; f.age = 0 }
                serving = f
            } else {
                f.pos.x += (centre.x - f.pos.x) * 0.03
                f.pos.y += (centre.y - f.pos.y) * 0.03
                f.radius *= 0.986
                if f.age > 1.0 {
                    absorb(at: f.pos, yield: f.yield)
                } else {
                    serving = f
                }
            }
        }

        let f = serving
        for i in dots.indices {
            let p = dots[i]
            let w = t * 0.24 + p.phase
            var tx = p.home.x + cos(w) * p.amp
            var ty = p.home.y + sin(w * 0.73) * p.amp * 0.85 + sin(w * 0.4) * p.drift * 9
            if let f, f.inside {
                let ddx = f.pos.x - p.pos.x, ddy = f.pos.y - p.pos.y
                let d = max(1, hypot(ddx, ddy))
                let pull = max(0, 1 - d / 400) * 0.34 * (0.4 + p.z)
                tx += ddx * pull; ty += ddy * pull
            }
            let ease = p.born > -90 ? 0.10 : 0.05
            dots[i].pos.x += (tx - p.pos.x) * ease
            dots[i].pos.y += (ty - p.pos.y) * ease
        }
    }

    /// The serving dissolves into the nearest unused sites — growth stays anatomical.
    private func absorb(at p: CGPoint, yield: Int) {
        let used = Set(dots.map(\.siteIndex))
        let free = sites.indices
            .filter { !used.contains($0) }
            .sorted { hypot(sites[$0].p.x - p.x, sites[$0].p.y - p.y)
                    < hypot(sites[$1].p.x - p.x, sites[$1].p.y - p.y) }
        for k in 0..<min(yield, free.count) { add(free[k], bornNow: true, from: p) }
        burst = (p, t)
        serving = nil
    }

    // MARK: Derived — pure functions of `t`

    /// The wavefront released on absorption. 0 when nothing is travelling.
    func wave(at p: CGPoint) -> Double {
        guard let b = burst else { return 0 }
        let age = t - b.at
        guard age >= 0, age < Self.waveLife else { return 0 }
        let d = hypot(p.x - b.p.x, p.y - b.p.y)
        let front = age * Self.waveSpeed
        let band = abs(d - front)
        guard band < Self.waveBand else { return 0 }
        return (1 - band / Self.waveBand) * max(0, 1 - age / 1.5)
    }
}
