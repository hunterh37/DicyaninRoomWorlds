import Foundation
import simd

/// Deterministic 64-bit generator (SplitMix64). Same seed, same world, on every device.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }

    /// Uniform in [lo, hi).
    public mutating func range(_ lo: Float, _ hi: Float) -> Float { lo + (hi - lo) * unit() }

    /// Uniform signed in [-a, a).
    public mutating func jitter(_ a: Float) -> Float { (unit() * 2 - 1) * a }

    /// Derives an independent stream for a sub-task (stable under reordering of other tasks).
    public static func derive(_ seed: UInt64, _ salt: String) -> SeededRandom {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in salt.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01B3 }
        return SeededRandom(seed: seed ^ h)
    }
}

/// Hash-based value noise. Pure function of position and seed.
public enum Noise {
    @inlinable static func hash(_ x: Int32, _ y: Int32, _ z: Int32, _ seed: UInt32) -> Float {
        var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841 ^ UInt32(bitPattern: z) &* 0xCB1A_B31F ^ seed &* 0x1656_67B1
        h = (h ^ (h >> 13)) &* 0x5BD1_E995
        h ^= h >> 15
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    /// Trilinear value noise in [0, 1].
    public static func value(_ p: SIMD3<Float>, seed: UInt32 = 0) -> Float {
        let f = p.rounded(.down)
        let t = p - f
        let s = t * t * (3 - 2 * t)
        let x = Int32(f.x), y = Int32(f.y), z = Int32(f.z)
        func h(_ dx: Int32, _ dy: Int32, _ dz: Int32) -> Float { hash(x + dx, y + dy, z + dz, seed) }
        let x00 = simd_mix(h(0, 0, 0), h(1, 0, 0), s.x), x10 = simd_mix(h(0, 1, 0), h(1, 1, 0), s.x)
        let x01 = simd_mix(h(0, 0, 1), h(1, 0, 1), s.x), x11 = simd_mix(h(0, 1, 1), h(1, 1, 1), s.x)
        return simd_mix(simd_mix(x00, x10, s.y), simd_mix(x01, x11, s.y), s.z)
    }

    /// Fractal sum of `octaves` value-noise layers, normalized to [0, 1].
    public static func fbm(_ p: SIMD3<Float>, octaves: Int = 3, seed: UInt32 = 0) -> Float {
        var sum: Float = 0, amp: Float = 0.5, norm: Float = 0, q = p
        for o in 0..<max(1, octaves) {
            sum += amp * value(q, seed: seed &+ UInt32(o) &* 101)
            norm += amp
            amp *= 0.5
            q *= 2.03
        }
        return sum / norm
    }
}
