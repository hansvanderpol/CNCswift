import CNCGeometry
import CNCMachineProfile
import Foundation

/// Parses GRBL 1.1 program text into modal moves and line-level findings (research D7, FR-026).
///
/// The parser owns its own grammar; it never calls the emitter and takes only `String` input.
/// Conformance problems are returned as findings rather than thrown so the UI can list them all.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct GRBLParser: Sendable {
    /// Creates a parser with no stored state.
    public init() {}

    /// Parses one program against the supplied profile.
    ///
    /// - Parameters:
    ///   - text: The exact program text, including comments and line endings.
    ///   - profile: The active machine profile supplying supported commands and line limits.
    /// - Returns: The parsed program and every line-level finding in source order.
    public func parse(
        _ text: String,
        profile: MachineProfile
    ) -> (program: ParsedProgram, findings: [Finding]) {
        let supported = Set(
            profile.supportedCommands.values.flatMap { $0.map(GCodeLexer.canonicalCommand) })
        let unsupported = Set(profile.unsupportedCommands.map(GCodeLexer.canonicalCommand))
        var findings: [Finding] = []
        var moves: [ParsedMove] = []
        var position = Vec3(x: 0, y: 0, z: 0)
        var motion: ParsedMoveMode?
        var modalFeed: Double?

        for (offset, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
        {
            let line = String(rawLine)
            let lineNumber = offset + 1

            if line.count > profile.limits.maxLineLength {
                findings.append(
                    Finding(
                        severity: .error,
                        lineNumber: lineNumber,
                        ruleIdentifier: "line-length",
                        message:
                            "Line \(lineNumber) has \(line.count) characters; the limit is \(profile.limits.maxLineLength)."
                    )
                )
            }

            let words = GCodeLexer.words(in: line)
            guard !words.isEmpty else { continue }

            var axes: [String: Double] = [:]
            for word in words {
                let canonical = word.canonical
                switch word.letter {
                case "G":
                    switch canonical {
                    case "G0":
                        motion = .rapid
                    case "G1":
                        motion = .cut
                    default:
                        guard !unsupported.contains(canonical) else {
                            findings.append(
                                Self.finding(
                                    .unsupported,
                                    canonical,
                                    lineNumber: lineNumber
                                )
                            )
                            continue
                        }
                        guard supported.contains(canonical) else {
                            findings.append(
                                Self.finding(.unknown, canonical, lineNumber: lineNumber)
                            )
                            continue
                        }
                    }
                case "M":
                    guard !unsupported.contains(canonical) else {
                        findings.append(
                            Self.finding(.unsupported, canonical, lineNumber: lineNumber)
                        )
                        continue
                    }
                    guard supported.contains(canonical) else {
                        findings.append(Self.finding(.unknown, canonical, lineNumber: lineNumber))
                        continue
                    }
                case "X", "Y", "Z":
                    guard let value = word.value else {
                        findings.append(Self.finding(.unknown, canonical, lineNumber: lineNumber))
                        continue
                    }
                    axes[word.letter] = value
                case "F":
                    guard let value = word.value else {
                        findings.append(Self.finding(.unknown, canonical, lineNumber: lineNumber))
                        continue
                    }
                    modalFeed = value
                case "S":
                    guard word.value != nil else {
                        findings.append(Self.finding(.unknown, canonical, lineNumber: lineNumber))
                        continue
                    }
                case "$":
                    findings.append(
                        Finding(
                            severity: .error,
                            lineNumber: lineNumber,
                            ruleIdentifier: "setting-command",
                            message: "Controller setting \(canonical) is forbidden in program text."
                        )
                    )
                default:
                    findings.append(Self.finding(.unknown, canonical, lineNumber: lineNumber))
                }
            }

            guard !axes.isEmpty, let mode = motion else { continue }
            let end = Vec3(
                x: axes["X"] ?? position.x,
                y: axes["Y"] ?? position.y,
                z: axes["Z"] ?? position.z
            )
            moves.append(
                ParsedMove(
                    lineNumber: lineNumber,
                    mode: mode,
                    start: position,
                    end: end,
                    feedRate: mode == .cut ? modalFeed : nil
                )
            )
            position = end
        }

        return (ParsedProgram(text: text, moves: moves), findings)
    }

    private enum FindingKind {
        case unknown
        case unsupported

        var ruleIdentifier: String {
            switch self {
            case .unknown: return "unknown-word"
            case .unsupported: return "unsupported-command"
            }
        }

        var prefix: String {
            switch self {
            case .unknown: return "Unknown word"
            case .unsupported: return "Unsupported command"
            }
        }
    }

    private static func finding(
        _ kind: FindingKind,
        _ token: String,
        lineNumber: Int
    ) -> Finding {
        Finding(
            severity: .error,
            lineNumber: lineNumber,
            ruleIdentifier: kind.ruleIdentifier,
            message: "\(kind.prefix) '\(token)' on line \(lineNumber)."
        )
    }
}
