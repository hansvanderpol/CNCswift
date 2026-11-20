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

/// The final write gate (FR-026, FR-064, FR-066, FR-069, SC-011, clarification Q6).
///
/// `run` never writes. A blocked or cancelled simulation leaves no `.nc` and no temporary file.
/// Only `commit` with a full `WriteConfirmation` writes exactly one atomically replaced file, and
/// it refuses a program with unacknowledged findings or simulation violations (T103).
private enum CommitFixtureError: Error, Equatable {
    case missing
}

private final class CommitFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw CommitFixtureError.missing }
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

private struct CommitPlanner: ToolpathPlanning {
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

private struct CommitRenderer: GCodeRendering {
    func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram {
        _ = toolpath
        return RenderedProgram(
            text: "G21\nG1 X10.000 Y10.000 Z-1.000 F600.000\nM30\n",
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

private struct CommitValidator: ProgramValidating {
    var findings: [Finding] = []

    func validate(_ text: String, profile: MachineProfile) -> ValidationReport {
        _ = profile
        return ValidationReport(findings: findings, program: ParsedProgram(text: text, moves: []))
    }
}

private struct CommitSimulator: MaterialRemovalSimulating {
    var cancelled = false
    var violations: [SimulationViolation] = []

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
            violations: violations,
            cancelled: cancelled
        )
    }
}

private final class CommitWriter: ProgramWriter, @unchecked Sendable {
    let fileSystem: CommitFileSystem
    let calls = Mutex<Int>(0)

    init(fileSystem: CommitFileSystem) {
        self.fileSystem = fileSystem
    }

    func write(_ program: RenderedProgram, to url: URL) async throws {
        calls.withLock { $0 += 1 }
        try fileSystem.write(Data(program.text.utf8), to: url)
    }
}

private func progress() -> ProgressSink {
    ProgressSink(report: { _ in }, isCancelled: { false })
}

private func request(destination: URL) throws -> GenerationRequest {
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
        cutter: cutter,
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

private func service(
    fileSystem: CommitFileSystem,
    validator: any ProgramValidating = CommitValidator(),
    simulator: any MaterialRemovalSimulating = CommitSimulator()
) -> ToolpathService {
    ToolpathService(
        planner: CommitPlanner(),
        renderer: CommitRenderer(),
        validator: validator,
        simulator: simulator,
        writer: CommitWriter(fileSystem: fileSystem)
    )
}

private func renderedProgram(from request: GenerationRequest) -> RenderedProgram {
    RenderedProgram(
        text: "G21\nG1 X10.000 Y10.000 Z-1.000 F600.000\nM30\n",
        record: GenerationRecord(
            cutter: request.cutter,
            material: request.material,
            job: request.job,
            profile: request.profile,
            appliedScale: 1,
            modelFileName: "relief-demo-binary.stl",
            generatedAt: request.generatedAt
        )
    )
}

private func assertNoArtifacts(_ fileSystem: CommitFileSystem, destination: URL) {
    #expect(!fileSystem.exists(destination), "no .nc file may exist before a full commit")
    let names = fileSystem.files.withLock { $0.keys.map(\.lastPathComponent) }
    #expect(names.allSatisfy { !$0.contains("tmp") }, "no temporary file may remain")
}

@Test func runLeavesNoFileAndOnlyCommitWritesOneNcFile() async throws {
    let fileSystem = CommitFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/commit.nc")
    let sut = service(fileSystem: fileSystem)
    let source = try request(destination: destination)

    let outcome = try await sut.run(source, progress: progress())
    guard case .ready(let program, _, _) = outcome else {
        Issue.record("expected .ready, got \(outcome)")
        return
    }
    assertNoArtifacts(fileSystem, destination: destination)

    let full = WriteConfirmation(previewShown: true, findingsAcknowledged: true)
    try await sut.commit(program, confirmation: full, to: destination)

    let files = fileSystem.files.withLock { $0 }
    #expect(files.count == 1, "commit must write exactly one file")
    #expect(destination.pathExtension == "nc")
    #expect(try fileSystem.read(destination) == Data(program.text.utf8))
}

@Test func incompleteConfirmationNeverWrites() async throws {
    let fileSystem = CommitFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/unconfirmed.nc")
    let source = try request(destination: destination)
    let program = renderedProgram(from: source)

    for confirmation in [
        WriteConfirmation(previewShown: false, findingsAcknowledged: true),
        WriteConfirmation(previewShown: true, findingsAcknowledged: false),
    ] {
        do {
            try await service(fileSystem: fileSystem).commit(
                program,
                confirmation: confirmation,
                to: destination
            )
            Issue.record("an incomplete confirmation must not write: \(confirmation)")
        } catch PipelineError.incompleteConfirmation {
            // Expected for both partial confirmations.
        } catch {
            Issue.record("expected incompleteConfirmation, got \(error)")
        }
    }
    assertNoArtifacts(fileSystem, destination: destination)
}

@Test func blockedSimulationCannotBeCommitted() async throws {
    let fileSystem = CommitFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/blocked.nc")
    let finding = Finding(
        severity: .error,
        lineNumber: 3,
        ruleIdentifier: "feed-ceiling",
        message: "Feed exceeds the profile ceiling"
    )
    let sut = service(
        fileSystem: fileSystem,
        validator: CommitValidator(findings: [finding])
    )
    let source = try request(destination: destination)

    let outcome = try await sut.run(source, progress: progress())
    guard case .blocked(let findings) = outcome else {
        Issue.record("expected .blocked, got \(outcome)")
        return
    }
    #expect(findings == [finding])
    assertNoArtifacts(fileSystem, destination: destination)

    do {
        try await sut.commit(
            renderedProgram(from: source),
            confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a blocked program must never be written")
    } catch PipelineError.blockedProgram {
        // Expected.
    } catch {
        Issue.record("expected blockedProgram, got \(error)")
    }
    assertNoArtifacts(fileSystem, destination: destination)
}

@Test func cancelledSimulationCannotBeCommitted() async throws {
    let fileSystem = CommitFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/cancelled.nc")
    let sut = service(
        fileSystem: fileSystem,
        simulator: CommitSimulator(cancelled: true)
    )
    let source = try request(destination: destination)

    let outcome = try await sut.run(source, progress: progress())
    guard case .cancelled = outcome else {
        Issue.record("expected .cancelled, got \(outcome)")
        return
    }
    assertNoArtifacts(fileSystem, destination: destination)

    do {
        try await sut.commit(
            renderedProgram(from: source),
            confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a cancelled simulation must never be committed")
    } catch PipelineError.cancelledProgram {
        // Expected.
    } catch {
        Issue.record("expected cancelledProgram, got \(error)")
    }
    assertNoArtifacts(fileSystem, destination: destination)
}

@Test func simulationViolationsPreventCommit() async throws {
    let fileSystem = CommitFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/violations.nc")
    let violation = SimulationViolation(
        kind: "envelope",
        message: "Move leaves the 460 x 460 x 80 mm envelope",
        lineNumber: 7
    )
    let sut = service(
        fileSystem: fileSystem,
        simulator: CommitSimulator(violations: [violation])
    )
    let source = try request(destination: destination)

    _ = try await sut.run(source, progress: progress())
    assertNoArtifacts(fileSystem, destination: destination)

    do {
        try await sut.commit(
            renderedProgram(from: source),
            confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a program with simulation violations must never be written")
    } catch {
        // The pipeline must refuse; the exact typed case is T103's choice.
    }
    assertNoArtifacts(fileSystem, destination: destination)
}
