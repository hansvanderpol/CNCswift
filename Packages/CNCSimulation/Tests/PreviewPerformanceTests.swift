import CNCSimulation
import CNCValidation
import Foundation
import Testing

/// 3D preview latency across the five reference models (SC-012, clarification Q5).
///
/// 95% of a five-fixture set still means five passes, so every committed reference model must
/// render within five seconds and its timing is recorded in the assertion message. Each golden
/// `.nc` file is the reviewed output for the matching STL fixture; the simulation stage parses that
/// program exactly as the pipeline does, so no generation pipeline is needed here.
private let referenceModels = [
    "relief-demo-ascii.stl",
    "relief-demo-binary.stl",
    "relief-demo-200k.stl",
    "deep-cavity.stl",
    "fine-detail.stl",
]

@Test func allFiveReferenceModelsRenderWithinFiveSeconds() async throws {
    let job = try SimulationFixture.job()
    let simulator = ZMapSimulator(resolution: 2)
    let clock = ContinuousClock()
    var timings: [String: Duration] = [:]

    for model in referenceModels {
        let goldenName = model.replacingOccurrences(of: ".stl", with: ".nc")
        let url = SimulationFixture.repositoryRoot()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("gcode", isDirectory: true)
            .appendingPathComponent(goldenName)
        let text = try String(contentsOf: url, encoding: .utf8)
        let validated = GRBLParser().parse(text, profile: SimulationFixture.profile).program
        #expect(!validated.moves.isEmpty, "\(goldenName) must supply moves to simulate")

        let started = clock.now
        let result = try await simulator.simulate(
            validated,
            job: job,
            profile: SimulationFixture.profile,
            progress: SimulationFixture.progress()
        )
        _ = PreviewMesh(heightmap: result.heightmap)
        let elapsed = clock.now - started
        timings[model] = elapsed

        #expect(
            elapsed < .seconds(5),
            "preview for \(model) took \(elapsed); the SC-012 budget is five seconds"
        )
    }

    #expect(timings.count == referenceModels.count, "every reference model needs a recorded timing")
}
