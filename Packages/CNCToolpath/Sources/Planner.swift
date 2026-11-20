import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import Foundation

/// Produces the ordered roughing and finishing moves for one job.
///
/// The layered roughing, raster finishing, footprint restriction, and move sequencing are added by
/// tasks T062-T064. The type exists now so the test-first planner contract compiles and fails for
/// the missing behaviour rather than for a missing symbol.
public struct ToolpathPlanner: ToolpathPlanning, Sendable {
    public init() {}

    public func plan(
        _ job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> Toolpath {
        _ = (job, profile, progress)
        let origin = Vec3(x: 0, y: 0, z: 0)
        return Toolpath(
            moves: [],
            feedRate: 0,
            bounds: AABB(min: origin, max: origin)
        )
    }
}
