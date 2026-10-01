import Foundation
import simd

/// Scan to `RoomModel`. Pure Swift and `Sendable`; run it off the main actor.
///
///     let model = RoomAnalyzer().analyze(scan)
public struct RoomAnalyzer: Sendable {
    public struct Options: Sendable {
        /// Voxel edge for object segmentation, meters.
        public var voxelSize: Float = 0.06
        /// Segments smaller than this (m^2 of scanned surface) are dropped.
        public var minObjectArea: Float = 0.04
        /// Keep unlabeled geometry standing on the floor as `clutter` objects.
        public var includeClutter: Bool = true
        /// Floor grid cell size, meters.
        public var gridCell: Float = 0.1
        public var classifier: ArchetypeClassifier = ArchetypeClassifier()
        /// When the scan has under 1 m^2 of wall and floor labels (iOS `.mesh` without
        /// classification, some recorded scans), label floor, ceiling and upper wall faces from
        /// geometry and classify objects by shape alone.
        public var inferMissingLabels: Bool = true
        public init() {}
    }

    public var options: Options

    public init(options: Options = Options()) { self.options = options }

    public func analyze(_ scan: RoomScan) -> RoomModel {
        var faces = FaceSet(scan: scan)
        let inferred = options.inferMissingLabels && Self.inferStructure(&faces, planes: scan.planes)
        let frame = RoomFrame.estimate(faces, planes: scan.planes)
        let walls = WallExtractor().extract(faces, frame: frame, planes: scan.planes)
        let openings = WallExtractor().openings(faces, frame: frame, walls: walls)
        let outline = floorOutline(faces, frame: frame, walls: walls, planes: scan.planes)
        let center = outline.isEmpty ? SIMD2<Float>.zero : outline.reduce(.zero, +) / Float(outline.count)
        let objects = detectObjects(faces, frame: frame, walls: walls, outline: outline, center: center, ignoreLabels: inferred)
        let grid = buildGrid(faces, frame: frame, walls: walls, outline: outline, objects: objects)
        return RoomModel(floorY: frame.floorY, ceilingY: frame.ceilingY, manhattanYaw: frame.manhattanYaw,
                         manhattanConfidence: frame.manhattanConfidence, walls: walls, openings: openings,
                         objects: objects, outline: outline, grid: grid)
    }

    // MARK: Stages

    /// Geometric labels for unclassified scans. Floor: up-facing faces within 5 cm of the floor
    /// mode. Ceiling: down-facing faces 1.9 m or more above it. Wall: vertical faces 1.9 m or more
    /// above the floor, a band that tall furniture rarely reaches. Returns true when it relabeled.
    static func inferStructure(_ faces: inout FaceSet, planes: [ScanPlane]) -> Bool {
        var labeled: Float = 0
        for i in 0..<faces.count where faces.label[i] == .wall || faces.label[i] == .floor { labeled += faces.area[i] }
        guard labeled < 1 else { return false }
        let floorY = RoomFrame.estimate(faces, planes: planes).floorY
        var changed = false
        for i in 0..<faces.count where faces.label[i] == .none {
            let n = faces.normal[i], y = faces.centroid[i].y - floorY
            if n.y > 0.85 && abs(y) < 0.05 { faces.label[i] = .floor; changed = true }
            else if n.y < -0.85 && y >= 1.9 { faces.label[i] = .ceiling; changed = true }
            else if abs(n.y) < 0.3 && y >= 1.9 { faces.label[i] = .wall; changed = true }
        }
        return changed
    }

    func floorOutline(_ faces: FaceSet, frame: RoomFrame, walls: [WallSegment], planes: [ScanPlane]) -> [SIMD2<Float>] {
        var pts: [SIMD2<Float>] = []
        for i in 0..<faces.count where faces.label[i] == .floor && abs(faces.centroid[i].y - frame.floorY) < 0.1 {
            pts.append(SIMD2(faces.centroid[i].x, faces.centroid[i].z))
        }
        for w in walls { pts.append(w.start); pts.append(w.end) }
        for p in planes where p.label == .floor {
            let a = SIMD2(p.widthAxis.x, p.widthAxis.z) * p.width / 2
            let n = simd_cross(p.normal, p.widthAxis)
            let b = SIMD2(n.x, n.z) * p.height / 2
            let c = SIMD2(p.center.x, p.center.z)
            pts += [c - a - b, c + a - b, c + a + b, c - a + b]
        }
        return Polygon2D.convexHull(pts)
    }

    func detectObjects(_ faces: FaceSet, frame: RoomFrame, walls: [WallSegment], outline: [SIMD2<Float>], center: SIMD2<Float>,
                       ignoreLabels: Bool = false) -> [DetectedObject] {
        let floorY = frame.floorY, ceilY = frame.ceilingY
        func nearWall(_ p: SIMD3<Float>) -> Bool {
            let q = SIMD2(p.x, p.z)
            return walls.contains { w in
                let (d, t) = Polygon2D.segmentDistance(q, w.start, w.end)
                return d < 0.1 && t > 0 && t < 1
            }
        }
        let cand = faces.indices { i in
            let l = faces.label[i], p = faces.centroid[i]
            if l.isObject { return p.y > floorY - 0.05 && p.y < ceilY - 0.05 }
            guard options.includeClutter, l == .none else { return false }
            guard p.y > floorY + 0.04, p.y < ceilY - 0.3 else { return false }
            return !nearWall(p) && (outline.count < 3 || Polygon2D.contains(outline, SIMD2(p.x, p.z)))
        }
        var segs = VoxelSegmenter(voxelSize: options.voxelSize).segment(faces, candidates: cand)
        segs = segs.filter { $0.area >= options.minObjectArea * 0.25 }
        segs = VoxelSegmenter.merge(segs)
        segs = segs.filter { $0.area >= options.minObjectArea }
        // Unlabeled clutter must stand on the floor; floating none-faces are usually wall decor or noise.
        segs = segs.filter { $0.label != .none || $0.lo.y - floorY < 0.3 }

        let fitter = ObjectFitter()
        var out: [DetectedObject] = []
        var used: Set<String> = []
        for seg in segs.sorted(by: { ($0.area, $0.lo.x, $0.lo.z) > ($1.area, $1.lo.x, $1.lo.z) }) {
            guard let fit = fitter.fit(seg, faces: faces, frame: frame, walls: walls, roomCenter: center) else { continue }
            let obs = ArchetypeClassifier.Observation(label: seg.label, size: fit.box.size, surface: fit.surfaceHeight, nearWall: fit.wallID != nil,
                                                      ignoresLabel: ignoreLabels)
            let ranked = options.classifier.classify(obs)
            guard let top = ranked.first else { continue }
            let id = Self.stableID(top.archetype.rawValue, at: fit.box.center, used: &used)
            out.append(DetectedObject(id: id, label: seg.label, archetype: top.archetype,
                                      box: fit.box, surfaceHeight: fit.surfaceHeight, area: seg.area, confidence: top.probability,
                                      wallID: fit.wallID, alternatives: Array(ranked.dropFirst().prefix(2))))
        }
        return out
    }

    /// ID from the kind and the XZ position quantized to 20 cm. Adding, removing or resizing one
    /// object leaves every other ID (and so every per-object seed) unchanged. Collisions get a suffix.
    static func stableID(_ kind: String, at p: SIMD3<Float>, used: inout Set<String>) -> String {
        let q = SIMD2<Float>(p.x, p.z) / 0.2
        let base = "\(kind)@\(Int((q.x).rounded()))_\(Int((q.y).rounded()))"
        var id = base, k = 2
        while used.contains(id) { id = "\(base)#\(k)"; k += 1 }
        used.insert(id)
        return id
    }

    func buildGrid(_ faces: FaceSet, frame: RoomFrame, walls: [WallSegment], outline: [SIMD2<Float>], objects: [DetectedObject]) -> FloorGrid {
        let yaw = frame.manhattanYaw, cell = options.gridCell
        let g = outline.map { Yaw.rotate($0, -yaw) }
        let lo = (g.reduce(SIMD2<Float>(repeating: .infinity)) { simd_min($0, $1) }) - 0.3
        let hi = (g.reduce(SIMD2<Float>(repeating: -.infinity)) { simd_max($0, $1) }) + 0.3
        guard lo.x.isFinite, hi.x.isFinite else { return FloorGrid(origin: .zero, cellSize: cell, yaw: yaw, columns: 1, rows: 1) }
        var grid = FloorGrid(origin: lo, cellSize: cell, yaw: yaw,
                             columns: Int(((hi.x - lo.x) / cell).rounded(.up)), rows: Int(((hi.y - lo.y) / cell).rounded(.up)))
        // Floor = hull cells within 0.3 m of scanned floor (handles L-shaped rooms and open sides).
        let reach = Int((0.3 / cell).rounded())
        for i in 0..<faces.count where faces.label[i] == .floor && abs(faces.centroid[i].y - frame.floorY) < 0.1 {
            guard let (c0, r0) = grid.cellIndex(SIMD2(faces.centroid[i].x, faces.centroid[i].z)), grid[c0, r0] == .outside else { continue }
            for r in max(0, r0 - reach)...min(grid.rows - 1, r0 + reach) {
                for c in max(0, c0 - reach)...min(grid.columns - 1, c0 + reach) where grid[c, r] == .outside {
                    if outline.count < 3 || Polygon2D.contains(outline, grid.cellCenter(c, r)) { grid[c, r] = .floor }
                }
            }
        }
        if grid.floorCellCount == 0 { grid.fill(polygon: outline, with: .floor) }
        for o in objects where o.box.bottomY - frame.floorY < 0.5 && o.box.size.y > 0.08 {
            grid.fill(polygon: o.box.footprint, with: .obstacle)
        }
        for w in walls { grid.stroke(w.start, w.end, thickness: 0.12, with: .wall) }
        grid.computeClearance()
        return grid
    }
}
