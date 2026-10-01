import Foundation
import simd

/// Oriented box resting in world space. Local +Z is the object's front, local X its width.
public struct FittedBox: Codable, Sendable, Hashable {
    /// World-space center of the box volume.
    public var center: SIMD3<Float>
    /// Width (local X), height (Y), depth (local Z).
    public var size: SIMD3<Float>
    /// Rotation about +Y mapping local +Z to (sin, 0, cos).
    public var yaw: Float

    public init(center: SIMD3<Float>, size: SIMD3<Float>, yaw: Float) {
        self.center = center
        self.size = size
        self.yaw = yaw
    }

    public var bottomY: Float { center.y - size.y / 2 }
    public var topY: Float { center.y + size.y / 2 }
    /// Bottom-center point (where the object touches its support).
    public var basePosition: SIMD3<Float> { SIMD3(center.x, bottomY, center.z) }
    public var front: SIMD2<Float> { SIMD2(sin(yaw), cos(yaw)) }
    public var right: SIMD2<Float> { SIMD2(cos(yaw), -sin(yaw)) }

    /// Footprint corners on the XZ plane, counter-clockwise.
    public var footprint: [SIMD2<Float>] {
        let c = SIMD2(center.x, center.z), hx = right * size.x / 2, hz = front * size.z / 2
        return [c - hx - hz, c + hx - hz, c + hx + hz, c - hx + hz]
    }

    /// True when the XZ point lies inside the footprint expanded by `margin`.
    public func footprintContains(_ p: SIMD2<Float>, margin: Float = 0) -> Bool {
        let d = p - SIMD2(center.x, center.z)
        return abs(simd_dot(d, right)) <= size.x / 2 + margin && abs(simd_dot(d, front)) <= size.z / 2 + margin
    }
}

/// Furniture and fixture roles an object can play. The asset library maps each to blueprints.
public enum Archetype: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable, Hashable {
    case diningTable, coffeeTable, sideTable, desk, counter
    case chair, armchair, sofa, stool, bed
    case lowCabinet, wardrobe, shelf, appliance, tallAppliance, tv, plant, stairs
    case clutter
}

/// One segmented, measured object in the room.
public struct DetectedObject: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    /// Dominant ARKit label of the faces in the segment.
    public var label: SurfaceLabel
    public var archetype: Archetype
    public var box: FittedBox
    /// Height of the main horizontal surface above the box bottom (table top, seat), when found.
    public var surfaceHeight: Float?
    /// Scanned surface area in m^2.
    public var area: Float
    /// Posterior probability of `archetype` against the other candidates (0...1).
    public var confidence: Float
    /// Wall the object backs onto, if within 0.35 m.
    public var wallID: String?
    /// Runner-up archetypes with their probabilities.
    public var alternatives: [Candidate]

    public struct Candidate: Codable, Sendable, Hashable {
        public var archetype: Archetype
        public var probability: Float
    }
}

/// A vertical wall piece projected onto the floor.
public struct WallSegment: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var start: SIMD2<Float>
    public var end: SIMD2<Float>
    /// Unit XZ normal pointing into the room.
    public var normal: SIMD2<Float>
    public var bottomY: Float
    public var topY: Float
    public var area: Float

    public var length: Float { simd_distance(start, end) }
    public var tangent: SIMD2<Float> { simd_normalize(end - start) }
    public var midpoint: SIMD2<Float> { (start + end) / 2 }
    public var height: Float { topY - bottomY }
    /// Yaw that faces into the room (local +Z along `normal`).
    public var inwardYaw: Float { Yaw.facing(normal) }
}

/// A window or door cut into a wall.
public struct WallOpening: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case window, door }
    public var id: String
    public var kind: Kind
    public var wallID: String?
    /// XZ center on the wall line.
    public var center: SIMD2<Float>
    public var width: Float
    public var bottomY: Float
    public var topY: Float
    /// Unit XZ normal pointing into the room.
    public var normal: SIMD2<Float>
}

/// Structured room understanding produced by `RoomAnalyzer`. World frame, meters, Y-up.
public struct RoomModel: Codable, Sendable {
    public var floorY: Float
    public var ceilingY: Float
    /// Dominant wall direction in (-pi/4, pi/4]. Rotating the world by -yaw aligns walls to X/Z.
    public var manhattanYaw: Float
    /// Circular concentration of wall normals around the Manhattan frame (0 random, 1 perfect box room).
    public var manhattanConfidence: Float
    public var walls: [WallSegment]
    public var openings: [WallOpening]
    public var objects: [DetectedObject]
    /// Convex floor outline on XZ, counter-clockwise.
    public var outline: [SIMD2<Float>]
    public var grid: FloorGrid

    public var ceilingHeight: Float { ceilingY - floorY }
    public var floorArea: Float { abs(Polygon2D.area(outline)) }
    public var center: SIMD2<Float> { outline.isEmpty ? .zero : outline.reduce(.zero, +) / Float(outline.count) }

    public func objects(_ archetype: Archetype) -> [DetectedObject] { objects.filter { $0.archetype == archetype } }
    public func wall(id: String?) -> WallSegment? { walls.first { $0.id == id } }
}
