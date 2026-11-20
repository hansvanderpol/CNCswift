import CNCGCode
import CNCMachineProfile
import Foundation
import Testing

/// Golden header from `contracts/gcode-output.md`.
///
/// Field order is fixed and only the `generated` line may vary between two runs of the same job
/// (FR-029, FR-028). The whole block is compared as text so a reordered, renamed, or reworded field
/// fails the build.
private let goldenHeader = [
    "; CNCswift 1.0",
    "; profile: twotrees-ttc450-pro 1.0.0",
    "; dialect: grbl1_1",
    "; units: mm  origin: stock front-left top",
    "; model: relief-demo-binary.stl",
    "; cutter: 8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10",
    "; cutter-name: 6mm flat",
    "; cutter-type: flat",
    "; cutting-diameter: 6.000",
    "; shank-diameter: 6.000",
    "; cutting-length: 20.000",
    "; flutes: 2",
    "; cutter-feed: 750.000",
    "; cutter-spindle: 8000",
    "; material: Hardwood (oak/maple)",
    "; material-feed-band: 400.000-600.000",
    "; material-spindle-band: 7000-8000",
    "; feed: 600.000",
    "; spindle: 8000",
    "; rapid-rate: controller 800 (see $110-$112)",
    "; stock: 200.000 x 150.000 x 30.000",
    "; stepover: 2.400",
    "; max-depth: 2.000",
    "; allowance: 0.500",
    "; scale: 1.000",
    "; generated: 2026-11-17T09:12:44Z",
    ";",
]

@Test func headerMatchesTheCommittedGoldenLayout() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)

    #expect(Array(lines.prefix(goldenHeader.count)) == goldenHeader)
    #expect(lines.prefix(goldenHeader.count).allSatisfy { $0.hasPrefix(";") })
    #expect(lines[goldenHeader.count] == "G21", "the start block follows the last header line")
}

@Test func headerRecordsCutterMaterialAndEffectiveRows() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let header = EmitterFixture.emittedLines(of: rendered.text)
        .prefix { $0.hasPrefix(";") }

    // FR-081: the identifier, the attributes actually used, the material name, both bands, and both
    // effective values are reproducible from the file alone.
    #expect(header.contains("; cutter: \(EmitterFixture.cutterID)"))
    #expect(header.contains("; cutter-name: 6mm flat"))
    #expect(header.contains("; cutter-type: flat"))
    #expect(header.contains("; cutting-diameter: 6.000"))
    #expect(header.contains("; material: Hardwood (oak/maple)"))
    #expect(header.contains("; material-feed-band: 400.000-600.000"))
    #expect(header.contains("; material-spindle-band: 7000-8000"))
    #expect(header.contains("; cutter-feed: 750.000"))
    #expect(header.contains("; cutter-spindle: 8000"))
    #expect(header.contains("; feed: 600.000"))
    #expect(header.contains("; spindle: 8000"))

    // The record carries the injected clock, not the system clock (FR-028).
    #expect(rendered.record.generatedAt == EmitterFixture.date("2026-11-17T09:12:44Z"))
}

@Test func startAndStopBlocksAreEmittedVerbatimInProfileOrder() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let profile = TTC450Pro.profile
    let lines = EmitterFixture.emittedLines(of: rendered.text)

    let headerEnd = goldenHeader.count
    let startBlock = Array(lines[headerEnd..<(headerEnd + profile.startBlock.count)])
    #expect(startBlock[0] == "G21")
    #expect(startBlock[1] == "G90")
    #expect(startBlock[2] == "G94")
    #expect(startBlock[3] == "G00 Z10.0")
    // Only the spindle-speed placeholder is substituted (FR-022).
    #expect(startBlock[4] == "M3 S8000")
    #expect(startBlock.count == 5)

    let stopBlock = Array(lines.suffix(profile.stopBlock.count))
    #expect(stopBlock == ["G90", "G00 Z15.0", "M5", "G00 X0 Y0", "M30"])
    #expect(stopBlock == profile.stopBlock, "the stop block is emitted verbatim")

    // FR-021: M5 stops the spindle before the origin return, M30 is last, and the file ends with a
    // newline after M30.
    #expect(lines.last == "M30")
    let spindleStop = try #require(lines.firstIndex(of: "M5"))
    let originReturn = try #require(lines.firstIndex(of: "G00 X0 Y0"))
    #expect(spindleStop < originReturn)
    #expect(rendered.text.hasSuffix("M30\n"))
}

@Test func cuttingCoordinatesUseThreeDecimals() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)
    let headerEnd = lines.prefix { $0.hasPrefix(";") }.count
    let profile = TTC450Pro.profile
    let bodyLines = Array(
        lines[(headerEnd + profile.startBlock.count)..<(lines.count - profile.stopBlock.count)]
    )

    var coordinateWords = 0
    for line in bodyLines {
        let words = line.split(separator: " ").map(String.init)
        guard let command = words.first else { continue }
        guard ["G0", "G00", "G1", "G01"].contains(command) else { continue }

        for word in words.dropFirst()
        where word.hasPrefix("X") || word.hasPrefix("Y")
            || word.hasPrefix("Z") || word.hasPrefix("F")
        {
            coordinateWords += 1
            #expect(
                hasThreeDecimals(word),
                "\(word) in '\(line)' must carry exactly three decimals"
            )
        }
    }
    #expect(coordinateWords > 0, "the fixture toolpath must emit numeric words")
}

/// A numeric word is `X`, `Y`, `Z`, or `F` followed by a fixed-point value with three decimals.
private func hasThreeDecimals(_ word: String) -> Bool {
    let number = word.dropFirst()
    guard let dot = number.firstIndex(of: ".") else { return false }
    let whole = number[number.startIndex..<dot]
    let fraction = number[number.index(after: dot)...]
    let signedWhole = whole.hasPrefix("-") ? whole.dropFirst() : whole
    return !signedWhole.isEmpty
        && signedWhole.allSatisfy(\.isNumber)
        && fraction.count == 3
        && fraction.allSatisfy(\.isNumber)
}
