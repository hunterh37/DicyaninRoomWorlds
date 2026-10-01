import Foundation
import simd

/// Yaw convention shared with StyleRoom: rotation about +Y that maps local +Z (object front)
/// to world (sin yaw, 0, cos yaw).
public enum Yaw {
    /// Rotates an XZ vector (x, z) by `yaw`.
    @inlinable public static func rotate(_ p: SIMD2<Float>, _ yaw: Float) -> SIMD2<Float> {
        let c = cos(yaw), s = sin(yaw)
        return SIMD2(c * p.x + s * p.y, -s * p.x + c * p.y)
    }

    /// Yaw whose local +Z points along the XZ direction `dir`.
    @inlinable public static func facing(_ dir: SIMD2<Float>) -> Float { atan2(dir.x, dir.y) }

    /// Wraps an angle into (-pi, pi].
    @inlinable public static func wrap(_ a: Float) -> Float {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x <= -.pi { x += 2 * .pi } else if x > .pi { x -= 2 * .pi }
        return x
    }

    public static func quaternion(_ yaw: Float) -> simd_quatf { simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)) }
}

/// Weighted 1D statistics used throughout the analyzer.
public enum Stats {
    /// Weighted percentile `q` in [0, 1] of `values`. Returns 0 for empty input.
    public static func percentile(_ values: [Float], weights: [Float]? = nil, _ q: Float) -> Float {
        guard !values.isEmpty else { return 0 }
        let order = values.indices.sorted { values[$0] < values[$1] }
        let w = weights ?? Array(repeating: 1, count: values.count)
        let total = order.reduce(Float(0)) { $0 + w[$1] }
        guard total > 0 else { return values[order[order.count / 2]] }
        let target = q * total
        var acc: Float = 0
        for i in order {
            acc += w[i]
            if acc >= target { return values[i] }
        }
        return values[order.last!]
    }

    /// Area-weighted histogram with Gaussian smoothing. Returns bin centers and smoothed mass.
    public static func histogram(_ values: [Float], weights: [Float], bin: Float, smooth: Int = 1) -> (lo: Float, mass: [Float]) {
        guard let mn = values.min(), let mx = values.max() else { return (0, []) }
        let n = max(1, Int(((mx - mn) / bin).rounded(.up)) + 1)
        var raw = [Float](repeating: 0, count: n)
        for (v, w) in zip(values, weights) { raw[min(n - 1, Int((v - mn) / bin))] += w }
        guard smooth > 0 else { return (mn, raw) }
        let kernel: [Float] = (-smooth...smooth).map { exp(-Float($0 * $0) / Float(2 * smooth * smooth)) }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            for (k, kw) in kernel.enumerated() {
                let j = i + k - smooth
                if j >= 0 && j < n { out[i] += raw[j] * kw }
            }
        }
        return (mn, out)
    }

    /// Local maxima of `mass` above `minMass`, separated by at least `minSeparation` bins, strongest first.
    public static func peaks(_ mass: [Float], minMass: Float, minSeparation: Int) -> [Int] {
        var cands: [Int] = []
        for i in mass.indices where mass[i] >= minMass {
            let l = i > 0 ? mass[i - 1] : -1, r = i < mass.count - 1 ? mass[i + 1] : -1
            if mass[i] >= l && mass[i] >= r { cands.append(i) }
        }
        var kept: [Int] = []
        for i in cands.sorted(by: { mass[$0] > mass[$1] }) where kept.allSatisfy({ abs($0 - i) >= minSeparation }) {
            kept.append(i)
        }
        return kept
    }
}

/// 2D polygon helpers on the XZ floor plane (x = world X, y = world Z).
public enum Polygon2D {
    @inlinable static func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }

    /// Andrew's monotone chain. Counter-clockwise, no repeated end point.
    public static func convexHull(_ pts: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let p = pts.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard p.count > 2 else { return p }
        var lower: [SIMD2<Float>] = [], upper: [SIMD2<Float>] = []
        for q in p {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 0 { lower.removeLast() }
            lower.append(q)
        }
        for q in p.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 0 { upper.removeLast() }
            upper.append(q)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    public static func area(_ poly: [SIMD2<Float>]) -> Float {
        var a: Float = 0
        for i in poly.indices { let j = (i + 1) % poly.count; a += poly[i].x * poly[j].y - poly[j].x * poly[i].y }
        return a / 2
    }

    /// Even-odd point in polygon test.
    public static func contains(_ poly: [SIMD2<Float>], _ p: SIMD2<Float>) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Minimum-area enclosing rectangle by rotating calipers over hull edge directions
    /// (Freeman and Shapira 1975). Returns the angle of the rectangle's first axis.
    public static func minAreaRectAngle(_ hull: [SIMD2<Float>]) -> Float {
        guard hull.count >= 3 else { return 0 }
        var best: (area: Float, angle: Float) = (.infinity, 0)
        for i in hull.indices {
            let e = hull[(i + 1) % hull.count] - hull[i]
            guard simd_length_squared(e) > 1e-10 else { continue }
            let u = simd_normalize(e), v = SIMD2(-u.y, u.x)
            var lo = SIMD2<Float>(repeating: .infinity), hi = SIMD2<Float>(repeating: -.infinity)
            for p in hull {
                let q = SIMD2(simd_dot(p, u), simd_dot(p, v))
                lo = simd_min(lo, q); hi = simd_max(hi, q)
            }
            let a = (hi.x - lo.x) * (hi.y - lo.y)
            if a < best.area { best = (a, atan2(u.y, u.x)) }
        }
        return best.angle
    }

    /// Distance from `p` to segment `a`-`b`, plus the clamped parameter t in [0, 1].
    public static func segmentDistance(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> (dist: Float, t: Float) {
        let d = b - a
        let t = simd_clamp(simd_dot(p - a, d) / max(simd_length_squared(d), 1e-9), 0, 1)
        return (simd_distance(p, a + d * t), t)
    }
}
