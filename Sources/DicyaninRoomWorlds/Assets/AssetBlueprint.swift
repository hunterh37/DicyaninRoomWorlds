import Foundation
import simd

/// One edge of a part along one axis, as an affine function of the measured box:
///
///     value = base(anchor) + fraction * extent + offset
///
/// `base` is the box minimum, maximum, center, or (on Y) the measured functional surface.
/// Because every bound is affine in the measured size, a blueprint fits any scanned box
/// exactly while legs, frames and slabs keep their real-world thickness (3D nine-slice).
public struct Bound: Codable, Sendable, Hashable {
    public enum Anchor: String, Codable, Sendable { case min, max, center, surface }
    public var anchor: Anchor
    public var fraction: Float
    public var offset: Float

    public init(_ anchor: Anchor, fraction: Float = 0, offset: Float = 0) {
        self.anchor = anchor; self.fraction = fraction; self.offset = offset
    }

    /// Box minimum plus `m` meters.
    public static func lo(_ m: Float = 0) -> Bound { Bound(.min, offset: m) }
    /// Box maximum minus `m` meters.
    public static func hi(_ m: Float = 0) -> Bound { Bound(.max, offset: -m) }
    /// Fraction `f` of the extent from the minimum, plus `m` meters.
    public static func f(_ f: Float, _ m: Float = 0) -> Bound { Bound(.min, fraction: f, offset: m) }
    /// Box center plus `m` meters.
    public static func mid(_ m: Float = 0) -> Bound { Bound(.center, offset: m) }
    /// Functional surface plus `m` meters (Y only; center on X and Z).
    public static func surf(_ m: Float = 0) -> Bound { Bound(.surface, offset: m) }

    func resolve(lo: Float, hi: Float, surface: Float) -> Float {
        let base: Float
        switch anchor {
        case .min: base = lo
        case .max: base = hi
        case .center: base = (lo + hi) / 2
        case .surface: base = surface
        }
        return base + fraction * (hi - lo) + offset
    }
}

public struct Span: Codable, Sendable, Hashable {
    public var lo: Bound
    public var hi: Bound
    public init(_ lo: Bound, _ hi: Bound) { self.lo = lo; self.hi = hi }

    public static let full = Span(.lo(), .hi())
    public static func inset(_ m: Float) -> Span { Span(.lo(m), .hi(m)) }
    /// Centered span of fixed width `w` meters.
    public static func centered(_ w: Float, _ shift: Float = 0) -> Span { Span(.mid(shift - w / 2), .mid(shift + w / 2)) }
    /// Centered span covering fraction `f` of the extent.
    public static func centeredFraction(_ f: Float) -> Span { Span(.f(0.5 - f / 2), .f(0.5 + f / 2)) }
    /// Span from the minimum of fixed width `w`, after `inset`.
    public static func fromLo(_ w: Float, inset: Float = 0) -> Span { Span(.lo(inset), .lo(inset + w)) }
    /// Span ending at the maximum of fixed width `w`, before `inset`.
    public static func fromHi(_ w: Float, inset: Float = 0) -> Span { Span(.hi(inset + w), .hi(inset)) }
    /// Fractional span.
    public static func frac(_ a: Float, _ b: Float) -> Span { Span(.f(a), .f(b)) }
}

/// Count-adaptive repetition: a part tiles its span along `axis` into n = round(extent / pitch)
/// cells (clamped to 1...maxCount). Within each cell the part covers fractions `from...to`,
/// shrunk by `gap` meters. Shelves use from 0 to 0.08; cushions use the full cell with a gap.
public struct RepeatRule: Codable, Sendable, Hashable {
    public var axis: PrimitiveShape.Axis
    public var pitch: Float
    public var gap: Float
    public var from: Float
    public var to: Float
    public var maxCount: Int
    public init(_ axis: PrimitiveShape.Axis, pitch: Float, gap: Float = 0.02, from: Float = 0, to: Float = 1, maxCount: Int = 12) {
        self.axis = axis; self.pitch = pitch; self.gap = gap; self.from = from; self.to = to; self.maxCount = maxCount
    }
}

/// Size-dependent part visibility.
public enum PartCondition: Codable, Sendable, Hashable {
    /// Part appears when height minus surface exceeds `m` (backrests, headboards).
    case aboveSurface(Float)
    case minWidth(Float)
    case minDepth(Float)
    case minHeight(Float)
    case maxHeight(Float)
}

public struct PartSpec: Codable, Sendable, Hashable {
    public var shape: PrimitiveShape
    public var role: MaterialRole
    public var x: Span
    public var y: Span
    public var z: Span
    /// Degrees XYZ about the part center.
    public var rotation: SIMD3<Float>?
    public var mirrorX: Bool
    public var mirrorZ: Bool
    public var repeatRule: RepeatRule?
    public var conditions: [PartCondition]

    public init(_ shape: PrimitiveShape, _ role: MaterialRole, x: Span = .full, y: Span = .full, z: Span = .full,
                rotation: SIMD3<Float>? = nil, mirrorX: Bool = false, mirrorZ: Bool = false,
                repeating: RepeatRule? = nil, when conditions: [PartCondition] = []) {
        self.shape = shape; self.role = role; self.x = x; self.y = y; self.z = z; self.rotation = rotation
        self.mirrorX = mirrorX; self.mirrorZ = mirrorZ; self.repeatRule = repeating; self.conditions = conditions
    }
}

/// A parametric, scan-fittable low-poly asset. Local frame: origin at bottom center,
/// x in [-w/2, w/2], y in [0, h], z in [-d/2, d/2], front is +Z.
public struct AssetBlueprint: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var tags: [String]
    public var parts: [PartSpec]
    /// Size used for decor and previews when no measurement exists.
    public var defaultSize: SIMD3<Float>
    /// Surface height as a fraction of height when no measurement exists.
    public var defaultSurfaceFraction: Float
    /// Uniform random size range for scattered decor, as a multiplier of `defaultSize`.
    public var scaleRange: ClosedRange<Float>

    public init(_ id: String, name: String? = nil, tags: [String] = [], size: SIMD3<Float>, surface: Float = 1,
                scale: ClosedRange<Float> = 1...1, parts: [PartSpec]) {
        self.id = id
        self.name = name ?? id
        self.tags = tags
        self.parts = parts
        self.defaultSize = size
        self.defaultSurfaceFraction = surface
        self.scaleRange = scale
    }

    /// Builds the mesh fitted to `size`, with the functional surface at `surface` meters
    /// above the bottom (nil uses the default fraction). Deterministic in `seed`.
    public func mesh(size: SIMD3<Float>? = nil, surface: Float? = nil, seed: UInt64 = 0) -> MeshData {
        let s = simd_max(size ?? defaultSize, SIMD3(repeating: 0.01))
        let surf = simd_clamp(surface ?? s.y * defaultSurfaceFraction, 0, s.y)
        let lo = SIMD3(-s.x / 2, 0, -s.z / 2), hi = SIMD3(s.x / 2, s.y, s.z / 2)
        var mesh = MeshData()
        for (pi, part) in parts.enumerated() {
            guard part.conditions.allSatisfy({ passes($0, size: s, surface: surf) }) else { continue }
            let mid = (lo + hi) / 2
            var plo = SIMD3(part.x.lo.resolve(lo: lo.x, hi: hi.x, surface: mid.x),
                            part.y.lo.resolve(lo: lo.y, hi: hi.y, surface: surf),
                            part.z.lo.resolve(lo: lo.z, hi: hi.z, surface: mid.z))
            var phi = SIMD3(part.x.hi.resolve(lo: lo.x, hi: hi.x, surface: mid.x),
                            part.y.hi.resolve(lo: lo.y, hi: hi.y, surface: surf),
                            part.z.hi.resolve(lo: lo.z, hi: hi.z, surface: mid.z))
            plo = simd_max(plo, lo - 0.5 * s); phi = simd_min(phi, hi + 0.5 * s)
            guard phi.x - plo.x > 0.003, phi.y - plo.y > 0.003, phi.z - plo.z > 0.003 else { continue }
            var boxes = [(plo, phi)]
            if let rep = part.repeatRule { boxes = tile(plo, phi, rep) }
            if part.mirrorX { boxes += boxes.map { b in (SIMD3(-b.1.x, b.0.y, b.0.z), SIMD3(-b.0.x, b.1.y, b.1.z)) } }
            if part.mirrorZ { boxes += boxes.map { b in (SIMD3(b.0.x, b.0.y, -b.1.z), SIMD3(b.1.x, b.1.y, -b.0.z)) } }
            for (k, b) in boxes.enumerated() {
                let partSeed = UInt32(truncatingIfNeeded: seed &* 0x9E37_79B9 &+ UInt64(pi * 131 + k))
                PrimitiveBuilder.emit(part.shape, lo: b.0, hi: b.1, rotation: part.rotation, role: part.role, seed: partSeed, into: &mesh)
            }
        }
        return mesh
    }

    private func passes(_ c: PartCondition, size s: SIMD3<Float>, surface: Float) -> Bool {
        switch c {
        case let .aboveSurface(m): return s.y - surface > m
        case let .minWidth(m): return s.x >= m
        case let .minDepth(m): return s.z >= m
        case let .minHeight(m): return s.y >= m
        case let .maxHeight(m): return s.y <= m
        }
    }

    private func tile(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>, _ r: RepeatRule) -> [(SIMD3<Float>, SIMD3<Float>)] {
        let k: Int = r.axis == .x ? 0 : r.axis == .y ? 1 : 2
        let ext = hi[k] - lo[k]
        let n = max(1, min(r.maxCount, Int((ext / r.pitch).rounded())))
        let cell = ext / Float(n)
        return (0..<n).compactMap { i in
            var a = lo, b = hi
            let c0 = lo[k] + Float(i) * cell
            a[k] = c0 + r.from * cell + r.gap / 2
            b[k] = c0 + r.to * cell - r.gap / 2
            return b[k] - a[k] > 0.003 ? (a, b) : nil
        }
    }
}
