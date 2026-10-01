#if canImport(RealityKit)
import Foundation
import RealityKit
import CoreGraphics
import simd
#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

/// Sun light and gradient sky dome for a theme.
@MainActor
public enum WorldAtmosphere {
    /// Directional sun with shadows, aimed at the room center from the theme's high angle.
    public static func sun(_ theme: WorldTheme, room: RoomModel) -> Entity {
        let e = Entity()
        e.name = "Sun"
        let c = MaterialStyle(theme.sky.sunColor).rgb
        let light = DirectionalLightComponent(color: PlatformColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1),
                                              intensity: 2500 * theme.sky.sunIntensity)
        e.components.set(light)
        e.components.set(DirectionalLightComponent.Shadow(maximumDistance: 12, depthBias: 2))
        let target = SIMD3(room.center.x, room.floorY, room.center.y)
        e.look(at: target, from: target + SIMD3(2.5, 6, 3.5), relativeTo: nil)
        return e
    }

    /// Inward-facing hemisphere with a vertical zenith-to-horizon gradient (unlit).
    public static func skyDome(_ theme: WorldTheme, radius: Float = 40, segments: Int = 32) throws -> ModelEntity {
        let rings = 10
        var pos: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = [], idx: [UInt32] = []
        for j in 0...rings {
            let el = Float(j) / Float(rings) * (.pi / 2) - 0.15
            for i in 0...segments {
                let az = Float(i) / Float(segments) * 2 * .pi
                pos.append(SIMD3(cos(el) * cos(az), sin(el), cos(el) * sin(az)) * radius)
                uv.append(SIMD2(Float(i) / Float(segments), simd_clamp(Float(j) / Float(rings), 0, 1)))
            }
        }
        let w = UInt32(segments + 1)
        for j in 0..<UInt32(rings) {
            for i in 0..<UInt32(segments) {
                let a = j * w + i, b = a + 1, c = a + w, d = c + 1
                idx += [a, b, c, b, d, c]
            }
        }
        var desc = MeshDescriptor(name: "SkyDome")
        desc.positions = MeshBuffers.Positions(pos)
        desc.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        desc.primitives = .triangles(idx)
        let tex = try TextureResource(image: gradient(top: theme.sky.zenith, bottom: theme.sky.horizon), options: .init(semantic: .color))
        var mat = UnlitMaterial()
        mat.color = .init(tint: .white, texture: .init(tex))
        let e = ModelEntity(mesh: try MeshResource.generate(from: [desc]), materials: [mat])
        e.name = "Sky"
        return e
    }

    static func gradient(top: UInt32, bottom: UInt32) -> CGImage {
        let h = 128
        let t = MaterialStyle(top).rgb, b = MaterialStyle(bottom).rgb
        var px = [UInt8](repeating: 255, count: h * 4)
        for y in 0..<h {
            // Row 0 is v = 1 (zenith) in RealityKit texture space.
            let f = pow(Float(y) / Float(h - 1), 0.8)
            let c = t * (1 - f) + b * f
            px[y * 4] = UInt8(c.x * 255); px[y * 4 + 1] = UInt8(c.y * 255); px[y * 4 + 2] = UInt8(c.z * 255)
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &px, width: 1, height: h, bitsPerComponent: 8, bytesPerRow: 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
}
#endif
