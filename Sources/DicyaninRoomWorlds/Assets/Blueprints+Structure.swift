import Foundation
import simd

// Boundary pieces tile along walls; opening pieces fit window and door rectangles;
// decor pieces are scattered on free floor with randomized scale.

extension AssetBlueprint {
    static let structure: [AssetBlueprint] = [
        AssetBlueprint("wall.hedge", name: "Hedge", tags: ["boundary"], size: [1.0, 2.4, 0.5], parts: [
            PartSpec(.box, .foliage, y: Span(.lo(), .hi(0.15))),
            PartSpec(.rock(segments: 6, roughness: 0.12), .foliageAlt, y: Span(.hi(0.35), .hi()), z: .inset(0.02)),
        ]),
        AssetBlueprint("wall.cliff", name: "Cliff", tags: ["boundary"], size: [1.2, 2.6, 0.7], parts: [
            PartSpec(.rock(segments: 7, roughness: 0.18), .stone, x: Span(.lo(-0.1), .hi(-0.1)), y: Span(.lo(), .f(0.6))),
            PartSpec(.rock(segments: 6, roughness: 0.2), .stone, x: Span(.f(0.05), .f(0.95)), y: Span(.f(0.45), .hi()), z: Span(.lo(), .f(0.85))),
            PartSpec(.dome(segments: 7), .foliage, x: Span(.f(0.1), .f(0.8)), y: Span(.hi(0.06), .hi(-0.08)), z: Span(.lo(), .f(0.8))),
        ]),
        AssetBlueprint("wall.dune", name: "Sandstone wall", tags: ["boundary"], size: [1.2, 2.6, 0.6], parts: [
            PartSpec(.box, .primary, x: Span(.lo(-0.01), .hi(-0.01)), y: .full, repeating: RepeatRule(.y, pitch: 0.4, gap: 0.03)),
            PartSpec(.box, .stone, x: Span(.f(0.3), .f(0.7)), y: Span(.hi(0.4), .hi()), z: .fromLo(0.3)),
            PartSpec(.wedge, .ground, y: Span(.lo(), .lo(0.35)), z: Span(.f(0.5), .hi(-0.35))),
        ]),
        AssetBlueprint("wall.ice", name: "Ice wall", tags: ["boundary"], size: [1.2, 2.6, 0.6], parts: [
            PartSpec(.rock(segments: 4, roughness: 0.1), .crystal, x: Span(.lo(-0.1), .hi(-0.1)), y: Span(.lo(), .f(0.7)), rotation: [0, 45, 0]),
            PartSpec(.cyl(5, taper: 0), .crystal, x: .centeredFraction(0.6), y: Span(.f(0.5), .hi())),
            PartSpec(.dome(segments: 7), .snow, x: Span(.lo(-0.05), .hi(-0.05)), y: Span(.lo(), .lo(0.25)), z: Span(.f(0.3), .hi(-0.2))),
        ]),
        AssetBlueprint("wall.panel", name: "Tech panel", tags: ["boundary"], size: [1.2, 2.6, 0.25], parts: [
            PartSpec(.box, .primary, x: Span(.lo(0.01), .hi(0.01)), z: Span(.lo(), .hi(0.04))),
            PartSpec(.box, .trim, x: .inset(0.06), y: Span(.f(0.12), .f(0.88)), z: .fromHi(0.04)),
            PartSpec(.box, .glow, x: .inset(0.02), y: Span(.f(0.08), .f(0.08, 0.025)), z: .fromHi(0.01, inset: -0.005)),
            PartSpec(.box, .glow, x: .centered(0.03), y: Span(.f(0.2), .f(0.8)), z: .fromHi(0.01, inset: 0.035)),
            PartSpec(.box, .metal, y: .fromHi(0.12), z: Span(.lo(), .hi(-0.06))),
        ]),
        AssetBlueprint("wall.timber", name: "Timber wall", tags: ["boundary"], size: [1.2, 2.6, 0.2], parts: [
            PartSpec(.box, .primary, x: Span(.lo(-0.005), .hi(-0.005)), z: Span(.lo(), .hi(0.05)), repeating: RepeatRule(.y, pitch: 0.24, gap: 0.012)),
            PartSpec(.box, .secondary, x: .fromLo(0.1), y: .full, z: Span(.lo(), .hi())),
            PartSpec(.box, .trim, y: Span(.lo(), .lo(0.12)), z: Span(.lo(), .hi(-0.02))),
        ]),
        // Openings: fitted to the window or door rectangle; local +Z faces into the room.
        AssetBlueprint("opening.arch", name: "Archway", tags: ["door"], size: [0.9, 2.05, 0.4], parts: [
            PartSpec(.box, .stone, x: .fromLo(0.18, inset: -0.18), y: Span(.lo(), .hi(0.15)), mirrorX: true),
            PartSpec(.box, .stone, x: Span(.lo(-0.22), .hi(-0.22)), y: Span(.hi(0.2), .hi(-0.12))),
            PartSpec(.wedge, .accent, x: .centered(0.3), y: Span(.hi(-0.12), .hi(-0.32)), z: .inset(0.05)),
            PartSpec(.box, .glow, x: .inset(0.02), y: Span(.lo(), .hi(0.2)), z: .centered(0.02)),
        ]),
        AssetBlueprint("opening.gate", name: "Gate", tags: ["door"], size: [0.9, 2.05, 0.3], parts: [
            PartSpec(.box, .metal, x: .fromLo(0.12, inset: -0.12), y: Span(.lo(), .hi(-0.1)), mirrorX: true),
            PartSpec(.box, .metal, x: Span(.lo(-0.14), .hi(-0.14)), y: .fromHi(0.14, inset: -0.1)),
            PartSpec(.box, .glow, x: .inset(0.01), y: Span(.lo(), .hi()), z: .centered(0.015)),
            PartSpec(.box, .accent, x: Span(.lo(-0.1), .lo(-0.02)), y: Span(.lo(0.2), .hi(0.2)), z: .fromHi(0.02, inset: -0.01), mirrorX: true),
        ]),
        AssetBlueprint("opening.frame", name: "Door frame", tags: ["door"], size: [0.9, 2.05, 0.16], parts: [
            PartSpec(.box, .trim, x: .fromLo(0.07, inset: -0.07), y: Span(.lo(), .hi(-0.07)), mirrorX: true),
            PartSpec(.box, .trim, x: Span(.lo(-0.07), .hi(-0.07)), y: .fromHi(0.07, inset: -0.07)),
            PartSpec(.box, .secondary, x: .inset(0.005), y: Span(.lo(), .hi(0.005)), z: .fromLo(0.04, inset: 0.0)),
            PartSpec(.sphere(segments: 6), .metal, x: .fromHi(0.06, inset: 0.06), y: Span(.f(0.47), .f(0.47, 0.06)), z: .fromLo(0.05, inset: 0.035)),
        ]),
        AssetBlueprint("opening.vista", name: "Vista", tags: ["window"], size: [1.4, 1.2, 0.2], parts: [
            PartSpec(.box, .trim, x: Span(.lo(-0.08), .hi(-0.08)), y: .fromLo(0.08, inset: -0.08)),
            PartSpec(.box, .trim, x: Span(.lo(-0.08), .hi(-0.08)), y: .fromHi(0.08, inset: -0.08)),
            PartSpec(.box, .trim, x: .fromLo(0.08, inset: -0.08), y: .full, mirrorX: true),
            PartSpec(.box, .glass, x: .full, y: .full, z: .centered(0.02, -0.05)),
        ]),
        AssetBlueprint("opening.portal", name: "Portal", tags: ["window", "door"], size: [1.4, 1.2, 0.2], parts: [
            PartSpec(.rock(segments: 6, roughness: 0.15), .stone, x: .fromLo(0.2, inset: -0.15), y: Span(.lo(-0.1), .hi(-0.1)), mirrorX: true),
            PartSpec(.rock(segments: 6, roughness: 0.15), .stone, x: Span(.lo(-0.1), .hi(-0.1)), y: .fromHi(0.2, inset: -0.15)),
            PartSpec(.cyl(16, axis: .z), .glow, x: .inset(0.02), y: .inset(0.02), z: .centered(0.02)),
        ]),

        // Decor.
        AssetBlueprint("grass.tuft", name: "Grass", tags: ["decor", "forest"], size: [0.25, 0.22, 0.25], scale: 0.6...1.4, parts: [
            PartSpec(.cyl(4, taper: 0), .foliage, x: .frac(0.0, 0.5), z: .frac(0.2, 0.7), rotation: [0, 0, -12]),
            PartSpec(.cyl(4, taper: 0), .foliageAlt, x: .frac(0.35, 0.85), y: Span(.lo(), .f(0.8)), z: .frac(0.0, 0.5), rotation: [10, 0, 8]),
            PartSpec(.cyl(4, taper: 0), .foliage, x: .frac(0.45, 1), y: Span(.lo(), .f(0.65)), z: .frac(0.45, 1), rotation: [-10, 0, 14]),
        ]),
        AssetBlueprint("flower", name: "Flower", tags: ["decor", "forest"], size: [0.12, 0.3, 0.12], scale: 0.7...1.3, parts: [
            PartSpec(.cyl(4), .foliage, x: .centered(0.012), y: Span(.lo(), .f(0.8)), z: .centered(0.012)),
            PartSpec(.sphere(segments: 6), .accent, y: Span(.f(0.72), .hi()), z: .centeredFraction(0.6)),
            PartSpec(.sphere(segments: 4), .trim, x: .centeredFraction(0.35), y: Span(.f(0.82), .f(0.98)), z: .centeredFraction(0.35)),
        ]),
        AssetBlueprint("pebble", name: "Pebbles", tags: ["decor", "forest", "desert", "tundra"], size: [0.3, 0.1, 0.25], scale: 0.5...1.6, parts: [
            PartSpec(.rock(segments: 6, roughness: 0.2), .stone, x: .frac(0, 0.6), z: .frac(0, 0.7)),
            PartSpec(.rock(segments: 5, roughness: 0.25), .stone, x: .frac(0.55, 1), y: Span(.lo(), .f(0.6)), z: .frac(0.4, 1)),
        ]),
        AssetBlueprint("mushroom.small", name: "Mushrooms", tags: ["decor", "forest"], size: [0.2, 0.18, 0.2], scale: 0.6...1.5, parts: [
            PartSpec(.cyl(5), .trim, x: .centered(0.03, -0.03), y: Span(.lo(), .f(0.7)), z: .centered(0.03)),
            PartSpec(.dome(segments: 7), .accent, x: Span(.lo(), .f(0.7)), y: Span(.f(0.6), .hi()), z: .frac(0.15, 0.85)),
            PartSpec(.cyl(5), .trim, x: .centered(0.02, 0.06), y: Span(.lo(), .f(0.4)), z: .centered(0.02, 0.05)),
            PartSpec(.dome(segments: 6), .accent, x: .frac(0.6, 1), y: Span(.f(0.35), .f(0.6)), z: .frac(0.6, 1)),
        ]),
        AssetBlueprint("shrub", name: "Shrub", tags: ["decor", "forest"], size: [0.45, 0.35, 0.4], scale: 0.7...1.5, parts: [
            PartSpec(.rock(segments: 7, roughness: 0.2), .foliage, x: .frac(0, 0.75)),
            PartSpec(.rock(segments: 6, roughness: 0.2), .foliageAlt, x: .frac(0.4, 1), y: Span(.lo(), .f(0.75)), z: .frac(0.1, 0.9)),
        ]),
        AssetBlueprint("cactus.small", name: "Small cactus", tags: ["decor", "desert"], size: [0.2, 0.35, 0.2], scale: 0.6...1.6, parts: [
            PartSpec(.cyl(7, taper: 0.8), .foliage, x: .centeredFraction(0.6), z: .centeredFraction(0.6)),
            PartSpec(.sphere(segments: 5), .accent, x: .centeredFraction(0.3), y: Span(.hi(0.04), .hi(-0.02)), z: .centeredFraction(0.3)),
        ]),
        AssetBlueprint("dune.ripple", name: "Dune", tags: ["decor", "desert"], size: [0.9, 0.12, 0.5], scale: 0.6...1.8, parts: [
            PartSpec(.dome(segments: 8), .ground),
        ]),
        AssetBlueprint("ice.shard", name: "Ice shard", tags: ["decor", "tundra"], size: [0.2, 0.45, 0.2], scale: 0.5...1.5, parts: [
            PartSpec(.cyl(5, taper: 0), .crystal, rotation: [8, 0, -6]),
            PartSpec(.cyl(5, taper: 0), .crystal, x: .frac(0.5, 1), y: Span(.lo(), .f(0.55)), z: .frac(0.4, 0.9), rotation: [-14, 0, 18]),
        ]),
        AssetBlueprint("neon.cone", name: "Light cone", tags: ["decor", "neon"], size: [0.18, 0.3, 0.18], scale: 0.8...1.2, parts: [
            PartSpec(.box, .metal, y: .fromLo(0.02)),
            PartSpec(.cyl(8, taper: 0.15), .accent, x: .inset(0.02), y: Span(.lo(0.02), .hi()), z: .inset(0.02)),
            PartSpec(.cyl(8), .glow, x: .centeredFraction(0.62), y: Span(.f(0.45), .f(0.55)), z: .centeredFraction(0.62)),
        ]),
        AssetBlueprint("cable.bundle", name: "Cables", tags: ["decor", "neon"], size: [0.6, 0.06, 0.12], scale: 0.7...1.8, parts: [
            PartSpec(.cyl(5, axis: .x), .trim, z: .frac(0, 0.45)),
            PartSpec(.cyl(5, axis: .x), .glow, x: .frac(0.1, 0.9), y: Span(.lo(), .f(0.7)), z: .frac(0.5, 0.85)),
        ]),
        AssetBlueprint("lantern", name: "Lantern", tags: ["decor", "forest", "tundra", "desert"], size: [0.16, 0.42, 0.16], scale: 0.9...1.3, parts: [
            PartSpec(.cyl(6), .metal, y: .fromLo(0.03)),
            PartSpec(.cyl(6), .glow, x: .inset(0.025), y: Span(.lo(0.03), .hi(0.1)), z: .inset(0.025)),
            PartSpec(.cyl(6, taper: 0), .metal, y: .fromHi(0.1)),
        ]),
    ]
}
