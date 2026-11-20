import CNCCutters
import CNCDiagnostics
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCPipeline
import CNCSTL
import CNCSimulation
import CNCStorage
import CNCToolpath
import CNCValidation
import Foundation
import Synchronization
import Testing

private enum CancellationFixtureError: Error {
    case missing
}

private final class CancellationFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else {
            throw CancellationFixtureError.missing
        }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        files.withLock { storage in
            if let previous = storage[url] {
                storage[backupURL] = previous
            }
            storage[url] = data
        }
    }

    func exists(_ url: URL) -> Bool {
        files.withLock { $0[url] != nil }
    }

    func remove(_ url: URL) throws {
        files.withLock { $0[url] = nil }
    }
}

private struct CancellationPlanner: ToolpathPlanning {
    func plan(
        _ job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> Toolpath {
        _ = (profile, progress)
        return Toolpath(
            moves: [
                Move(
                    from: Vec3(x: 0, y: 0, z: 10),
                    to: Vec3(x: 10, y: 10, z: -1),
                    mode: .cut
                )
            ],
            feedRate: job.effective.feed,
            bounds: job.modelBounds
        )
    }
}

private struct CancellationRenderer: GCodeRendering {
    func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram {
        _ = (toolpath, profile, generatedAt)
        return RenderedProgram(
            text: "G21\nG1 X1 Y1 Z-1 F600\nM30\n",
            record: GenerationRecord(
                cutter: cutter,
                material: material,
                job: job,
                profile: profile,
                appliedScale: 1,
                modelFileName: "relief-demo-binary.stl",
                generatedAt: generatedAt
            )
        )
    }
}

private struct CancellationValidator: ProgramValidating {
    func validate(_ text: String, profile: MachineProfile) -> ValidationReport {
        _ = profile
        return ValidationReport(findings: [], program: ParsedProgram(text: text, moves: []))
    }
}

private struct CancellationSimulator: MaterialRemovalSimulating {
    func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult {
        _ = (program, job, profile, progress)
        return SimulationResult(
            heightmap: Heightmap(
                columns: 1,
                rows: 1,
                resolution: 1,
                origin: Vec3(x: 0, y: 0, z: 0),
                values: [0]
            ),
            resolution: 1,
            removedVolume: 0,
            violations: [],
            cancelled: false
        )
    }
}

private final class CancellationWriter: ProgramWriter, @unchecked Sendable {
    let calls = Mutex<Int>(0)

    func write(_ program: RenderedProgram, to url: URL) async throws {
        _ = (program, url)
        calls.withLock { $0 += 1 }
    }
}

private func cancellationProgress(isCancelled: @escaping @Sendable () -> Bool) -> ProgressSink {
    ProgressSink(report: { _ in }, isCancelled: isCancelled)
}

private func cancellationRequest(destination: URL) throws -> GenerationRequest {
    let profile = TTC450Pro.profile
    let material = Presets.all[1]
    let cutter = Cutter(
        id: CutterID("8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10"),
        name: "6mm flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
    let effective = try EffectiveCuttingValues(
        feed: 600,
        spindle: 8000,
        source: .userChoice,
        material: material,
        profile: profile
    ).confirming()
    let bounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 200, y: 150, z: 30)
    )
    let mesh = Mesh(triangles: [
        Triangle(
            a: Vec3(x: 0, y: 0, z: 30),
            b: Vec3(x: 200, y: 0, z: 30),
            c: Vec3(x: 0, y: 150, z: 30)
        )
    ])
    let job = JobSettings(
        mesh: mesh,
        modelBounds: bounds,
        stock: StockBlank(width: 200, depth: 150, height: 30),
        cutterID: cutter.id,
        materialID: material.id,
        effective: effective,
        stepover: 2.4,
        maxDepthPerPass: 2,
        finishingAllowance: 0.5,
        unitsConfirmed: true,
        orientationConfirmed: true,
        rapidRateConfirmed: true,
        confirmed: true
    )
    return GenerationRequest(
        model: MeshDocument(
            encoding: .binary,
            triangleCount: 1,
            bounds: bounds,
            isManifold: true,
            degenerateTriangleCount: 0,
            mesh: mesh
        ),
        job: job,
        cutter: cutter,
        material: material,
        profile: profile,
        destination: destination,
        generatedAt: Date(timeIntervalSince1970: 0)
    )
}

private func cancellationService(writer: CancellationWriter) -> ToolpathService {
    ToolpathService(
        planner: CancellationPlanner(),
        renderer: CancellationRenderer(),
        validator: CancellationValidator(),
        simulator: CancellationSimulator(),
        writer: writer
    )
}

@Test func cancelledGenerationIsAnOutcomeAndLeavesNoArtifacts() async throws {
    let fileSystem = CancellationFileSystem()
    let writer = CancellationWriter()
    let service = cancellationService(writer: writer)

    // Control run: cancellation must be a distinct outcome, not the service's only result.
    let control = try await service.run(
        try cancellationRequest(destination: URL(fileURLWithPath: "/sandbox/control.nc")),
        progress: cancellationProgress(isCancelled: { false })
    )
    guard case .ready = control else {
        Issue.record("an uncancelled control run must be ready, got \(control)")
        return
    }

    let destination = URL(fileURLWithPath: "/sandbox/cancelled.nc")
    let task = Task {
        try await service.run(
            try cancellationRequest(destination: destination),
            progress: cancellationProgress(isCancelled: { true })
        )
    }
    task.cancel()
    let outcome = try await task.value

    guard case .cancelled = outcome else {
        Issue.record("expected .cancelled, got \(outcome)")
        return
    }
    #expect(!fileSystem.exists(destination), "cancellation must never leave an .nc file")
    #expect(
        !fileSystem.exists(URL(fileURLWithPath: destination.path + ".tmp")),
        "cancellation must never leave a temporary file"
    )
    let names = fileSystem.files.withLock { $0.keys.map(\.lastPathComponent) }
    #expect(names.allSatisfy { !$0.contains("tmp") })
    #expect(writer.calls.withLock { $0 } == 0, "cancellation must not reach the writer")
}
