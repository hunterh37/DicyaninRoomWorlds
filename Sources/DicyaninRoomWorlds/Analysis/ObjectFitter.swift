import Foundation
import simd

/// Turns a face segment into a measured, oriented box.
///
/// 1. Height: robust 2nd/98th height percentiles; bottoms within 0.25 m of the floor snap to it
///    (scanners rarely see under furniture, so the visible bottom is biased high).
/// 2. Orientation: minimum-area rectangle of the convex hull of the footprint, snapped to
///    the Manhattan frame when within `manhattanSnap`.
/// 3. Extents: area-weighted 1st/99th percentiles along the chosen axes (outlier robust).
/// 4. Functional surface: the dominant height of up-facing area (seat, table top, mattress).
/// 5. Front: away from a backrest (area above the seat), else away from the nearest wall,
///    else toward the room center.
struct ObjectFitter {
    var manhattanSnap: Float = 12 * .pi / 180
    var floorSnap: Float = 0.25

    struct Fit {
        var box: FittedBox
        var surfaceHeight: Float?
        var wallID: String?
    }

    func fit(_ seg: VoxelSegmenter.Segment, faces: FaceSet, frame: RoomFrame, walls: [WallSegment], roomCenter: SIMD2<Float>) -> Fit? {
        let f = seg.faces
        guard f.count >= 3 else { return nil }
        let w = f.map { faces.area[$0] }
        var pts: [SIMD2<Float>] = [], ptsW: [Float] = [], ys: [Float] = []
        pts.reserveCapacity(f.count * 3)
        for (k, i) in f.enumerated() {
            for v in 0..<3 {
                let p = faces.verts[i * 3 + v]
                pts.append(SIMD2(p.x, p.z)); ptsW.append(w[k] / 3); ys.append(p.y)
            }
        }
        var y0 = Stats.percentile(ys, weights: ptsW, 0.02)
        let y1 = Stats.percentile(ys, weights: ptsW, 0.98)
        if y0 - frame.floorY < floorSnap { y0 = frame.floorY }
        guard y1 - y0 > 0.04 else { return nil }

        // Orientation from the hull of the inner 96% of points.
        let mean = pts.indices.reduce(SIMD2<Float>.zero) { $0 + pts[$1] * ptsW[$1] } / max(ptsW.reduce(0, +), 1e-6)
        let r = pts.map { simd_distance($0, mean) }
        let rCut = Stats.percentile(r, weights: ptsW, 0.96)
        let hull = Polygon2D.convexHull(pts.indices.filter { r[$0] <= rCut + 1e-4 }.map { pts[$0] })
        var angle = Polygon2D.minAreaRectAngle(hull)
        // Snap to the Manhattan frame (angles compared modulo 90 degrees).
        let rel = angle - (.pi / 2 - frame.manhattanYaw)
        let q = (rel / (.pi / 2)).rounded()
        if abs(rel - q * .pi / 2) < manhattanSnap { angle = .pi / 2 - frame.manhattanYaw + q * .pi / 2 }
        let u = SIMD2<Float>(cos(angle), sin(angle)), v = SIMD2<Float>(-u.y, u.x)

        let su = pts.map { simd_dot($0, u) }, sv = pts.map { simd_dot($0, v) }
        let u0 = Stats.percentile(su, weights: ptsW, 0.01), u1 = Stats.percentile(su, weights: ptsW, 0.99)
        let v0 = Stats.percentile(sv, weights: ptsW, 0.01), v1 = Stats.percentile(sv, weights: ptsW, 0.99)
        let midU: Float = (u0 + u1) / 2, midV: Float = (v0 + v1) / 2
        let c2: SIMD2<Float> = u * midU + v * midV
        let extU = max(0.05, u1 - u0), extV = max(0.05, v1 - v0)

        // Functional surface: mode of up-facing area height.
        var surface: Float?
        let upIdx = f.filter { faces.normal[$0].y > 0.85 }
        let upArea = upIdx.reduce(Float(0)) { $0 + faces.area[$1] }
        if upArea > 0.02 {
            let h = Stats.histogram(upIdx.map { faces.centroid[$0].y - y0 }, weights: upIdx.map { faces.area[$0] }, bin: 0.02, smooth: 1)
            if let pk = h.mass.indices.max(by: { h.mass[$0] < h.mass[$1] }) {
                surface = min(y1 - y0, max(0.02, h.lo + (Float(pk) + 0.5) * 0.02))
            }
        }

        // Front direction among the four box axes.
        let candidates: [SIMD2<Float>] = [u, -u, v, -v]
        var front: SIMD2<Float>
        var wallID: String?
        let nearest: (WallSegment, Float)? = walls.map { w -> (WallSegment, Float) in
            (w, Polygon2D.segmentDistance(c2, w.start, w.end).dist)
        }.min { $0.1 < $1.1 }
        let halfMin = min(extU, extV) / 2
        if let s = surface, y1 - y0 - s > 0.15, let back = backrestDirection(f, faces: faces, floor: y0, seat: s, center: c2) {
            front = best(candidates, along: -back)
        } else if let (wall, dist) = nearest, dist - halfMin < 0.35 {
            front = best(candidates, along: wall.normal)
            wallID = wall.id
        } else {
            let toCenter = roomCenter - c2
            front = best(candidates, along: simd_length(toCenter) > 1e-3 ? simd_normalize(toCenter) : u)
        }
        if wallID == nil, let (wall, dist) = nearest, dist - halfMin < 0.35 { wallID = wall.id }
        let alongU = abs(simd_dot(front, u)) > 0.5
        let depth = alongU ? extU : extV, width = alongU ? extV : extU
        let box = FittedBox(center: SIMD3(c2.x, (y0 + y1) / 2, c2.y), size: SIMD3(width, y1 - y0, depth), yaw: Yaw.facing(front))
        return Fit(box: box, surfaceHeight: surface, wallID: wallID)
    }

    private func best(_ c: [SIMD2<Float>], along d: SIMD2<Float>) -> SIMD2<Float> {
        c.max { simd_dot($0, d) < simd_dot($1, d) }!
    }

    /// Direction from the box center to the area-weighted centroid of faces well above the seat.
    private func backrestDirection(_ f: [Int], faces: FaceSet, floor: Float, seat: Float, center: SIMD2<Float>) -> SIMD2<Float>? {
        var acc = SIMD2<Float>.zero, wsum: Float = 0
        for i in f where faces.centroid[i].y - floor > seat + 0.12 {
            acc += SIMD2(faces.centroid[i].x, faces.centroid[i].z) * faces.area[i]; wsum += faces.area[i]
        }
        guard wsum > 0.03 else { return nil }
        let d = acc / wsum - center
        return simd_length(d) > 0.05 ? simd_normalize(d) : nil
    }
}
