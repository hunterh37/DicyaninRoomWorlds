#if canImport(ARKit) && (os(visionOS) || os(iOS))
import ARKit
import simd

/// Reads an indexed buffer of 16- or 32-bit indices.
@inline(__always)
func readIndex(_ base: UnsafeRawPointer, _ i: Int, bytes: Int) -> UInt32 {
    bytes == 2 ? UInt32(base.load(fromByteOffset: i * 2, as: UInt16.self)) : base.load(fromByteOffset: i * 4, as: UInt32.self)
}

@inline(__always)
func transformPoint(_ m: simd_float4x4, _ p: SIMD3<Float>) -> SIMD3<Float> {
    let q = m * SIMD4(p, 1)
    return SIMD3(q.x, q.y, q.z)
}
#endif

#if canImport(ARKit) && os(visionOS)
public extension ScanMesh {
    /// Copies a visionOS scene-reconstruction anchor into world space.
    /// Run the provider with `modes: [.classification]` to get per-face labels.
    @MainActor
    init(meshAnchor anchor: MeshAnchor) {
        let g = anchor.geometry, T = anchor.originFromAnchorTransform
        let vs = g.vertices
        let vbase = UnsafeRawPointer(vs.buffer.contents()).advanced(by: vs.offset)
        var positions = [SIMD3<Float>](repeating: .zero, count: vs.count)
        for i in 0..<vs.count {
            let p = vbase.advanced(by: i * vs.stride).assumingMemoryBound(to: Float.self)
            positions[i] = transformPoint(T, SIMD3(p[0], p[1], p[2]))
        }
        let faces = g.faces
        let per = faces.primitive.indexCount
        let ibase = UnsafeRawPointer(faces.buffer.contents())
        var indices = [UInt32](); indices.reserveCapacity(faces.count * 3)
        var labels = [SurfaceLabel](); labels.reserveCapacity(faces.count)
        let cls = g.classifications
        let cbase = cls.map { UnsafeRawPointer($0.buffer.contents()).advanced(by: $0.offset) }
        for f in 0..<faces.count where per == 3 {
            for k in 0..<3 { indices.append(readIndex(ibase, f * per + k, bytes: faces.bytesPerIndex)) }
            if let cls, let cbase, f < cls.count {
                labels.append(SurfaceLabel(arkitRaw: Int(cbase.load(fromByteOffset: f * cls.stride, as: UInt8.self))))
            } else {
                labels.append(.none)
            }
        }
        self.init(id: anchor.id, positions: positions, indices: indices, faceLabels: labels)
    }
}

public extension ScanPlane {
    /// Flattens a visionOS plane anchor. Normal and extents come from the plane's own mesh,
    /// so no assumption about the anchor's local axis convention is needed.
    @MainActor
    init?(planeAnchor a: PlaneAnchor) {
        let mv = a.geometry.meshVertices, mf = a.geometry.meshFaces
        guard mv.count >= 3, mf.count >= 1 else { return nil }
        let T = a.originFromAnchorTransform
        let vbase = UnsafeRawPointer(mv.buffer.contents()).advanced(by: mv.offset)
        let pts: [SIMD3<Float>] = (0..<mv.count).map { i in
            let p = vbase.advanced(by: i * mv.stride).assumingMemoryBound(to: Float.self)
            return transformPoint(T, SIMD3(p[0], p[1], p[2]))
        }
        let ibase = UnsafeRawPointer(mf.buffer.contents())
        var n = SIMD3<Float>.zero
        for f in 0..<mf.count {
            let i0 = Int(readIndex(ibase, f * 3, bytes: mf.bytesPerIndex)), i1 = Int(readIndex(ibase, f * 3 + 1, bytes: mf.bytesPerIndex))
            let i2 = Int(readIndex(ibase, f * 3 + 2, bytes: mf.bytesPerIndex))
            guard i0 < pts.count, i1 < pts.count, i2 < pts.count else { continue }
            n += simd_cross(pts[i1] - pts[i0], pts[i2] - pts[i0])
        }
        guard simd_length(n) > 1e-8 else { return nil }
        n = simd_normalize(n)
        let up = SIMD3<Float>(0, 1, 0)
        var u = abs(n.y) > 0.9 ? SIMD3(T.columns.0.x, 0, T.columns.0.z) : simd_cross(up, n)
        if simd_length(u) < 1e-4 { u = SIMD3(1, 0, 0) }
        u = simd_normalize(u)
        let v = simd_normalize(simd_cross(n, u))
        let c0 = pts.reduce(.zero, +) / Float(pts.count)
        var lo = SIMD2<Float>(repeating: .infinity), hi = SIMD2<Float>(repeating: -.infinity)
        for p in pts { let q = SIMD2(simd_dot(p - c0, u), simd_dot(p - c0, v)); lo = simd_min(lo, q); hi = simd_max(hi, q) }
        let mid = (lo + hi) / 2
        let label: SurfaceLabel
        if #available(visionOS 26.0, *) {
            label = SurfaceLabel(arkitRaw: a.surfaceClassification.rawValue)
        } else {
            switch a.classification {
            case .wall: label = .wall
            case .floor: label = .floor
            case .ceiling: label = .ceiling
            case .table: label = .table
            case .seat: label = .seat
            case .window: label = .window
            case .door: label = .door
            default: label = .none
            }
        }
        self.init(id: a.id, label: label, center: c0 + u * mid.x + v * mid.y, normal: n, widthAxis: u,
                  width: hi.x - lo.x, height: hi.y - lo.y)
    }
}
#endif

#if canImport(ARKit) && os(iOS)
public extension ScanMesh {
    /// Copies an iPhone/iPad LiDAR mesh anchor (`ARWorldTrackingConfiguration.sceneReconstruction
    /// = .meshWithClassification`) into world space.
    init(meshAnchor anchor: ARMeshAnchor) {
        let g = anchor.geometry, T = anchor.transform
        let vs = g.vertices
        let vbase = UnsafeRawPointer(vs.buffer.contents()).advanced(by: vs.offset)
        let positions: [SIMD3<Float>] = (0..<vs.count).map { i in
            let p = vbase.advanced(by: i * vs.stride).assumingMemoryBound(to: Float.self)
            return transformPoint(T, SIMD3(p[0], p[1], p[2]))
        }
        let faces = g.faces
        let per = faces.indexCountPerPrimitive
        let ibase = UnsafeRawPointer(faces.buffer.contents())
        var indices = [UInt32](); indices.reserveCapacity(faces.count * 3)
        var labels = [SurfaceLabel](); labels.reserveCapacity(faces.count)
        let cls = g.classification
        let cbase = cls.map { UnsafeRawPointer($0.buffer.contents()).advanced(by: $0.offset) }
        for f in 0..<faces.count where per == 3 {
            for k in 0..<3 { indices.append(readIndex(ibase, f * per + k, bytes: faces.bytesPerIndex)) }
            if let cls, let cbase, f < cls.count {
                labels.append(SurfaceLabel(arkitRaw: Int(cbase.load(fromByteOffset: f * cls.stride, as: UInt8.self))))
            } else {
                labels.append(.none)
            }
        }
        self.init(id: anchor.identifier, positions: positions, indices: indices, faceLabels: labels)
    }
}

public extension RoomScan {
    /// Snapshot of every LiDAR mesh anchor in an `ARSession` frame.
    init(meshAnchors: [ARMeshAnchor], source: String = "ios-lidar") {
        self.init(source: source, meshes: meshAnchors.map { ScanMesh(meshAnchor: $0) })
    }
}
#endif
