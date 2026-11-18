import CNCGCode
import Foundation
import Testing

/// The 800 mm/min rapid ceiling is machine setup, not program text (FR-024).
///
/// GRBL 1.1 ignores any `F` word on a `G0` line, so the file records the controller settings that
/// produce the ceiling and never claims to command it itself.
@Test func rapidRateIsRecordedAsControllerSetupInTheHeader() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)

    #expect(lines.contains("; rapid-rate: controller 800 (see $110-$112)"))
    #expect(
        lines.filter { $0.contains("rapid-rate") } == [
            "; rapid-rate: controller 800 (see $110-$112)"
        ],
        "the header carries exactly one rapid-rate line"
    )
    #expect(
        lines.prefix { $0.hasPrefix(";") }.contains("; rapid-rate: controller 800 (see $110-$112)"))
}

@Test func noRapidLineCarriesAFeedOrSpindleWord() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let rapids = EmitterFixture.emittedLines(of: rendered.text).filter(isRapid)

    // The fixture toolpath has four rapids, so this test cannot pass vacuously.
    #expect(rapids.count == 4)
    for line in rapids {
        let words = line.split(separator: " ").map(String.init)
        #expect(
            !words.contains { $0.hasPrefix("F") },
            "'\(line)' must not carry a feed word on a rapid"
        )
        #expect(
            !words.contains { $0.hasPrefix("S") },
            "'\(line)' must not carry a spindle word on a rapid"
        )
    }
}

@Test func rapidRateIsNeverClaimedAsProgramText() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let programLines = EmitterFixture.emittedLines(of: rendered.text)
        .filter { !$0.hasPrefix(";") }

    #expect(!programLines.contains { $0.uppercased().contains("RAPID") })
    #expect(!programLines.contains { $0.contains("F800") }, "no program line commands a rapid rate")
    #expect(!programLines.contains { $0.hasPrefix("$") }, "controller settings are never emitted")
}

private func isRapid(_ line: String) -> Bool {
    guard let command = line.split(separator: " ").first else { return false }
    return command == "G0" || command == "G00"
}
