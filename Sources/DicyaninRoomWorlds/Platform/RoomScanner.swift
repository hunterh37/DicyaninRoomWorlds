#if canImport(ARKit) && os(visionOS)
import ARKit
import RealityKit
import Foundation
import Observation

/// One-object scanning service for Vision Pro: scene reconstruction with classification,
/// plane detection, optional room tracking, live coverage and a colored preview mesh.
///
///     let scanner = RoomScanner()
///     await scanner.start()
///     content.add(scanner.previewRoot)          // live labeled mesh
///     if scanner.coverage.isSufficient { let world = await scanner.makeWorld(theme: .enchantedForest) }
@MainActor
@Observable
public final class RoomScanner {
    public enum State: Equatable, Sendable {
        case idle, scanning, stopped, unsupported, denied
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var coverage = ScanCoverage()
    public private(set) var meshCount = 0

    /// Live preview of the scan colored by label. Add it to a RealityView.
    public let previewRoot = Entity()
    public var showsPreview = true { didSet { previewRoot.isEnabled = showsPreview } }
    public var previewOpacity: Float = 0.55
    /// Minimum seconds between preview rebuilds per anchor.
    public var previewInterval: TimeInterval = 0.6
    /// Restrict snapshots to the room the user is standing in (visionOS 2 room tracking).
    public var limitToCurrentRoom = true

    @ObservationIgnored private let session: ARKitSession
    @ObservationIgnored private let ownsSession: Bool
    @ObservationIgnored private var pendingPreview: Set<UUID> = []
    @ObservationIgnored private var meshes: [UUID: ScanMesh] = [:]
    @ObservationIgnored private var planes: [UUID: ScanPlane] = [:]
    @ObservationIgnored private var previews: [UUID: ModelEntity] = [:]
    @ObservationIgnored private var lastPreview: [UUID: Date] = [:]
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var roomProvider: RoomTrackingProvider?
    @ObservationIgnored private var coverageDirty = false

    /// Uses a private `ARKitSession`. `stop()` stops it.
    public init() {
        self.session = ARKitSession()
        self.ownsSession = true
        previewRoot.name = "RoomScannerPreview"
    }

    /// Pass the app's shared `ARKitSession` when it already runs hand tracking or other providers.
    /// `stop()` then only stops consuming updates and leaves the session running, since
    /// `ARKitSession.stop()` would also stop the app's other providers.
    public init(session: ARKitSession) {
        self.session = session
        self.ownsSession = false
        previewRoot.name = "RoomScannerPreview"
    }

    public static var isSupported: Bool { SceneReconstructionProvider.isSupported }

    public func start(detectPlanes: Bool = true) async {
        guard state != .scanning else { return }
        guard Self.isSupported else { state = .unsupported; return }
        let auth = await session.requestAuthorization(for: [.worldSensing])
        guard auth[.worldSensing] != .denied else { state = .denied; return }
        let recon = SceneReconstructionProvider(modes: [.classification])
        var providers: [any DataProvider] = [recon]
        let planeProvider = detectPlanes && PlaneDetectionProvider.isSupported ? PlaneDetectionProvider(alignments: [.horizontal, .vertical]) : nil
        if let planeProvider { providers.append(planeProvider) }
        if limitToCurrentRoom, RoomTrackingProvider.isSupported {
            let r = RoomTrackingProvider()
            roomProvider = r
            providers.append(r)
        }
        do {
            try await session.run(providers)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        state = .scanning
        tasks.append(Task { [weak self] in
            for await update in recon.anchorUpdates {
                guard let self, self.state == .scanning else { continue }
                self.apply(update)
            }
        })
        if let planeProvider {
            tasks.append(Task { [weak self] in
                for await update in planeProvider.anchorUpdates {
                    guard let self else { continue }
                    switch update.event {
                    case .added, .updated: self.planes[update.anchor.id] = ScanPlane(planeAnchor: update.anchor)
                    case .removed: self.planes.removeValue(forKey: update.anchor.id)
                    }
                }
            })
        }
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.flushPendingPreviews()
                guard self.coverageDirty else { continue }
                self.coverageDirty = false
                // Measuring walks every face; keep it off the main actor.
                let scan = RoomScan(source: "visionos", meshes: Array(self.meshes.values))
                let cov = await Task.detached(priority: .utility) { ScanCoverage.measure(scan) }.value
                if self.state == .scanning { self.coverage = cov }
            }
        })
    }

    /// Stops consuming updates. The captured data stays available for `snapshot()`.
    public func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        pendingPreview.removeAll()
        if ownsSession { session.stop() }
        if state == .scanning { state = .stopped }
    }

    /// Clears captured data and the preview.
    public func reset() {
        meshes.removeAll(); planes.removeAll(); lastPreview.removeAll(); pendingPreview.removeAll()
        previews.values.forEach { $0.removeFromParent() }
        previews.removeAll()
        coverage = ScanCoverage(); meshCount = 0
    }

    /// Loads a synthetic room (simulator, previews, demos).
    public func loadSynthetic(_ scan: RoomScan = SyntheticRoom.scan(yaw: 0, offset: [0, 0, -1.5])) {
        reset()
        for m in scan.meshes { meshes[m.id] = m; refreshPreview(m, force: true) }
        meshCount = meshes.count
        coverage = ScanCoverage.measure(scan)
    }

    /// Current capture as a platform-independent scan.
    public func snapshot() -> RoomScan {
        var list = Array(meshes.values)
        if limitToCurrentRoom, let room = roomProvider?.currentRoomAnchor {
            list = list.map { m in
                var keep: [UInt32] = [], labels: [SurfaceLabel] = []
                for f in 0..<m.faceCount {
                    let c = (m.positions[Int(m.indices[f * 3])] + m.positions[Int(m.indices[f * 3 + 1])] + m.positions[Int(m.indices[f * 3 + 2])]) / 3
                    guard room.contains(c) else { continue }
                    keep += [m.indices[f * 3], m.indices[f * 3 + 1], m.indices[f * 3 + 2]]
                    labels.append(m.label(ofFace: f))
                }
                return ScanMesh(id: m.id, positions: m.positions, indices: keep, faceLabels: labels)
            }.filter { $0.faceCount > 0 }
        }
        return RoomScan(source: "visionos", meshes: list, planes: Array(planes.values))
    }

    /// Snapshot and analysis off the main actor.
    public func analyze(options: RoomAnalyzer.Options = .init()) async -> RoomModel {
        let scan = snapshot()
        return await Task.detached(priority: .userInitiated) { RoomAnalyzer(options: options).analyze(scan) }.value
    }

    /// Snapshot, analysis and world generation off the main actor.
    public func makeWorld(theme: WorldTheme, seed: UInt64 = UInt64.random(in: 1...UInt64.max),
                          library: AssetLibrary = .standard, options: WorldGenerator.Options = .init(),
                          analyzerOptions: RoomAnalyzer.Options = .init()) async -> WorldSpec {
        let scan = snapshot()
        return await Task.detached(priority: .userInitiated) {
            let model = RoomAnalyzer(options: analyzerOptions).analyze(scan)
            return WorldGenerator(library: library, options: options).generate(room: model, theme: theme, seed: seed)
        }.value
    }

    // MARK: Updates

    private func apply(_ update: AnchorUpdate<MeshAnchor>) {
        switch update.event {
        case .added, .updated:
            let m = ScanMesh(meshAnchor: update.anchor)
            meshes[m.id] = m
            refreshPreview(m, force: update.event == .added)
        case .removed:
            meshes.removeValue(forKey: update.anchor.id)
            previews.removeValue(forKey: update.anchor.id)?.removeFromParent()
            pendingPreview.remove(update.anchor.id)
        }
        meshCount = meshes.count
        coverageDirty = true
    }

    private func flushPendingPreviews() {
        guard showsPreview, !pendingPreview.isEmpty else { return }
        for id in pendingPreview { if let m = meshes[id] { refreshPreview(m, force: true) } }
        pendingPreview.removeAll()
    }

    private func refreshPreview(_ m: ScanMesh, force: Bool) {
        guard showsPreview else { return }
        let now = Date()
        if !force, let last = lastPreview[m.id], now.timeIntervalSince(last) < previewInterval {
            // Throttled: rebuild on the next tick so the final update of an anchor is never lost.
            pendingPreview.insert(m.id)
            return
        }
        pendingPreview.remove(m.id)
        lastPreview[m.id] = now
        guard let e = try? ScanPreview.entity(for: m, opacity: previewOpacity) else { return }
        previews[m.id]?.removeFromParent()
        previews[m.id] = e
        previewRoot.addChild(e)
    }
}
#endif
