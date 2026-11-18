import CNCMachineProfile
import Foundation

/// Semantic validation rules over parsed GRBL 1.1 programs. Full implementation is T061.
public struct ValidationRules: Sendable {
    public init() {}

    public func evaluate(_ program: ParsedProgram, profile: MachineProfile) -> [Finding] {
        []
    }
}
