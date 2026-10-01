import Foundation
import simd

/// Material role. Themes map each role to a concrete material, so one blueprint renders
/// as oak in a cottage and as chrome in a neon city.
public enum MaterialRole: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable, Hashable {
    case primary, secondary, accent, trim, soft, metal, glass, glow
    case stone, wood, foliage, foliageAlt, bark, ground, groundAlt, water, snow, crystal
}

/// Flat-shaded triangle buffers grouped by material role. Pure Swift; RealityKit
/// conversion lives in `WorldEntityBuilder`.
public struct MeshData: Sendable {
    public struct Group: Sendable {
        public var positions: [SIMD3<Float>] = []
        public var normals: [SIMD3<Float>] = []
        public var indices: [UInt32] = []
        public init() {}
        public var triangleCount: Int { indices.count / 3 }
    }

    public var groups: [MaterialRole: Group] = [:]

    public init() {}

    public var triangleCount: Int { groups.values.reduce(0) { $0 + $1.triangleCount } }
    public var isEmpty: Bool { groups.values.allSatisfy { $0.indices.isEmpty } }

    /// Appends a planar convex polygon with a flat normal facing `outward` when given.
    public mutating func addPolygon(_ verts: [SIMD3<Float>], role: MaterialRole, outward: SIMD3<Float>? = nil) {
        guard verts.count >= 3 else { return }
        var v = verts
        var n = simd_cross(v[1] - v[0], v[2] - v[0])
        if verts.count > 3 {
            // Newell normal for robustness on slightly non-planar quads.
            n = .zero
            for i in v.indices {
                let a = v[i], b = v[(i + 1) % v.count]
                n += SIMD3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
            }
        }
        let len = simd_length(n)
        guard len > 1e-12 else { return }
        n /= len
        if let outward, simd_dot(n, outward) < 0 { v.reverse(); n = -n }
        var g = groups[role] ?? Group()
        let base = UInt32(g.positions.count)
        g.positions.append(contentsOf: v)
        g.normals.append(contentsOf: repeatElement(n, count: v.count))
        for k in 1..<(v.count - 1) { g.indices.append(contentsOf: [base, base + UInt32(k), base + UInt32(k + 1)]) }
        groups[role] = g
    }

    /// Appends another mesh transformed by `transform`.
    public mutating func append(_ other: MeshData, transform: simd_float4x4 = matrix_identity_float4x4) {
        let normalMatrix = simd_float3x3(SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                                         SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                                         SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)).inverse.transpose
        for (role, src) in other.groups {
            var g = groups[role] ?? Group()
            let base = UInt32(g.positions.count)
            g.positions.append(contentsOf: src.positions.map { p in
                let q = transform * SIMD4(p, 1); return SIMD3(q.x, q.y, q.z)
            })
            g.normals.append(contentsOf: src.normals.map { simd_normalize(normalMatrix * $0) })
            g.indices.append(contentsOf: src.indices.map { $0 + base })
            groups[role] = g
        }
    }

    /// Axis-aligned bounds of all vertices.
    public var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)? {
        var lo = SIMD3<Float>(repeating: .infinity), hi = SIMD3<Float>(repeating: -.infinity)
        var any = false
        for g in groups.values { for p in g.positions { lo = simd_min(lo, p); hi = simd_max(hi, p); any = true } }
        return any ? (lo, hi) : nil
    }
}

/// Builds a local -> world transform from a floor-contact position, yaw and scale.
public func placementMatrix(position: SIMD3<Float>, yaw: Float, scale: SIMD3<Float> = .one) -> simd_float4x4 {
    let c = cos(yaw), s = sin(yaw)
    return simd_float4x4(SIMD4(c * scale.x, 0, -s * scale.x, 0),
                         SIMD4(0, scale.y, 0, 0),
                         SIMD4(s * scale.z, 0, c * scale.z, 0),
                         SIMD4(position, 1))
}
