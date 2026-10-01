import Foundation

public extension WorldTheme {
    static let builtIn: [WorldTheme] = [cozy, enchantedForest, neonCity, desertRuins, frozenTundra]

    /// Same room, same furniture, stylized low-poly. Matches the real layout one to one (good for passthrough overlay).
    static let cozy = WorldTheme(
        id: "cozy", name: "Cozy Low-Poly",
        palette: [
            .primary: .init(0xC8935A), .secondary: .init(0x7A4E2D), .accent: .init(0xD9614C), .trim: .init(0x3B2A20),
            .soft: .init(0xE9D8B4, roughness: 1), .metal: .init(0xB9B9B0, roughness: 0.35, metallic: 0.8),
            .glass: .init(0x24303D, roughness: 0.15), .glow: .init(0xFFD27A, emissive: 2), .stone: .init(0x9C9488),
            .wood: .init(0xB27B48), .foliage: .init(0x5E9E4A), .foliageAlt: .init(0x7DB85A), .bark: .init(0x6B4A2E),
            .ground: .init(0xB98A5A, roughness: 0.9), .groundAlt: .init(0xA77A4E, roughness: 0.9),
            .water: .init(0x4FA3C7, roughness: 0.1), .snow: .init(0xF4F7FB), .crystal: .init(0x9FD8F0, roughness: 0.2),
        ],
        furniture: [:],
        boundary: ["wall.timber"], boundarySpacing: 1.2, boundaryDepth: 0.12...0.12, boundaryHeight: 1...1, boundaryJitter: 0,
        door: "opening.frame", window: "opening.vista",
        decor: [DecorRule("pebble", density: 0.02, openness: 0)],
        terrain: { var t = TerrainStyle(); t.bump = 0; t.rimHeight = 0; t.apron = 0.1; t.patchCoverage = 0.2; t.patchScale = 0.6; return t }(),
        sky: SkyStyle(zenith: 0x8EC5E8, horizon: 0xF6E3C3, sunColor: 0xFFE7C2, sunIntensity: 1, ambient: 0.6),
        ceiling: .flat)

    static let enchantedForest = WorldTheme(
        id: "forest", name: "Enchanted Forest",
        palette: [
            .primary: .init(0x8C6A43), .secondary: .init(0x5C4128), .accent: .init(0xD8433A), .trim: .init(0xF1E6C8),
            .soft: .init(0x8FBF5A, roughness: 1), .metal: .init(0x6D6A5E, roughness: 0.5, metallic: 0.6),
            .glass: .init(0x8BD3E6, roughness: 0.1, opacity: 0.85), .glow: .init(0xFFE38A, emissive: 3),
            .stone: .init(0x8D9188), .wood: .init(0xC49A64), .foliage: .init(0x3F8F3A), .foliageAlt: .init(0x6BB34A),
            .bark: .init(0x5E4026), .ground: .init(0x5E9A3E, roughness: 1), .groundAlt: .init(0x7AAF48, roughness: 1),
            .water: .init(0x5CC0D8, roughness: 0.05, emissive: 0.4), .snow: .init(0xF2F6F8), .crystal: .init(0x9C7BFF, roughness: 0.2, emissive: 1.2),
        ],
        furniture: [
            .diningTable: ["rock.slab", "stump.table"], .coffeeTable: ["stump.table"], .sideTable: ["stump.table"],
            .desk: ["rock.slab"], .counter: ["rock.slab"], .chair: ["stump.seat"], .armchair: ["rock.throne"],
            .sofa: ["log.bench"], .stool: ["mushroom.seat"], .bed: ["moss.bed"], .lowCabinet: ["boulder"],
            .wardrobe: ["cliff.pillar"], .shelf: ["cliff.pillar"], .appliance: ["boulder"], .tallAppliance: ["cliff.pillar"],
            .tv: ["spirit.mirror"], .plant: ["tree.small"], .stairs: ["stairs.ramp"], .clutter: ["boulder", "crystal.cluster"],
        ],
        boundary: ["tree.pine", "tree.pine", "tree.small"], boundarySpacing: 0.75, boundaryDepth: 0.6...1.0, boundaryHeight: 0.9...1.35,
        door: "opening.portal", window: "opening.portal",
        decor: [
            DecorRule("grass.tuft", density: 2.5, minClearance: 0.05, openness: 0.3), DecorRule("flower", density: 0.5, minClearance: 0.1),
            DecorRule("mushroom.small", density: 0.2, minClearance: 0.1, openness: 0), DecorRule("pebble", density: 0.25),
            DecorRule("shrub", density: 0.12, minClearance: 0.25, openness: 0), DecorRule("lantern", density: 0.04, minClearance: 0.3),
        ],
        terrain: { var t = TerrainStyle(); t.rimHeight = 0.45; return t }(),
        sky: SkyStyle(zenith: 0x4F8FD6, horizon: 0xCFE9C8, sunColor: 0xFFF1C9, sunIntensity: 1.1, ambient: 0.55))

    static let neonCity = WorldTheme(
        id: "neon", name: "Neon City",
        palette: [
            .primary: .init(0x3C4260, roughness: 0.5), .secondary: .init(0x272A3D, roughness: 0.6), .accent: .init(0xFF3D9A, emissive: 1.5),
            .trim: .init(0x1A1C28, roughness: 0.4), .soft: .init(0x6A55A8, roughness: 0.9),
            .metal: .init(0x8A93A6, roughness: 0.25, metallic: 1), .glass: .init(0x3BE8FF, roughness: 0.05, emissive: 0.6, opacity: 0.55),
            .glow: .init(0x2DF5FF, emissive: 3.5), .stone: .init(0x3A3D4C), .wood: .init(0x3A3D4C), .foliage: .init(0x39FF88, emissive: 1),
            .foliageAlt: .init(0x26C46A, emissive: 0.6), .bark: .init(0x22242F), .ground: .init(0x24283A, roughness: 0.35, metallic: 0.4),
            .groundAlt: .init(0x30354D, roughness: 0.3, metallic: 0.5), .water: .init(0x3BE8FF, emissive: 1),
            .snow: .init(0xD8E2FF), .crystal: .init(0xB45CFF, roughness: 0.15, emissive: 1.8),
        ],
        furniture: [
            .diningTable: ["holo.table"], .coffeeTable: ["holo.table"], .sideTable: ["cargo.crate"], .desk: ["terminal.desk"],
            .counter: ["terminal.desk"], .chair: ["neon.chair"], .armchair: ["neon.sofa"], .sofa: ["neon.sofa"], .stool: ["neon.chair"],
            .bed: ["cryo.pod"], .lowCabinet: ["cargo.crate"], .wardrobe: ["server.rack"], .shelf: ["server.rack"],
            .appliance: ["cargo.crate"], .tallAppliance: ["server.rack"], .tv: ["holo.screen"], .plant: ["neon.tree"],
            .stairs: ["stairs.ramp"], .clutter: ["cargo.crate"],
        ],
        boundary: ["wall.panel", "wall.panel", "server.rack"], boundarySpacing: 1.0, boundaryDepth: 0.25...0.45, boundaryHeight: 1...1.15, boundaryJitter: 0.2,
        door: "opening.gate", window: "opening.vista",
        decor: [DecorRule("neon.cone", density: 0.08, minClearance: 0.3, openness: 0), DecorRule("cable.bundle", density: 0.15, minClearance: 0.1, openness: 0)],
        terrain: { var t = TerrainStyle(); t.bump = 0; t.rimHeight = 0.05; t.patchScale = 0.5; t.patchCoverage = 0.5; return t }(),
        sky: SkyStyle(zenith: 0x0B0820, horizon: 0x5A1E6E, sunColor: 0xB8A6FF, sunIntensity: 0.5, ambient: 0.35))

    static let desertRuins = WorldTheme(
        id: "desert", name: "Desert Ruins",
        palette: [
            .primary: .init(0xD9B47A), .secondary: .init(0xB88A52), .accent: .init(0x2F8F9D), .trim: .init(0x8C5A3C),
            .soft: .init(0xC9744A, roughness: 1), .metal: .init(0xC9A24A, roughness: 0.3, metallic: 0.9),
            .glass: .init(0x7FD6E0, roughness: 0.1), .glow: .init(0x5FF2E1, emissive: 2.5), .stone: .init(0xC29B6B),
            .wood: .init(0x9A6B3F), .foliage: .init(0x6E9A4A), .foliageAlt: .init(0x8DB35A), .bark: .init(0x7B5536),
            .ground: .init(0xE2C08A, roughness: 1), .groundAlt: .init(0xD4AC72, roughness: 1),
            .water: .init(0x3CB4C8, roughness: 0.05), .snow: .init(0xF5E9D0), .crystal: .init(0x46E0C8, roughness: 0.2, emissive: 1),
        ],
        furniture: [
            .diningTable: ["sandstone.altar"], .coffeeTable: ["rock.slab"], .sideTable: ["boulder"], .desk: ["sandstone.altar"],
            .counter: ["sandstone.altar"], .chair: ["rock.throne"], .armchair: ["rock.throne"], .sofa: ["rock.throne"], .stool: ["boulder"],
            .bed: ["moss.bed"], .lowCabinet: ["boulder"], .wardrobe: ["ruin.column"], .shelf: ["ruin.column"], .appliance: ["boulder"],
            .tallAppliance: ["ruin.column"], .tv: ["crystal.cluster"], .plant: ["cactus"], .stairs: ["stairs.ramp"], .clutter: ["boulder"],
        ],
        boundary: ["wall.dune", "wall.dune", "ruin.column"], boundarySpacing: 1.1, boundaryDepth: 0.5...0.9, boundaryHeight: 0.6...1.0,
        door: "opening.arch", window: "opening.portal",
        decor: [DecorRule("pebble", density: 0.35), DecorRule("cactus.small", density: 0.15, minClearance: 0.25, openness: 0), DecorRule("dune.ripple", density: 0.25, minClearance: 0.05, openness: 1)],
        terrain: { var t = TerrainStyle(); t.rimHeight = 0.6; t.patchScale = 2; return t }(),
        sky: SkyStyle(zenith: 0x3E8EDB, horizon: 0xF7D9A8, sunColor: 0xFFE0A8, sunIntensity: 1.4, ambient: 0.6))

    static let frozenTundra = WorldTheme(
        id: "tundra", name: "Frozen Tundra",
        palette: [
            .primary: .init(0xBFD7EA), .secondary: .init(0x8FB3D1), .accent: .init(0xE0565B), .trim: .init(0x4E6A85),
            .soft: .init(0xD8C3A5, roughness: 1), .metal: .init(0x9AA7B4, roughness: 0.3, metallic: 0.8),
            .glass: .init(0xBDE8FF, roughness: 0.05, opacity: 0.8), .glow: .init(0xFFB25C, emissive: 2.5), .stone: .init(0x7D8A99),
            .wood: .init(0x8A6A4C), .foliage: .init(0x2F5D4A), .foliageAlt: .init(0x3D7058), .bark: .init(0x4A3A2C),
            .ground: .init(0xEEF4FA, roughness: 0.95), .groundAlt: .init(0xD9E6F2, roughness: 0.9),
            .water: .init(0x6FB6E8, roughness: 0.05), .snow: .init(0xFBFDFF, roughness: 0.95), .crystal: .init(0xA8E4FF, roughness: 0.1, opacity: 0.85),
        ],
        furniture: [
            .diningTable: ["ice.block"], .coffeeTable: ["ice.block"], .sideTable: ["ice.block"], .desk: ["ice.block"], .counter: ["ice.block"],
            .chair: ["ice.bench"], .armchair: ["ice.bench"], .sofa: ["ice.bench"], .stool: ["snow.mound"], .bed: ["snow.bed"],
            .lowCabinet: ["ice.block"], .wardrobe: ["wall.ice"], .shelf: ["wall.ice"], .appliance: ["ice.block"], .tallAppliance: ["wall.ice"],
            .tv: ["crystal.cluster"], .plant: ["pine.snowy"], .stairs: ["stairs.ramp"], .clutter: ["snow.mound", "boulder"],
        ],
        boundary: ["pine.snowy", "wall.ice", "pine.snowy"], boundarySpacing: 0.8, boundaryDepth: 0.6...1.0, boundaryHeight: 0.9...1.3,
        door: "opening.portal", window: "opening.vista",
        decor: [DecorRule("snow.mound", density: 0.35, minClearance: 0.1, openness: 0.2), DecorRule("ice.shard", density: 0.15, minClearance: 0.2, openness: 0),
                DecorRule("pebble", density: 0.08), DecorRule("lantern", density: 0.04, minClearance: 0.3)],
        terrain: { var t = TerrainStyle(); t.rimHeight = 0.5; return t }(),
        sky: SkyStyle(zenith: 0x7FA8D9, horizon: 0xEAF2FA, sunColor: 0xFFF4E0, sunIntensity: 0.9, ambient: 0.7))
}
