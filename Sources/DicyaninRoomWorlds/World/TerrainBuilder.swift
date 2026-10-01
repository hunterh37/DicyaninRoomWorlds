import Foundation
import simd

/// Low-poly ground that replaces the floor and rolls up into hills past the walls.
///
///     h(p) = bump * (2 * fbm(p) - 1)                                  inside the room
///     h(p) = rim * smoothstep(0, apron, d(p)) * (0.6 + 0.4 * fbm(p))  outside, d = distance past the outline
///
/// Walkable floor stays within `bump` of the real floor so players never trip over virtual ground.
struct TerrainBuilder {
    var style: TerrainStyle
    var seed: UInt64

    func build(room: RoomModel) -> MeshData {
        var mesh = MeshData()
        let outline = room.outline
        guard outline.count >= 3 else { return mesh }
        let yaw = room.manhattanYaw
        let g = outline.map { Yaw.rotate($0, -yaw) }
        let lo = g.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) } - style.apron
        let hi = g.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) } + style.apron
        let step = max(0.1, style.cell)
        let nx = Int(((hi.x - lo.x) / step).rounded(.up)), nz = Int(((hi.y - lo.y) / step).rounded(.up))
        let s32 = UInt32(truncatingIfNeeded: seed)

        func outsideDistance(_ p: SIMD2<Float>) -> Float {
            if Polygon2D.contains(outline, p) { return 0 }
            var d = Float.infinity
            for i in outline.indices { d = min(d, Polygon2D.segmentDistance(p, outline[i], outline[(i + 1) % outline.count]).dist) }
            return d
        }

        var verts = [SIMD3<Float>](repeating: .zero, count: (nx + 1) * (nz + 1))
        var keep = [Bool](repeating: false, count: verts.count)
        for j in 0...nz {
            for i in 0...nx {
                // Offset alternate rows for a triangulated, less grid-like look.
                let q = lo + SIMD2(Float(i) + (j % 2 == 0 ? 0 : 0.5), Float(j)) * step
                let p = Yaw.rotate(q, yaw)
                let d = outsideDistance(p)
                let n = Noise.fbm(SIMD3(p.x, 0, p.y) * 1.7, octaves: 3, seed: s32)
                var h: Float
                if d <= 0 {
                    h = style.bump * (2 * n - 1)
                } else {
                    let t = simd_clamp(d / max(style.apron, 1e-3), 0, 1)
                    h = style.rimHeight * t * t * (3 - 2 * t) * (0.6 + 0.4 * n) + style.bump * (2 * n - 1)
                }
                verts[j * (nx + 1) + i] = SIMD3(p.x, room.floorY + h, p.y)
                keep[j * (nx + 1) + i] = d <= style.apron
            }
        }
        for j in 0..<nz {
            for i in 0..<nx {
                let a = j * (nx + 1) + i, b = a + 1, c = a + nx + 1, d = c + 1
                let tris = j % 2 == 0 ? [[a, b, c], [b, d, c]] : [[a, b, d], [a, d, c]]
                for t in tris where t.contains(where: { keep[$0] }) {
                    let v = t.map { verts[$0] }
                    let cen = (v[0] + v[1] + v[2]) / 3
                    let patch = Noise.fbm(cen / max(style.patchScale, 0.05), octaves: 2, seed: s32 &+ 77)
                    let role: MaterialRole = patch < style.patchCoverage ? .groundAlt : .ground
                    mesh.addPolygon(v, role: role, outward: SIMD3(0, 1, 0))
                }
            }
        }
        return mesh
    }
}
