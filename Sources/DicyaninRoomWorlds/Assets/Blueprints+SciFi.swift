import Foundation
import simd

extension AssetBlueprint {
    static let sciFi: [AssetBlueprint] = [
        AssetBlueprint("holo.table", name: "Holo table", tags: ["neon", "table", "desk"], size: [1.4, 0.75, 0.85], parts: [
            PartSpec(.box, .glass, y: Span(.surf(-0.03), .surf())),
            PartSpec(.box, .glow, y: Span(.surf(-0.04), .surf(-0.025)), z: .fromLo(0.015), mirrorZ: true),
            PartSpec(.box, .glow, x: .fromLo(0.015), y: Span(.surf(-0.04), .surf(-0.025)), mirrorX: true),
            PartSpec(.box, .metal, x: .centeredFraction(0.5), y: Span(.lo(0.04), .surf(-0.04)), z: .centeredFraction(0.25)),
            PartSpec(.box, .metal, x: .centeredFraction(0.8), y: Span(.lo(), .lo(0.04)), z: .centeredFraction(0.6)),
            PartSpec(.box, .glow, x: .centeredFraction(0.82), y: Span(.lo(0.004), .lo(0.012)), z: .centeredFraction(0.62)),
        ]),
        AssetBlueprint("terminal.desk", name: "Terminal", tags: ["neon", "desk", "counter"], size: [1.4, 0.75, 0.7], parts: [
            PartSpec(.box, .metal, y: Span(.surf(-0.05), .surf())),
            PartSpec(.box, .primary, x: .fromLo(0.08, inset: 0.02), y: Span(.lo(), .surf(-0.05)), z: .inset(0.03), mirrorX: true),
            PartSpec(.box, .trim, x: .fromLo(0.42, inset: 0.15), y: Span(.surf(0.05), .surf(0.34)), z: .fromLo(0.03, inset: 0.1), rotation: [0, 12, 0], mirrorX: true),
            PartSpec(.box, .glow, x: .fromLo(0.38, inset: 0.17), y: Span(.surf(0.07), .surf(0.32)), z: .fromLo(0.005, inset: 0.135), rotation: [0, 12, 0], mirrorX: true),
            PartSpec(.box, .glow, x: .centeredFraction(0.35), y: Span(.surf(), .surf(0.012)), z: Span(.f(0.55), .f(0.75))),
            PartSpec(.box, .glow, y: Span(.surf(-0.03), .surf(-0.02)), z: .fromHi(0.01, inset: -0.005)),
        ]),
        AssetBlueprint("neon.sofa", name: "Lounge", tags: ["neon", "sofa", "armchair"], size: [2.1, 0.85, 0.9], surface: 0.5, parts: [
            PartSpec(.box, .metal, x: .inset(0.02), y: Span(.lo(0.06), .surf(-0.1)), z: Span(.lo(0.02), .hi(0.02))),
            PartSpec(.box, .soft, x: .inset(0.04), y: Span(.surf(-0.11), .surf()), z: Span(.lo(0.2), .hi(0.01)), repeating: RepeatRule(.x, pitch: 0.7, gap: 0.02)),
            PartSpec(.wedge, .soft, x: .inset(0.04), y: Span(.surf(-0.1), .hi()), z: .fromLo(0.22, inset: 0.0), when: [.aboveSurface(0.15)]),
            PartSpec(.box, .glow, x: .inset(0.04), y: Span(.lo(0.03), .lo(0.05)), z: .fromHi(0.01, inset: 0.02)),
            PartSpec(.box, .glow, x: .fromLo(0.015), y: Span(.lo(0.06), .surf(-0.1)), z: .fromHi(0.4, inset: 0.05), mirrorX: true),
        ]),
        AssetBlueprint("neon.chair", name: "Shell chair", tags: ["neon", "chair", "stool"], size: [0.5, 0.88, 0.5], surface: 0.52, parts: [
            PartSpec(.cyl(8), .metal, x: .centered(0.07), y: Span(.lo(0.03), .surf(-0.06)), z: .centered(0.07)),
            PartSpec(.cyl(8, taper: 0.6), .metal, x: .centeredFraction(0.75), y: Span(.lo(), .lo(0.03)), z: .centeredFraction(0.75)),
            PartSpec(.cyl(10), .primary, y: Span(.surf(-0.07), .surf())),
            PartSpec(.box, .primary, x: .inset(0.03), y: Span(.surf(-0.02), .hi()), z: .fromLo(0.06), rotation: [-8, 0, 0], when: [.aboveSurface(0.15)]),
            PartSpec(.box, .glow, x: .inset(0.08), y: Span(.hi(0.05), .hi(0.03)), z: .fromLo(0.01, inset: 0.065), rotation: [-8, 0, 0], when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("cryo.pod", name: "Cryo pod", tags: ["neon", "bed"], size: [1.6, 0.6, 2.05], surface: 0.95, parts: [
            PartSpec(.box, .metal, y: Span(.lo(0.05), .surf(-0.12)), z: Span(.lo(0.05), .hi())),
            PartSpec(.box, .soft, x: .inset(0.05), y: Span(.surf(-0.12), .surf()), z: Span(.lo(0.1), .hi(0.05))),
            PartSpec(.box, .glow, x: .inset(0.02), y: Span(.lo(0.02), .lo(0.05)), z: Span(.lo(0.07), .hi(0.02))),
            PartSpec(.box, .trim, y: Span(.lo(), .hi()), z: .fromLo(0.08), when: [.aboveSurface(0.12)]),
            PartSpec(.box, .glow, x: .inset(0.1), y: Span(.hi(0.12), .hi(0.08)), z: .fromLo(0.005, inset: 0.08), when: [.aboveSurface(0.12)]),
        ]),
        AssetBlueprint("server.rack", name: "Server rack", tags: ["neon", "wardrobe", "shelf", "tallAppliance", "boundary"], size: [0.9, 2.0, 0.6], parts: [
            PartSpec(.box, .metal, z: Span(.lo(), .hi(0.02))),
            PartSpec(.box, .trim, x: .inset(0.04), y: .inset(0.06), z: .fromHi(0.02)),
            PartSpec(.box, .glow, x: .inset(0.08), y: .inset(0.1), z: .fromHi(0.005, inset: -0.002),
                     repeating: RepeatRule(.y, pitch: 0.18, gap: 0, from: 0.45, to: 0.55, maxCount: 16)),
            PartSpec(.box, .accent, x: Span(.f(0.8), .hi(0.08)), y: .inset(0.1), z: .fromHi(0.006, inset: -0.003),
                     repeating: RepeatRule(.y, pitch: 0.18, gap: 0, from: 0.3, to: 0.4, maxCount: 16)),
        ]),
        AssetBlueprint("holo.screen", name: "Holo screen", tags: ["neon", "tv"], size: [1.3, 0.75, 0.08], parts: [
            PartSpec(.box, .trim, x: .fromLo(0.03), mirrorX: true),
            PartSpec(.box, .trim, y: .fromLo(0.03), mirrorX: false),
            PartSpec(.box, .trim, y: .fromHi(0.03)),
            PartSpec(.box, .glow, x: .inset(0.04), y: .inset(0.04), z: .centeredFraction(0.2)),
        ]),
        AssetBlueprint("neon.tree", name: "Neon tree", tags: ["neon", "plant"], size: [0.5, 1.2, 0.5], parts: [
            PartSpec(.box, .metal, x: .centeredFraction(0.7), y: Span(.lo(), .lo(0.06)), z: .centeredFraction(0.7)),
            PartSpec(.cyl(6), .metal, x: .centered(0.04), y: Span(.lo(0.06), .f(0.7)), z: .centered(0.04)),
            PartSpec(.sphere(segments: 8), .crystal, x: .centeredFraction(0.9), y: Span(.f(0.5), .hi()), z: .centeredFraction(0.9)),
            PartSpec(.sphere(segments: 6), .glow, x: .centeredFraction(0.35), y: Span(.f(0.62), .f(0.88)), z: .centeredFraction(0.35)),
        ]),
        AssetBlueprint("cargo.crate", name: "Cargo crate", tags: ["neon", "clutter", "cabinet", "appliance"], size: [0.6, 0.5, 0.5], parts: [
            PartSpec(.box, .primary, x: .inset(0.02), y: .inset(0.02), z: .inset(0.02)),
            PartSpec(.box, .metal, x: .fromLo(0.04), mirrorX: true),
            PartSpec(.box, .metal, x: .inset(0.04), y: .fromHi(0.04)),
            PartSpec(.box, .glow, x: .inset(0.04), y: Span(.f(0.45), .f(0.52)), z: .fromHi(0.005, inset: 0.01), mirrorZ: true),
        ]),
    ]
}
