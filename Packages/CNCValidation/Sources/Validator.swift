import CNCMachineProfile
import Foundation

/// Independent validator composing parser and rules. Full implementation is T061/T060 integration.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct GRBLValidator: ProgramValidating, Sendable {
    /// Creates a validator with no stored state.
    public init() {}

    /// Parses and validates program text, combining line-level and semantic findings.
    ///
    /// - Parameters:
    ///   - text: The exact program text to check.
    ///   - profile: The active machine profile.
    /// - Returns: A report with all findings and the parsed program.
    public func validate(_ text: String, profile: MachineProfile) -> ValidationReport {
        let parsed = GRBLParser().parse(text, profile: profile)
        let semantic = ValidationRules().evaluate(parsed.program, profile: profile)
        return ValidationReport(findings: parsed.findings + semantic, program: parsed.program)
    }
}
