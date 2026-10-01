import Foundation
import simd

public extension FloorGrid {
    /// A* over walkable cells (8-connected, octile heuristic). Returns world XZ waypoints
    /// from `start` to `goal`, or nil when unreachable for an agent of `radius`.
    /// `smooth` drops every waypoint that has line of sight past it (string pulling), which turns
    /// the cell staircase into a few straight legs.
    func path(from start: SIMD2<Float>, to goal: SIMD2<Float>, radius: Float = 0.25, smooth: Bool = false) -> [SIMD2<Float>]? {
        guard let s = cellIndex(start), let g = cellIndex(goal) else { return nil }
        func ok(_ c: Int, _ r: Int) -> Bool {
            c >= 0 && r >= 0 && c < columns && r < rows && cells[r * columns + c] == .floor && clearance[r * columns + c] >= radius
        }
        guard ok(s.c, s.r), ok(g.c, g.r) else { return nil }
        let n = columns * rows
        var gScore = [Float](repeating: .infinity, count: n)
        var came = [Int32](repeating: -1, count: n)
        var closed = [Bool](repeating: false, count: n)
        let si = s.r * columns + s.c, gi = g.r * columns + g.c
        func h(_ i: Int) -> Float {
            let dx = Float(abs(i % columns - g.c)), dy = Float(abs(i / columns - g.r))
            return max(dx, dy) + (Float(2).squareRoot() - 1) * min(dx, dy)
        }
        var heap = MinHeap()
        gScore[si] = 0
        heap.push(h(si), si)
        let steps: [(Int, Int, Float)] = [(1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1),
                                          (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
        while let (_, cur) = heap.pop() {
            if cur == gi { break }
            if closed[cur] { continue }
            closed[cur] = true
            let c = cur % columns, r = cur / columns
            for (dc, dr, cost) in steps {
                let nc = c + dc, nr = r + dr
                guard ok(nc, nr) else { continue }
                if dc != 0 && dr != 0 && !(ok(c + dc, r) && ok(c, r + dr)) { continue }
                let ni = nr * columns + nc
                let t = gScore[cur] + cost
                if t < gScore[ni] {
                    gScore[ni] = t
                    came[ni] = Int32(cur)
                    heap.push(t + h(ni), ni)
                }
            }
        }
        guard gScore[gi].isFinite else { return nil }
        var cellsPath: [Int] = [gi]
        var cur = gi
        while came[cur] >= 0 { cur = Int(came[cur]); cellsPath.append(cur) }
        var pts = cellsPath.reversed().map { cellCenter($0 % columns, $0 / columns) }
        pts[0] = start
        pts[pts.count - 1] = goal
        return smooth ? simplify(pts, radius: radius) : pts
    }

    /// True when every point on segment a-b, sampled at half-cell steps, is walkable for `radius`.
    func hasLineOfSight(_ a: SIMD2<Float>, _ b: SIMD2<Float>, radius: Float = 0.25) -> Bool {
        let n = max(1, Int((simd_distance(a, b) / (cellSize * 0.5)).rounded(.up)))
        for i in 0...n where !isWalkable(a + (b - a) * (Float(i) / Float(n)), radius: radius) { return false }
        return true
    }

    /// Greedy string pulling: from each kept waypoint, jump to the farthest later one in sight.
    func simplify(_ pts: [SIMD2<Float>], radius: Float = 0.25) -> [SIMD2<Float>] {
        guard pts.count > 2 else { return pts }
        var out = [pts[0]], i = 0
        while i < pts.count - 1 {
            var j = pts.count - 1
            while j > i + 1 && !hasLineOfSight(pts[i], pts[j], radius: radius) { j -= 1 }
            out.append(pts[j])
            i = j
        }
        return out
    }
}

/// Binary min-heap keyed by Float priority.
struct MinHeap {
    private var items: [(Float, Int)] = []
    var isEmpty: Bool { items.isEmpty }

    mutating func push(_ priority: Float, _ value: Int) {
        items.append((priority, value))
        var i = items.count - 1
        while i > 0 {
            let p = (i - 1) / 2
            guard items[p].0 > items[i].0 else { break }
            items.swapAt(p, i)
            i = p
        }
    }

    mutating func pop() -> (Float, Int)? {
        guard !items.isEmpty else { return nil }
        let top = items[0]
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var m = i
                if l < items.count && items[l].0 < items[m].0 { m = l }
                if r < items.count && items[r].0 < items[m].0 { m = r }
                if m == i { break }
                items.swapAt(m, i)
                i = m
            }
        }
        return top
    }
}
