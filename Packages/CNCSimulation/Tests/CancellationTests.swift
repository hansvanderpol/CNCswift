import CNCDiagnostics
import CNCGeometry
import CNCSimulation
import CNCToolpath
import CNCValidation
import Synchronization
import Testing

/// Simulation cancellation is an outcome, not a failure (FR-066, FR-069).
///
/// These tests define the contract T096 must satisfy: `ZMapSimulator` cooperates with both the
/// injected `ProgressSink.isCancelled` and structured `Task.cancel()`, returning a result whose
/// `cancelled` flag is set rather than throwing a conformance error.
private func program() throws -> ParsedProgram {
    SimulationFixture.program([
        SimulationFixture.move(
            from: Vec3(x: 10, y: 10, z: 10),
            to: Vec3(x: 20, y: 10, z: -1)
        ),
        SimulationFixture.move(
            line: 2,
            from: Vec3(x: 20, y: 10, z: 10),
            to: Vec3(x: 30, y: 10, z: -1)
        ),
    ])
}

@Test func cancelledProgressProducesACancelledResultRatherThanAnError() async throws {
    let result = try await ZMapSimulator(resolution: 2).simulate(
        try program(),
        job: try SimulationFixture.job(),
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress(cancelled: true)
    )

    #expect(result.cancelled, "an injected cancellation must be reported as cancelled")
    #expect(result.violations.isEmpty)
}

@Test func taskCancellationIsReportedAsCancelled() async throws {
    let job = try SimulationFixture.job()
    let validated = try program()
    let task = Task {
        try await ZMapSimulator(resolution: 2).simulate(
            validated,
            job: job,
            profile: SimulationFixture.profile,
            progress: SimulationFixture.progress()
        )
    }
    task.cancel()
    let result = try await task.value

    #expect(result.cancelled, "Task.cancel() must produce a cancelled result, not a thrown error")
}

@Test func anUncancelledSimulationCompletesAndReportsProgress() async throws {
    let reports = Mutex<[StageProgress]>([])
    let result = try await ZMapSimulator(resolution: 2).simulate(
        try program(),
        job: try SimulationFixture.job(),
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress { update in
            reports.withLock { $0.append(update) }
        }
    )

    let recorded = reports.withLock { $0 }
    #expect(!result.cancelled)
    #expect(!recorded.isEmpty, "a long stage must report progress")
    #expect(recorded.contains { $0.total > 0 })
}
