import CNCGeometry
import CNCSimulation
import CNCToolpath
import CNCValidation
import Testing

/// Cutter-sweep z-map behaviour (FR-061, FR-062, FR-063).
///
/// These tests define the contract T096 must satisfy: `ZMapSimulator(resolution:)` sweeps the
/// validated program's cutting footprint into a documented stock-space heightmap. Stock-space Z0
/// is the untouched top, so cuts lower values below zero and rapids never change them.
private let tolerance = 0.05

@Test func cuttingMovesLowerTheHeightmapAndRapidsDoNot() async throws {
    let job = try SimulationFixture.job()
    let resolution = 2.0
    let simulator = ZMapSimulator(resolution: resolution)

    let cut = SimulationFixture.move(
        from: Vec3(x: 50, y: 50, z: 10),
        to: Vec3(x: 50, y: 50, z: -4)
    )
    let result = try await simulator.simulate(
        SimulationFixture.program([cut]),
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )

    #expect(result.heightmap.resolution == resolution)
    #expect(result.heightmap.columns == Int(job.stock.width / resolution))
    #expect(result.heightmap.rows == Int(job.stock.depth / resolution))
    #expect(result.heightmap.origin == Vec3(x: 0, y: 0, z: 0))

    let cutColumn = Int(50 / resolution)
    let cutRow = Int(50 / resolution)
    let cutHeight = try #require(
        result.heightmap.height(column: cutColumn, row: cutRow),
        "the cut must land inside the heightmap"
    )
    #expect(
        cutHeight <= -4 + tolerance,
        "a cut to Z=-4 must lower the covered cell to at most -4, got \(cutHeight)"
    )

    let farColumn = Int(150 / resolution)
    let farRow = Int(120 / resolution)
    let farHeight = try #require(result.heightmap.height(column: farColumn, row: farRow))
    #expect(farHeight == 0, "material outside the cutter footprint must stay untouched")

    #expect(result.removedVolume > 0, "a cut must report a positive removal volume")
    #expect(!result.cancelled)

    let rapid = SimulationFixture.move(
        mode: .rapid,
        from: Vec3(x: 0, y: 0, z: 10),
        to: Vec3(x: 100, y: 100, z: 10)
    )
    let rapidResult = try await simulator.simulate(
        SimulationFixture.program([rapid]),
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )
    #expect(
        rapidResult.heightmap.values.allSatisfy { $0 == 0 },
        "rapid moves must not remove material (FR-063)"
    )
    #expect(rapidResult.removedVolume == 0)
}

@Test func roughingThenFinishingProduceTheExpectedDepths() async throws {
    let job = try SimulationFixture.job()
    let simulator = ZMapSimulator(resolution: 2.0)

    let roughing = SimulationFixture.move(
        line: 10,
        from: Vec3(x: 50, y: 50, z: 10),
        to: Vec3(x: 50, y: 50, z: -29.5)
    )
    let finishing = SimulationFixture.move(
        line: 20,
        from: Vec3(x: 50, y: 50, z: 10),
        to: Vec3(x: 50, y: 50, z: -30)
    )
    let column = 25
    let row = 25

    let roughOnly = try await simulator.simulate(
        SimulationFixture.program([roughing]),
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )
    let withFinish = try await simulator.simulate(
        SimulationFixture.program([roughing, finishing]),
        job: job,
        profile: SimulationFixture.profile,
        progress: SimulationFixture.progress()
    )

    let roughHeight = try #require(roughOnly.heightmap.height(column: column, row: row))
    let finishHeight = try #require(withFinish.heightmap.height(column: column, row: row))

    #expect(
        abs(roughHeight + 29.5) < 0.6,
        "roughing must stop at the finishing allowance, got \(roughHeight)"
    )
    #expect(
        abs(finishHeight + 30) < 0.6,
        "finishing must reach the stock bottom, got \(finishHeight)"
    )
    #expect(
        finishHeight < roughHeight - 0.4,
        "finishing must remove the allowance left by roughing"
    )
    #expect(withFinish.removedVolume >= roughOnly.removedVolume)
}
