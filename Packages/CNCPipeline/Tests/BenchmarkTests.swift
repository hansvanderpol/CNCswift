import CNCCutters
import CNCDiagnostics
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCPipeline
import CNCSTL
import CNCSimulation
import CNCToolpath
import CNCValidation
import Foundation
import Testing

/// Evidence harness for SC-001 and SC-012 (task T112).
///
/// These tests use the real decoder, planner, emitter, validator and simulator. Unlike the unit
/// suites they measure wall-clock time on the five committed reference fixtures, so their timings
/// are recorded in the validation evidence rather than asserted as exact values. The only budgets
/// asserted are the ones the success criteria state: five minutes for decode plus generation and
/// five seconds for each preview.
private enum BenchmarkSupport {
    static let profile = TTC450Pro.profile
    static let material = Presets.all[1]
    static let referenceModels = [
        "relief-demo-ascii.stl",
        "relief-demo-binary.stl",
        "relief-demo-200k.stl",
        "deep-cavity.stl",
        "fine-detail.stl",
    ]

    static let cutter = Cutter(
        id: CutterID("8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10"),
        name: "benchmark 6mm flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 79,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )

    static func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url = url.deletingLastPathComponent()
        }
        return url
    }

    static func progress() -> ProgressSink {
        ProgressSink(report: { _ in }, isCancelled: { false })
    }

    static func effective() throws -> EffectiveCuttingValues {
        try EffectiveCuttingValues(
            feed: 600,
            spindle: 8000,
            source: .userChoice,
            material: material,
            profile: profile
        ).confirming()
    }

    /// Decodes a fixture and expresses it in the front-left-top machine convention. The 200k
    /// reference spans the full bed, so its explicit scale action is applied before planning.
    static func prepared(_ model: String) async throws -> MeshDocument {
        let url = repositoryRoot()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("stl", isDirectory: true)
            .appendingPathComponent(model)
        let decoded = try await STLDecoder.decode(url: url, progress: progress())
        let scale = decoded.triangleCount > 100_000 ? 0.5 : 1.0
        let originX = decoded.bounds.min.x
        let originY = decoded.bounds.min.y
        func mapped(_ point: Vec3) -> Vec3 {
            Vec3(
                x: (point.x - originX) * scale,
                y: (point.y - originY) * scale,
                z: point.z * scale
            )
        }
        let mesh = Mesh(
            triangles: decoded.mesh.triangles.map { triangle in
                Triangle(
                    a: mapped(triangle.a),
                    b: mapped(triangle.b),
                    c: mapped(triangle.c)
                )
            }
        )
        guard let bounds = mesh.bounds else {
            Issue.record("\(model) must have bounds after the explicit scale action")
            return decoded
        }
        return MeshDocument(
            encoding: decoded.encoding,
            triangleCount: decoded.triangleCount,
            bounds: bounds,
            isManifold: decoded.isManifold,
            degenerateTriangleCount: decoded.degenerateTriangleCount,
            mesh: mesh
        )
    }

    static func job(for document: MeshDocument) throws -> JobSettings {
        let width = min(460, max(1, document.bounds.max.x - document.bounds.min.x + 8))
        let depth = min(460, max(1, document.bounds.max.y - document.bounds.min.y + 8))
        return JobSettings(
            mesh: document.mesh,
            modelBounds: document.bounds,
            stock: StockBlank(width: width, depth: depth, height: 70),
            cutter: cutter,
            materialID: material.id,
            effective: try effective(),
            stepover: 4,
            maxDepthPerPass: 5,
            finishingAllowance: 0.5,
            unitsConfirmed: true,
            orientationConfirmed: true,
            rapidRateConfirmed: true,
            confirmed: true
        )
    }

    static func generate(_ document: MeshDocument, model: String) async throws -> (
        RenderedProgram, Int
    ) {
        let job = try job(for: document)
        let toolpath = try await ToolpathPlanner().plan(
            job,
            profile: profile,
            progress: progress()
        )
        let program = try GCodeEmitter(
            modelFileName: model,
            appliedScale: 1
        ).render(
            toolpath,
            cutter: job.cutter,
            material: material,
            job: job,
            profile: profile,
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        return (program, toolpath.moves.count)
    }

    static func seconds(_ duration: Duration) -> String {
        let components = duration.components
        let value = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

@Test func benchmarkDecodeAndGenerationFor200KTriangleFixture() async throws {
    let clock = ContinuousClock()
    let model = "relief-demo-200k.stl"

    let decodeStarted = clock.now
    let document = try await BenchmarkSupport.prepared(model)
    let decode = clock.now - decodeStarted

    let generationStarted = clock.now
    let (program, moveCount) = try await BenchmarkSupport.generate(document, model: model)
    let generation = clock.now - generationStarted

    let validateStarted = clock.now
    let report = GRBLValidator().validate(program.text, profile: BenchmarkSupport.profile)
    let validate = clock.now - validateStarted
    let total = decode + generation + validate

    print(
        "BENCHMARK SC-001 \(model) triangles=\(document.triangleCount) moves=\(moveCount) "
            + "bytes=\(program.text.utf8.count) decode=\(BenchmarkSupport.seconds(decode))s "
            + "generation=\(BenchmarkSupport.seconds(generation))s "
            + "validate=\(BenchmarkSupport.seconds(validate))s "
            + "total=\(BenchmarkSupport.seconds(total))s findings=\(report.findings.count)"
    )
    #expect(document.triangleCount == 200_000)
    #expect(total < .seconds(300), "SC-001 budget is five minutes for decode plus generation")
}

@Test func benchmarkPreviewForAllFiveReferenceModels() async throws {
    let clock = ContinuousClock()
    let simulator = ZMapSimulator(resolution: 2)
    let job = try BenchmarkSupport.job(
        for: MeshDocument(
            encoding: .binary,
            triangleCount: 2,
            bounds: AABB(
                min: Vec3(x: 0, y: 0, z: 0),
                max: Vec3(x: 200, y: 150, z: 70)
            ),
            isManifold: true,
            degenerateTriangleCount: 0,
            mesh: Mesh(triangles: [])
        )
    )

    // The reviewed golden programs are the validated outputs for these five fixtures (T074), so
    // preview latency is measured on exactly the text the app would hand to the simulator.
    for model in BenchmarkSupport.referenceModels {
        let goldenName = model.replacingOccurrences(of: ".stl", with: ".nc")
        let url = BenchmarkSupport.repositoryRoot()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("gcode", isDirectory: true)
            .appendingPathComponent(goldenName)
        let text = try String(contentsOf: url, encoding: .utf8)
        let parsed = GRBLParser().parse(text, profile: BenchmarkSupport.profile)

        let started = clock.now
        let result = try await simulator.simulate(
            parsed.program,
            job: job,
            profile: BenchmarkSupport.profile,
            progress: BenchmarkSupport.progress()
        )
        _ = PreviewMesh(heightmap: result.heightmap)
        let elapsed = clock.now - started

        print(
            "BENCHMARK SC-012 \(model) preview=\(BenchmarkSupport.seconds(elapsed))s "
                + "moves=\(parsed.program.moves.count)"
        )
        #expect(elapsed < .seconds(5), "\(model) exceeded the five-second preview budget")
    }
}
