import CNCGeometry
import CNCSimulation
import RealityKit
import SwiftUI
import simd

/// The third main-screen panel: a 3D material-removal preview of the validated program (FR-055,
/// FR-061, FR-070).
///
/// `CNCSimulation` produces a framework-neutral `PreviewMesh`; this panel converts it to a
/// RealityKit `MeshResource` and keeps the swept surface and rapid traverses visually distinct.
/// Rapids are drawn as thin blue guides and never modify the carved surface (FR-063). The named
/// findings are listed above the preview so a write is never authorized out of sight of a
/// violation (FR-064).
///
/// Navigation has two equivalent paths: RealityView's built-in orbit camera handles pointer
/// gestures, while `SimulationCamera` commands rotate and scale the centered model root so every
/// view change is also reachable by keyboard alone (FR-070).
@MainActor
public struct SimulationPanel: View {
    private static let rootName = "simulation-root"
    private static let surfaceName = "simulation-surface"
    private static let metresPerMillimetre: Float = 0.01

    private let model: MainScreenModel

    public init(model: MainScreenModel) {
        self.model = model
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                findingsList
                preview
                controls
                navigation
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } label: {
            Label("G-code simulation", systemImage: "cube")
        }
        .accessibilityIdentifier("simulation-panel")
    }

    @ViewBuilder
    private var findingsList: some View {
        let findings = model.simulation.findings
        VStack(alignment: .leading, spacing: 4) {
            if findings.isEmpty {
                Label("No findings to review", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Review before writing").font(.headline)
                ForEach(findings, id: \.self) { finding in
                    Label(finding, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("simulation-violation")
                }
                if !model.simulation.findingsAcknowledged {
                    Button("Acknowledge findings") {
                        model.simulation.acknowledgeFindings()
                    }
                    .font(.caption)
                    .accessibilityIdentifier("acknowledge-findings")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var preview: some View {
        if let simulation = model.simulation.result, !simulation.cancelled {
            let mesh = PreviewMesh(heightmap: simulation.heightmap)
            let rapids = simulation.rapids
            let centre = Self.stockCentre(of: simulation.heightmap)
            let yaw = model.camera.yaw
            let pitch = model.camera.pitch
            let distance = model.camera.distance

            RealityView { content in
                content.camera = .virtual

                let root = Entity()
                root.name = Self.rootName
                if let surface = Self.surfaceEntity(from: mesh, centredAt: centre) {
                    root.addChild(surface)
                }
                for rapid in Self.rapidEntities(rapids, centredAt: centre) {
                    root.addChild(rapid)
                }
                content.add(root)
                content.cameraTarget = root
            } update: { content in
                guard let root = content.entities.first(where: { $0.name == Self.rootName }) else {
                    return
                }
                root.orientation = Self.orientation(yaw: yaw, pitch: pitch)
                root.scale = SIMD3<Float>(
                    repeating: Self.metresPerMillimetre
                        * (SimulationCamera.referenceDistance / distance)
                )
            }
            .realityViewCameraControls(.orbit)
            .id(
                "\(simulation.heightmap.columns)-\(simulation.heightmap.rows)-\(simulation.removedVolume)"
            )
            .frame(minHeight: 240)
            .focusable()
            .onKeyPress(.leftArrow) {
                model.camera.navigate(.orbitLeft)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                model.camera.navigate(.orbitRight)
                return .handled
            }
            .onKeyPress(.upArrow) {
                model.camera.navigate(.orbitUp)
                return .handled
            }
            .onKeyPress(.downArrow) {
                model.camera.navigate(.orbitDown)
                return .handled
            }
            .onKeyPress("+") {
                model.camera.navigate(.zoomIn)
                return .handled
            }
            .onKeyPress("-") {
                model.camera.navigate(.zoomOut)
                return .handled
            }
            .accessibilityLabel("3D material removal preview")
            .accessibilityHint("Arrow keys change the view; plus and minus zoom.")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text(model.simulation.isCancelled ? "Simulation cancelled" : "No preview yet")
                    .font(.headline)
                Text("Generate G-code to preview the carved stock before writing a file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("simulation-placeholder")
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if model.generationStatus == .running {
                Button(role: .destructive) {
                    model.requestCancellation()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("cancel-simulation")
            }
            Spacer()
            if let simulation = model.simulation.result {
                Text("Removed \(Int(simulation.removedVolume)) mm³")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await model.commitProgram() }
            } label: {
                Label("Write G-code file", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.simulation.canWrite)
            .accessibilityIdentifier("write-gcode")
        }
    }

    private var navigation: some View {
        HStack(spacing: 6) {
            Text("View").font(.caption).foregroundStyle(.secondary)
            Button {
                model.camera.navigate(.orbitLeft)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Orbit left")
            Button {
                model.camera.navigate(.orbitRight)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Orbit right")
            Button {
                model.camera.navigate(.orbitUp)
            } label: {
                Image(systemName: "chevron.up")
            }
            .accessibilityLabel("Orbit up")
            Button {
                model.camera.navigate(.orbitDown)
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Orbit down")
            Button {
                model.camera.navigate(.zoomIn)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Zoom in")
            Button {
                model.camera.navigate(.zoomOut)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Zoom out")
            Button("Reset") { model.camera.navigate(.reset) }
                .font(.caption)
                .accessibilityLabel("Reset preview camera")
        }
        .buttonStyle(.borderless)
        .disabled(model.simulation.result == nil)
        .accessibilityIdentifier("simulation-navigation")
    }

    /// Stock-space Z is up; RealityKit's virtual camera uses Y up. The remaining rotations map the
    /// discrete `SimulationCamera` orbit state onto a viewing angle for keyboard navigation.
    private static func orientation(yaw: Double, pitch: Double) -> simd_quatf {
        let zUpToYUp = simd_quatf(angle: -Float.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        let tilt = simd_quatf(angle: Float(Double.pi / 2 - pitch), axis: SIMD3<Float>(1, 0, 0))
        let turn = simd_quatf(angle: Float(-yaw), axis: SIMD3<Float>(0, 1, 0))
        return turn * tilt * zUpToYUp
    }

    private static func stockCentre(of heightmap: Heightmap) -> SIMD3<Float> {
        let width = Float(heightmap.columns) * Float(heightmap.resolution)
        let depth = Float(heightmap.rows) * Float(heightmap.resolution)
        let deepest = heightmap.values.min() ?? 0
        return SIMD3<Float>(width / 2, depth / 2, Float(deepest) / 2)
    }

    private static func surfaceEntity(from mesh: PreviewMesh, centredAt centre: SIMD3<Float>)
        -> ModelEntity?
    {
        guard !mesh.vertices.isEmpty, !mesh.indices.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "stock-surface")
        descriptor.positions = MeshBuffers.Positions(
            mesh.vertices.map { vector(of: $0) - centre }
        )
        descriptor.normals = MeshBuffers.Normals(
            mesh.normals.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
        )
        descriptor.primitives = .triangles(mesh.indices)
        guard let resource = try? MeshResource.generate(from: [descriptor]) else { return nil }
        let entity = ModelEntity(
            mesh: resource,
            materials: [SimpleMaterial(color: .brown, isMetallic: false)]
        )
        entity.name = surfaceName
        return entity
    }

    /// Rapids are visual guides only: they are never swept into the surface heightmap (FR-063).
    private static func rapidEntities(
        _ rapids: [SimulationSegment],
        centredAt centre: SIMD3<Float>
    ) -> [Entity] {
        rapids.enumerated().compactMap { index, segment in
            let start = vector(of: segment.start)
            let end = vector(of: segment.end)
            let vector = end - start
            let length = simd_length(vector)
            guard length > 0.01 else { return nil }

            let entity = ModelEntity(
                mesh: .generateBox(width: 0.8, height: length, depth: 0.8),
                materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
            )
            entity.name = "simulation-rapid-\(index)"
            entity.position = (start + end) / 2 - centre
            entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: vector / length)
            return entity
        }
    }

    private static func vector(of point: Vec3) -> SIMD3<Float> {
        SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))
    }
}
