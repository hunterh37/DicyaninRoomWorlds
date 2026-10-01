import Foundation
import simd

/// Registry of blueprints and themes. `AssetLibrary.standard` ships every built-in;
/// apps register their own blueprints and themes on a copy.
///
///     var lib = AssetLibrary.standard
///     lib.register(myBlueprint)
///     lib.register(myTheme)
public struct AssetLibrary: Sendable {
    public private(set) var blueprints: [String: AssetBlueprint] = [:]
    public private(set) var themes: [String: WorldTheme] = [:]

    /// Faithful blueprint per archetype, used when a theme does not map one.
    public var defaults: [Archetype: [String]] = [
        .diningTable: ["table.classic", "table.round"], .coffeeTable: ["table.classic"], .sideTable: ["table.round"],
        .desk: ["desk.drawers"], .counter: ["counter.block"], .chair: ["chair.classic"], .armchair: ["chair.armchair"],
        .sofa: ["sofa.cushions"], .stool: ["stool.round"], .bed: ["bed.frame"], .lowCabinet: ["cabinet.doors"],
        .wardrobe: ["wardrobe.tall"], .shelf: ["shelf.books"], .appliance: ["appliance.box"], .tallAppliance: ["appliance.tall"],
        .tv: ["tv.panel"], .plant: ["plant.potted"], .stairs: ["stairs.ramp"], .clutter: ["crate.box"],
    ]

    public init(blueprints: [AssetBlueprint] = [], themes: [WorldTheme] = []) {
        blueprints.forEach { register($0) }
        themes.forEach { register($0) }
    }

    public static let standard = AssetLibrary(
        blueprints: AssetBlueprint.furniture + AssetBlueprint.nature + AssetBlueprint.sciFi + AssetBlueprint.structure,
        themes: WorldTheme.builtIn)

    public mutating func register(_ blueprint: AssetBlueprint) { blueprints[blueprint.id] = blueprint }
    public mutating func register(_ theme: WorldTheme) { themes[theme.id] = theme }

    public subscript(blueprint id: String) -> AssetBlueprint? { blueprints[id] }
    public subscript(theme id: String) -> WorldTheme? { themes[id] }

    /// Blueprint for an archetype in a theme. Variant chosen by `rng`; falls back to defaults, then a crate.
    public func blueprint(for archetype: Archetype, theme: WorldTheme, rng: inout SeededRandom) -> AssetBlueprint {
        let ids = (theme.furniture[archetype] ?? []).filter { blueprints[$0] != nil }
        let pool = ids.isEmpty ? (defaults[archetype] ?? []).filter { blueprints[$0] != nil } : ids
        if !pool.isEmpty, let b = blueprints[pool[Int(rng.next() % UInt64(pool.count))]] { return b }
        return blueprints["crate.box"] ?? AssetBlueprint("fallback.box", size: [0.5, 0.5, 0.5], parts: [PartSpec(.box, .primary)])
    }

    /// Blueprints carrying `tag`.
    public func blueprints(tagged tag: String) -> [AssetBlueprint] {
        blueprints.values.filter { $0.tags.contains(tag) }.sorted { $0.id < $1.id }
    }
}
