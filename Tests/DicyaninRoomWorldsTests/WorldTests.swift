import Testing
import simd
@testable import DicyaninRoomWorlds

@Suite struct BlueprintTests {
    let lib = AssetLibrary.standard

    @Test func fitsMeasuredBoxExactly() throws {
        let table = try #require(lib[blueprint: "table.classic"])
        for size: SIMD3<Float> in [[0.6, 0.45, 0.6], [1.2, 0.75, 0.8], [2.4, 0.9, 1.1]] {
            let b = try #require(table.mesh(size: size).bounds)
            #expect(simd_length(b.max - b.min - size) < 1e-3)
            #expect(abs(b.min.y) < 1e-4)
        }
    }

    @Test func legThicknessIsMetric() throws {
        let table = try #require(lib[blueprint: "table.classic"])
        func legWidth(_ size: SIMD3<Float>) -> Float {
            let g = table.mesh(size: size).groups[.secondary]!
            // Leg vertices sit below the apron; their X spread at the left edge is the leg width.
            let left = g.positions.filter { $0.y < 0.2 && $0.x < -size.x / 2 + 0.2 }
            return (left.map(\.x).max() ?? 0) - (left.map(\.x).min() ?? 0)
        }
        #expect(abs(legWidth([0.8, 0.75, 0.8]) - 0.06) < 1e-3)
        #expect(abs(legWidth([2.4, 0.75, 1.2]) - 0.06) < 1e-3)
    }

    @Test func seatSurfaceFollowsMeasurement() throws {
        let sofa = try #require(lib[blueprint: "sofa.cushions"])
        let m = sofa.mesh(size: [2, 0.85, 0.9], surface: 0.4)
        let cushions = try #require(m.groups[.soft])
        let seatTop = cushions.positions.filter { $0.z > 0.2 }.map(\.y).max() ?? 0
        #expect(abs(seatTop - 0.4) < 0.02)
    }

    @Test func repeatCountScalesWithWidth() throws {
        let sofa = try #require(lib[blueprint: "sofa.cushions"])
        func cushions(_ w: Float) -> Int { (sofa.mesh(size: [w, 0.85, 0.9], surface: 0.45).groups[.soft]?.triangleCount ?? 0) }
        #expect(cushions(3.0) > cushions(1.4))
    }

    @Test func everyBlueprintBuildsAndThemesResolve() {
        for (id, bp) in lib.blueprints {
            #expect(!bp.mesh().isEmpty, "empty mesh \(id)")
        }
        for theme in WorldTheme.builtIn {
            for ids in theme.furniture.values { for id in ids { #expect(lib[blueprint: id] != nil, "\(theme.id) missing \(id)") } }
            for id in theme.boundary { #expect(lib[blueprint: id] != nil, "\(theme.id) missing \(id)") }
            for r in theme.decor { #expect(lib[blueprint: r.blueprint] != nil, "\(theme.id) missing \(r.blueprint)") }
            if let d = theme.door { #expect(lib[blueprint: d] != nil) }
            if let w = theme.window { #expect(lib[blueprint: w] != nil) }
        }
    }

    @Test func classifierSeparatesSeats() {
        let c = ArchetypeClassifier()
        func top(_ size: SIMD3<Float>, _ s: Float?, wall: Bool = false) -> Archetype? {
            c.classify(.init(label: .seat, size: size, surface: s, nearWall: wall)).first?.archetype
        }
        #expect(top([0.48, 0.88, 0.5], 0.46) == .chair)
        #expect(top([0.9, 0.9, 0.85], 0.44) == .armchair)
        #expect(top([2.2, 0.85, 0.95], 0.43, wall: true) == .sofa)
        #expect(top([0.38, 0.65, 0.38], nil) == .stool)
    }
}

@Suite struct WorldTests {
    static let room = AnalyzerTests.model

    @Test func deterministicBySeed() throws {
        let a = WorldGenerator().generate(room: Self.room, theme: .enchantedForest, seed: 9)
        let b = WorldGenerator().generate(room: Self.room, theme: .enchantedForest, seed: 9)
        let c = WorldGenerator().generate(room: Self.room, theme: .enchantedForest, seed: 10)
        #expect(a.instances == b.instances)
        #expect(a.instances != c.instances)
    }

    @Test func furnitureKeepsMeasuredBoxes() {
        for theme in WorldTheme.builtIn {
            let w = WorldGenerator().generate(room: Self.room, theme: theme, seed: 3)
            let f = w.instances(.furniture)
            #expect(f.count == Self.room.objects.count)
            for inst in f {
                let o = Self.room.objects.first { $0.id == inst.sourceID }!
                #expect(simd_distance(inst.size, o.box.size) < 1e-5)
                #expect(simd_distance(inst.position, o.box.basePosition) < 1e-5)
            }
        }
    }

    @Test func decorAvoidsObstaclesAndWalkways() {
        let w = WorldGenerator().generate(room: Self.room, theme: .enchantedForest, seed: 5)
        let decor = w.instances(.decor)
        #expect(decor.count > 20)
        for d in decor {
            let p = SIMD2(d.position.x, d.position.z)
            #expect(Self.room.grid.cell(at: p) == .floor)
            for o in Self.room.objects where o.box.bottomY - Self.room.floorY < 0.3 {
                #expect(!o.box.footprintContains(p, margin: -0.05))
            }
        }
    }

    @Test func boundaryLeavesDoorOpen() throws {
        let w = WorldGenerator().generate(room: Self.room, theme: .enchantedForest, seed: 2)
        let door = try #require(Self.room.openings.first { $0.kind == .door })
        let wall = try #require(Self.room.wall(id: door.wallID))
        for b in w.instances(.boundary) where b.sourceID == wall.id {
            let t = simd_dot(SIMD2(b.position.x, b.position.z) - door.center, wall.tangent)
            #expect(abs(t) > door.width / 2 - 0.05)
        }
        #expect(w.instances(.opening).count == Self.room.openings.count)
    }

    @Test func terrainFlatOnWalkableFloor() {
        let w = WorldGenerator().generate(room: Self.room, theme: .desertRuins, seed: 4)
        let t = w.terrainMesh()
        #expect(t.triangleCount > 200)
        for g in t.groups.values {
            for p in g.positions where Polygon2D.contains(Self.room.outline, SIMD2(p.x, p.z)) {
                #expect(abs(p.y - Self.room.floorY) <= w.theme.terrain.bump + 1e-4)
            }
        }
    }

    @Test func specRoundTrip() throws {
        let w = WorldGenerator().generate(room: Self.room, theme: .neonCity, seed: 8)
        let back = try WorldSpec.decode(w.encoded())
        #expect(back.instances == w.instances)
        #expect(back.theme.id == "neon")
        #expect(w.spawnPoints.count == 6)
    }

    @Test func poissonSpacing() {
        var rng = SeededRandom(seed: 1)
        let pts = PoissonDisk.sample(min: [0, 0], max: [4, 4], radius: 0.3, rng: &rng)
        #expect(pts.count > 60)
        for i in pts.indices { for j in pts.indices where j > i { #expect(simd_distance(pts[i], pts[j]) >= 0.3 - 1e-5) } }
    }
}
