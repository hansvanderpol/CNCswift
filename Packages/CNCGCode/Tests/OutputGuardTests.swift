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

@Test func noEmittedLineCanBeClassifiedAsLaserPower() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let programLines = EmitterFixture.emittedLines(of: rendered.text).filter { !$0.hasPrefix(";") }
    let sBearing = programLines.filter { $0.uppercased().contains("S") }

    // Under the 2026-11-20 clarification an S word is power only with M4, $32, or a
    // dynamic-power comment. The emitter produces none of those, so every S word is spindle.
    #expect(sBearing.count == 1)
    #expect(sBearing.first?.hasPrefix("M3 S") == true)
    #expect(!sBearing.contains { $0.uppercased().contains("M4") })
    #expect(!rendered.text.contains("$32"))
    #expect(!rendered.text.localizedCaseInsensitiveContains("dynamic power"))
}
