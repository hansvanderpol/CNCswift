import CNCCutters
import CNCGeometry
import CNCMachineProfile
import Foundation

/// Checks the job's preconditions before any move is planned.
///
/// The full rejection chain is added by task T065. The entry point exists now so the preflight and
/// feature-size tests compile and fail for the missing checks, not for a missing symbol.
public enum Preflight {
    /// Validates `job` against `cutter` and `profile` and reports the smallest feature.
    ///
    /// - Throws: A `PlanningError` naming the failed precondition.
    /// - Returns: A report whose radii are both in millimetres (FR-041).
    public static func check(
        _ job: JobSettings,
        cutter: Cutter,
        profile: MachineProfile
    ) throws -> FeatureReport {
        _ = (job, cutter, profile)
        return FeatureReport(smallestConcaveRadius: 1_000, effectiveRadius: 0)
    }
}
