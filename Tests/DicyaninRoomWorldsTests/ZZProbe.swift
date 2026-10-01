import Testing
import Foundation
import simd
@testable import DicyaninRoomWorlds

@Suite struct ZZProbe {
    @Test func probe() throws {
        var scan = SyntheticRoom.scan()
        scan.meshes = scan.meshes.map { var m = $0; m.faceLabels = Array(repeating: .none, count: m.faceCount); return m }
        let r = RoomAnalyzer().analyze(scan)
        print("PROBE unlabeled walls", r.walls.count, "outline", r.outline.count, "objects", r.objects.count, "floorCells", r.grid.floorCellCount, "floorY", r.floorY)
        // heavy partial: drop 30% of faces randomly (holes)
        var rng = SeededRandom(seed: 3)
        var s2 = SyntheticRoom.scan(noise: 0.015)
        s2.meshes = s2.meshes.map { m in
            var idx: [UInt32] = [], lab: [SurfaceLabel] = []
            for f in 0..<m.faceCount where rng.unit() > 0.3 { idx += m.indices[f*3..<f*3+3]; lab.append(m.faceLabels[f]) }
            return ScanMesh(id: m.id, positions: m.positions, indices: idx, faceLabels: lab)
        }
        let r2 = RoomAnalyzer().analyze(s2)
        print("PROBE holes walls", r2.walls.count, r2.walls.map { String(format: "%.2f", $0.length) }, "objects", r2.objects.map(\.archetype.rawValue))
        // non-manhattan: rotate one item 30 deg
        var L = SyntheticRoom.livingRoomLayout
        L.items[0].yaw = .pi / 6
        let r3 = RoomAnalyzer().analyze(SyntheticRoom.scan(L))
        if let sofa = r3.objects(.sofa).first { print("PROBE sofa30 size", sofa.box.size, "yaw", sofa.box.yaw) } else { print("PROBE sofa30 missing", r3.objects.map(\.archetype.rawValue)) }
    }
}
