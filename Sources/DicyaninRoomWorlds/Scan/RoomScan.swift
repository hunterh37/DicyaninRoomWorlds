import Foundation
import simd

/// One chunk of reconstructed room mesh in world space (meters, Y-up).
/// `faceLabels` holds one label per triangle (`indices.count / 3` entries).
public struct ScanMesh: Codable, Sendable, Hashable {
    public var id: UUID
    public var positions: [SIMD3<Float>]
    public var indices: [UInt32]
    public var faceLabels: [SurfaceLabel]

    public init(id: UUID = UUID(), positions: [SIMD3<Float>], indices: [UInt32], faceLabels: [SurfaceLabel]) {
        self.id = id
        self.positions = positions
        self.indices = indices
        self.faceLabels = faceLabels
    }

    public var faceCount: Int { indices.count / 3 }

    /// Label for face `f`; `.none` when labels are missing.
    @inlinable public func label(ofFace f: Int) -> SurfaceLabel {
        f < faceLabels.count ? faceLabels[f] : .none
    }
}

/// A detected plane (ARKit plane anchor) flattened to world space.
public struct ScanPlane: Codable, Sendable, Hashable {
    public var id: UUID
    public var label: SurfaceLabel
    /// World-space center of the plane extent.
    public var center: SIMD3<Float>
    /// World-space unit normal.
    public var normal: SIMD3<Float>
    /// World-space unit axis along `width`.
    public var widthAxis: SIMD3<Float>
    public var width: Float
    public var height: Float

    public init(id: UUID = UUID(), label: SurfaceLabel, center: SIMD3<Float>, normal: SIMD3<Float>,
                widthAxis: SIMD3<Float>, width: Float, height: Float) {
        self.id = id
        self.label = label
        self.center = center
        self.normal = normal
        self.widthAxis = widthAxis
        self.width = width
        self.height = height
    }
}

/// Raw room capture: classified mesh chunks plus optional planes. Platform independent,
/// Codable for saving and replaying scans in tests or the simulator.
public struct RoomScan: Codable, Sendable {
    public var version: Int = 1
    public var source: String
    public var capturedAt: Date
    public var meshes: [ScanMesh]
    public var planes: [ScanPlane]

    public init(source: String, capturedAt: Date = Date(), meshes: [ScanMesh], planes: [ScanPlane] = []) {
        self.source = source
        self.capturedAt = capturedAt
        self.meshes = meshes
        self.planes = planes
    }

    public var faceCount: Int { meshes.reduce(0) { $0 + $1.faceCount } }

    /// Surface area per label in square meters.
    public func areaByLabel() -> [SurfaceLabel: Float] {
        var out: [SurfaceLabel: Float] = [:]
        for m in meshes {
            for f in 0..<m.faceCount {
                let a = m.positions[Int(m.indices[f * 3])]
                let b = m.positions[Int(m.indices[f * 3 + 1])]
                let c = m.positions[Int(m.indices[f * 3 + 2])]
                out[m.label(ofFace: f), default: 0] += 0.5 * simd_length(simd_cross(b - a, c - a))
            }
        }
        return out
    }

    /// Binary property-list encoding (smaller and faster than JSON for large meshes).
    public func encoded() throws -> Data {
        let enc = PropertyListEncoder()
        enc.outputFormat = .binary
        return try enc.encode(self)
    }

    public static func decode(_ data: Data) throws -> RoomScan {
        try PropertyListDecoder().decode(RoomScan.self, from: data)
    }
}

/// Rough scan completeness, computed from labeled area. Drives "keep looking around" UX.
public struct ScanCoverage: Sendable, Hashable {
    public var floorArea: Float
    public var wallArea: Float
    public var objectArea: Float
    public var faceCount: Int
    /// Wall facing directions seen with at least 0.5 m^2 of area, in 45 degree bins (0...8).
    public var wallDirections: Int

    public init(floorArea: Float = 0, wallArea: Float = 0, objectArea: Float = 0, faceCount: Int = 0, wallDirections: Int = 0) {
        self.floorArea = floorArea
        self.wallArea = wallArea
        self.objectArea = objectArea
        self.faceCount = faceCount
        self.wallDirections = wallDirections
    }

    /// 0...1 progress estimate. Saturates at 6 m^2 of floor, 10 m^2 of wall and 4 wall directions.
    public var progress: Float {
        let f = min(1, floorArea / 6), w = min(1, wallArea / 10), d = min(1, Float(wallDirections) / 4)
        return 0.4 * f + 0.35 * w + 0.25 * d
    }

    /// True when enough of the room is mapped to build a world.
    public var isSufficient: Bool { floorArea >= 3 && wallArea >= 4 && wallDirections >= 2 }

    public static func measure(_ scan: RoomScan) -> ScanCoverage {
        var cov = ScanCoverage(faceCount: scan.faceCount)
        var dirArea = [Float](repeating: 0, count: 8)
        for m in scan.meshes {
            for f in 0..<m.faceCount {
                let a = m.positions[Int(m.indices[f * 3])]
                let b = m.positions[Int(m.indices[f * 3 + 1])]
                let c = m.positions[Int(m.indices[f * 3 + 2])]
                let cr = simd_cross(b - a, c - a)
                let area = 0.5 * simd_length(cr)
                switch m.label(ofFace: f) {
                case .floor: cov.floorArea += area
                case .wall:
                    cov.wallArea += area
                    let n = cr / max(2 * area, 1e-9)
                    let bin = Int(((atan2(n.x, n.z) + .pi) / (.pi / 4)).rounded(.down)) % 8
                    dirArea[bin] += area
                case let l where l.isObject: cov.objectArea += area
                default: break
                }
            }
        }
        cov.wallDirections = dirArea.filter { $0 >= 0.5 }.count
        return cov
    }
}
