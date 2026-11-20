import CNCCutters
import CNCGeometry
import CNCMachineProfile
import Foundation

/// Checks a job's preconditions before any move is planned (FR-010, FR-011, FR-033–FR-041).
///
/// `check` is the full gate used by the pipeline, including cutter reach. `checkPlanningInputs`
/// omits only the reach check because toolpath geometry is deliberately independent of how the
/// operator chose to hold a short cutter; the pipeline still refuses a short cutter before it ever
/// calls the planner.
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
        try evaluate(job, cutter: cutter, profile: profile, enforceCutterReach: true)
    }

    /// Validates the inputs that determine toolpath geometry, without the stock-reach check.
    static func checkPlanningInputs(
        _ job: JobSettings,
        cutter: Cutter,
        profile: MachineProfile
    ) throws -> FeatureReport {
        try evaluate(job, cutter: cutter, profile: profile, enforceCutterReach: false)
    }

    private static func evaluate(
        _ job: JobSettings,
        cutter: Cutter,
        profile: MachineProfile,
        enforceCutterReach: Bool
    ) throws -> FeatureReport {
        let epsilon = 1e-9

        guard job.unitsConfirmed, job.orientationConfirmed else {
            throw PlanningError.unconfirmedModel
        }
        guard job.effective.confirmed else {
            throw PlanningError.unconfirmedEffectiveValues
        }
        guard job.rapidRateConfirmed else {
            throw PlanningError.rapidSetupUnconfirmed
        }
        guard job.confirmed else {
            throw PlanningError.unconfirmedSettings
        }

        let stock = job.stock
        guard stock.width > 0, stock.depth > 0, stock.height > 0 else {
            throw PlanningError.invalidStock("dimension")
        }
        guard stock.width <= profile.envelope.x + epsilon,
            stock.depth <= profile.envelope.y + epsilon,
            stock.height <= profile.envelope.z + epsilon
        else {
            throw PlanningError.envelopeExceeded
        }

        let bounds = job.modelBounds
        let modelWidth = bounds.max.x - bounds.min.x
        let modelDepth = bounds.max.y - bounds.min.y
        let modelHeight = bounds.max.z - bounds.min.z
        guard bounds.min.x >= -epsilon, bounds.min.y >= -epsilon, bounds.min.z >= -epsilon,
            modelWidth <= stock.width + epsilon,
            modelDepth <= stock.depth + epsilon,
            modelHeight <= stock.height + epsilon
        else {
            throw PlanningError.modelOutsideStock
        }

        let extent = try CutterGeometrySupport.extent(of: cutter)
        let radius = extent / 2
        guard modelWidth + 2 * radius <= stock.width + epsilon,
            modelDepth + 2 * radius <= stock.depth + epsilon,
            modelWidth + 2 * radius <= profile.envelope.x + epsilon,
            modelDepth + 2 * radius <= profile.envelope.y + epsilon
        else {
            throw PlanningError.insufficientCutterMargin(required: radius)
        }

        guard job.maxDepthPerPass > 0, job.maxDepthPerPass <= cutter.cuttingLength + epsilon else {
            throw PlanningError.depthExceedsCuttingLength
        }
        guard job.stepover > 0, job.stepover < extent - epsilon else {
            throw PlanningError.invalidStepover
        }
        guard job.finishingAllowance >= -epsilon, job.finishingAllowance < stock.height - epsilon
        else {
            throw PlanningError.invalidAllowance
        }

        let effectiveRadius = Geometry.effectiveRadius(
            try CutterGeometrySupport.geometry(of: cutter),
            stepover: job.stepover
        )
        let smallestConcaveRadius = CutterGeometrySupport.smallestConcaveRadius(in: job.mesh)
        let report = FeatureReport(
            smallestConcaveRadius: smallestConcaveRadius,
            effectiveRadius: effectiveRadius
        )
        guard report.isAchievable else {
            throw PlanningError.featureTooSmall(
                smallestConcaveRadius: smallestConcaveRadius,
                effectiveRadius: effectiveRadius
            )
        }

        if enforceCutterReach, cutter.cuttingLength + epsilon < stock.height {
            throw PlanningError.cutterTooShort(requiredCuttingLength: stock.height)
        }

        return report
    }
}
