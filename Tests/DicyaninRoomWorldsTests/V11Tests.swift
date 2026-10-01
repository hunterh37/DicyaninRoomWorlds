import Foundation
import Testing
import simd
@testable import DicyaninRoomWorlds

@Suite struct StableIDTests {
    @Test func addingAnObjectKeepsOtherIDsAndSeeds() {
        var layout = SyntheticRoom.livingRoomLayout
        let a = RoomAnalyzer().analyze(SyntheticRoom.scan(layout))
        layout.items.append(.init(.cabinet, .box, center: [-2.0, -1.6], size: [0.8, 0.9, 0.5]))
        let b = RoomAnalyzer().analyze(SyntheticRoom.scan(layout))
        #expect(b.objects.count == a.objects.count + 1)
        #expect(Set(a.objects.map(\.id)).isSubset(of: Set(b.objects.map(\.id))))
        #expect(Set(a.walls.map(\.id)) == Set(b.walls.map(\.id)))
        let wa = WorldGenerator().generate(room: a, theme: .enchantedForest, seed: 4).instances(.furniture)
        let wb = Dictionary(uniqueKeysWithValues: WorldGenerator().generate(room: b, theme: .enchantedForest, seed: 4)
            .instances(.furniture).map { ($0.id, $0) })
        for inst in wa {
            #expect(wb[inst.id]?.blueprintID == inst.blueprintID)
            #expect(wb[inst.id]?.seed == inst.seed)
        }
    }

    @Test func idsAreUnique() {
        let m = AnalyzerTests.model
        #expect(Set(m.objects.map(\.id)).count == m.objects.count)
        #expect(Set(m.walls.map(\.id)).count == m.walls.count)
        #expect(Set(m.openings.map(\.id)).count == m.openings.count)
    }
}

@Suite struct CodingTests {
    @Test func themeEncodesKeyedAndByteStable() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let a = try enc.encode(WorldTheme.enchantedForest), b = try enc.encode(WorldTheme.enchantedForest)
        #expect(a == b)
        let obj = try #require(JSONSerialization.jsonObject(with: a) as? [String: Any])
        let palette = try #require(obj["palette"] as? [String: Any])
        #expect(palette["foliage"] != nil)
        #expect((obj["furniture"] as? [String: Any])?["sofa"] != nil)
        #expect(try JSONDecoder().decode(WorldTheme.self, from: a) == .enchantedForest)
    }

    @Test func decodesLegacyArrayDictionaries() throws {
        let json = """
        {"id":"t","name":"T","palette":["primary",{"color":255,"roughness":0.5,"metallic":0,"emissive":0,"opacity":1}],
         "furniture":["sofa",["log.bench"]],"boundary":["tree.pine"],
         "sky":{"zenith":0,"horizon":0,"sunColor":0,"sunIntensity":1,"ambient":0.5}}
        """
        let t = try JSONDecoder().decode(WorldTheme.self, from: Data(json.utf8))
        #expect(t.palette[.primary]?.color == 255)
        #expect(t.furniture[.sofa] == ["log.bench"])
        #expect(t.ceiling == .open && t.terrain == TerrainStyle() && t.decor.isEmpty)
    }

    @Test func minimalThemeJSON() throws {
        let json = """
        {"id":"m","name":"M","palette":{"primary":{"color":16711680,"roughness":1,"metallic":0,"emissive":0,"opacity":1}},
         "boundary":[],"terrain":{"rimHeight":0.1},"sky":{"zenith":1,"horizon":2,"sunColor":3,"sunIntensity":1,"ambient":0.5}}
        """
        let t = try JSONDecoder().decode(WorldTheme.self, from: Data(json.utf8))
        #expect(t.terrain.rimHeight == 0.1 && t.terrain.cell == TerrainStyle().cell)
        #expect(t.boundarySpacing == 0.9)
    }

    @Test func gridPacksAndRecomputesClearance() throws {
        let g = AnalyzerTests.model.grid
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(FloorGrid.self, from: data)
        #expect(back.cells == g.cells)
        #expect(back.clearance == g.clearance)
        #expect(String(data: data, encoding: .utf8)?.contains("clearance") == false)
        // 1.0 layout: cells as numbers plus clearance.
        let legacy = """
        {"origin":[0,0],"cellSize":0.1,"yaw":0,"columns":2,"rows":1,"cells":[1,2],"clearance":[0.1,0]}
        """
        let old = try JSONDecoder().decode(FloorGrid.self, from: Data(legacy.utf8))
        #expect(old.cells == [.floor, .obstacle])
    }

    @Test func specIsSmaller() throws {
        let spec = WorldGenerator().generate(room: AnalyzerTests.model, theme: .enchantedForest, seed: 9)
        #expect(try spec.encoded().count < 30_000)
        #expect(try WorldSpec.decode(spec.encoded()).version == 2)
    }
}

@Suite struct UnlabeledScanTests {
    static let model: RoomModel = {
        var scan = SyntheticRoom.scan()
        scan.meshes = scan.meshes.map { var m = $0; m.faceLabels = Array(repeating: .none, count: m.faceCount); return m }
        return RoomAnalyzer().analyze(scan)
    }()

    @Test func wallsAndFloorInferred() {
        #expect(Self.model.walls.count == 4)
        #expect(abs(Self.model.ceilingHeight - 2.6) < 0.05)
        #expect(Self.model.grid.floorCellCount > 800)
    }

    @Test func objectsClassifiedByShape() {
        let kinds = Set(Self.model.objects.map(\.archetype))
        #expect(!kinds.contains(.clutter))
        #expect(kinds.contains(.sofa))
    }

    @Test func labeledScansUnaffected() {
        var o = RoomAnalyzer.Options()
        o.inferMissingLabels = false
        let a = RoomAnalyzer(options: o).analyze(SyntheticRoom.scan())
        #expect(a.objects.map(\.id) == AnalyzerTests.model.objects.map(\.id))
    }
}

@Suite struct PathTests {
    @Test func smoothedPathIsShortAndClear() throws {
        let g = AnalyzerTests.model.grid
        let a = AnalyzerTests.world([-1.5, -1.5]), b = AnalyzerTests.world([1.3, 1.2])
        let raw = try #require(g.path(from: a, to: b, radius: 0.2))
        let smooth = try #require(g.path(from: a, to: b, radius: 0.2, smooth: true))
        #expect(smooth.count < raw.count / 3)
        #expect(smooth.first == a && smooth.last == b)
        for i in 1..<smooth.count { #expect(g.hasLineOfSight(smooth[i - 1], smooth[i], radius: 0.2)) }
        func length(_ p: [SIMD2<Float>]) -> Float { zip(p, p.dropFirst()).reduce(0) { $0 + simd_distance($1.0, $1.1) } }
        #expect(length(smooth) <= length(raw) + 1e-4)
    }
}
