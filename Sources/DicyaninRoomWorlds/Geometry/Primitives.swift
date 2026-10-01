import Foundation
import simd

/// Low-poly primitive shapes, authored in the unit cube [-0.5, 0.5]^3 and mapped into a part box.
public enum PrimitiveShape: Codable, Sendable, Hashable {
    case box
    /// Prism with `segments` sides along `axis`. `taper` scales the far cap (0 makes a cone).
    case cylinder(segments: Int, taper: Float, axis: Axis)
    /// UV sphere with `segments` around and `segments / 2` rings.
    case sphere(segments: Int)
    /// Upper hemisphere.
    case dome(segments: Int)
    /// Ramp rising toward -Z (back). Full height at the back, zero at the front.
    case wedge
    /// Jittered sphere. `roughness` 0...0.5 is vertex displacement as a fraction of size.
    case rock(segments: Int, roughness: Float)

    public enum Axis: String, Codable, Sendable, Hashable { case x, y, z }

    public static func cyl(_ seg: Int = 8, taper: Float = 1, axis: Axis = .y) -> PrimitiveShape {
        .cylinder(segments: seg, taper: taper, axis: axis)
    }
}

enum PrimitiveBuilder {
    typealias Face = [SIMD3<Float>]

    static func unitFaces(_ shape: PrimitiveShape) -> [Face] {
        switch shape {
        case .box: return box()
        case let .cylinder(seg, taper, axis): return cylinder(max(3, seg), taper, axis)
        case let .sphere(seg): return sphere(max(4, seg), hemisphere: false)
        case let .dome(seg): return sphere(max(4, seg), hemisphere: true)
        case .wedge: return wedge()
        case let .rock(seg, _): return sphere(max(4, seg), hemisphere: false)
        }
    }

    static func box() -> [Face] {
        func p(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { SIMD3(x, y, z) * 0.5 }
        return [
            [p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1)],
            [p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1)],
            [p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1)],
            [p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1)],
            [p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1)],
            [p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1)],
        ]
    }

    static func cylinder(_ seg: Int, _ taper: Float, _ axis: PrimitiveShape.Axis) -> [Face] {
        func ring(_ y: Float, _ r: Float) -> [SIMD3<Float>] {
            (0..<seg).map { i in
                let a = (Float(i) + 0.5) / Float(seg) * 2 * .pi
                return SIMD3(cos(a) * r, y, sin(a) * r)
            }
        }
        let bottom = ring(-0.5, 0.5), top = ring(0.5, 0.5 * taper)
        var faces: [Face] = []
        for i in 0..<seg {
            let j = (i + 1) % seg
            faces.append(taper < 0.01 ? [bottom[i], bottom[j], SIMD3(0, 0.5, 0)] : [bottom[i], bottom[j], top[j], top[i]])
        }
        faces.append(bottom)
        if taper >= 0.01 { faces.append(top) }
        switch axis {
        case .y: return faces
        case .x: return faces.map { $0.map { SIMD3($0.y, $0.x, $0.z) } }
        case .z: return faces.map { $0.map { SIMD3($0.x, $0.z, $0.y) } }
        }
    }

    static func sphere(_ seg: Int, hemisphere: Bool) -> [Face] {
        let rings = max(2, seg / 2)
        let jEnd = hemisphere ? max(1, rings / 2) : rings
        func pt(_ i: Int, _ j: Int) -> SIMD3<Float> {
            let th = Float(j) / Float(rings) * .pi, ph = Float(i % seg) / Float(seg) * 2 * .pi
            var p = SIMD3(0.5 * sin(th) * cos(ph), 0.5 * cos(th), 0.5 * sin(th) * sin(ph))
            if hemisphere { p.y = p.y * 2 - 0.5 }
            return p
        }
        var faces: [Face] = []
        for j in 0..<jEnd {
            for i in 0..<seg {
                let a = pt(i, j), b = pt(i + 1, j), c = pt(i + 1, j + 1), d = pt(i, j + 1)
                if j == 0 { faces.append([a, c, d]) } else if j == rings - 1 { faces.append([a, b, c]) } else { faces.append([a, b, c, d]) }
            }
        }
        if hemisphere { faces.append((0..<seg).map { pt(seg - $0, jEnd) }) }
        return faces
    }

    static func wedge() -> [Face] {
        let A = SIMD3<Float>(-0.5, -0.5, 0.5), B = SIMD3<Float>(0.5, -0.5, 0.5)
        let C = SIMD3<Float>(0.5, -0.5, -0.5), D = SIMD3<Float>(-0.5, -0.5, -0.5)
        let E = SIMD3<Float>(-0.5, 0.5, -0.5), F = SIMD3<Float>(0.5, 0.5, -0.5)
        return [[A, B, C, D], [D, C, F, E], [A, B, F, E], [B, C, F], [A, D, E]]
    }

    /// Emits `shape` into `mesh`, filling the box [lo, hi] (part-local meters), rotated by
    /// `rotation` (degrees XYZ) about the box center. `seed` drives rock jitter.
    static func emit(_ shape: PrimitiveShape, lo: SIMD3<Float>, hi: SIMD3<Float>, rotation: SIMD3<Float>?,
                     role: MaterialRole, seed: UInt32, into mesh: inout MeshData) {
        let size = simd_max(hi - lo, SIMD3(repeating: 1e-4))
        let center = (lo + hi) / 2
        let R = rotation.map(rotationMatrix)
        var roughness: Float = 0
        if case let .rock(_, r) = shape { roughness = simd_clamp(r, 0, 0.5) }
        let faces = unitFaces(shape)
        for face in faces {
            var faceCenter = SIMD3<Float>.zero
            let verts = face.map { u -> SIMD3<Float> in
                var q = u
                if roughness > 0 {
                    let k = u * 3.1 + SIMD3(repeating: Float(seed % 997) * 0.37)
                    let d = (Noise.value(k, seed: seed) - 0.5) * 2 * roughness
                    q = u * (1 + d)
                    q.y = max(q.y, -0.5)
                }
                q *= size
                if let R { q = R * q }
                return q + center
            }
            for v in verts { faceCenter += v }
            faceCenter /= Float(verts.count)
            mesh.addPolygon(verts, role: role, outward: faceCenter - center)
        }
    }

    static func rotationMatrix(_ deg: SIMD3<Float>) -> simd_float3x3 {
        let r = deg * (.pi / 180)
        let X = simd_float3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, cos(r.x), -sin(r.x)), SIMD3(0, sin(r.x), cos(r.x))])
        let Y = simd_float3x3(rows: [SIMD3(cos(r.y), 0, sin(r.y)), SIMD3(0, 1, 0), SIMD3(-sin(r.y), 0, cos(r.y))])
        let Z = simd_float3x3(rows: [SIMD3(cos(r.z), -sin(r.z), 0), SIMD3(sin(r.z), cos(r.z), 0), SIMD3(0, 0, 1)])
        return Z * Y * X
    }
}
