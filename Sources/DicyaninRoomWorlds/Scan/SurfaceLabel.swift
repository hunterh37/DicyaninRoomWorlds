import Foundation

/// Semantic label for a scanned surface. Raw values match ARKit's face classification byte
/// on visionOS (`SurfaceClassification` / `MeshAnchor.MeshClassification`) and iOS
/// (`ARMeshClassification`, which uses the first eight cases).
public enum SurfaceLabel: UInt8, Codable, Sendable, CaseIterable, Hashable {
    case none = 0
    case wall
    case floor
    case ceiling
    case table
    case seat
    case window
    case door
    case stairs
    case bed
    case cabinet
    case homeAppliance
    case tv
    case plant

    /// Room shell surfaces (walls, floor, ceiling).
    public var isStructural: Bool { self == .wall || self == .floor || self == .ceiling }

    /// Surfaces that cut into a wall.
    public var isOpening: Bool { self == .window || self == .door }

    /// Surfaces that belong to a movable or built-in object.
    public var isObject: Bool {
        switch self {
        case .table, .seat, .stairs, .bed, .cabinet, .homeAppliance, .tv, .plant: return true
        default: return false
        }
    }

    /// Initializes from the raw ARKit classification byte. Unknown values map to `.none`.
    public init(arkitRaw value: Int) {
        self = SurfaceLabel(rawValue: UInt8(clamping: value)) ?? .none
    }

    /// Debug color (sRGB hex) used by scan previews.
    public var debugColor: UInt32 {
        switch self {
        case .none: return 0x8A8F98
        case .wall: return 0x5B8DEF
        case .floor: return 0x3FB37F
        case .ceiling: return 0xC9D3E3
        case .table: return 0xF2A541
        case .seat: return 0xE4572E
        case .window: return 0x7FDBFF
        case .door: return 0x9D6B53
        case .stairs: return 0xB388EB
        case .bed: return 0xF7A1C4
        case .cabinet: return 0xA47148
        case .homeAppliance: return 0xD9D9D9
        case .tv: return 0x2D2D34
        case .plant: return 0x6CC24A
        }
    }
}
