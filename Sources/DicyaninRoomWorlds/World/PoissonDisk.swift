import Foundation
import simd

/// Bridson's fast Poisson-disk sampling (SIGGRAPH 2007) on a rectangle. Points are at least
/// `radius` apart, giving natural, clump-free scatter in O(n).
public enum PoissonDisk {
    public static func sample(min lo: SIMD2<Float>, max hi: SIMD2<Float>, radius r: Float, rng: inout SeededRandom,
                              attempts k: Int = 20, limit: Int = 20_000, accept: (SIMD2<Float>) -> Bool = { _ in true }) -> [SIMD2<Float>] {
        let size = hi - lo
        guard r > 0, size.x > 0, size.y > 0 else { return [] }
        let cell = r / Float(2).squareRoot()
        let cols = Int((size.x / cell).rounded(.up)) + 1, rows = Int((size.y / cell).rounded(.up)) + 1
        var grid = [Int32](repeating: -1, count: cols * rows)
        var pts: [SIMD2<Float>] = [], active: [Int] = []
        func gi(_ p: SIMD2<Float>) -> (Int, Int) { (Int((p.x - lo.x) / cell), Int((p.y - lo.y) / cell)) }
        func fits(_ p: SIMD2<Float>) -> Bool {
            guard p.x >= lo.x, p.y >= lo.y, p.x <= hi.x, p.y <= hi.y else { return false }
            let (c, rr) = gi(p)
            for y in max(0, rr - 2)...min(rows - 1, rr + 2) {
                for x in max(0, c - 2)...min(cols - 1, c + 2) {
                    let j = grid[y * cols + x]
                    if j >= 0 && simd_distance_squared(pts[Int(j)], p) < r * r { return false }
                }
            }
            return true
        }
        func add(_ p: SIMD2<Float>) {
            let (c, rr) = gi(p)
            grid[rr * cols + c] = Int32(pts.count)
            active.append(pts.count)
            pts.append(p)
        }
        // Seed several starts so disconnected accepted regions all get covered.
        for _ in 0..<32 {
            let p = lo + SIMD2(rng.unit(), rng.unit()) * size
            if fits(p) && accept(p) { add(p) }
        }
        while !active.isEmpty && pts.count < limit {
            let ai = Int(rng.next() % UInt64(active.count))
            let base = pts[active[ai]]
            var found = false
            for _ in 0..<k {
                let a = rng.unit() * 2 * .pi, d = r * (1 + rng.unit())
                let p = base + SIMD2(cos(a), sin(a)) * d
                if fits(p) && accept(p) { add(p); found = true; break }
            }
            if !found { active.swapAt(ai, active.count - 1); active.removeLast() }
        }
        return pts
    }
}
