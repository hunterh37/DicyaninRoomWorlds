# Algorithms

Units are meters, Y up. Yaw rotates local +Z (object front) to (sin yaw, 0, cos yaw), matching StyleRoom.

## Inputs on Vision Pro

Third-party visionOS apps get no camera frames (enterprise entitlement only), so image-based detectors are out. The available signals are:

| Source | Data | Use here |
|---|---|---|
| `SceneReconstructionProvider(modes: [.classification])` | world mesh chunks, one label per triangle (14 classes in visionOS 2+) | primary input |
| `PlaneDetectionProvider` | planar patches with a class (7 classes) | fallback walls and floor, Manhattan vote |
| `RoomTrackingProvider` (visionOS 2) | current room volume, `contains(point)` | crop the scan to the room the user stands in |
| `WorldTrackingProvider` | head pose, world anchors | app side: persistence and relocalization |

The mesh labels are per face and noisy at object boundaries; furniture is often half labeled (a sofa seat as `seat`, its backrest as `none`). Chunks share no vertices across seams. The pipeline below is built around those two facts.

## 0. Unclassified scans

When a scan holds under 1 m^2 of `wall` and `floor` faces, labels are inferred before step 1: up-facing faces within 5 cm of the floor mode become `floor`, down-facing faces at least 1.9 m up become `ceiling`, and vertical faces at least 1.9 m up become `wall` (tall furniture rarely reaches that band, and the wall histogram in step 2 needs only the upper band). Objects are then classified on geometry alone, without the label term and without `clutter`.

## 1. Room frame

Floor height is the area-weighted median height of up-facing (`n.y > 0.85`) `floor` faces. Without labels it is the lowest histogram mode holding at least 35% of the peak mass of all up-facing area. Ceiling height is the same over down-facing `ceiling` faces, else the 98th percentile of wall height.

Manhattan yaw uses angle quadrupling. For wall faces with horizontal normal angle theta and area w:

```
C = sum w cos(4 theta)    S = sum w sin(4 theta)
yaw = atan2(S, C) / 4                  in (-pi/4, pi/4]
R   = |(C, S)| / sum w                 0 = no dominant axes, 1 = perfect box room
```

Multiplying by 4 maps the four wall directions of a rectangular room onto one, so a plain circular mean finds the axis without clustering. R gates every later Manhattan snap (R >= 0.25).

## 2. Walls

Wall and opening faces are rotated by -yaw and binned by facing direction (four axis bins within 25 degrees when R is high, else 15 degree bins). Within one direction u, each physical wall is a peak of the area-weighted histogram of the plane offset `d = u . p` (4 cm bins, Gaussian smoothed, peaks at least 24 cm apart). This is a 1D Hough transform per direction. Faces within 12 cm of a peak are sorted along the tangent and split into runs at gaps over 0.6 m. Endpoints are the 0.5th and 99.5th weighted percentiles along the tangent. Corners are snapped by intersecting neighbouring wall lines when both endpoints are within 0.45 m of the intersection.

Window and door faces count toward wall support (so a window does not split its wall) and are segmented separately into openings attached to the nearest wall.

## 3. Object segmentation

Candidate faces are object-labeled faces plus unlabeled faces above the floor, inside the outline and more than 10 cm from any wall. Each face is hashed to a 6 cm voxel; faces of one label are connected when their voxels touch (26-neighbourhood), solved with union-find. Voxel adjacency works across mesh chunk seams where vertex adjacency fails.

A merge pass fuses fragments of one object: an unlabeled segment that overlaps a labeled one by at least 35% of the smaller footprint (vertical gap at most 20 cm) joins it and takes its label. That reattaches backrests, table legs and headboards.

## 4. Oriented box fitting

- Height: 2nd and 98th weighted percentiles of vertex height. A bottom within 25 cm of the floor snaps to the floor, since the scanner rarely sees under furniture.
- Orientation: minimum-area enclosing rectangle of the convex hull of the inner 96% of footprint points (rotating calipers, Freeman and Shapira 1975), snapped to the Manhattan frame when within 12 degrees.
- Extents: 1st and 99th weighted percentiles along the chosen axes.
- Functional surface: the mode of the up-facing area histogram (2 cm bins), measured from the box bottom. This is the seat height of a sofa or the top of a table, and it drives asset fitting.
- Front: if area exists more than 12 cm above the surface (a backrest or headboard), the front points away from its centroid. Else, if the object is within 35 cm of a wall, the front is the wall's inward normal. Else it faces the room center. The result is snapped to a box axis.

## 5. Archetype classification

Naive Bayes over the measured box, with log-normal size likelihoods so error is relative to scale:

```
score(a) = ln P(label | a)
         + sum_k -1/2 ((ln x_k - ln mu_k) / sigma_k)^2     x = (long side, short side, height)
         + -1/2 ((s - mu_s) / sigma_s)^2                    s = functional surface height
         + ln P(near wall | a)
P(a | obs) = softmax(score)
```

Footprint sides are sorted, so the score does not depend on which side is the front. Priors cover 19 archetypes (dining, coffee and side tables, desk, counter, chair, armchair, sofa, stool, bed, low cabinet, wardrobe, shelf, appliance, tall appliance, TV, plant, stairs, clutter). `ArchetypeClassifier.defaultPriors` is plain data; apps can retune it or add classes.

## 6. Floor grid

A 10 cm grid in the Manhattan frame, stored as one byte per cell; clearance is recomputed on decode. Cells inside the outline and within 30 cm of a scanned floor face are floor; object footprints standing on the floor are obstacles; walls are stroked 12 cm wide. A two-pass 8-neighbour chamfer transform (Borgefors 1986) gives each floor cell its clearance to the nearest non-floor cell. On top: `isWalkable(radius:)`, A* with an octile heuristic and no corner cutting, optional string pulling (keep a waypoint only when the next one is out of sight, line of sight sampled at half-cell steps against the agent radius), and farthest-point spawn sampling seeded at the most open cell.

## 7. Fitting assets to measured objects

A blueprint part has a primitive (box, cylinder or cone, sphere, dome, wedge, jittered rock) and a span on each axis. Each span edge is affine in the measured box:

```
edge = base + fraction * extent + offset          base in { min, max, center, surface }
```

Since every edge is affine in (width, height, depth, surface), a blueprint reproduces any measured box exactly, and parts given in metric offsets (legs, slabs, frames) keep real thickness at any size. This is a 3D nine-slice; the closest prior work is non-homogeneous resizing (Kraevoy et al. 2008), which learns the same stretch-or-keep split per region by optimization. Here the author states it, which costs nothing at runtime and keeps assets editable as data.

Two extensions:

- `RepeatRule`: a part tiles its span into n = clamp(round(extent / pitch), 1, max) cells and covers fractions [from, to] of each. A 3 m sofa gets five cushions, a 1.4 m one gets two; shelves get one plank per 36 cm.
- `PartCondition`: parts appear only above size thresholds, so a backless bench drops the backrest (`height - surface <= 0.15`).

The functional surface anchor matters for mixed reality: a stand-in sofa's seat is at the measured seat height, so a user who sits on the virtual log sits on the real cushion.

## 8. World generation

- Furniture: each object maps through the theme's archetype table (variant by seed) to a blueprint fitted to its box, surface and yaw.
- Boundary: pieces tile each wall at the theme spacing, pushed outward by half their depth so their room-facing side sits on the wall. Door spans stay open. Window spans keep a piece up to the sill. `boundaryJitter` moves between a clean panel grid (0) and an organic tree line (1).
- Openings: the theme's door and window blueprints are fitted to the opening rectangle.
- Terrain: a triangulated grid over the outline plus an apron. Inside the room `h = bump * (2 fbm - 1)` with bump at most 1.2 cm, so walkable ground matches the real floor. Outside, `h = rim * smoothstep(d / apron) * (0.6 + 0.4 fbm)` raises hills, dunes or drifts past the walls.
- Decor: Bridson Poisson-disk samples (radius `0.35 / sqrt(total density)`) restricted to floor cells, then per-rule clearance and an openness term `p = o c + (1 - o)(1 - c)` (c = normalized clearance) that pushes mushrooms toward edges and grass into the open. Decor is non-colliding and batched per 2.5 m tile.

Every random choice uses SplitMix64 streams derived from (seed, stable ID), so changing one object does not reshuffle the rest of the world. IDs are kind plus position quantized to 20 cm (walls: facing in 15 degree steps plus plane offset), with a `#n` suffix on collisions. An object whose center crosses a 20 cm boundary between scans gets a new ID.

## Comparison with published approaches

| Approach | Needs | Fit for on-device visionOS |
|---|---|---|
| Apple RoomPlan | iPhone/iPad LiDAR + camera | not on visionOS; accepted as input on iOS via `RoomScan(meshAnchors:)` or a converter |
| Scan2CAD, ROCA, SceneCAD (learned CAD retrieval and alignment) | RGB-D frames, GPU network, CAD database | no camera frames; network and database too large |
| SceneScript (Meta 2024), structured layout language from point clouds | trained transformer | possible later with Core ML; no public visionOS model |
| Holodeck, LayoutGPT (LLM layout) | network LLM | complementary: an LLM can author blueprints and themes as JSON, this package fits them to the room |
| This package | mesh labels and planes only | runs in about 50 ms for a 95k-triangle room |

## Extension points

- Retune `ArchetypeClassifier.defaultPriors` or add archetypes for a game's needs.
- Blueprints and themes are `Codable`: an LLM (the StyleRoom pattern) can return new blueprint JSON that registers into `AssetLibrary` and fits to the scan with no code.
- Replace `SyntheticRoom` scans in tests with recorded `RoomScan.encoded()` captures from a headset.

## References

- Coughlan and Yuille, Manhattan World, ICCV 1999.
- Freeman and Shapira, Determining the minimum-area encasing rectangle, CACM 1975.
- Borgefors, Distance transformations in digital images, CVGIP 1986.
- Bridson, Fast Poisson disk sampling in arbitrary dimensions, SIGGRAPH 2007 sketches.
- Kraevoy, Sheffer, Shamir, Cohen-Or, Non-homogeneous resizing of complex models, SIGGRAPH Asia 2008.
- Avetisyan et al., Scan2CAD, CVPR 2019. Gumeli et al., ROCA, CVPR 2022.
- Avetisyan et al., SceneScript, ECCV 2024.
- Yang et al., Holodeck, CVPR 2024. Feng et al., LayoutGPT, NeurIPS 2023.
