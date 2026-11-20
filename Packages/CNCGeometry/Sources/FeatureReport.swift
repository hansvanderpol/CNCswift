/// The numeric result of the feature-size preflight (FR-041).
///
/// Both values are millimetres, so the UI can report a number instead of an adjective. Planning is
/// blocked when `smallestConcaveRadius < effectiveRadius`.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct FeatureReport: Sendable, Equatable {
    /// The smallest concave radius found in the model.
    public let smallestConcaveRadius: Double

    /// The cutter's effective radius at the finishing stepover, from `Geometry.effectiveRadius`.
    public let effectiveRadius: Double

    /// Creates a feature report from the measured radius and the cutter's effective radius.
    public init(smallestConcaveRadius: Double, effectiveRadius: Double) {
        self.smallestConcaveRadius = smallestConcaveRadius
        self.effectiveRadius = effectiveRadius
    }

    /// Whether the selected cutter can reproduce the model's smallest feature.
    public var isAchievable: Bool {
        smallestConcaveRadius >= effectiveRadius
    }
}
