import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import Foundation

/// Whether a move in a validated program repositions the cutter or removes material.
public enum ParsedMoveMode: String, Sendable, Equatable, Codable {
    case rapid
    case cut
}

/// One move reconstructed by the independent parser.
///
/// Positions are machine-space millimetres after modal state is applied, so simulation can use
/// them directly (FR-065).
public struct ParsedMove: Sendable, Equatable {
    /// The one-based line the move was parsed from.
    public let lineNumber: Int
    public let mode: ParsedMoveMode
    public let start: Vec3
    public let end: Vec3

    /// The modal feed in effect on this line, when one has been set.
    public let feedRate: Double?

    public init(
        lineNumber: Int,
        mode: ParsedMoveMode,
        start: Vec3,
        end: Vec3,
        feedRate: Double?
    ) {
        self.lineNumber = lineNumber
        self.mode = mode
        self.start = start
        self.end = end
        self.feedRate = feedRate
    }
}

/// The program text plus the moves the validator derived from it.
///
/// Simulation consumes this value, never the emitter's toolpath (FR-065).
public struct ParsedProgram: Sendable, Equatable {
    public let text: String
    public let moves: [ParsedMove]

    public init(text: String, moves: [ParsedMove]) {
        self.text = text
        self.moves = moves
    }

    /// The program's lines, in order, including comment and blank lines.
    public var lines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

/// How a finding affects generation.
public enum FindingSeverity: String, Sendable, Equatable, Codable {
    /// Writing is blocked while any error exists (FR-026).
    case error

    /// Reported to the user but does not block writing.
    case warning
}

/// One conformance problem, with the line and rule that produced it.
public struct Finding: Sendable, Equatable {
    public let severity: FindingSeverity

    /// The one-based line number, or zero for a program-level finding.
    public let lineNumber: Int

    /// A stable rule identifier such as `line-length` or `feed-on-rapid`.
    public let ruleIdentifier: String

    public let message: String

    public init(
        severity: FindingSeverity,
        lineNumber: Int,
        ruleIdentifier: String,
        message: String
    ) {
        self.severity = severity
        self.lineNumber = lineNumber
        self.ruleIdentifier = ruleIdentifier
        self.message = message
    }
}

/// The validator's result: every finding at once, plus the program that was checked.
public struct ValidationReport: Sendable, Equatable {
    public let findings: [Finding]

    /// The validated text and its parsed moves, handed to simulation unchanged.
    public let program: ParsedProgram

    /// Ties this report to the matching structured log record (FR-067).
    public let correlationID: CorrelationID

    public init(
        findings: [Finding],
        program: ParsedProgram,
        correlationID: CorrelationID = CorrelationID(UUID().uuidString)
    ) {
        self.findings = findings
        self.program = program
        self.correlationID = correlationID
    }

    /// Whether writing is blocked by this report.
    public var hasErrors: Bool {
        findings.contains { $0.severity == .error }
    }
}

/// The validation stage boundary.
///
/// Implemented as an independent parser over program text; it never imports the emitter
/// (research D7, C2). Conformance problems are findings, not thrown errors, so the UI can list
/// them all at once.
public protocol ProgramValidating: Sendable {
    func validate(_ text: String, profile: MachineProfile) -> ValidationReport
}
