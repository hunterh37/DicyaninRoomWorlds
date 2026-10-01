// Example only (not compiled by the package). visionOS app: scan, pick a theme, enter the world.
import SwiftUI
import RealityKit
import DicyaninRoomWorlds

@MainActor @Observable
final class RoomWorldModel {
    let scanner = RoomScanner()
    let root = Entity()
    var world: Entity?
    var theme: WorldTheme = .enchantedForest
    var status = "Look around the room"

    func startScan() async {
        await scanner.start()
        if scanner.state == .unsupported { scanner.loadSynthetic() }   // simulator
        root.addChild(scanner.previewRoot)
    }

    func buildWorld() async {
        let spec = await scanner.makeWorld(theme: theme, seed: 42)
        scanner.stop()
        scanner.showsPreview = false
        world?.removeFromParent()
        guard let e = try? WorldEntityBuilder.build(spec) else { status = "Build failed"; return }
        world = e
        root.addChild(e)
        status = "\(spec.instances.count) pieces, \(spec.room.objects.count) objects"
    }
}

/// Immersive space content.
struct RoomWorldImmersiveView: View {
    let model: RoomWorldModel

    var body: some View {
        RealityView { content in content.add(model.root) }
            .task { await model.startScan() }
    }
}

/// Window controls (immersive spaces do not host ornaments).
struct RoomWorldControls: View {
    @Bindable var model: RoomWorldModel

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: model.scanner.coverage.progress)
            Picker("Theme", selection: $model.theme) {
                ForEach(WorldTheme.builtIn) { Text($0.name).tag($0) }
            }
            Button("Build world") { Task { await model.buildWorld() } }
                .disabled(!model.scanner.coverage.isSufficient)
            Text(model.status)
        }
        .padding()
    }
}

@main
struct RoomWorldApp: App {
    @State private var model = RoomWorldModel()

    var body: some SwiftUI.Scene {
        WindowGroup { RoomWorldControls(model: model) }
        ImmersiveSpace(id: "world") { RoomWorldImmersiveView(model: model) }
            .immersionStyle(selection: .constant(.mixed), in: .mixed, .full)
    }
}
