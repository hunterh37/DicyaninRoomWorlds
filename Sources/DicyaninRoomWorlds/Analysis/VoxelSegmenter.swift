import Foundation
import simd

/// Connected-component segmentation of labeled faces on a sparse voxel hash.
///
/// ARKit splits the room into independent mesh chunks that share no vertices, so mesh
/// adjacency cannot be trusted across chunk seams. Voxel adjacency can: two faces of the
/// same label are connected when their voxels touch (26-neighbourhood). Union-find with
/// path halving makes this near-linear in face count.
struct VoxelSegmenter {
    struct Segment: Sendable {
        var label: SurfaceLabel
        var faces: [Int]
        var area: Float
        var lo: SIMD3<Float>
        var hi: SIMD3<Float>
    }

    var voxelSize: Float

    private struct Key: Hashable { var x: Int32, y: Int32, z: Int32 }

    /// Segments `candidates` (face indices) grouped by label.
    func segment(_ faces: FaceSet, candidates: [Int]) -> [Segment] {
        var byLabel: [SurfaceLabel: [Int]] = [:]
        for i in candidates { byLabel[faces.label[i], default: []].append(i) }
        var out: [Segment] = []
        for (label, list) in byLabel { out += components(faces, list, label) }
        return out
    }

    private func components(_ faces: FaceSet, _ list: [Int], _ label: SurfaceLabel) -> [Segment] {
        var voxelOf: [Key: Int] = [:]
        var members: [[Int]] = []
        for f in list {
            let p = faces.centroid[f] / voxelSize
            let k = Key(x: Int32(p.x.rounded(.down)), y: Int32(p.y.rounded(.down)), z: Int32(p.z.rounded(.down)))
            if let v = voxelOf[k] { members[v].append(f) } else { voxelOf[k] = members.count; members.append([f]) }
        }
        var parent = Array(0..<members.count)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        for (k, v) in voxelOf {
            for dz: Int32 in -1...1 { for dy: Int32 in -1...1 { for dx: Int32 in -1...1 where dx != 0 || dy != 0 || dz != 0 {
                guard let u = voxelOf[Key(x: k.x + dx, y: k.y + dy, z: k.z + dz)] else { continue }
                let a = find(u), b = find(v)
                if a != b { parent[a] = b }
            } } }
        }
        var groups: [Int: [Int]] = [:]
        for v in members.indices { groups[find(v), default: []].append(contentsOf: members[v]) }
        return groups.values.map { fs in
            var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity), area: Float = 0
            for f in fs { lo = simd_min(lo, faces.centroid[f]); hi = simd_max(hi, faces.centroid[f]); area += faces.area[f] }
            return Segment(label: label, faces: fs, area: area, lo: lo, hi: hi)
        }
    }

    /// Merges fragments that belong to one physical object:
    /// unlabeled clutter that overlaps a labeled object in plan view joins it (sofa backrests,
    /// table legs), and same-label fragments with overlapping footprints fuse.
    static func merge(_ segs: [Segment], overlap: Float = 0.35, verticalGap: Float = 0.2) -> [Segment] {
        var s = segs.sorted { $0.area > $1.area }
        func footprintOverlap(_ a: Segment, _ b: Segment) -> Float {
            let ix = max(0, min(a.hi.x, b.hi.x) - max(a.lo.x, b.lo.x)), iz = max(0, min(a.hi.z, b.hi.z) - max(a.lo.z, b.lo.z))
            let aa = max(1e-4, (a.hi.x - a.lo.x) * (a.hi.z - a.lo.z)), ab = max(1e-4, (b.hi.x - b.lo.x) * (b.hi.z - b.lo.z))
            return ix * iz / min(aa, ab)
        }
        func gapY(_ a: Segment, _ b: Segment) -> Float { max(0, max(a.lo.y, b.lo.y) - min(a.hi.y, b.hi.y)) }
        var changed = true
        while changed {
            changed = false
            outer: for i in s.indices {
                for j in s.indices where j > i {
                    let a = s[i], b = s[j]
                    let compatible = a.label == b.label || a.label == .none || b.label == .none
                    guard compatible, gapY(a, b) <= verticalGap, footprintOverlap(a, b) >= overlap else { continue }
                    let keepLabel = a.label == .none ? b.label : a.label
                    s[i] = Segment(label: keepLabel, faces: a.faces + b.faces, area: a.area + b.area,
                                   lo: simd_min(a.lo, b.lo), hi: simd_max(a.hi, b.hi))
                    s.remove(at: j)
                    changed = true
                    break outer
                }
            }
        }
        return s
    }
}
