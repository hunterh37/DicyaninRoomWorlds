import Foundation
import simd

/// Concrete look for a material role.
public struct MaterialStyle: Codable, Sendable, Hashable {
    /// sRGB 0xRRGGBB.
    public var color: UInt32
    public var roughness: Float
    public var metallic: Float
    /// Emissive intensity multiplier using `color`. 0 is non-emissive.
    public var emissive: Float
    public var opacity: Float

    public init(_ color: UInt32, roughness: Float = 0.85, metallic: Float = 0, emissive: Float = 0, opacity: Float = 1) {
        self.color = color; self.roughness = roughness; self.metallic = metallic; self.emissive = emissive; self.opacity = opacity
    }

    public var rgb: SIMD3<Float> {
        SIMD3(Float((color >> 16) & 0xFF), Float((color >> 8) & 0xFF), Float(color & 0xFF)) / 255
    }
}

/// Scatter rule for floor decor.
public struct DecorRule: Codable, Sendable, Hashable {
    public var blueprint: String
    /// Expected instances per m^2 of free floor.
    public var density: Float
    /// Minimum walkable clearance (m) at the spawn point. Decor stays out of narrow walkways.
    public var minClearance: Float
    /// Prefer cells near walls and furniture (0) or open floor (1).
    public var openness: Float

    public init(_ blueprint: String, density: Float, minClearance: Float = 0.15, openness: Float = 0.5) {
        self.blueprint = blueprint; self.density = density; self.minClearance = minClearance; self.openness = openness
    }
}

public struct TerrainStyle: Codable, Sendable, Hashable {
    /// Terrain triangle size, meters.
    public var cell: Float = 0.3
    /// Height noise on walkable floor. Keep small: the real floor is flat.
    public var bump: Float = 0.012
    /// Rise of the ground toward walls and outside the room (hills, dunes, drifts).
    public var rimHeight: Float = 0.25
    /// World-space scale of the two-tone ground patches.
    public var patchScale: Float = 1.3
    /// Fraction of ground triangles in `groundAlt`.
    public var patchCoverage: Float = 0.35
    /// How far the terrain extends past the walls, meters.
    public var apron: Float = 1.2
    public init() {}
}

public struct SkyStyle: Codable, Sendable, Hashable {
    public var zenith: UInt32
    public var horizon: UInt32
    public var sunColor: UInt32
    public var sunIntensity: Float
    public var ambient: Float
    public init(zenith: UInt32, horizon: UInt32, sunColor: UInt32, sunIntensity: Float = 1, ambient: Float = 0.5) {
        self.zenith = zenith; self.horizon = horizon; self.sunColor = sunColor; self.sunIntensity = sunIntensity; self.ambient = ambient
    }
}

/// A world style: palette, archetype to blueprint mapping, boundary, openings, decor, terrain, sky.
public struct WorldTheme: Codable, Sendable, Identifiable, Hashable {
    public enum Ceiling: String, Codable, Sendable { case open, flat }

    public var id: String
    public var name: String
    public var palette: [MaterialRole: MaterialStyle]
    /// Blueprint variants per archetype; the generator picks one per object by seed.
    public var furniture: [Archetype: [String]]
    /// Blueprints tiled along walls.
    public var boundary: [String]
    /// Spacing of boundary pieces along the wall, meters.
    public var boundarySpacing: Float
    /// Boundary depth (thickness away from the wall), meters.
    public var boundaryDepth: ClosedRange<Float>
    /// Boundary height as a multiple of the wall height.
    public var boundaryHeight: ClosedRange<Float>
    /// 0 places boundary pieces on a clean grid (paneling); 1 scatters them organically (tree lines).
    public var boundaryJitter: Float
    public var door: String?
    public var window: String?
    public var decor: [DecorRule]
    public var terrain: TerrainStyle
    public var sky: SkyStyle
    public var ceiling: Ceiling

    public init(id: String, name: String, palette: [MaterialRole: MaterialStyle], furniture: [Archetype: [String]],
                boundary: [String], boundarySpacing: Float = 0.9, boundaryDepth: ClosedRange<Float> = 0.4...0.7,
                boundaryHeight: ClosedRange<Float> = 0.85...1.1, boundaryJitter: Float = 1, door: String?, window: String?, decor: [DecorRule],
                terrain: TerrainStyle = TerrainStyle(), sky: SkyStyle, ceiling: Ceiling = .open) {
        self.id = id; self.name = name; self.palette = palette; self.furniture = furniture; self.boundary = boundary
        self.boundarySpacing = boundarySpacing; self.boundaryDepth = boundaryDepth; self.boundaryHeight = boundaryHeight
        self.boundaryJitter = boundaryJitter
        self.door = door; self.window = window; self.decor = decor; self.terrain = terrain; self.sky = sky; self.ceiling = ceiling
    }

    /// Material for `role`, falling back to `primary` then neutral gray.
    public func material(_ role: MaterialRole) -> MaterialStyle {
        palette[role] ?? palette[.primary] ?? MaterialStyle(0x9A9A9A)
    }
}
