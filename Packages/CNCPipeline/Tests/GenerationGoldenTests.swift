import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCPipeline
import CNCToolpath
import CNCValidation
import Foundation
import Testing

/// Byte-level proof that the VS-1 cutter-margin behaviour produces reproducible production output
/// (T121, FR-028).
///
/// The emitter-level files in `Fixtures/gcode/` start from a hand-authored toolpath and therefore
/// cannot exercise model placement. This fixture is generated from a real reference STL through the
/// same decode, plan, and emit stages the app uses. `BenchmarkSupport` fixes every volatile input,
/// so a byte comparison is meaningful without scrubbing the output.
private enum GenerationGolden {
    static let model = "relief-demo-binary.stl"
    static let fileName = "footprint-margin-relief-demo-binary.nc"

    static func url() -> URL {
        BenchmarkSupport.repositoryRoot()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("gcode", isDirectory: true)
            .appendingPathComponent("generation", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func generate() async throws -> (
        program: RenderedProgram, toolpath: Toolpath, job: JobSettings
    ) {
        let document = try await BenchmarkSupport.prepared(model)
        let job = try BenchmarkSupport.job(for: document)
        let toolpath = try await ToolpathPlanner().plan(
            job,
            profile: BenchmarkSupport.profile,
            progress: BenchmarkSupport.progress()
        )
        let program = try GCodeEmitter(
            modelFileName: model,
            appliedScale: 1
        ).render(
            toolpath,
            cutter: job.cutter,
            material: BenchmarkSupport.material,
            job: job,
            profile: BenchmarkSupport.profile,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        return (program, toolpath, job)
    }
}

@Test func committedGenerationGoldenMatchesPipelineOutput() async throws {
    let expected = try String(contentsOf: GenerationGolden.url(), encoding: .utf8)
    let generated = try await GenerationGolden.generate()

    #expect(
        generated.program.text == expected,
        "\(GenerationGolden.fileName) no longer matches full-pipeline output"
    )

    let report = GRBLValidator().validate(
        generated.program.text,
        profile: BenchmarkSupport.profile
    )
    #expect(report.findings.isEmpty, "the golden program must have zero validation findings")
    #expect(!report.hasErrors, "the golden program must be committable")

    let envelope = BenchmarkSupport.profile.envelope
    let epsilon = 1e-6
    for move in generated.toolpath.moves {
        for point in [move.from, move.to] {
            #expect(point.x >= -epsilon && point.x <= min(generated.job.stock.width, envelope.x) + epsilon)
            #expect(point.y >= -epsilon && point.y <= min(generated.job.stock.depth, envelope.y) + epsilon)
            #expect(
                point.z >= -generated.job.stock.height - epsilon
                    && point.z <= BenchmarkSupport.profile.clearanceZ + epsilon
            )
        }
    }
}

/// Writes a review candidate only. `Scripts/update-golden.sh` supplies an isolated,
/// gitignored directory; no test ever writes to the committed golden fixture.
@Test func generateGoldenCandidateIntoReceivedDirectoryForReview() async throws {
    guard let directory = ProcessInfo.processInfo.environment["CNCSWIFT_GOLDEN_CANDIDATE_DIR"]
    else { return }

    let received = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: received, withIntermediateDirectories: true)
    let generated = try await GenerationGolden.generate()
    try generated.program.text.write(
        to: received.appendingPathComponent(GenerationGolden.fileName),
        atomically: true,
        encoding: .utf8
    )
}
