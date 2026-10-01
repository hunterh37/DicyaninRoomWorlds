#if canImport(RealityKit)
import Foundation
import RealityKit
import simd

/// ECS tag on every generated entity. Query it to find furniture stand-ins, boundary pieces,
/// openings and decor, and map them back to the scanned object (`sourceID`).
public struct RoomWorldComponent: Component, Codable, Sendable {
    public var instanceID: String
    public var role: WorldInstance.Role
    public var blueprintID: String
    public var sourceID: String?
    public var archetype: Archetype?
}

/// Marks the functional surface of a furniture stand-in (seat or table top) for gameplay:
/// height above the entity origin and the surface footprint.
public struct WorldSurfaceComponent: Component, Codable, Sendable {
    public var height: Float
    public var size: SIMD2<Float>
}

@MainActor
public enum WorldEntityBuilder {
    public struct Options: Sendable {
        public var includeTerrain = true
        public var includeCeiling = true
        public var includeSky = false
        public var includeLighting = true
        /// Box colliders (and static physics bodies) on furniture, boundary and terrain.
        public var collisions = true
        public var physicsBodies = false
        /// Merges decor into one mesh per `chunkSize` tile. Cuts draw calls by 10 to 100x.
        public var batchDecor = true
        public var chunkSize: Float = 2.5
        /// Unlit materials (flat toon look, cheapest to render).
        public var unlit = false
        public var skyRadius: Float = 40
        public init() {}
    }

    /// Builds the whole world under one root. Entities are in world space (the scan's ARKit frame),
    /// so add the root to an immersive space with an identity transform.
    public static func build(_ spec: WorldSpec, library: AssetLibrary = .standard, options: Options = Options()) throws -> Entity {
        RoomWorldComponent.registerComponent()
        WorldSurfaceComponent.registerComponent()
        let root = Entity()
        root.name = "RoomWorld.\(spec.theme.id)"
        let mats = materials(spec.theme, unlit: options.unlit)

        if options.includeTerrain {
            let terrain = try model(spec.terrainMesh(), mats, name: "Terrain")
            if options.collisions, spec.room.outline.count >= 3 {
                let b = spec.room.grid
                let ext = SIMD2(Float(b.columns), Float(b.rows)) * b.cellSize
                let center = b.toWorld(b.origin + ext / 2)
                let shape = ShapeResource.generateBox(size: SIMD3(ext.x, 0.02, ext.y))
                    .offsetBy(rotation: Yaw.quaternion(b.yaw), translation: SIMD3(center.x, spec.room.floorY - 0.01, center.y))
                terrain.components.set(CollisionComponent(shapes: [shape], isStatic: true))
                if options.physicsBodies { terrain.components.set(PhysicsBodyComponent(mode: .static)) }
            }
            root.addChild(terrain)
        }
        if options.includeCeiling, let ceiling = spec.ceilingMesh() { root.addChild(try model(ceiling, mats, name: "Ceiling")) }

        let groups: [(String, WorldInstance.Role)] = [("Furniture", .furniture), ("Boundary", .boundary), ("Openings", .opening)]
        for (name, role) in groups {
            let parent = Entity()
            parent.name = name
            for inst in spec.instances(role) {
                guard let mesh = spec.mesh(for: inst, library: library), !mesh.isEmpty else { continue }
                let e = try model(mesh, mats, name: inst.id)
                e.transform = Transform(scale: .one, rotation: Yaw.quaternion(inst.yaw), translation: inst.position)
                e.components.set(RoomWorldComponent(instanceID: inst.id, role: inst.role, blueprintID: inst.blueprintID,
                                                    sourceID: inst.sourceID, archetype: inst.archetype))
                if let s = inst.surface { e.components.set(WorldSurfaceComponent(height: s, size: SIMD2(inst.size.x, inst.size.z))) }
                if options.collisions && inst.collides {
                    let shape = ShapeResource.generateBox(size: inst.size).offsetBy(translation: SIMD3(0, inst.size.y / 2, 0))
                    e.components.set(CollisionComponent(shapes: [shape], isStatic: true))
                    if options.physicsBodies { e.components.set(PhysicsBodyComponent(mode: .static)) }
                }
                parent.addChild(e)
            }
            root.addChild(parent)
        }

        let decorRoot = Entity()
        decorRoot.name = "Decor"
        let decor = spec.instances(.decor)
        if options.batchDecor {
            var chunks: [SIMD2<Int32>: MeshData] = [:]
            for inst in decor {
                guard let mesh = spec.mesh(for: inst, library: library) else { continue }
                let key = SIMD2(Int32((inst.position.x / options.chunkSize).rounded(.down)), Int32((inst.position.z / options.chunkSize).rounded(.down)))
                chunks[key, default: MeshData()].append(mesh, transform: inst.transform)
            }
            for (key, mesh) in chunks.sorted(by: { ($0.key.x, $0.key.y) < ($1.key.x, $1.key.y) }) {
                decorRoot.addChild(try model(mesh, mats, name: "DecorChunk_\(key.x)_\(key.y)"))
            }
        } else {
            for inst in decor {
                guard let mesh = spec.mesh(for: inst, library: library) else { continue }
                let e = try model(mesh, mats, name: inst.id)
                e.transform = Transform(scale: .one, rotation: Yaw.quaternion(inst.yaw), translation: inst.position)
                e.components.set(RoomWorldComponent(instanceID: inst.id, role: .decor, blueprintID: inst.blueprintID, sourceID: nil, archetype: nil))
                decorRoot.addChild(e)
            }
        }
        root.addChild(decorRoot)

        if options.includeLighting { root.addChild(WorldAtmosphere.sun(spec.theme, room: spec.room)) }
        if options.includeSky, let sky = try? WorldAtmosphere.skyDome(spec.theme, radius: options.skyRadius) {
            sky.position = SIMD3(spec.room.center.x, spec.room.floorY, spec.room.center.y)
            root.addChild(sky)
        }
        return root
    }

    /// Single fitted asset in its local frame (bottom center at origin, front +Z).
    public static func entity(for blueprint: AssetBlueprint, theme: WorldTheme, size: SIMD3<Float>? = nil,
                              surface: Float? = nil, seed: UInt64 = 0, unlit: Bool = false) throws -> ModelEntity {
        try model(blueprint.mesh(size: size, surface: surface, seed: seed), materials(theme, unlit: unlit), name: blueprint.id)
    }

    /// One ModelEntity with a submesh per material role.
    public static func model(_ mesh: MeshData, _ mats: [MaterialRole: RealityKit.Material], name: String) throws -> ModelEntity {
        var descriptors: [MeshDescriptor] = []
        var materials: [RealityKit.Material] = []
        for role in MaterialRole.allCases {
            guard let g = mesh.groups[role], !g.indices.isEmpty else { continue }
            var d = MeshDescriptor(name: "\(name).\(role.rawValue)")
            d.positions = MeshBuffers.Positions(g.positions)
            d.normals = MeshBuffers.Normals(g.normals)
            d.primitives = .triangles(g.indices)
            d.materials = .allFaces(UInt32(materials.count))
            descriptors.append(d)
            materials.append(mats[role] ?? SimpleMaterial())
        }
        let e = ModelEntity()
        e.name = name
        guard !descriptors.isEmpty else { return e }
        e.model = ModelComponent(mesh: try MeshResource.generate(from: descriptors), materials: materials)
        return e
    }

    /// RealityKit material per role for a theme.
    public static func materials(_ theme: WorldTheme, unlit: Bool = false) -> [MaterialRole: RealityKit.Material] {
        var out: [MaterialRole: RealityKit.Material] = [:]
        for role in MaterialRole.allCases {
            let s = theme.material(role)
            let c = s.rgb
            let color = PlatformColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1)
            if unlit || s.emissive > 1.5 {
                var m = UnlitMaterial(color: color)
                if s.opacity < 0.999 { m.blending = .transparent(opacity: .init(floatLiteral: s.opacity)) }
                out[role] = m
                continue
            }
            var m = PhysicallyBasedMaterial()
            m.baseColor = .init(tint: color)
            m.roughness = .init(floatLiteral: s.roughness)
            m.metallic = .init(floatLiteral: s.metallic)
            if s.emissive > 0 {
                m.emissiveColor = .init(color: color)
                m.emissiveIntensity = s.emissive
            }
            if s.opacity < 0.999 { m.blending = .transparent(opacity: .init(floatLiteral: s.opacity)) }
            out[role] = m
        }
        return out
    }
}
#endif
