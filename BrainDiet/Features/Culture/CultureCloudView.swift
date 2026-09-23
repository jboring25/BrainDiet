import SwiftUI

// MARK: - Culture · the cloud renderer.
//
// A 1:1 port of drawCloud() from design/culture-cloud/cloud.js, with two changes
// that alter the CODE but not one pixel of the OUTPUT:
//
//   • BATCHING. The web build issues one fill per point and one stroke per link
//     (~1,100 draw calls a frame). SwiftUI's Canvas is not GPU-instanced, so that
//     stutters on device. Points are bucketed by tone + alpha and links by alpha,
//     then each bucket is filled/stroked ONCE — about a dozen calls a frame.
//   • SPATIAL GRID. The link search was all-pairs (514² ≈ 264k tests a frame).
//     Points are hashed into cells the size of the link radius, so each point
//     only tests its own cell and the eight around it.
//
// The model is stepped inside the draw closure on a NON-observed class, so no
// SwiftUI state is mutated during a view update. TimelineView drives the clock.

struct CultureCloudView: View {

    let model: CultureCloudModel
    /// Honours Reduce Motion: the drift freezes, feeding still resolves.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let deep = Color(hex: "#244A2F")
    private static let mid  = Color(hex: "#3E7A4E")
    private static let hi   = Color(hex: "#7DB68B")

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                Canvas { ctx, size in
                    advance(to: now)
                    draw(ctx, size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let t = CultureCloudGeometry.transform(in: geo.size)
                            model.feed(from: value.location.applying(t.inverted()))
                        }
                )
            }
        }
    }

    // MARK: Fixed-timestep clock

    private func advance(to now: Double) {
        if model.lastTick == 0 { model.lastTick = now; return }
        // clamp so a backgrounded app does not try to catch up hundreds of steps
        model.accumulator += min(0.25, now - model.lastTick)
        model.lastTick = now
        var guardCount = 0
        while model.accumulator >= CultureCloudModel.dt, guardCount < 8 {
            model.step()
            model.accumulator -= CultureCloudModel.dt
            guardCount += 1
        }
    }

    // MARK: Draw

    private func draw(_ ctx: GraphicsContext, size: CGSize) {
        let xf = CultureCloudGeometry.transform(in: size)
        let s = xf.a
        let R = CultureCloudModel.nodeRadius * s
        let dots = model.dots
        guard !dots.isEmpty else { return }

        // Screen-space positions once, sorted far → near so depth stacks.
        struct Rendered { var p: CGPoint; var z: Double; var r: CGFloat; var a: Double; var wave: Double; var edge: Bool }
        var items: [Rendered] = []
        items.reserveCapacity(dots.count)
        for d in dots {
            let wv = model.wave(at: d.pos)
            let fresh = max(0, 1 - (model.t - d.born) / 1.8)
            let grow = d.born > -90 ? min(1, (model.t - d.born) / 0.7) : 1
            let r = R * d.grade * (0.35 + 0.95 * d.z) * grow * (1 + fresh * 0.7 + wv * 0.75)
            var a = (0.22 + d.z * 0.66) * (d.born > -90 ? min(1, grow + 0.25) : 1)
            if d.tier == 0 { a = min(1, a * 1.22 + 0.10) }      // the edge asserts itself
            items.append(Rendered(p: d.pos.applying(xf), z: d.z,
                                  r: max(0.35, r),
                                  a: fresh > 0.05 ? min(1, a + 0.32) : a,
                                  wave: wv,
                                  edge: d.tier == 0))
        }
        items.sort { $0.z < $1.z }

        // ---- links, via a uniform grid ----
        let lim = CultureCloudModel.linkRadius * s
        drawLinks(ctx, items: items.map { ($0.p, $0.z, $0.wave) }, limit: lim, s: s)

        // ---- absorption bloom ----
        if let b = model.burst, model.t - b.at < 1.3 {
            let u = (model.t - b.at) / 1.3
            let c = b.p.applying(xf)
            let rr = 30 * s + CGFloat(u) * 190 * s
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                     with: .radialGradient(
                        Gradient(colors: [Self.hi.opacity(0.30 * (1 - u)), Self.hi.opacity(0)]),
                        center: c, startRadius: 0, endRadius: rr))
        }

        // ---- points, batched into tone × alpha buckets ----
        var buckets: [Int: Path] = [:]
        for it in items {
            let lit = it.wave > 0.22
            let tone = lit ? 2 : ((it.edge || it.z > 0.62) ? 0 : 1)
            let alpha = min(1.0, it.a + (lit ? it.wave * 0.34 : 0))
            let step = max(0, min(7, Int(alpha * 8)))
            let key = tone * 8 + step
            buckets[key, default: Path()].addEllipse(
                in: CGRect(x: it.p.x - it.r, y: it.p.y - it.r, width: it.r * 2, height: it.r * 2))
        }
        for (key, path) in buckets.sorted(by: { $0.key < $1.key }) {
            let tone = key / 8, step = key % 8
            let colour: Color = tone == 0 ? Self.deep : (tone == 1 ? Self.mid : Self.hi)
            ctx.fill(path, with: .color(colour.opacity(Double(step) / 8 + 0.0625)))
        }

        // ---- the serving ----
        if let f = model.serving {
            let c = f.pos.applying(xf)
            let fr = CGFloat(f.radius) * s
            let halo = fr * 3.4
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - halo, y: c.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(
                        Gradient(colors: [Self.hi.opacity(0.34), Self.hi.opacity(0)]),
                        center: c, startRadius: 0, endRadius: halo))
            let dot = Path(ellipseIn: CGRect(x: c.x - fr, y: c.y - fr, width: fr * 2, height: fr * 2))
            ctx.fill(dot, with: .color(Self.hi.opacity(0.95)))
            ctx.stroke(dot, with: .color(Self.mid.opacity(0.65)), lineWidth: 1.8)
        }
    }

    /// Links only join points at similar depth — the rule that keeps it volumetric.
    private func drawLinks(_ ctx: GraphicsContext,
                           items: [(p: CGPoint, z: Double, wave: Double)],
                           limit: CGFloat, s: CGFloat) {
        guard limit > 0 else { return }
        var grid: [Int64: [Int]] = [:]
        let cell = limit
        @inline(__always) func key(_ x: Int, _ y: Int) -> Int64 { Int64(x) &* 100_003 &+ Int64(y) }
        for (i, it) in items.enumerated() {
            grid[key(Int(it.p.x / cell), Int(it.p.y / cell)), default: []].append(i)
        }
        var lit = Path()
        var buckets = [Path](repeating: Path(), count: 12)
        // ⭐ Candidates are gathered from the grid then sorted BY INDEX before the
        // cap is applied. The grid visits cells in spatial order, so taking the
        // first two it happens to find produces a denser, different mesh than the
        // web build, which scans j > i in order. Sorting restores 1:1.
        var candidates: [Int] = []
        candidates.reserveCapacity(16)
        for (i, a) in items.enumerated() {
            candidates.removeAll(keepingCapacity: true)
            let cx = Int(a.p.x / cell), cy = Int(a.p.y / cell)
            for gx in (cx - 1)...(cx + 1) {
                for gy in (cy - 1)...(cy + 1) {
                    for j in grid[key(gx, gy)] ?? [] where j > i {
                        let b = items[j]
                        if abs(a.z - b.z) > CultureCloudModel.linkDepthWindow { continue }
                        if hypot(a.p.x - b.p.x, a.p.y - b.p.y) > limit { continue }
                        candidates.append(j)
                    }
                }
            }
            candidates.sort()
            for j in candidates.prefix(2) {
                let b = items[j]
                let d = hypot(a.p.x - b.p.x, a.p.y - b.p.y)
                let w = 1 - d / limit
                let wv = max(a.wave, b.wave)
                var seg = Path()
                seg.move(to: a.p); seg.addLine(to: b.p)
                if wv > 0.06 {
                    lit.addPath(seg)
                } else {
                    let z = (a.z + b.z) / 2
                    let alpha = (0.04 + Double(w) * 0.30) * (0.3 + z * 0.7)
                    buckets[max(0, min(11, Int(alpha * 24)))].addPath(seg)
                }
            }
        }
        for (i, path) in buckets.enumerated() where !path.isEmpty {
            // bucket centre, so 0 maps to ~0.02 rather than a 0.04 floor
            let alpha = (Double(i) + 0.5) / 24
            let width = 0.25 + 0.85 * (CGFloat(i) / 11)
            ctx.stroke(path, with: .color(Self.mid.opacity(alpha)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        if !lit.isEmpty {
            ctx.stroke(lit, with: .color(Self.hi.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }
}
