import Foundation
import simd

/// RoomModel + theme + seed to a `WorldSpec`. Pure, deterministic, `Sendable`.
///
///     let world = WorldGenerator().generate(room: model, theme: .enchantedForest, seed: 42)
public struct WorldGenerator: Sendable {
    public struct Options: Sendable {
        public var includeFurniture = true
        public var includeBoundary = true
        public var includeOpenings = true
        public var includeDecor = true
        /// Multiplies every decor rule density.
        public var decorDensity: Float = 1
        public var maxDecor = 900
        /// Decor never spawns where clearance is below this, keeping walkways open.
        public var walkwayRadius: Float = 0.0
        public var spawnCount = 6
        public var spawnRadius: Float = 0.3
        public init() {}
    }

    public var library: AssetLibrary
    public var options: Options

    public init(library: AssetLibrary = .standard, options: Options = Options()) {
        self.library = library
        self.options = options
    }

    public func generate(room: RoomModel, theme: WorldTheme, seed: UInt64 = 1) -> WorldSpec {
        var out: [WorldInstance] = []
        if options.includeFurniture { out += furniture(room, theme, seed) }
        if options.includeBoundary { out += boundary(room, theme, seed) }
        if options.includeOpenings { out += openings(room, theme, seed) }
        if options.includeDecor { out += decor(room, theme, seed) }
        let spawns = room.grid.spawnPoints(count: options.spawnCount, radius: options.spawnRadius)
        return WorldSpec(seed: seed, theme: theme, room: room, instances: out, spawnPoints: spawns)
    }

    public func generate(room: RoomModel, themeID: String, seed: UInt64 = 1) -> WorldSpec? {
        library[theme: themeID].map { generate(room: room, theme: $0, seed: seed) }
    }

    // MARK: Furniture

    func furniture(_ room: RoomModel, _ theme: WorldTheme, _ seed: UInt64) -> [WorldInstance] {
        room.objects.map { o in
            var rng = SeededRandom.derive(seed, "obj:" + o.id)
            let bp = library.blueprint(for: o.archetype, theme: theme, rng: &rng)
            return WorldInstance(id: "furniture:\(o.id)", blueprintID: bp.id, role: .furniture, position: o.box.basePosition,
                                 yaw: o.box.yaw, size: o.box.size, surface: o.surfaceHeight, seed: rng.next(),
                                 sourceID: o.id, archetype: o.archetype, collides: true)
        }
    }

    // MARK: Boundary

    func boundary(_ room: RoomModel, _ theme: WorldTheme, _ seed: UInt64) -> [WorldInstance] {
        let ids = theme.boundary.filter { library[blueprint: $0] != nil }
        guard !ids.isEmpty else { return [] }
        var out: [WorldInstance] = []
        for wall in room.walls {
            var rng = SeededRandom.derive(seed, "wall:" + wall.id)
            let len = wall.length, spacing = max(0.2, theme.boundarySpacing)
            let n = max(1, Int((len / spacing).rounded()))
            let step = len / Float(n)
            let cuts = room.openings.filter { $0.wallID == wall.id }.map { o -> (Float, Float, WallOpening) in
                let t = simd_dot(o.center - wall.start, wall.tangent)
                return (t - o.width / 2, t + o.width / 2, o)
            }
            for k in 0..<n {
                let j = simd_clamp(theme.boundaryJitter, 0, 1)
                let t = (Float(k) + 0.5) * step + rng.jitter(step * 0.15 * j)
                let width = step * (1 + j * rng.range(0, 0.35))
                var height = wall.height * rng.range(theme.boundaryHeight.lowerBound, theme.boundaryHeight.upperBound)
                let blocked = cuts.first { t + width * 0.35 > $0.0 && t - width * 0.35 < $0.1 }
                if let b = blocked {
                    // Doors stay open; under windows keep a low piece up to the sill.
                    guard b.2.kind == .window else { continue }
                    height = b.2.bottomY - wall.bottomY
                    guard height > 0.3 else { continue }
                }
                let depth = rng.range(theme.boundaryDepth.lowerBound, theme.boundaryDepth.upperBound)
                let p2 = wall.start + wall.tangent * t - wall.normal * (depth / 2 - 0.04)
                let id = blocked == nil ? ids[Int(rng.next() % UInt64(ids.count))] : ids[0]
                out.append(WorldInstance(id: "boundary:\(wall.id):\(k)", blueprintID: id, role: .boundary,
                                         position: SIMD3(p2.x, wall.bottomY, p2.y), yaw: wall.inwardYaw + rng.jitter(0.06 * j),
                                         size: SIMD3(width, height, depth), surface: nil, seed: rng.next(),
                                         sourceID: wall.id, archetype: nil, collides: true))
            }
        }
        return out
    }

    // MARK: Openings

    func openings(_ room: RoomModel, _ theme: WorldTheme, _ seed: UInt64) -> [WorldInstance] {
        room.openings.compactMap { o in
            guard let id = o.kind == .door ? theme.door : theme.window, let bp = library[blueprint: id] else { return nil }
            var rng = SeededRandom.derive(seed, "opening:" + o.id)
            let depth = bp.defaultSize.z
            let p2 = o.center + o.normal * (depth / 2 - 0.06)
            return WorldInstance(id: "opening:\(o.id)", blueprintID: id, role: .opening, position: SIMD3(p2.x, o.bottomY, p2.y),
                                 yaw: Yaw.facing(o.normal), size: SIMD3(o.width, o.topY - o.bottomY, depth), surface: nil,
                                 seed: rng.next(), sourceID: o.id, archetype: nil, collides: false)
        }
    }

    // MARK: Decor

    func decor(_ room: RoomModel, _ theme: WorldTheme, _ seed: UInt64) -> [WorldInstance] {
        let rules = theme.decor.filter { library[blueprint: $0.blueprint] != nil && $0.density > 0 }
        let total = rules.reduce(Float(0)) { $0 + $1.density } * options.decorDensity
        guard total > 0 else { return [] }
        let grid = room.grid
        var rng = SeededRandom.derive(seed, "decor")
        let r = max(0.08, 0.35 / total.squareRoot())
        let floorCells = Float(grid.floorCellCount) * grid.cellSize * grid.cellSize
        let target = min(options.maxDecor, Int((total * floorCells).rounded()))
        guard target > 0 else { return [] }
        let lo = grid.origin, hi = grid.origin + SIMD2(Float(grid.columns), Float(grid.rows)) * grid.cellSize
        var pts = PoissonDisk.sample(min: lo, max: hi, radius: r, rng: &rng) { q in
            let p = grid.toWorld(q)
            return grid.cell(at: p) == .floor && grid.clearance(at: p) >= max(0.05, options.walkwayRadius)
        }.map(grid.toWorld)
        // Fisher-Yates so the kept subset is spatially uniform.
        for i in stride(from: pts.count - 1, to: 0, by: -1) { pts.swapAt(i, Int(rng.next() % UInt64(i + 1))) }

        var out: [WorldInstance] = []
        for p in pts {
            guard out.count < target else { break }
            var pick = rng.unit() * rules.reduce(0) { $0 + $1.density }
            guard let rule = rules.first(where: { pick -= $0.density; return pick <= 0 }) ?? rules.last,
                  let bp = library[blueprint: rule.blueprint] else { continue }
            let clear = grid.clearance(at: p)
            guard clear >= rule.minClearance else { continue }
            let c = simd_clamp(clear / 1.2, 0, 1)
            let keepP = rule.openness * c + (1 - rule.openness) * (1 - c)
            guard rng.unit() < 0.25 + 0.75 * keepP else { continue }
            let s = rng.range(bp.scaleRange.lowerBound, bp.scaleRange.upperBound)
            let size = bp.defaultSize * s
            guard clear >= max(size.x, size.z) * 0.4 || rule.minClearance < 0.1 else { continue }
            out.append(WorldInstance(id: "decor:\(out.count)", blueprintID: bp.id, role: .decor,
                                     position: SIMD3(p.x, room.floorY, p.y), yaw: rng.range(-.pi, .pi), size: size, surface: nil,
                                     seed: rng.next(), sourceID: nil, archetype: nil, collides: false))
        }
        return out
    }
}
