import Foundation
import simd

/// Wall and opening extraction.
///
/// Wall faces are rotated into the Manhattan frame and binned by facing direction. Within
/// one direction, each physical wall is a peak in the area-weighted histogram of the
/// plane offset d = n . p (a 1D Hough transform). Each peak is split into runs along the
/// wall tangent wherever the support has a gap, then corners are snapped by intersecting
/// neighbouring wall lines.
struct WallExtractor {
    var minWallArea: Float = 0.35
    var minWallLength: Float = 0.4
    var gapSplit: Float = 0.6
    var cornerSnap: Float = 0.45

    func extract(_ faces: FaceSet, frame: RoomFrame, planes: [ScanPlane]) -> [WallSegment] {
        let yaw = frame.manhattanYaw
        let manhattan = frame.manhattanConfidence >= 0.25
        struct Item { var q: SIMD2<Float>; var y: Float; var w: Float }
        var bins: [Int: (dir: SIMD2<Float>, items: [Item])] = [:]

        func add(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ w: Float) {
            let m2 = SIMD2(n.x, n.z)
            guard simd_length(m2) > 0.5 else { return }
            let m = simd_normalize(Yaw.rotate(m2, -yaw))
            let q = Yaw.rotate(SIMD2(p.x, p.z), -yaw)
            let ang = atan2(m.x, m.y)
            if manhattan {
                let k = Int((ang / (.pi / 2)).rounded())
                let axisAng = Float(k) * .pi / 2
                if abs(Yaw.wrap(ang - axisAng)) < 25 * .pi / 180 {
                    let key = ((k % 4) + 4) % 4
                    bins[key, default: (SIMD2(sin(axisAng), cos(axisAng)), [])].items.append(Item(q: q, y: p.y, w: w))
                    return
                }
            }
            let k = 4 + Int(((ang + .pi) / (.pi / 12)).rounded(.down)) % 24
            let a = -.pi + (Float(k - 4) + 0.5) * .pi / 12
            bins[k, default: (SIMD2(sin(a), cos(a)), [])].items.append(Item(q: q, y: p.y, w: w))
        }

        for i in 0..<faces.count where abs(faces.normal[i].y) < 0.3 && (faces.label[i] == .wall || faces.label[i].isOpening) {
            add(faces.centroid[i], faces.normal[i], faces.area[i])
        }
        if bins.isEmpty {
            // Plane-only capture: sample each wall plane along its width.
            for p in planes where p.label == .wall {
                let n = max(2, Int(p.width / 0.1))
                for s in 0...n {
                    let x = p.center + p.widthAxis * (Float(s) / Float(n) - 0.5) * p.width
                    add(x, p.normal, p.width * p.height / Float(n + 1))
                }
            }
        }

        var walls: [WallSegment] = []
        for key in bins.keys.sorted() {
            guard let (u, items) = bins[key], items.reduce(Float(0), { $0 + $1.w }) >= minWallArea else { continue }
            let t = SIMD2(-u.y, u.x)
            let ds = items.map { simd_dot($0.q, u) }
            let hist = Stats.histogram(ds, weights: items.map(\.w), bin: 0.04, smooth: 1)
            for pk in Stats.peaks(hist.mass, minMass: minWallArea * 0.5, minSeparation: 6) {
                let d0 = hist.lo + (Float(pk) + 0.5) * 0.04
                let near = items.indices.filter { abs(ds[$0] - d0) < 0.12 }
                guard !near.isEmpty else { continue }
                let d = Stats.percentile(near.map { ds[$0] }, weights: near.map { items[$0].w }, 0.5)
                let sorted = near.sorted { simd_dot(items[$0].q, t) < simd_dot(items[$1].q, t) }
                var run: [Int] = []
                func flush() {
                    defer { run.removeAll() }
                    let area = run.reduce(Float(0)) { $0 + items[$1].w }
                    guard area >= minWallArea else { return }
                    let ss = run.map { simd_dot(items[$0].q, t) }, ws = run.map { items[$0].w }
                    let s0 = Stats.percentile(ss, weights: ws, 0.005), s1 = Stats.percentile(ss, weights: ws, 0.995)
                    guard s1 - s0 >= minWallLength else { return }
                    var top = min(frame.ceilingY, max(frame.floorY + 0.5, Stats.percentile(run.map { items[$0].y }, weights: ws, 0.99)))
                    if frame.ceilingY - top < 0.2 { top = frame.ceilingY }
                    let a = Yaw.rotate(u * d + t * s0, yaw), b = Yaw.rotate(u * d + t * s1, yaw)
                    walls.append(WallSegment(id: "", start: a, end: b, normal: Yaw.rotate(u, yaw),
                                             bottomY: frame.floorY, topY: top, area: area))
                }
                var last: Float = -.infinity
                for i in sorted {
                    let s = simd_dot(items[i].q, t)
                    if s - last > gapSplit, !run.isEmpty { flush() }
                    run.append(i)
                    last = s
                }
                flush()
            }
        }
        walls = snapCorners(walls)
        for i in walls.indices { walls[i].id = "wall_\(i)" }
        return walls
    }

    /// Extends or trims neighbouring walls to their line intersection when endpoints are close.
    func snapCorners(_ input: [WallSegment]) -> [WallSegment] {
        var w = input
        for i in w.indices {
            for j in w.indices where j > i {
                let ti = w[i].tangent, tj = w[j].tangent
                let denom = ti.x * tj.y - ti.y * tj.x
                guard abs(denom) > 0.5 else { continue }
                let dp = w[j].start - w[i].start
                let si = (dp.x * tj.y - dp.y * tj.x) / denom
                let x = w[i].start + ti * si
                let ei = simd_distance(w[i].start, x) < simd_distance(w[i].end, x) ? 0 : 1
                let ej = simd_distance(w[j].start, x) < simd_distance(w[j].end, x) ? 0 : 1
                let pi = ei == 0 ? w[i].start : w[i].end, pj = ej == 0 ? w[j].start : w[j].end
                guard simd_distance(pi, x) < cornerSnap, simd_distance(pj, x) < cornerSnap else { continue }
                if ei == 0 { w[i].start = x } else { w[i].end = x }
                if ej == 0 { w[j].start = x } else { w[j].end = x }
            }
        }
        return w
    }

    /// Window and door segments attached to their nearest wall.
    func openings(_ faces: FaceSet, frame: RoomFrame, walls: [WallSegment]) -> [WallOpening] {
        let cand = faces.indices { faces.label[$0].isOpening }
        let segs = VoxelSegmenter(voxelSize: 0.1).segment(faces, candidates: cand).filter { $0.area >= 0.08 }
        var out: [WallOpening] = []
        for seg in segs.sorted(by: { $0.area > $1.area }) {
            let ws = seg.faces.map { faces.area[$0] }
            let pts = seg.faces.map { SIMD2(faces.centroid[$0].x, faces.centroid[$0].z) }
            let c = pts.indices.reduce(SIMD2<Float>.zero) { $0 + pts[$1] * ws[$1] } / max(seg.area, 1e-6)
            let wall = walls.min { Polygon2D.segmentDistance(c, $0.start, $0.end).dist < Polygon2D.segmentDistance(c, $1.start, $1.end).dist }
            let tangent = wall?.tangent ?? simd_normalize(SIMD2(1, 0))
            let normal = wall?.normal ?? SIMD2(0, 1)
            let anchor = wall?.start ?? c
            let ss = pts.map { simd_dot($0 - anchor, tangent) }
            let s0 = Stats.percentile(ss, weights: ws, 0.02), s1 = Stats.percentile(ss, weights: ws, 0.98)
            let ys = seg.faces.map { faces.centroid[$0].y }
            var y0 = Stats.percentile(ys, weights: ws, 0.02), y1 = Stats.percentile(ys, weights: ws, 0.98)
            let kind: WallOpening.Kind = seg.label == .door ? .door : .window
            if kind == .door, y0 - frame.floorY < 0.25 { y0 = frame.floorY }
            y1 = min(y1, frame.ceilingY)
            guard s1 - s0 > 0.25, y1 - y0 > 0.25 else { continue }
            var center = anchor + tangent * (s0 + s1) / 2
            if let wall { center = wall.start + tangent * simd_dot(center - wall.start, tangent) }
            out.append(WallOpening(id: "\(kind.rawValue)_\(out.count)", kind: kind, wallID: wall?.id, center: center,
                                   width: s1 - s0, bottomY: y0, topY: y1, normal: normal))
        }
        return out
    }
}
