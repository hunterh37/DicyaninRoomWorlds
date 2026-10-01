import Foundation
import simd

/// Structure-of-arrays view of every scanned triangle: centroid, unit normal, area, label.
/// Built once per analysis; all later stages index into it.
struct FaceSet: Sendable {
    var centroid: [SIMD3<Float>] = []
    var normal: [SIMD3<Float>] = []
    var area: [Float] = []
    var label: [SurfaceLabel] = []
    /// Up to three vertices per face, kept for footprint hulls of objects.
    var verts: [SIMD3<Float>] = []

    var count: Int { area.count }

    init(scan: RoomScan, minArea: Float = 1e-6) {
        let n = scan.faceCount
        centroid.reserveCapacity(n); normal.reserveCapacity(n); area.reserveCapacity(n); label.reserveCapacity(n)
        verts.reserveCapacity(n * 3)
        for m in scan.meshes {
            let P = m.positions, I = m.indices
            for f in 0..<m.faceCount {
                let ia = Int(I[f * 3]), ib = Int(I[f * 3 + 1]), ic = Int(I[f * 3 + 2])
                guard ia < P.count, ib < P.count, ic < P.count else { continue }
                let a = P[ia], b = P[ib], c = P[ic]
                let cr = simd_cross(b - a, c - a)
                let len = simd_length(cr)
                let ar = 0.5 * len
                guard ar > minArea, ar.isFinite else { continue }
                centroid.append((a + b + c) / 3)
                normal.append(cr / len)
                area.append(ar)
                label.append(m.label(ofFace: f))
                verts.append(contentsOf: [a, b, c])
            }
        }
    }

    func indices(where predicate: (Int) -> Bool) -> [Int] { (0..<count).filter(predicate) }
}

/// Gravity-aligned room frame: floor, ceiling and the dominant wall direction.
struct RoomFrame: Sendable {
    var floorY: Float
    var ceilingY: Float
    var manhattanYaw: Float
    var manhattanConfidence: Float

    static func estimate(_ faces: FaceSet, planes: [ScanPlane]) -> RoomFrame {
        // Floor: area-weighted median height of up-facing floor faces. Fallback: lowest strong
        // mode of all up-facing faces (labels missing on some devices or early in a scan).
        let up = faces.indices { faces.normal[$0].y > 0.85 }
        let floorFaces = up.filter { faces.label[$0] == .floor }
        var floorY: Float
        if floorFaces.reduce(Float(0), { $0 + faces.area[$1] }) > 0.2 {
            floorY = Stats.percentile(floorFaces.map { faces.centroid[$0].y }, weights: floorFaces.map { faces.area[$0] }, 0.5)
        } else if let p = planes.filter({ $0.label == .floor }).max(by: { $0.width * $0.height < $1.width * $1.height }) {
            floorY = p.center.y
        } else if !up.isEmpty {
            let ys = up.map { faces.centroid[$0].y }, ws = up.map { faces.area[$0] }
            let h = Stats.histogram(ys, weights: ws, bin: 0.03, smooth: 1)
            let peak = h.mass.max() ?? 0
            let i = h.mass.firstIndex { $0 >= 0.35 * peak } ?? 0
            floorY = h.lo + (Float(i) + 0.5) * 0.03
        } else {
            floorY = (faces.centroid.map(\.y).min() ?? 0)
        }

        let down = faces.indices { faces.normal[$0].y < -0.85 && faces.label[$0] == .ceiling }
        var ceilingY: Float
        if down.reduce(Float(0), { $0 + faces.area[$1] }) > 0.2 {
            ceilingY = Stats.percentile(down.map { faces.centroid[$0].y }, weights: down.map { faces.area[$0] }, 0.5)
        } else {
            let wallTop = faces.indices { faces.label[$0] == .wall }.map { faces.centroid[$0].y }
            ceilingY = max(floorY + 2.2, Stats.percentile(wallTop, 0.98) + 0.05)
            if wallTop.isEmpty { ceilingY = floorY + 2.5 }
        }

        // Manhattan yaw: angle quadrupling maps the four wall directions onto one, so the
        // area-weighted circular mean of 4*theta recovers the room's dominant axis.
        var C: Float = 0, S: Float = 0, W: Float = 0
        for i in 0..<faces.count where abs(faces.normal[i].y) < 0.3 && (faces.label[i] == .wall || faces.label[i].isOpening) {
            let n = faces.normal[i]
            let h = simd_length(SIMD2(n.x, n.z))
            guard h > 0.5 else { continue }
            let th = atan2(n.x, n.z)
            let w = faces.area[i] * h
            C += w * cos(4 * th); S += w * sin(4 * th); W += w
        }
        for p in planes where p.label == .wall {
            let th = atan2(p.normal.x, p.normal.z), w = p.width * p.height * 0.25
            C += w * cos(4 * th); S += w * sin(4 * th); W += w
        }
        let yaw = W > 0 ? atan2(S, C) / 4 : 0
        let conf = W > 0 ? simd_length(SIMD2(C, S)) / W : 0
        return RoomFrame(floorY: floorY, ceilingY: ceilingY, manhattanYaw: yaw, manhattanConfidence: conf)
    }
}
