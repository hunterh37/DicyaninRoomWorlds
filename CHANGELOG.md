# Changelog

## 1.1.0 (2026-10-01)

- Stable IDs. Objects, walls and openings are named by kind and quantized position (`sofa@1_-11`, `wall90@12_0`, `door@-6_3`) instead of list index. Adding or removing one object no longer renumbers the others, so their blueprint variants and seeds stay put. IDs from 1.0 scans change once.
- Theme JSON. `MaterialRole` and `Archetype` are `CodingKeyRepresentable`, so `palette` and `furniture` encode as objects keyed by name and `WorldSpec.encoded()` is byte-stable. 1.0 files (alternating key/value arrays) still decode. Optional theme and terrain fields default when missing.
- `FloorGrid` encodes cells as packed bytes and recomputes clearance on decode. The sample room spec drops from 40 KB to under 30 KB. `WorldSpec.version` is 2; version 1 decodes.
- Unclassified scans. `RoomAnalyzer.Options.inferMissingLabels` (default on) labels floor, ceiling and upper wall faces from geometry when a scan has under 1 m^2 of wall and floor labels, and classifies objects by shape. An unlabeled sample room now yields 4 walls and a floor grid (1.0: 0 walls, empty outline).
- `FloorGrid.path(..., smooth: true)`, `hasLineOfSight` and `simplify` for straight-leg NPC paths.
- `RoomScanner(session:)` no longer stops a shared `ARKitSession` in `stop()`. Coverage is measured off the main actor. Throttled preview updates are flushed on the next tick. `makeWorld` takes `analyzerOptions`.
- Sky gradient texture: sRGB color space; the pixel buffer no longer outlives its pointer.

## 1.0.1 (2026-10-01)

- Builds with Xcode 16 (Swift 6.1, visionOS 2 and iOS 18 SDKs). 1.0.0 required Xcode 26.
- CI: macOS tests plus iOS and visionOS builds.

## 1.0.0 (2026-10-01)

First release.

- `RoomScanner` (visionOS): scene reconstruction with classification, plane detection, room tracking, live labeled preview, coverage.
- ARKit conversion for visionOS `MeshAnchor` and `PlaneAnchor`, and iOS `ARMeshAnchor`.
- `RoomAnalyzer`: floor and ceiling, Manhattan axis, walls, windows, doors, measured objects with archetypes, floor grid with clearance, A* and spawn points.
- 70 parametric blueprints fitted to measured boxes; 5 themes (cozy, forest, neon, desert, tundra).
- `WorldGenerator` and Codable `WorldSpec`; `WorldEntityBuilder` with ECS components, colliders, batched decor, sun and sky.
- `SyntheticRoom` scans for tests and the simulator.
