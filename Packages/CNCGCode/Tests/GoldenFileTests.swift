import CNCGCode
import CNCMachineProfile
import Foundation
import Testing

/// Proves the committed `.nc` files are reproducible production output (T074, FR-028).
///
/// Every value comes from the contract-sourced emitter fixture; only the model basename changes, so
/// the golden files exercise filename derivation as well as the fixed header and body bytes.
@Test func committedGoldenFilesMatchEmitterOutput() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let directory = root.appendingPathComponent("Fixtures/gcode", isDirectory: true)
    let generatedAt = EmitterFixture.date("2026-11-17T09:12:44Z")

    for model in [
        "relief-demo-ascii.stl",
        "relief-demo-binary.stl",
        "relief-demo-200k.stl",
        "deep-cavity.stl",
        "fine-detail.stl",
    ] {
        let expected = try GCodeEmitter(modelFileName: model)
            .render(
                EmitterFixture.toolpath,
                cutter: EmitterFixture.cutter,
                material: EmitterFixture.material,
                job: EmitterFixture.job(),
                profile: TTC450Pro.profile,
                generatedAt: generatedAt
            )
            .text
        let file = directory.appendingPathComponent(OutputFileName.deriving(from: model))
        let actual = try String(contentsOf: file, encoding: .utf8)

        #expect(actual == expected, "\(file.lastPathComponent) no longer matches emitter output")
        #expect(actual.contains("; material: Hardwood (oak/maple)"))
        #expect(actual.contains("; feed: 600.000"))
        #expect(actual.contains("; spindle: 8000"))
        #expect(actual.contains("; rapid-rate: controller 800 (see $110-$112)"))
        #expect(actual.hasSuffix("M30\n"))
        #expect(actual.utf8.allSatisfy { $0 < 128 })
        #expect(
            actual.split(separator: "\n", omittingEmptySubsequences: false).allSatisfy {
                $0.utf8.count <= 80
            })
    }
}
