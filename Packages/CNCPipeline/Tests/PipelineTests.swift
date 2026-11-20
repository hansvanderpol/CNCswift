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

private enum FakeError: Error, Equatable {
    case missing
}

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw FakeError.missing }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        let previous = files.withLock { $0[url] }
        files.withLock { storage in
            if let previous {
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

private struct FakePlanner: ToolpathPlanning {
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

private struct FakeRenderer: GCodeRendering {
    func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram {
        _ = (toolpath, profile, generatedAt)
        let record = GenerationRecord(
            cutter: cutter,
            material: material,
            job: job,
            profile: profile,
            appliedScale: 1,
            modelFileName: "relief-demo-binary.stl",
            generatedAt: generatedAt
        )
        return RenderedProgram(
            text: "G21\nG90\nM3 S8000\nG1 X1 Y1 Z-1 F600\nM5\nG00 X0 Y0\nM30\n", record: record)
    }
}

private struct FakeValidator: ProgramValidating {
    var findings: [Finding] = []

    func validate(_ text: String, profile: MachineProfile) -> ValidationReport {
        _ = profile
        return ValidationReport(findings: findings, program: ParsedProgram(text: text, moves: []))
    }
}

private struct FakeSimulator: MaterialRemovalSimulating {
    var cancelled = false
    var violations: [SimulationViolation] = []

    func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult {
        _ = (program, job, profile, progress)
        let map = Heightmap(
            columns: 1,
            rows: 1,
            resolution: 1,
            origin: Vec3(x: 0, y: 0, z: 0),
            values: [0]
        )
        return SimulationResult(
            heightmap: map,
            resolution: 1,
            removedVolume: 0,
            violations: violations,
            cancelled: cancelled
        )
    }
}

private final class RecordingWriter: ProgramWriter, @unchecked Sendable {
    let fileSystem: FakeFileSystem
    let calls = Mutex<Int>(0)

    init(fileSystem: FakeFileSystem) {
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
    let model = MeshDocument(
        encoding: .binary,
        triangleCount: 1,
        bounds: bounds,
        isManifold: true,
        degenerateTriangleCount: 0,
        mesh: mesh
    )
    return GenerationRequest(
        model: model,
        job: job,
        cutter: cutter,
        material: material,
        profile: profile,
        destination: destination,
        generatedAt: Date(timeIntervalSince1970: 0)
    )
}

private func service(
    fileSystem: FakeFileSystem,
    validator: any ProgramValidating = FakeValidator(),
    simulator: any MaterialRemovalSimulating = FakeSimulator()
) -> ToolpathService {
    ToolpathService(
        planner: FakePlanner(),
        renderer: FakeRenderer(),
        validator: validator,
        simulator: simulator,
        writer: RecordingWriter(fileSystem: fileSystem)
    )
}

private func readyProgram(
    cutter: Cutter,
    material: Material,
    job: JobSettings,
    profile: MachineProfile
) -> RenderedProgram {
    RenderedProgram(
        text: "G21\nG90\nM3 S8000\nM5\nG00 X0 Y0\nM30\n",
        record: GenerationRecord(
            cutter: cutter,
            material: material,
            job: job,
            profile: profile,
            appliedScale: 1,
            modelFileName: "relief-demo-binary.stl",
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    )
}

@Test func runPreparesAValidatedProgramWithoutWritingAFile() async throws {
    let fs = FakeFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/run-only.nc")
    let outcome = try await service(fileSystem: fs).run(
        try request(destination: destination),
        progress: progress()
    )

    guard case .ready(let program, let report, let simulation) = outcome else {
        Issue.record("expected ready, got \(outcome)")
        return
    }
    #expect(!program.text.isEmpty)
    #expect(!report.hasErrors)
    #expect(!simulation.cancelled)
    #expect(!fs.exists(destination), "run must prepare, never write (clarification Q6)")
}

@Test func commitWithFullConfirmationWritesExactlyOneNcFile() async throws {
    let fs = FakeFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/committed.nc")
    let sut = service(fileSystem: fs)
    let outcome = try await sut.run(try request(destination: destination), progress: progress())

    guard case .ready(let program, _, _) = outcome else {
        Issue.record("expected ready, got \(outcome)")
        return
    }
    try await sut.commit(
        program,
        confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
        to: destination
    )

    #expect(fs.exists(destination))
    #expect(try fs.read(destination) == Data(program.text.utf8))
}

@Test func aBlockedProgramCannotBeCommitted() async throws {
    let fs = FakeFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/blocked.nc")
    let finding = Finding(
        severity: .error,
        lineNumber: 3,
        ruleIdentifier: "feed-ceiling",
        message: "Feed exceeds the profile ceiling"
    )
    let validator = FakeValidator(findings: [finding])
    let outcome = try await service(fileSystem: fs, validator: validator).run(
        try request(destination: destination),
        progress: progress()
    )

    guard case .blocked(let findings) = outcome else {
        Issue.record("expected blocked, got \(outcome)")
        return
    }
    #expect(findings == [finding])

    let prepared = try request(destination: destination)
    let program = readyProgram(
        cutter: prepared.cutter,
        material: prepared.material,
        job: prepared.job,
        profile: prepared.profile
    )
    do {
        try await service(fileSystem: fs, validator: validator).commit(
            program,
            confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a blocked program must never be written")
    } catch PipelineError.blockedProgram {
        // Expected.
    } catch {
        Issue.record("expected blockedProgram, got \(error)")
    }
    #expect(!fs.exists(destination))
}

@Test func aCancelledSimulationCannotBeCommitted() async throws {
    let fs = FakeFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/cancelled.nc")
    let sut = service(fileSystem: fs, simulator: FakeSimulator(cancelled: true))
    let outcome = try await sut.run(
        try request(destination: destination),
        progress: progress()
    )

    guard case .cancelled = outcome else {
        Issue.record("expected cancelled, got \(outcome)")
        return
    }

    let prepared = try request(destination: destination)
    let program = readyProgram(
        cutter: prepared.cutter,
        material: prepared.material,
        job: prepared.job,
        profile: prepared.profile
    )
    do {
        try await sut.commit(
            program,
            confirmation: WriteConfirmation(previewShown: true, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a cancelled simulation must never be committed")
    } catch PipelineError.cancelledProgram {
        // Expected.
    } catch {
        Issue.record("expected cancelledProgram, got \(error)")
    }
    #expect(!fs.exists(destination))
}

@Test func anIncompleteConfirmationDoesNotWrite() async throws {
    let fs = FakeFileSystem()
    let destination = URL(fileURLWithPath: "/sandbox/unconfirmed.nc")
    let prepared = try request(destination: destination)
    let program = readyProgram(
        cutter: prepared.cutter,
        material: prepared.material,
        job: prepared.job,
        profile: prepared.profile
    )

    do {
        try await service(fileSystem: fs).commit(
            program,
            confirmation: WriteConfirmation(previewShown: false, findingsAcknowledged: true),
            to: destination
        )
        Issue.record("a preview that was not shown cannot authorize a write")
    } catch PipelineError.incompleteConfirmation {
        // Expected.
    } catch {
        Issue.record("expected incompleteConfirmation, got \(error)")
    }
    #expect(!fs.exists(destination))
}
