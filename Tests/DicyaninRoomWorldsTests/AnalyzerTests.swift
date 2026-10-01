import Testing
import simd
@testable import DicyaninRoomWorlds

@Suite struct AnalyzerTests {
    static let yaw: Float = 0.3
    static let offset = SIMD3<Float>(0.4, -1.3, -0.7)
    static let model: RoomModel = RoomAnalyzer().analyze(SyntheticRoom.scan(yaw: yaw, offset: offset))

    /// Room-local XZ to world, matching SyntheticRoom.scan.
    static func world(_ p: SIMD2<Float>) -> SIMD2<Float> {
        Yaw.rotate(p, yaw) + SIMD2(offset.x, offset.z)
    }

    @Test func frameHeights() {
        #expect(abs(Self.model.floorY - Self.offset.y) < 0.02)
        #expect(abs(Self.model.ceilingHeight - 2.6) < 0.05)
    }

    @Test func manhattanYawRecovered() {
        let m = Self.model.manhattanYaw
        let err = abs(Yaw.wrap(4 * (m - Self.yaw))) / 4
        #expect(err < 0.02)
        #expect(Self.model.manhattanConfidence > 0.8)
    }

    @Test func fourWalls() {
        let walls = Self.model.walls
        #expect(walls.count == 4)
        let lengths = walls.map(\.length).sorted()
        #expect(abs(lengths[0] - 4) < 0.15 && abs(lengths[3] - 5) < 0.15)
        // Normals point into the room.
        let c = Self.world(.zero)
        for w in walls { #expect(simd_dot(c - w.midpoint, w.normal) > 0) }
    }

    @Test func openingsFound() {
        let o = Self.model.openings
        #expect(o.contains { $0.kind == .window && abs($0.width - 1.4) < 0.15 && abs($0.bottomY - Self.offset.y - 0.9) < 0.1 })
        #expect(o.contains { $0.kind == .door && abs($0.width - 0.9) < 0.15 && abs($0.bottomY - Self.offset.y) < 0.02 })
    }

    @Test func sofaMeasuredAndFacingTV() throws {
        let sofa = try #require(Self.model.objects(.sofa).first)
        #expect(abs(sofa.box.size.x - 2.1) < 0.1)
        #expect(abs(sofa.box.size.z - 0.9) < 0.1)
        #expect(abs(sofa.box.size.y - 0.85) < 0.05)
        #expect(abs((sofa.surfaceHeight ?? 0) - 0.44) < 0.04)
        let expectedFront = Yaw.rotate(SIMD2(0, 1), Self.yaw)
        #expect(simd_dot(sofa.box.front, expectedFront) > 0.95)
    }

    @Test func archetypes() {
        let kinds = Set(Self.model.objects.map(\.archetype))
        for a: Archetype in [.sofa, .coffeeTable, .armchair, .chair, .tv, .plant, .shelf] {
            #expect(kinds.contains(a), "missing \(a)")
        }
        #expect(kinds.contains(.diningTable) || kinds.contains(.desk))
    }

    @Test func coffeeTableHeight() throws {
        let t = try #require(Self.model.objects(.coffeeTable).first)
        #expect(abs(t.box.size.y - 0.42) < 0.04)
        #expect(abs(t.box.bottomY - Self.model.floorY) < 0.01)
        let c = SIMD2(t.box.center.x, t.box.center.z)
        #expect(simd_distance(c, Self.world([0.2, -0.35])) < 0.08)
    }

    @Test func gridWalkable() {
        let g = Self.model.grid
        #expect(g.floorCellCount > 800)
        #expect(!g.isWalkable(Self.world([0.2, -1.5])))
        let a = Self.world([-1.5, -1.5]), b = Self.world([1.3, 1.2])
        #expect(g.isWalkable(a, radius: 0.2) && g.isWalkable(b, radius: 0.2))
        let path = g.path(from: a, to: b, radius: 0.2)
        #expect(path != nil)
        #expect(g.spawnPoints(count: 4).count == 4)
    }

    @Test func coverage() {
        let cov = ScanCoverage.measure(SyntheticRoom.scan())
        #expect(cov.isSufficient)
        #expect(cov.wallDirections == 4)
    }

    @Test func codableRoundTrip() throws {
        let scan = SyntheticRoom.scan()
        let back = try RoomScan.decode(scan.encoded())
        #expect(back.faceCount == scan.faceCount)
    }
}
