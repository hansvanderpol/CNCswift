import CNCGCode
import Foundation
import Testing

@Test func renderedProgramContainsNoForbiddenLaserOrUnsupportedTokens() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    #expect(!rendered.text.isEmpty)
    let lines = EmitterFixture.emittedLines(of: rendered.text)
    let programLines = lines.filter { !$0.hasPrefix(";") }
    let upperProgram = programLines.map { $0.uppercased() }

    #expect(!upperProgram.contains { line in line.split(separator: " ").contains("M4") })
    #expect(!rendered.text.contains("$32"))
    #expect(!programLines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("$") })

    for token in ["G43", "G43.1", "G49", "G93", "M6", "M7"] {
        #expect(
            !upperProgram.contains { line in
                line.split(whereSeparator: { $0 == " " || $0 == ";" }).contains(Substring(token))
            },
            "forbidden token \(token) must not appear in output"
        )
    }

    // No dynamic-power or laser-mode comments/markers.
    #expect(!rendered.text.localizedCaseInsensitiveContains("laser"))
    #expect(!rendered.text.localizedCaseInsensitiveContains("dynamic"))
}

@Test func spindleSpeedIsEmittedOnlyAsSpindleCommandNotAsLaserPower() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let programLines = EmitterFixture.emittedLines(of: rendered.text).filter { !$0.hasPrefix(";") }

    // Legitimate spindle activation is exactly the start-block M3 line with an S word.
    let sLines = programLines.filter { line in
        line.split(separator: " ").contains { $0.hasPrefix("S") }
    }
    #expect(sLines == ["M3 S8000"], "S words appear only on the spindle start command")
    #expect(!programLines.contains { $0.split(separator: " ").contains("M4") })
}
