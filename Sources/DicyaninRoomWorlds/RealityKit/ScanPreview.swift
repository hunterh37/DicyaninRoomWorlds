#if canImport(RealityKit)
import Foundation
import RealityKit
import simd

/// Debug and progress visualization: scan faces colored by surface label, and analyzed boxes.
@MainActor
public enum ScanPreview {
    /// One entity per scan mesh, a submesh per label, flat colored (unlit).
    public static func entity(for scan: RoomScan, opacity: Float = 0.85) throws -> Entity {
        let root = Entity()
        root.name = "ScanPreview"
        for m in scan.meshes {
            if let e = try entity(for: m, opacity: opacity) { root.addChild(e) }
        }
        return root
    }

    public static func entity(for mesh: ScanMesh, opacity: Float = 0.85) throws -> ModelEntity? {
        var byLabel: [SurfaceLabel: [UInt32]] = [:]
        for f in 0..<mesh.faceCount {
            byLabel[mesh.label(ofFace: f), default: []] += [mesh.indices[f * 3], mesh.indices[f * 3 + 1], mesh.indices[f * 3 + 2]]
        }
        var descs: [MeshDescriptor] = [], mats: [RealityKit.Material] = []
        for label in SurfaceLabel.allCases {
            guard let idx = byLabel[label], !idx.isEmpty else { continue }
            var d = MeshDescriptor(name: "scan.\(label)")
            d.positions = MeshBuffers.Positions(mesh.positions)
            d.primitives = .triangles(idx)
            d.materials = .allFaces(UInt32(mats.count))
            descs.append(d)
            mats.append(labelMaterial(label, opacity: opacity))
        }
        guard !descs.isEmpty else { return nil }
        let e = ModelEntity(mesh: try MeshResource.generate(from: descs), materials: mats)
        e.name = "scan.\(mesh.id)"
        return e
    }

    /// Wire boxes for analyzed objects plus wall lines, colored by label.
    public static func entity(for model: RoomModel) -> Entity {
        let root = Entity()
        root.name = "RoomModelPreview"
        for o in model.objects {
            let e = ModelEntity(mesh: .generateBox(size: o.box.size), materials: [labelMaterial(o.label, opacity: 0.35)])
            e.position = o.box.center
            e.orientation = Yaw.quaternion(o.box.yaw)
            e.name = o.id
            let nose = ModelEntity(mesh: .generateBox(size: [0.04, 0.04, 0.2]), materials: [UnlitMaterial(color: .white)])
            nose.position = [0, 0, o.box.size.z / 2 + 0.1]
            e.addChild(nose)
            root.addChild(e)
        }
        for w in model.walls {
            let e = ModelEntity(mesh: .generateBox(size: [w.length, w.height, 0.02]), materials: [labelMaterial(.wall, opacity: 0.25)])
            e.position = SIMD3(w.midpoint.x, (w.bottomY + w.topY) / 2, w.midpoint.y)
            e.orientation = Yaw.quaternion(w.inwardYaw)
            root.addChild(e)
        }
        return root
    }

    static func labelMaterial(_ label: SurfaceLabel, opacity: Float) -> RealityKit.Material {
        let c = MaterialStyle(label.debugColor).rgb
        var m = UnlitMaterial(color: PlatformColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1))
        if opacity < 0.999 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
        return m
    }
}
#endif
