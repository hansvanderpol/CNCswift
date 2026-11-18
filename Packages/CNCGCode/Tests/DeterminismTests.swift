import CNCGCode
import Foundation
import Testing

/// Determinism (FR-028, SC-005): the injected clock is the only permitted difference.
///
/// Two renders of the same job at different instants must produce byte-identical text apart from
/// the `; generated:` header line, and the renderer must never consult the system clock (research
/// D8, Principle III).
@Test func twoRunsDifferOnlyOnTheGeneratedLine() throws {
    let firstDate = EmitterFixture.date("2026-11-17T09:12:44Z")
    let secondDate = EmitterFixture.date("2026-11-18T10:00:00Z")

    let first = try EmitterFixture.render(generatedAt: firstDate)
    let second = try EmitterFixture.render(generatedAt: secondDate)

    let firstLines = EmitterFixture.emittedLines(of: first.text)
    let secondLines = EmitterFixture.emittedLines(of: second.text)

    #expect(firstLines.count == secondLines.count)

    let differences = zip(firstLines, secondLines).enumerated()
        .filter { $0.element.0 != $0.element.1 }
        .map { (index: $0.offset, first: $0.element.0, second: $0.element.1) }

    #expect(differences.count == 1, "only the generated line may differ between runs")
    let difference = try #require(differences.first)
    #expect(difference.first.hasPrefix("; generated: "))
    #expect(difference.second.hasPrefix("; generated: "))
    #expect(difference.first != difference.second)
    #expect(difference.first == "; generated: 2026-11-17T09:12:44Z")
    #expect(difference.second == "; generated: 2026-11-18T10:00:00Z")
}

@Test func identicalInputsAndClockProduceByteIdenticalText() throws {
    let date = EmitterFixture.date("2026-11-17T09:12:44Z")

    let first = try EmitterFixture.render(generatedAt: date)
    let second = try EmitterFixture.render(generatedAt: date)

    #expect(first.text == second.text)
    #expect(Array(first.text.utf8) == Array(second.text.utf8))
    #expect(first.record.generatedAt == date)
    #expect(second.record.generatedAt == date)
}

@Test func headerWeldsTheInjectedInstantRatherThanTodaysDate() throws {
    let rendered = try EmitterFixture.render(
        generatedAt: EmitterFixture.date("2026-11-17T09:12:44Z")
    )
    let lines = EmitterFixture.emittedLines(of: rendered.text)

    #expect(lines.contains("; generated: 2026-11-17T09:12:44Z"))
    #expect(
        !lines.contains {
            $0.hasPrefix("; generated: ") && $0 != "; generated: 2026-11-17T09:12:44Z"
        })
}
