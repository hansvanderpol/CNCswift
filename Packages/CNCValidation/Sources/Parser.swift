import CNCMachineProfile
import Foundation

/// Parses GRBL 1.1 program text into moves and line-level findings. Full implementation is T060.
public struct GRBLParser: Sendable {
    public init() {}

    public func parse(_ text: String, profile: MachineProfile) -> (program: ParsedProgram, findings: [Finding]) {
        (ParsedProgram(text: text, moves: []), [])
    }
}
