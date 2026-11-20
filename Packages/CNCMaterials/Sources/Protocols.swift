import CNCCutters
import CNCMachineProfile

/// The single seam through which feed and spindle values are resolved (FR-079, FR-080).
///
/// Pure and synchronous: the same material, cutter, and profile always produce the same outcome,
/// and no planner or view can bypass it.
///
/// - Concurrency: Conformers are `Sendable` and may be shared across concurrency boundaries.
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
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct MaterialResolver: MaterialResolving {
    /// Creates the default resolver.
    public init() {}

    /// Delegates to `EffectiveCuttingValues.resolve` with the supplied inputs.
    ///
    /// - Returns: Resolved cutting values or the conflicting bands.
    public func resolve(
        material: Material,
        cutter: Cutter,
        profile: MachineProfile
    ) -> ResolutionOutcome {
        EffectiveCuttingValues.resolve(material: material, cutter: cutter, profile: profile)
    }
}
