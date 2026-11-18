import CNCGCode
import CNCCutters
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation
import Testing

@Test func everyEmittedLineIsAtMost80ASCIICharacters() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    #expect(!rendered.text.isEmpty)
    #expect(rendered.text.hasSuffix("\n"))

    let lines = EmitterFixture.emittedLines(of: rendered.text)
    #expect(!lines.isEmpty)
    #expect(lines.contains { $0.hasPrefix(";") })
    #expect(lines.contains("M30"))

    for (index, line) in lines.enumerated() {
        #expect(line.count <= 80, "line \(index + 1) exceeds 80 characters: \(line.count)")
        #expect(line.allSatisfy { $0.isASCII }, "line \(index + 1) contains non-ASCII: \(line)")
        #expect(line.unicodeScalars.allSatisfy { $0.value <= 0x7F }, "line \(index + 1) is not 7-bit ASCII")
    }

    #expect(rendered.text.utf8.allSatisfy { $0 <= 0x7F })
}

@Test func nonASCIIEllipsisCharacterIsRejected() throws {
    let ellipsisCutter = Cutter(
        id: EmitterFixture.cutterID,
        name: "6mm flat \u{2026}",
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

    #expect(throws: RenderingError.self) {
        try GCodeEmitter().render(
            EmitterFixture.toolpath,
            cutter: ellipsisCutter,
            material: EmitterFixture.material,
            job: EmitterFixture.job(),
            profile: TTC450Pro.profile,
            generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
        )
    }
}

@Test func overLongHeaderValueIsTruncatedWithASCIIEllipsis() throws {
    let longName = String(repeating: "A", count: 120)
    let longCutter = Cutter(
        id: EmitterFixture.cutterID,
        name: longName,
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

    let rendered = try GCodeEmitter().render(
        EmitterFixture.toolpath,
        cutter: longCutter,
        material: EmitterFixture.material,
        job: EmitterFixture.job(),
        profile: TTC450Pro.profile,
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )

    let lines = EmitterFixture.emittedLines(of: rendered.text)
    let cutterNameLine = try #require(lines.first { $0.hasPrefix("; cutter-name: ") })
    #expect(cutterNameLine.count <= 80)
    #expect(cutterNameLine.hasSuffix("..."))
    #expect(!cutterNameLine.contains("\u{2026}"))
    #expect(cutterNameLine.allSatisfy { $0.isASCII })
}

@Test func anOverLongLineCaseThrows() throws {
    // A body line that cannot be represented within 80 characters must be refused rather than emitted.
    let farMove = Move(
        from: Vec3(x: 0, y: 0, z: 10),
        to: Vec3(x: 12345678901234567890.0, y: 0, z: -1),
        mode: .cut
    )
    let toolpath = Toolpath(
        moves: [farMove],
        feedRate: 600,
        bounds: AABB(
            min: Vec3(x: 0, y: 0, z: -1),
            max: Vec3(x: 12345678901234567890.0, y: 0, z: 10)
        )
    )

    #expect(throws: RenderingError.self) {
        try GCodeEmitter().render(
            toolpath,
            cutter: EmitterFixture.cutter,
            material: EmitterFixture.material,
            job: EmitterFixture.job(),
            profile: TTC450Pro.profile,
            generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
        )
    }
}
