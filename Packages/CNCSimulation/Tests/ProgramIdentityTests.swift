import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCSimulation
import CNCToolpath
import CNCValidation
import Foundation
import Synchronization
import Testing

/// Simulation consumes the exact `ParsedProgram` the validator accepted (FR-065).
///
/// The boundary is the validator's value, not the emitter's `Toolpath` or the rendered text. These
/// tests prove both the compile-time boundary (a simulator receives `ParsedProgram`) and the
/// runtime behaviour (the parsed moves, not a canned string, drive material removal).
private final class RecordingSimulator: MaterialRemovalSimulating, @unchecked Sendable {
    let recorded = Mutex<ParsedProgram?>(nil)

    func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult {
        _ = (job, profile, progress)
        recorded.withLock { $0 = program }
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

@Test func simulatorReceivesTheValidatorsProgramUnchanged() async throws {
    let validated = SimulationFixture.program([
        SimulationFixture.move(
            from: Vec3(x: 10, y: 10, z: 10),
            to: Vec3(x: 20, y: 10, z: -1)
        )
    ])
    let recorder = RecordingSimulator()

    _ = try await recorder.simulate(
        validated,
        job: try SimulationFixture.job(),
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )

    #expect(recorder.recorded.withLock { $0 } == validated)
}

@Test func differentParsedMovesProduceDifferentMaterialRemoval() async throws {
    let job = try SimulationFixture.job()
    let text = "G1 X20.000 Y10.000 Z-1.000 F600.000"
    let shallow = ParsedProgram(
        text: text,
        moves: [
            SimulationFixture.move(
                from: Vec3(x: 10, y: 10, z: 10),
                to: Vec3(x: 20, y: 10, z: -1)
            )
        ])
    let deep = ParsedProgram(
        text: text,
        moves: [
            SimulationFixture.move(
                from: Vec3(x: 10, y: 10, z: 10),
                to: Vec3(x: 20, y: 10, z: -8)
            )
        ])
    let simulator = ZMapSimulator(resolution: 2)

    let shallowMap = try await simulator.simulate(
        shallow,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    ).heightmap
    let deepMap = try await simulator.simulate(
        deep,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    ).heightmap

    #expect(shallowMap != deepMap, "the parsed move list must drive the heightmap")
}

@Test func identicalMovesWithDifferentTextProduceTheSameHeightmap() async throws {
    let job = try SimulationFixture.job()
    let moves = [
        SimulationFixture.move(
            from: Vec3(x: 10, y: 10, z: 10),
            to: Vec3(x: 20, y: 10, z: -1)
        )
    ]
    let original = SimulationFixture.program(moves)
    let annotated = ParsedProgram(text: "; reviewed\n" + original.text, moves: moves)
    let simulator = ZMapSimulator(resolution: 2)

    let originalMap = try await simulator.simulate(
        original,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    ).heightmap
    let annotatedMap = try await simulator.simulate(
        annotated,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    ).heightmap

    #expect(originalMap == annotatedMap, "comments in the text must not change material removal")
}
