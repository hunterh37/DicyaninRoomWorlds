import Foundation
import simd

/// Procedural labeled room scans for tests, previews and the visionOS simulator
/// (which has no scene reconstruction). Surfaces are tessellated like ARKit output
/// (small triangles, per-face labels, optional noise) and split into chunks.
public enum SyntheticRoom {
    public enum Shape: Sendable {
        case box
        /// Slab top of the given thickness on four legs.
        case table(top: Float)
        /// Seat slab at `seat` height with a backrest along local -Z, optional arms.
        case seat(seat: Float, back: Float, arms: Bool)
        /// Mattress of height `mattress` with a headboard along local -Z.
        case bed(mattress: Float)
    }

    public struct Item: Sendable {
        public var label: SurfaceLabel
        public var shape: Shape
        /// Room-local XZ center of the footprint.
        public var center: SIMD2<Float>
        /// Width (local X), height, depth (local Z).
        public var size: SIMD3<Float>
        public var yaw: Float
        public var elevation: Float
        public init(_ label: SurfaceLabel, _ shape: Shape, center: SIMD2<Float>, size: SIMD3<Float>, yaw: Float = 0, elevation: Float = 0) {
            self.label = label; self.shape = shape; self.center = center; self.size = size; self.yaw = yaw; self.elevation = elevation
        }
    }

    public struct Layout: Sendable {
        public var width: Float
        public var depth: Float
        public var height: Float
        public var items: [Item]
        /// Window on the +Z wall: (center x, width, sill, top).
        public var window: SIMD4<Float>?
        /// Door on the -X wall: (center z, width, top).
        public var door: SIMD3<Float>?
        public init(width: Float, depth: Float, height: Float, items: [Item], window: SIMD4<Float>? = nil, door: SIMD3<Float>? = nil) {
            self.width = width; self.depth = depth; self.height = height; self.items = items; self.window = window; self.door = door
        }
    }

    /// 5 x 4 m living room: sofa facing a TV, coffee table, armchair, dining set, shelf, plant.
    public static let livingRoomLayout = Layout(width: 5, depth: 4, height: 2.6, items: [
        Item(.seat, .seat(seat: 0.44, back: 0.85, arms: true), center: [0.2, -1.5], size: [2.1, 0.85, 0.9]),
        Item(.table, .table(top: 0.05), center: [0.2, -0.35], size: [1.1, 0.42, 0.6]),
        Item(.tv, .box, center: [0.2, 1.93], size: [1.3, 0.75, 0.1], yaw: .pi, elevation: 0.9),
        Item(.cabinet, .box, center: [0.2, 1.75], size: [1.6, 0.5, 0.45], yaw: .pi),
        Item(.seat, .seat(seat: 0.45, back: 0.9, arms: true), center: [-1.6, -0.2], size: [0.85, 0.9, 0.85], yaw: .pi / 2),
        Item(.table, .table(top: 0.04), center: [1.75, 0.2], size: [1.4, 0.75, 0.85], yaw: .pi / 2),
        Item(.seat, .seat(seat: 0.46, back: 0.88, arms: false), center: [1.0, 0.2], size: [0.46, 0.88, 0.48], yaw: .pi / 2),
        Item(.cabinet, .box, center: [-2.3, 1.3], size: [0.9, 1.85, 0.35], yaw: .pi / 2),
        Item(.plant, .box, center: [2.2, -1.7], size: [0.45, 1.1, 0.45]),
        Item(.none, .box, center: [-1.0, 1.4], size: [0.45, 0.35, 0.4]),
    ], window: [-1.4, 1.4, 0.9, 2.1], door: [-1.2, 0.9, 2.05])

    /// Builds a scan of `layout` rotated by `yaw` and translated by `offset` (floor at offset.y).
    public static func scan(_ layout: Layout = livingRoomLayout, yaw: Float = 0.3, offset: SIMD3<Float> = [0.4, -1.3, -0.7],
                            noise: Float = 0.004, tessellation: Float = 0.1, seed: UInt64 = 7) -> RoomScan {
        var b = Builder(step: tessellation, noise: noise, rng: SeededRandom(seed: seed))
        let W = layout.width / 2, D = layout.depth / 2, H = layout.height
        b.rect(o: [-W, 0, -D], u: [2 * W, 0, 0], v: [0, 0, 2 * D], normal: [0, 1, 0], label: .floor)
        b.rect(o: [-W, H, -D], u: [2 * W, 0, 0], v: [0, 0, 2 * D], normal: [0, -1, 0], label: .ceiling)
        let window = layout.window, door = layout.door
        b.rect(o: [-W, 0, D], u: [2 * W, 0, 0], v: [0, H, 0], normal: [0, 0, -1], label: .wall) { p in
            guard let w = window, abs(p.x - w.x) < w.y / 2, p.y > w.z, p.y < w.w else { return .wall }
            return .window
        }
        b.rect(o: [-W, 0, -D], u: [2 * W, 0, 0], v: [0, H, 0], normal: [0, 0, 1], label: .wall)
        b.rect(o: [W, 0, -D], u: [0, 0, 2 * D], v: [0, H, 0], normal: [-1, 0, 0], label: .wall)
        b.rect(o: [-W, 0, -D], u: [0, 0, 2 * D], v: [0, H, 0], normal: [1, 0, 0], label: .wall) { p in
            guard let d = door, abs(p.z - d.x) < d.y / 2, p.y < d.z else { return .wall }
            return .door
        }
        for item in layout.items { b.item(item) }

        let c = cos(yaw), s = sin(yaw)
        let meshes = b.meshes.map { m -> ScanMesh in
            var m = m
            m.positions = m.positions.map { p in SIMD3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z) + offset }
            return m
        }
        return RoomScan(source: "synthetic", capturedAt: Date(timeIntervalSince1970: 0), meshes: meshes)
    }

    struct Builder {
        var step: Float
        var noise: Float
        var rng: SeededRandom
        var meshes: [ScanMesh] = []

        /// Tessellated rectangle o + a*u + b*v, wound so faces point along `normal`.
        mutating func rect(o: SIMD3<Float>, u: SIMD3<Float>, v: SIMD3<Float>, normal: SIMD3<Float>, label: SurfaceLabel,
                           labelAt: ((SIMD3<Float>) -> SurfaceLabel)? = nil) {
            let nu = max(1, Int((simd_length(u) / step).rounded())), nv = max(1, Int((simd_length(v) / step).rounded()))
            var pos: [SIMD3<Float>] = [], idx: [UInt32] = [], labels: [SurfaceLabel] = []
            for j in 0...nv {
                for i in 0...nu {
                    let p = o + u * (Float(i) / Float(nu)) + v * (Float(j) / Float(nv))
                    pos.append(p + normal * rng.jitter(noise))
                }
            }
            let flip = simd_dot(simd_cross(u, v), normal) < 0
            for j in 0..<nv {
                for i in 0..<nu {
                    let a = UInt32(j * (nu + 1) + i), b = a + 1, c = a + UInt32(nu + 1), d = c + 1
                    let tris: [[UInt32]] = flip ? [[a, c, b], [b, c, d]] : [[a, b, c], [b, d, c]]
                    for t in tris {
                        idx += t
                        let center = o + u * ((Float(i) + 0.5) / Float(nu)) + v * ((Float(j) + 0.5) / Float(nv))
                        labels.append(labelAt?(center) ?? label)
                    }
                }
            }
            meshes.append(ScanMesh(positions: pos, indices: idx, faceLabels: labels))
        }

        /// Open-bottom box in item-local space [lo, hi], transformed by the item pose.
        mutating func box(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>, label: SurfaceLabel, pose: (SIMD3<Float>) -> SIMD3<Float>, rot: (SIMD3<Float>) -> SIMD3<Float>) {
            let d = hi - lo
            let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
                (SIMD3(lo.x, hi.y, lo.z), [d.x, 0, 0], [0, 0, d.z], [0, 1, 0]),
                (SIMD3(lo.x, lo.y, hi.z), [d.x, 0, 0], [0, d.y, 0], [0, 0, 1]),
                (lo, [d.x, 0, 0], [0, d.y, 0], [0, 0, -1]),
                (SIMD3(hi.x, lo.y, lo.z), [0, 0, d.z], [0, d.y, 0], [1, 0, 0]),
                (lo, [0, 0, d.z], [0, d.y, 0], [-1, 0, 0]),
            ]
            for (o, u, v, n) in faces {
                rect(o: pose(o), u: rot(u), v: rot(v), normal: rot(n), label: label)
            }
        }

        mutating func item(_ it: Item) {
            let c = cos(it.yaw), s = sin(it.yaw)
            let rot: (SIMD3<Float>) -> SIMD3<Float> = { p in SIMD3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z) }
            let pose: (SIMD3<Float>) -> SIMD3<Float> = { p in rot(p) + SIMD3(it.center.x, it.elevation, it.center.y) }
            let w = it.size.x / 2, h = it.size.y, d = it.size.z / 2
            switch it.shape {
            case .box:
                box([-w, 0, -d], [w, h, d], label: it.label, pose: pose, rot: rot)
            case let .table(top):
                box([-w, h - top, -d], [w, h, d], label: it.label, pose: pose, rot: rot)
                for sx in [-1, 1] as [Float] {
                    for sz in [-1, 1] as [Float] {
                        let x = sx * (w - 0.06), z = sz * (d - 0.06)
                        box([x - 0.025, 0, z - 0.025], [x + 0.025, h - top, z + 0.025], label: .none, pose: pose, rot: rot)
                    }
                }
            case let .seat(seat, back, arms):
                box([-w, 0, -d + 0.18], [w, seat, d], label: it.label, pose: pose, rot: rot)
                box([-w, 0, -d], [w, back, -d + 0.18], label: it.label, pose: pose, rot: rot)
                if arms {
                    box([-w, seat, -d + 0.18], [-w + 0.14, seat + 0.2, d], label: it.label, pose: pose, rot: rot)
                    box([w - 0.14, seat, -d + 0.18], [w, seat + 0.2, d], label: it.label, pose: pose, rot: rot)
                }
            case let .bed(mattress):
                box([-w, 0, -d + 0.08], [w, mattress, d], label: it.label, pose: pose, rot: rot)
                box([-w, 0, -d], [w, h, -d + 0.08], label: it.label, pose: pose, rot: rot)
            }
        }
    }
}
