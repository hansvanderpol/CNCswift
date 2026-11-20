import CNCGeometry
import CNCSimulation
import CNCToolpath
import CNCValidation
import Testing

/// Named envelope and limit violations surfaced before writing (FR-064, FR-065).
///
/// These tests define the contract T098 must satisfy: `SimulationViolations().collect` turns a
/// validated program into named `SimulationViolation` values carrying a stable kind, an actionable
/// message, and the offending line. `SimulationResult` surfaces them before any write. The
/// commit-side refusal for those violations is covered by `CommitTests` in `CNCPipeline`, because a
/// stage package must not depend on the pipeline (`BoundaryTests.noStageDependsOnPipeline`).
private func named(_ violations: [SimulationViolation], containing token: String)
    -> [SimulationViolation]
{
    violations.filter {
        $0.kind.localizedCaseInsensitiveContains(token)
            || $0.message.localizedCaseInsensitiveContains(token)
    }
}

@Test func outOfEnvelopeMoveIsNamedWithItsLine() async throws {
    let job = try SimulationFixture.job()
    let program = SimulationFixture.program([
        SimulationFixture.move(
            line: 12,
            from: Vec3(x: 10, y: 10, z: 10),
            to: Vec3(x: 500, y: 10, z: -1)
        )
    ])

    let violations = SimulationViolations().collect(
        program,
        job: job,
        profile: SimulationFixture.profile
    )
    let envelope = named(violations, containing: "envelope")
    #expect(!envelope.isEmpty, "an out-of-envelope move must produce a named violation")
    #expect(envelope.contains { $0.message.contains("460") })
    #expect(envelope.contains { $0.lineNumber == 12 })

    let result = try await ZMapSimulator(resolution: 2).simulate(
        program,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )
    #expect(
        result.violations.map(\.kind) == violations.map(\.kind),
        "the simulator must surface every collected violation before writing"
    )
}

@Test func feedAboveTheProfileCeilingIsNamed() throws {
    let job = try SimulationFixture.job()
    let program = SimulationFixture.program([
        SimulationFixture.move(
            line: 7,
            from: Vec3(x: 10, y: 10, z: 0),
            to: Vec3(x: 20, y: 10, z: -1),
            feedRate: 900
        )
    ])

    let violations = SimulationViolations().collect(
        program,
        job: job,
        profile: SimulationFixture.profile
    )
    let feed = named(violations, containing: "feed")
    #expect(!feed.isEmpty, "a feed above the ceiling must produce a named violation")
    #expect(feed.contains { $0.message.contains("800") })
}

@Test func aValidProgramHasNoViolations() async throws {
    let job = try SimulationFixture.job()
    let program = SimulationFixture.program([
        SimulationFixture.move(
            from: Vec3(x: 10, y: 10, z: 10),
            to: Vec3(x: 20, y: 10, z: -1)
        )
    ])

    let violations = SimulationViolations().collect(
        program,
        job: job,
        profile: SimulationFixture.profile
    )
    #expect(violations.isEmpty, "a program inside the envelope and limits has no violations")

    let result = try await ZMapSimulator(resolution: 2).simulate(
        program,
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )
    #expect(result.violations.isEmpty)
    #expect(!result.cancelled)
}
