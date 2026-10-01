import Foundation
import simd

// Organic stand-ins: same footprint, height and seat/table surface as the real object,
// so a player who sits on a log or leans on a rock slab touches real furniture.

extension AssetBlueprint {
    static let nature: [AssetBlueprint] = [
        AssetBlueprint("stump.table", name: "Stump table", tags: ["forest", "table"], size: [1.0, 0.45, 0.6], parts: [
            PartSpec(.cyl(9, taper: 0.88), .bark, x: .centeredFraction(0.62), y: Span(.lo(), .surf(-0.04)), z: .centeredFraction(0.7)),
            PartSpec(.cyl(11), .wood, x: .centeredFraction(1.0), y: Span(.surf(-0.05), .surf()), z: .centeredFraction(1.0)),
            PartSpec(.cyl(9, taper: 0.8), .bark, x: .centeredFraction(0.8), y: Span(.lo(), .lo(0.08)), z: .centeredFraction(0.9)),
            PartSpec(.dome(segments: 7), .accent, x: .fromHi(0.12, inset: -0.02), y: Span(.lo(0.1), .lo(0.15)), z: .centered(0.12, 0.05), when: [.minHeight(0.3)]),
        ]),
        AssetBlueprint("rock.slab", name: "Rock slab", tags: ["forest", "desert", "table"], size: [1.4, 0.75, 0.85], parts: [
            PartSpec(.rock(segments: 8, roughness: 0.12), .stone, y: Span(.surf(-0.12), .surf())),
            PartSpec(.rock(segments: 7, roughness: 0.22), .stone, x: .centeredFraction(0.55), y: Span(.lo(), .surf(-0.08)), z: .centeredFraction(0.6)),
            PartSpec(.dome(segments: 8), .foliage, x: .centeredFraction(0.7), y: Span(.surf(-0.01), .surf(0.02)), z: .centeredFraction(0.6)),
        ]),
        AssetBlueprint("log.bench", name: "Log bench", tags: ["forest", "sofa"], size: [2.1, 0.85, 0.9], surface: 0.5, parts: [
            PartSpec(.cyl(9, axis: .x), .bark, x: .inset(0.02), y: Span(.lo(), .surf()), z: Span(.f(0.3), .hi())),
            PartSpec(.cyl(9, axis: .x), .bark, y: Span(.surf(-0.08), .hi()), z: .fromLo(0.32), when: [.aboveSurface(0.15)]),
            PartSpec(.dome(segments: 8), .foliage, x: .inset(0.25), y: Span(.surf(-0.02), .surf(0.025)), z: Span(.f(0.45), .hi(0.08))),
            PartSpec(.cyl(7, taper: 0.9), .wood, x: .fromLo(0.22), y: Span(.lo(), .surf(0.12)), z: .fromLo(0.36, inset: 0), mirrorX: true, when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("stump.seat", name: "Stump seat", tags: ["forest", "chair"], size: [0.5, 0.88, 0.5], surface: 0.52, parts: [
            PartSpec(.cyl(8, taper: 0.9), .bark, x: .inset(0.02), y: Span(.lo(), .surf()), z: Span(.lo(0.1), .hi())),
            PartSpec(.cyl(8), .wood, x: .inset(0.04), y: Span(.surf(-0.01), .surf(0.005)), z: Span(.lo(0.12), .hi(0.02))),
            PartSpec(.rock(segments: 6, roughness: 0.15), .stone, y: Span(.surf(-0.15), .hi()), z: .fromLo(0.16), when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("mushroom.seat", name: "Mushroom stool", tags: ["forest", "stool"], size: [0.45, 0.6, 0.45], parts: [
            PartSpec(.cyl(8, taper: 0.8), .trim, x: .centeredFraction(0.4), y: Span(.lo(), .hi(0.1)), z: .centeredFraction(0.4)),
            PartSpec(.dome(segments: 10), .accent, x: .centeredFraction(1.15), y: Span(.hi(0.16), .hi()), z: .centeredFraction(1.15)),
            PartSpec(.sphere(segments: 6), .trim, x: .centered(0.07, 0.1), y: Span(.hi(0.05), .hi(-0.015)), z: .centered(0.07, 0.06)),
            PartSpec(.sphere(segments: 6), .trim, x: .centered(0.06, -0.12), y: Span(.hi(0.07), .hi(0.01)), z: .centered(0.06, -0.05)),
        ]),
        AssetBlueprint("moss.bed", name: "Moss bed", tags: ["forest", "bed"], size: [1.6, 0.6, 2.05], surface: 0.95, parts: [
            PartSpec(.rock(segments: 8, roughness: 0.1), .stone, y: Span(.lo(), .surf(-0.16)), z: Span(.lo(0.08), .hi())),
            PartSpec(.box, .foliage, x: .inset(0.04), y: Span(.surf(-0.17), .surf()), z: Span(.lo(0.1), .hi(0.04))),
            PartSpec(.rock(segments: 6, roughness: 0.1), .foliageAlt, x: .inset(0.15), y: Span(.surf(-0.02), .surf(0.1)), z: .fromLo(0.3, inset: 0.12)),
            PartSpec(.cyl(8, axis: .x), .bark, y: Span(.lo(), .hi()), z: .fromLo(0.12), when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("tree.small", name: "Tree", tags: ["forest", "plant"], size: [0.6, 1.2, 0.6], parts: [
            PartSpec(.cyl(6, taper: 0.7), .bark, x: .centeredFraction(0.18), y: Span(.lo(), .f(0.45)), z: .centeredFraction(0.18)),
            PartSpec(.rock(segments: 8, roughness: 0.18), .foliage, x: .centeredFraction(1.1), y: Span(.f(0.3), .f(0.8)), z: .centeredFraction(1.1)),
            PartSpec(.rock(segments: 7, roughness: 0.2), .foliageAlt, x: .centeredFraction(0.75), y: Span(.f(0.6), .hi()), z: .centeredFraction(0.75)),
        ]),
        AssetBlueprint("tree.pine", name: "Pine", tags: ["forest", "tundra", "plant", "boundary"], size: [0.8, 2.5, 0.8], parts: [
            PartSpec(.cyl(6, taper: 0.6), .bark, x: .centeredFraction(0.16), y: Span(.lo(), .f(0.3)), z: .centeredFraction(0.16)),
            PartSpec(.cyl(7, taper: 0), .foliage, y: Span(.f(0.15), .f(0.55)), rotation: [0, 12, 0]),
            PartSpec(.cyl(7, taper: 0), .foliageAlt, x: .centeredFraction(0.8), y: Span(.f(0.38), .f(0.78)), z: .centeredFraction(0.8), rotation: [0, 31, 0]),
            PartSpec(.cyl(7, taper: 0), .foliage, x: .centeredFraction(0.55), y: Span(.f(0.6), .hi()), z: .centeredFraction(0.55), rotation: [0, 47, 0]),
        ]),
        AssetBlueprint("pine.snowy", name: "Snowy pine", tags: ["tundra", "plant", "boundary"], size: [0.8, 2.5, 0.8], parts: [
            PartSpec(.cyl(6, taper: 0.6), .bark, x: .centeredFraction(0.16), y: Span(.lo(), .f(0.3)), z: .centeredFraction(0.16)),
            PartSpec(.cyl(7, taper: 0), .foliage, y: Span(.f(0.15), .f(0.55))),
            PartSpec(.cyl(7, taper: 0), .snow, x: .centeredFraction(0.62), y: Span(.f(0.33), .f(0.57)), z: .centeredFraction(0.62)),
            PartSpec(.cyl(7, taper: 0), .foliage, x: .centeredFraction(0.75), y: Span(.f(0.45), .f(0.82)), z: .centeredFraction(0.75)),
            PartSpec(.cyl(7, taper: 0), .snow, x: .centeredFraction(0.42), y: Span(.f(0.68), .hi()), z: .centeredFraction(0.42)),
        ]),
        AssetBlueprint("boulder", name: "Boulder", tags: ["forest", "desert", "tundra", "clutter"], size: [0.6, 0.45, 0.5], parts: [
            PartSpec(.rock(segments: 8, roughness: 0.22), .stone, x: Span(.lo(), .f(0.8)), z: .full),
            PartSpec(.rock(segments: 6, roughness: 0.25), .stone, x: Span(.f(0.5), .hi()), y: Span(.lo(), .f(0.6)), z: Span(.f(0.15), .f(0.85))),
            PartSpec(.dome(segments: 7), .foliage, x: Span(.f(0.15), .f(0.6)), y: Span(.f(0.85), .f(1.04)), z: Span(.f(0.2), .f(0.7))),
        ]),
        AssetBlueprint("cliff.pillar", name: "Rock pillar", tags: ["forest", "desert", "wardrobe", "shelf"], size: [1.0, 2.0, 0.6], parts: [
            PartSpec(.rock(segments: 7, roughness: 0.14), .stone, y: Span(.lo(), .f(0.55))),
            PartSpec(.rock(segments: 7, roughness: 0.16), .stone, x: .centeredFraction(0.85), y: Span(.f(0.45), .f(0.95)), z: .centeredFraction(0.9)),
            PartSpec(.dome(segments: 8), .foliage, x: .centeredFraction(0.75), y: Span(.f(0.88), .hi(-0.03)), z: .centeredFraction(0.8)),
        ]),
        AssetBlueprint("rock.throne", name: "Rock throne", tags: ["forest", "desert", "armchair"], size: [0.85, 0.9, 0.85], surface: 0.5, parts: [
            PartSpec(.rock(segments: 7, roughness: 0.1), .stone, y: Span(.lo(), .surf()), z: Span(.lo(0.15), .hi())),
            PartSpec(.rock(segments: 7, roughness: 0.14), .stone, y: Span(.lo(), .hi()), z: .fromLo(0.22)),
            PartSpec(.box, .foliage, x: .inset(0.08), y: Span(.surf(-0.01), .surf(0.03)), z: Span(.lo(0.26), .hi(0.06))),
        ]),
        AssetBlueprint("crystal.cluster", name: "Crystals", tags: ["forest", "tundra", "clutter", "tv"], size: [0.5, 0.6, 0.5], parts: [
            PartSpec(.rock(segments: 6, roughness: 0.15), .stone, y: Span(.lo(), .f(0.25))),
            PartSpec(.cyl(5, taper: 0), .crystal, x: .centeredFraction(0.4), y: Span(.f(0.1), .hi())),
            PartSpec(.cyl(5, taper: 0), .crystal, x: Span(.f(0.05), .f(0.35)), y: Span(.f(0.1), .f(0.7)), z: Span(.f(0.2), .f(0.5)), rotation: [0, 0, 22]),
            PartSpec(.cyl(5, taper: 0), .crystal, x: Span(.f(0.6), .f(0.9)), y: Span(.f(0.1), .f(0.62)), z: Span(.f(0.5), .f(0.8)), rotation: [-18, 0, -20]),
        ]),
        AssetBlueprint("spirit.mirror", name: "Spirit pool", tags: ["forest", "tv"], size: [1.3, 0.75, 0.1], parts: [
            PartSpec(.box, .bark, z: Span(.lo(), .hi())),
            PartSpec(.box, .water, x: .inset(0.04), y: .inset(0.04), z: .fromHi(0.01, inset: -0.005)),
            PartSpec(.dome(segments: 7), .foliage, x: .fromLo(0.25, inset: -0.05), y: Span(.hi(0.1), .hi(-0.06)), z: .full),
        ]),
        AssetBlueprint("ruin.column", name: "Ruined column", tags: ["desert", "wardrobe", "shelf", "boundary"], size: [0.8, 2.2, 0.8], parts: [
            PartSpec(.box, .stone, y: Span(.lo(), .lo(0.15))),
            PartSpec(.cyl(10), .primary, x: .centeredFraction(0.7), y: Span(.lo(0.15), .hi(0.18)), z: .centeredFraction(0.7)),
            PartSpec(.box, .stone, x: .centeredFraction(0.92), y: Span(.hi(0.18), .hi(0.05)), z: .centeredFraction(0.92)),
            PartSpec(.wedge, .primary, x: .centeredFraction(0.6), y: Span(.hi(0.05), .hi()), z: .centeredFraction(0.6), rotation: [0, 35, 0]),
        ]),
        AssetBlueprint("sandstone.altar", name: "Altar", tags: ["desert", "table", "counter", "desk"], size: [1.4, 0.75, 0.85], parts: [
            PartSpec(.box, .primary, x: .inset(0.08), y: Span(.lo(0.06), .surf(-0.08)), z: .inset(0.08)),
            PartSpec(.box, .stone, y: Span(.lo(), .lo(0.06))),
            PartSpec(.box, .stone, y: Span(.surf(-0.08), .surf())),
            PartSpec(.box, .accent, x: .inset(0.06), y: Span(.f(0.3), .f(0.3, 0.05)), z: .fromHi(0.01, inset: 0.07)),
        ]),
        AssetBlueprint("cactus", name: "Cactus", tags: ["desert", "plant"], size: [0.5, 1.2, 0.4], parts: [
            PartSpec(.cyl(8, taper: 0.9), .foliage, x: .centeredFraction(0.4), y: Span(.lo(), .hi()), z: .centeredFraction(0.5)),
            PartSpec(.cyl(7, taper: 0.8), .foliage, x: .fromLo(0.15, inset: 0.02), y: Span(.f(0.35), .f(0.75)), z: .centeredFraction(0.4)),
            PartSpec(.cyl(7, taper: 0.8), .foliageAlt, x: .fromHi(0.13, inset: 0.03), y: Span(.f(0.5), .f(0.85)), z: .centeredFraction(0.38)),
            PartSpec(.cyl(6, axis: .x), .foliage, x: Span(.f(0.15), .f(0.4)), y: Span(.f(0.35), .f(0.45)), z: .centeredFraction(0.32)),
            PartSpec(.cyl(6, axis: .x), .foliageAlt, x: Span(.f(0.6), .f(0.85)), y: Span(.f(0.5), .f(0.58)), z: .centeredFraction(0.3)),
        ]),
        AssetBlueprint("ice.block", name: "Ice block", tags: ["tundra", "table", "cabinet", "clutter", "appliance"], size: [1.0, 0.75, 0.6], parts: [
            PartSpec(.rock(segments: 4, roughness: 0.06), .crystal, x: .inset(0.01), y: Span(.lo(), .hi(0.04)), z: .inset(0.01), rotation: [0, 45, 0]),
            PartSpec(.box, .snow, y: .fromHi(0.05)),
        ]),
        AssetBlueprint("ice.bench", name: "Ice bench", tags: ["tundra", "sofa", "chair", "armchair"], size: [2.0, 0.85, 0.9], surface: 0.5, parts: [
            PartSpec(.box, .crystal, y: Span(.lo(), .surf(-0.06)), z: Span(.f(0.2), .hi())),
            PartSpec(.box, .soft, x: .inset(0.04), y: Span(.surf(-0.06), .surf()), z: Span(.f(0.22), .hi(0.02)), repeating: RepeatRule(.x, pitch: 0.6, gap: 0.02)),
            PartSpec(.box, .crystal, y: Span(.lo(), .hi()), z: .fromLo(0.18), when: [.aboveSurface(0.15)]),
            PartSpec(.box, .snow, y: .fromHi(0.04), z: .fromLo(0.2), when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("snow.bed", name: "Fur bed", tags: ["tundra", "bed"], size: [1.6, 0.6, 2.05], surface: 0.95, parts: [
            PartSpec(.box, .snow, y: Span(.lo(), .surf(-0.15)), z: Span(.lo(0.08), .hi())),
            PartSpec(.rock(segments: 6, roughness: 0.05), .soft, x: .inset(0.02), y: Span(.surf(-0.17), .surf()), z: Span(.lo(0.1), .hi(0.02))),
            PartSpec(.box, .crystal, y: Span(.lo(), .hi()), z: .fromLo(0.12), when: [.aboveSurface(0.15)]),
        ]),
        AssetBlueprint("snow.mound", name: "Snow mound", tags: ["tundra", "clutter", "decor"], size: [0.5, 0.3, 0.5], scale: 0.5...1.4, parts: [
            PartSpec(.dome(segments: 8), .snow),
            PartSpec(.dome(segments: 6), .snow, x: Span(.f(0.5), .f(1.1)), y: Span(.lo(), .f(0.6)), z: Span(.f(0.1), .f(0.6))),
        ]),
    ]
}
