import CNCMachineProfile
import Foundation

/// Independent validator composing parser and rules. Full implementation is T061/T060 integration.
public struct GRBLValidator: ProgramValidating, Sendable {
    public init() {}

    public func validate(_ text: String, profile: MachineProfile) -> ValidationReport {
        let parsed = GRBLParser().parse(text, profile: profile)
        let semantic = ValidationRules().evaluate(parsed.program, profile: profile)
        return ValidationReport(findings: parsed.findings + semantic, program: parsed.program)
    }
}
