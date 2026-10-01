import Foundation
import simd

/// One placed asset in a generated world.
public struct WorldInstance: Codable, Sendable, Identifiable, Hashable {
    public enum Role: String, Codable, Sendable { case furniture, boundary, opening, decor }

    public var id: String
    public var blueprintID: String
    public var role: Role
    /// Bottom-center contact point, world space.
    public var position: SIMD3<Float>
    /// Local +Z (front) maps to (sin, 0, cos).
    public var yaw: Float
    /// Fitted width, height, depth.
    public var size: SIMD3<Float>
    /// Functional surface height above the bottom (seat, table top), when measured.
    public var surface: Float?
    public var seed: UInt64
    /// ID of the room object, wall or opening this instance stands in for.
    public var sourceID: String?
    public var archetype: Archetype?
    /// True for solid pieces a game should collide with.
    public var collides: Bool

    public var transform: simd_float4x4 { placementMatrix(position: position, yaw: yaw) }
    public var box: FittedBox { FittedBox(center: position + SIMD3(0, size.y / 2, 0), size: size, yaw: yaw) }
}

/// Serializable result of world generation. Small (no meshes): meshes are rebuilt
/// deterministically from blueprints, sizes and seeds, so specs can be saved, synced or shared.
public struct WorldSpec: Codable, Sendable {
    /// 2 since 1.1: keyed theme dictionaries, byte-packed floor grid. Version 1 files still decode.
    public var version: Int = 2
    public var seed: UInt64
    public var theme: WorldTheme
    public var room: RoomModel
    public var instances: [WorldInstance]
    /// Suggested player and NPC spawn points (world XZ, at floor height).
    public var spawnPoints: [SIMD2<Float>]

    public func instances(_ role: WorldInstance.Role) -> [WorldInstance] { instances.filter { $0.role == role } }

    /// Fitted mesh for one instance in its local frame.
    public func mesh(for instance: WorldInstance, library: AssetLibrary = .standard) -> MeshData? {
        library[blueprint: instance.blueprintID]?.mesh(size: instance.size, surface: instance.surface, seed: instance.seed)
    }

    /// Ground mesh in world space.
    public func terrainMesh() -> MeshData { TerrainBuilder(style: theme.terrain, seed: seed).build(room: room) }

    /// Ceiling mesh in world space, when the theme has a ceiling.
    public func ceilingMesh() -> MeshData? {
        guard theme.ceiling == .flat, room.outline.count >= 3 else { return nil }
        var m = MeshData()
        for tri in Triangulate.fan(room.outline) {
            m.addPolygon(tri.map { SIMD3($0.x, room.ceilingY, $0.y) }, role: .trim, outward: SIMD3(0, -1, 0))
        }
        return m
    }

    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }

    public static func decode(_ data: Data) throws -> WorldSpec { try JSONDecoder().decode(WorldSpec.self, from: data) }
}

enum Triangulate {
    /// Fan triangulation of a convex polygon.
    static func fan(_ poly: [SIMD2<Float>]) -> [[SIMD2<Float>]] {
        guard poly.count >= 3 else { return [] }
        return (1..<(poly.count - 1)).map { [poly[0], poly[$0], poly[$0 + 1]] }
    }
}
