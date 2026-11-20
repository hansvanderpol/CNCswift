import CNCMachineProfile
import Foundation

/// Profile-driven semantic checks over a parsed program (FR-022 – FR-026, FR-031).
///
/// Findings carry stable rule identifiers and one-based source lines. Any error-severity finding
/// blocks the commit path; conformance problems are reported rather than thrown.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct ValidationRules: Sendable {
    /// Creates a rule evaluator with no stored state.
    public init() {}

    /// Evaluates every semantic rule against one parsed program.
    ///
    /// - Parameters:
    ///   - program: The program returned by the independent parser.
    ///   - profile: The active machine profile owning all limits, blocks, and command tables.
    /// - Returns: All findings, in rule order. An empty array means the program is committable.
    public func evaluate(_ program: ParsedProgram, profile: MachineProfile) -> [Finding] {
        var findings: [Finding] = []
        let commands = commandLines(in: program)

        findings.append(contentsOf: forbiddenCommands(in: commands, profile: profile))
        findings.append(contentsOf: feedOnRapid(in: commands))
        findings.append(contentsOf: spindleRange(in: commands, profile: profile))
        findings.append(contentsOf: envelope(program.moves, profile: profile))
        findings.append(contentsOf: feedCeiling(program.moves, profile: profile))
        findings.append(contentsOf: blockOrder(commands, profile: profile))
        findings.append(contentsOf: spindleBeforeOrigin(commands))

        return findings
    }

    private func commandLines(in program: ParsedProgram) -> [(lineNumber: Int, text: String)] {
        program.lines.enumerated().compactMap { offset, line in
            GCodeLexer.isCommentOrBlank(line) ? nil : (offset + 1, line)
        }
    }

    private func forbiddenCommands(
        in commands: [(lineNumber: Int, text: String)],
        profile: MachineProfile
    ) -> [Finding] {
        let unsupported = Set(profile.unsupportedCommands.map(GCodeLexer.canonicalCommand))
        var findings: [Finding] = []

        for command in commands {
            for word in GCodeLexer.words(in: command.text) {
                if word.letter == "$" {
                    findings.append(
                        Finding(
                            severity: .error,
                            lineNumber: command.lineNumber,
                            ruleIdentifier: "setting-command",
                            message:
                                "Controller setting \(word.canonical) is forbidden in a program."
                        )
                    )
                }
                if unsupported.contains(word.canonical) {
                    findings.append(
                        Finding(
                            severity: .error,
                            lineNumber: command.lineNumber,
                            ruleIdentifier: "unsupported-command",
                            message: "Unsupported command \(word.canonical) is forbidden."
                        )
                    )
                }
            }
        }

        return findings
    }

    private func feedOnRapid(
        in commands: [(lineNumber: Int, text: String)]
    ) -> [Finding] {
        var findings: [Finding] = []

        for command in commands {
            let words = GCodeLexer.words(in: command.text)
            guard let motion = words.first, motion.canonical == "G0" else { continue }
            guard words.contains(where: { $0.letter == "F" }) else { continue }
            findings.append(
                Finding(
                    severity: .error,
                    lineNumber: command.lineNumber,
                    ruleIdentifier: "feed-on-rapid",
                    message: "Rapid move \(motion.canonical) must not carry an F feed word."
                )
            )
        }

        return findings
    }

    private func spindleRange(
        in commands: [(lineNumber: Int, text: String)],
        profile: MachineProfile
    ) -> [Finding] {
        var findings: [Finding] = []

        for command in commands {
            for word in GCodeLexer.words(in: command.text) where word.letter == "S" {
                guard let value = word.value else { continue }
                guard value < profile.limits.spindleMin || value > profile.limits.spindleMax else {
                    continue
                }
                let lower = Int(profile.limits.spindleMin.rounded())
                let upper = Int(profile.limits.spindleMax.rounded())
                findings.append(
                    Finding(
                        severity: .error,
                        lineNumber: command.lineNumber,
                        ruleIdentifier: "spindle-range",
                        message:
                            "Spindle value \(word.number) is outside the \(lower)-\(upper) RPM range."
                    )
                )
            }
        }

        return findings
    }

    private func envelope(
        _ moves: [ParsedMove],
        profile: MachineProfile
    ) -> [Finding] {
        let envelope = profile.envelope
        let epsilon = 1e-9
        var findings: [Finding] = []

        for move in moves {
            for point in [move.start, move.end] {
                let outside =
                    point.x < -epsilon || point.x > envelope.x + epsilon || point.y < -epsilon
                    || point.y > envelope.y + epsilon || point.z < -envelope.z - epsilon
                    || point.z > envelope.z + epsilon
                guard outside else { continue }
                findings.append(
                    Finding(
                        severity: .error,
                        lineNumber: move.lineNumber,
                        ruleIdentifier: "envelope",
                        message:
                            "Move leaves the \(Int(envelope.x)) x \(Int(envelope.y)) x \(Int(envelope.z)) mm envelope."
                    )
                )
                break
            }
        }

        return findings
    }

    private func feedCeiling(
        _ moves: [ParsedMove],
        profile: MachineProfile
    ) -> [Finding] {
        let ceiling = profile.limits.maxFeedRate
        var findings: [Finding] = []

        for move in moves where move.mode == .cut {
            guard let feed = move.feedRate, feed > ceiling else { continue }
            findings.append(
                Finding(
                    severity: .error,
                    lineNumber: move.lineNumber,
                    ruleIdentifier: "feed-ceiling",
                    message: "Cutting feed \(feed) exceeds the \(Int(ceiling)) mm/min ceiling."
                )
            )
        }

        return findings
    }

    private func blockOrder(
        _ commands: [(lineNumber: Int, text: String)],
        profile: MachineProfile
    ) -> [Finding] {
        var findings: [Finding] = []
        let lines = commands.map(\.text)

        if lines.count < profile.startBlock.count {
            findings.append(blockFinding(profile.startBlock.first ?? "", "start"))
        } else {
            for (index, template) in profile.startBlock.enumerated()
            where !Self.matchesBlockLine(lines[index], template) {
                findings.append(blockFinding(template, "start"))
                break
            }
        }

        let stopStart = lines.count - profile.stopBlock.count
        if stopStart < profile.startBlock.count {
            findings.append(blockFinding(profile.stopBlock.first ?? "", "stop"))
        } else {
            for (index, template) in profile.stopBlock.enumerated()
            where !Self.matchesBlockLine(lines[stopStart + index], template) {
                findings.append(blockFinding(template, "stop"))
                break
            }
        }

        let finalCommand = lines.last.flatMap { GCodeLexer.words(in: $0).first?.canonical }
        if finalCommand != "M30" {
            findings.append(
                Finding(
                    severity: .error,
                    lineNumber: commands.last?.lineNumber ?? 0,
                    ruleIdentifier: "final-m30",
                    message: "M30 must be the final command in the program."
                )
            )
        }

        return findings
    }

    private func blockFinding(_ template: String, _ position: String) -> Finding {
        Finding(
            severity: .error,
            lineNumber: 0,
            ruleIdentifier: "block-order",
            message: "The profile \(position) block '\(template)' is missing or out of order."
        )
    }

    private func spindleBeforeOrigin(
        _ commands: [(lineNumber: Int, text: String)]
    ) -> [Finding] {
        let m5Line = commands.first { command in
            GCodeLexer.words(in: command.text).first?.canonical == "M5"
        }?.lineNumber
        let originLine = commands.first { command in
            let words = GCodeLexer.words(in: command.text)
            guard words.contains(where: { $0.canonical == "G0" }) else { return false }
            return words.contains { $0.letter == "X" && $0.value == 0 }
                && words.contains { $0.letter == "Y" && $0.value == 0 }
        }?.lineNumber

        guard let originLine, m5Line == nil || originLine < (m5Line ?? Int.max) else {
            return []
        }

        return [
            Finding(
                severity: .error,
                lineNumber: originLine,
                ruleIdentifier: "spindle-before-origin",
                message: "M5 must stop the spindle before the origin return."
            )
        ]
    }

    private static func matchesBlockLine(_ line: String, _ template: String) -> Bool {
        let hasSpindlePlaceholder = template.contains("{spindleSpeed}")
        let expected = GCodeLexer.words(
            in: template.replacingOccurrences(of: "{spindleSpeed}", with: "0")
        )
        let actual = GCodeLexer.words(in: line)
        guard actual.count == expected.count else { return false }

        return zip(actual, expected).allSatisfy { word, reference in
            guard word.letter == reference.letter else { return false }
            if hasSpindlePlaceholder, word.letter == "S", reference.canonical == "S0" {
                return true
            }
            if word.letter == "G" || word.letter == "M" {
                return word.canonical == reference.canonical
            }
            guard let value = word.value, let target = reference.value else {
                return word.number == reference.number
            }
            return abs(value - target) < 1e-9
        }
    }
}
