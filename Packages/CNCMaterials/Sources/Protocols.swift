import CNCCutters
import CNCMachineProfile

/// The single seam through which feed and spindle values are resolved (FR-079, FR-080).
///
/// Pure and synchronous: the same material, cutter, and profile always produce the same outcome,
/// and no planner or view can bypass it.
public protocol MaterialResolving: Sendable {
    /// Intersects the material bands with the profile limits and prefills from the cutter record.
    ///
    /// - Returns: `.resolved` with `confirmed == false`, or `.noOverlap` naming every band that
    ///   cannot be satisfied.
    func resolve(
        material: Material,
        cutter: Cutter,
        profile: MachineProfile
    ) -> ResolutionOutcome
}

/// The default resolver, delegating to `EffectiveCuttingValues.resolve`.
public struct MaterialResolver: MaterialResolving {
    public init() {}

    public func resolve(
        material: Material,
        cutter: Cutter,
        profile: MachineProfile
    ) -> ResolutionOutcome {
        EffectiveCuttingValues.resolve(material: material, cutter: cutter, profile: profile)
    }
}
