import Foundation
import simd

/// Occupancy grid of the floor in the room's Manhattan frame, with a clearance field.
/// Used for walkability, decor scatter, spawn points and A* paths in games.
public struct FloorGrid: Codable, Sendable {
    public enum Cell: UInt8, Codable, Sendable { case outside = 0, floor, obstacle, wall }

    /// World XZ of the corner of cell (0, 0), in the rotated frame.
    public var origin: SIMD2<Float>
    public var cellSize: Float
    /// Grid axes are the world axes rotated by this yaw (the Manhattan yaw).
    public var yaw: Float
    public var columns: Int
    public var rows: Int
    public var cells: [Cell]
    /// Distance in meters from each floor cell to the nearest non-floor cell.
    public var clearance: [Float]

    public init(origin: SIMD2<Float>, cellSize: Float, yaw: Float, columns: Int, rows: Int) {
        self.origin = origin
        self.cellSize = cellSize
        self.yaw = yaw
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        cells = Array(repeating: .outside, count: self.columns * self.rows)
        clearance = Array(repeating: 0, count: self.columns * self.rows)
    }

    // MARK: Coordinates

    /// World XZ to the grid frame (unrotated by `yaw`).
    @inlinable public func toGrid(_ p: SIMD2<Float>) -> SIMD2<Float> { Yaw.rotate(p, -yaw) }
    @inlinable public func toWorld(_ q: SIMD2<Float>) -> SIMD2<Float> { Yaw.rotate(q, yaw) }

    public func cellIndex(_ world: SIMD2<Float>) -> (c: Int, r: Int)? {
        let q = (toGrid(world) - origin) / cellSize
        let c = Int(q.x.rounded(.down)), r = Int(q.y.rounded(.down))
        return c >= 0 && r >= 0 && c < columns && r < rows ? (c, r) : nil
    }

    public func cellCenter(_ c: Int, _ r: Int) -> SIMD2<Float> {
        toWorld(origin + (SIMD2(Float(c), Float(r)) + 0.5) * cellSize)
    }

    public subscript(c: Int, r: Int) -> Cell {
        get { cells[r * columns + c] }
        set { cells[r * columns + c] = newValue }
    }

    public func cell(at world: SIMD2<Float>) -> Cell {
        guard let (c, r) = cellIndex(world) else { return .outside }
        return self[c, r]
    }

    public func clearance(at world: SIMD2<Float>) -> Float {
        guard let (c, r) = cellIndex(world) else { return 0 }
        return clearance[r * columns + c]
    }

    /// Floor cell with at least `radius` meters of clearance.
    public func isWalkable(_ world: SIMD2<Float>, radius: Float = 0.25) -> Bool {
        guard let (c, r) = cellIndex(world) else { return false }
        return cells[r * columns + c] == .floor && clearance[r * columns + c] >= radius
    }

    public var floorCellCount: Int { cells.reduce(0) { $0 + ($1 == .floor ? 1 : 0) } }

    // MARK: Rasterization

    /// Marks cells whose centers fall inside `poly` (world XZ).
    public mutating func fill(polygon poly: [SIMD2<Float>], with value: Cell, onlyOver: Set<Cell>? = nil) {
        guard poly.count >= 3 else { return }
        let g = poly.map(toGrid)
        let lo = g.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) }
        let hi = g.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) }
        let c0 = max(0, Int(((lo.x - origin.x) / cellSize).rounded(.down))), c1 = min(columns - 1, Int(((hi.x - origin.x) / cellSize).rounded(.up)))
        let r0 = max(0, Int(((lo.y - origin.y) / cellSize).rounded(.down))), r1 = min(rows - 1, Int(((hi.y - origin.y) / cellSize).rounded(.up)))
        guard c0 <= c1, r0 <= r1 else { return }
        for r in r0...r1 {
            for c in c0...c1 {
                let q = origin + (SIMD2(Float(c), Float(r)) + 0.5) * cellSize
                guard Polygon2D.contains(g, q) else { continue }
                if let onlyOver, !onlyOver.contains(self[c, r]) { continue }
                self[c, r] = value
            }
        }
    }

    /// Marks cells within `thickness / 2` of the segment.
    public mutating func stroke(_ a: SIMD2<Float>, _ b: SIMD2<Float>, thickness: Float, with value: Cell) {
        let d = simd_normalize(b - a), n = SIMD2(-d.y, d.x) * thickness / 2
        fill(polygon: [a - n, b - n, b + n, a + n], with: value)
    }

    /// Two-pass 8-neighbour chamfer distance transform (Borgefors 1986, weights 1 and sqrt 2).
    public mutating func computeClearance() {
        let inf = Float.greatestFiniteMagnitude / 4
        var d = cells.map { $0 == .floor ? inf : 0 }
        let s2 = Float(2).squareRoot()
        func at(_ c: Int, _ r: Int) -> Float { c < 0 || r < 0 || c >= columns || r >= rows ? 0 : d[r * columns + c] }
        for r in 0..<rows {
            for c in 0..<columns where d[r * columns + c] > 0 {
                d[r * columns + c] = min(d[r * columns + c], at(c - 1, r) + 1, at(c, r - 1) + 1, at(c - 1, r - 1) + s2, at(c + 1, r - 1) + s2)
            }
        }
        for r in stride(from: rows - 1, through: 0, by: -1) {
            for c in stride(from: columns - 1, through: 0, by: -1) where d[r * columns + c] > 0 {
                d[r * columns + c] = min(d[r * columns + c], at(c + 1, r) + 1, at(c, r + 1) + 1, at(c + 1, r + 1) + s2, at(c - 1, r + 1) + s2)
            }
        }
        clearance = d.map { $0 * cellSize }
    }

    // MARK: Queries

    /// Walkable cell centers, row-major.
    public func walkableCells(radius: Float) -> [(c: Int, r: Int)] {
        var out: [(Int, Int)] = []
        for r in 0..<rows { for c in 0..<columns where cells[r * columns + c] == .floor && clearance[r * columns + c] >= radius { out.append((c, r)) } }
        return out
    }

    /// `count` well-separated walkable points by farthest-point sampling, seeded at the most open cell.
    public func spawnPoints(count: Int, radius: Float = 0.3) -> [SIMD2<Float>] {
        let cand = walkableCells(radius: radius)
        guard !cand.isEmpty, count > 0 else { return [] }
        let pts = cand.map { cellCenter($0.c, $0.r) }
        var first = 0
        for i in cand.indices where clearance[cand[i].r * columns + cand[i].c] > clearance[cand[first].r * columns + cand[first].c] { first = i }
        var chosen = [pts[first]]
        var minD = pts.map { simd_distance_squared($0, pts[first]) }
        while chosen.count < min(count, pts.count) {
            guard let next = minD.indices.max(by: { minD[$0] < minD[$1] }), minD[next] > 0 else { break }
            chosen.append(pts[next])
            for i in pts.indices { minD[i] = min(minD[i], simd_distance_squared(pts[i], pts[next])) }
        }
        return chosen
    }
}
