import CNCCutters
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation
import Testing

/// Rapid sequencing and modal restoration are the emitter's responsibility (FR-024, FR-039).
/// The tests are written against the public rendering boundary so the private formatter can be
/// refactored without changing the emitted bytes.
@Test func rapidsRestoreModalCutWithFeedAfterEachRapidRun() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)
    let headerEnd = lines.prefix { $0.hasPrefix(";") }.count
    let profile = TTC450Pro.profile
    let movementLines = Array(
        lines[(headerEnd + profile.startBlock.count)..<(lines.count - profile.stopBlock.count)]
    )

    var rapidRunsFollowedByCuts = 0
    for (index, line) in movementLines.enumerated() where isRapid(line) {
        #expect(
            !line.split(separator: " ").contains { $0.hasPrefix("F") || $0.hasPrefix("S") },
            "'\(line)' must not carry feed or spindle words"
        )
        guard let nextCut = movementLines.dropFirst(index + 1).first(where: { !isRapid($0) })
        else { continue }
        if index == 0 || !isRapid(movementLines[index - 1]) {
            rapidRunsFollowedByCuts += 1
        }
        #expect(nextCut.hasPrefix("G1 "), "'\(nextCut)' must restore modal G1")
        #expect(nextCut.contains("F600.000"), "'\(nextCut)' must restore the modal feed")
    }

    // Two rapid runs are followed by cutting in the shared fixture, so this cannot pass vacuously.
    #expect(rapidRunsFollowedByCuts == 2)
}

@Test func aDescendingRapidRetractsToClearanceBeforeTraversingInXY() throws {
    let toolpath = Toolpath(
        moves: [
            Move(
                from: Vec3(x: 0, y: 0, z: 0),
                to: Vec3(x: 10, y: 10, z: -5),
                mode: .rapid
            ),
            Move(
                from: Vec3(x: 10, y: 10, z: -5),
                to: Vec3(x: 12, y: 10, z: -5),
                mode: .cut
            ),
        ],
        feedRate: 600,
        bounds: AABB(
            min: Vec3(x: 0, y: 0, z: -5),
            max: Vec3(x: 12, y: 10, z: 0)
        )
    )
    let rendered = try GCodeEmitter().render(
        toolpath,
        cutter: EmitterFixture.cutter,
        material: EmitterFixture.material,
        job: EmitterFixture.job(),
        profile: TTC450Pro.profile,
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)
    let headerEnd = lines.prefix { $0.hasPrefix(";") }.count
    let movementLines = Array(
        lines[
            (headerEnd + TTC450Pro.profile.startBlock.count)..<(lines.count
                - TTC450Pro.profile.stopBlock.count)]
    )

    #expect(movementLines.prefix(3) == ["G0 Z10.000", "G0 X10.000 Y10.000", "G0 Z-5.000"])
    #expect(movementLines.dropFirst(3).first == "G1 X12.000 F600.000")
}

private func isRapid(_ line: String) -> Bool {
    guard let command = line.split(separator: " ").first else { return false }
    return command == "G0" || command == "G00"
}
