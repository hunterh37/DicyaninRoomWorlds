# Changelog

## 1.0.0 (2026-10-01)

First release.

- `RoomScanner` (visionOS): scene reconstruction with classification, plane detection, room tracking, live labeled preview, coverage.
- ARKit conversion for visionOS `MeshAnchor` and `PlaneAnchor`, and iOS `ARMeshAnchor`.
- `RoomAnalyzer`: floor and ceiling, Manhattan axis, walls, windows, doors, measured objects with archetypes, floor grid with clearance, A* and spawn points.
- 70 parametric blueprints fitted to measured boxes; 5 themes (cozy, forest, neon, desert, tundra).
- `WorldGenerator` and Codable `WorldSpec`; `WorldEntityBuilder` with ECS components, colliders, batched decor, sun and sky.
- `SyntheticRoom` scans for tests and the simulator.
