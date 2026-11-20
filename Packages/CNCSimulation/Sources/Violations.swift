import CNCMachineProfile
import CNCToolpath
import CNCValidation
import Foundation

/// Collects named envelope and limit problems from a validated program (FR-064, FR-065).
///
/// The simulator re-checks the parsed moves it is about to preview so the user sees every named
/// violation before the write gate, with the offending line and the same numbers the validator
/// uses. A stage package deliberately has no dependency on `CNCPipeline`: the write-side refusal
/// lives there, while this collector only names and measures.
public struct SimulationViolations: Sendable {
    public init() {}

    public func collect(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile
    ) -> [SimulationViolation] {
        _ = job
        var violations: [SimulationViolation] = []
        let envelope = profile.envelope
        let epsilon = 1e-9

        for move in program.moves {
            for point in [move.start, move.end] {
                let outside =
                    point.x < -epsilon || point.x > envelope.x + epsilon || point.y < -epsilon
                    || point.y > envelope.y + epsilon || point.z < -envelope.z - epsilon
                    || point.z > envelope.z + epsilon
                guard outside else { continue }
                violations.append(
                    SimulationViolation(
                        kind: "envelope",
                        message:
                            "Move leaves the \(Int(envelope.x)) x \(Int(envelope.y)) x \(Int(envelope.z)) mm envelope.",
                        lineNumber: move.lineNumber
                    )
                )
                break
            }

            guard move.mode == .cut, let feed = move.feedRate else { continue }
            let ceiling = profile.limits.maxFeedRate
            guard feed > ceiling else { continue }
            violations.append(
                SimulationViolation(
                    kind: "feed-ceiling",
                    message:
                        "Cutting feed \(Self.format(feed)) exceeds the \(Int(ceiling)) mm/min ceiling.",
                    lineNumber: move.lineNumber
                )
            )
        }

        return violations
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
