import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import Foundation

/// Produces the ordered roughing and finishing moves for one job (T062–T064).
///
/// The planner is pure: it reads only the resolved values in `JobSettings`, the injected profile,
/// and progress/cancellation. Asset lookup and the full stock-reach gate belong to the pipeline,
/// which calls `Preflight.check` before this type is used.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct ToolpathPlanner: ToolpathPlanning, Sendable {
    /// Creates a planner with no stored state.
    public init() {}

    /// Plans one deterministic toolpath.
    ///
    /// - Parameters:
    ///   - job: The confirmed job with its resolved cutter value.
    ///   - profile: The machine profile supplying clearance height.
    ///   - progress: The sink used for cancellation and stage progress.
    /// - Throws: `PlanningError` for invalid inputs or `CancellationError` when cancelled.
    /// - Returns: Roughing passes followed by finishing raster passes at the effective feed.
    /// - Concurrency: `async`; cancellation is reported through `progress`.
    public func plan(
        _ job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> Toolpath {
        let report = try Preflight.checkPlanningInputs(
            job,
            cutter: job.cutter,
            profile: profile
        )
        _ = report

        try Task.checkCancellation()
        guard !progress.isCancelled() else { throw CancellationError() }

        let footprint = try Footprint.make(job: job, profile: profile)
        let roughing = try RoughingPlanner.moves(
            job: job,
            footprint: footprint,
            progress: progress
        )
        let finishing = try FinishingPlanner.moves(
            job: job,
            footprint: footprint,
            progress: progress
        )

        return Toolpath(
            moves: roughing + finishing,
            feedRate: job.effective.feed,
            bounds: footprint.bounds
        )
    }
}
