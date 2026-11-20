import Foundation

/// A model-to-machine coordinate transform with a front-left-top origin.
///
/// Model minimum X and Y map to zero; model maximum Z maps to machine Z0.
///
/// - Concurrency: `Sendable` value type; safe to share across tasks.
public struct Transform: Equatable, Sendable {
    private let translationX: Double
    private let translationY: Double
    private let maxZ: Double

    /// Creates a transform for the given model bounds.
    ///
    /// - Precondition: `modelBounds` must be well formed (minimum components not greater
    ///   than maximum components).
    public init(modelBounds: AABB) {
        self.translationX = -modelBounds.min.x
        self.translationY = -modelBounds.min.y
        self.maxZ = modelBounds.max.z
    }

    /// Maps a model-space point into machine space.
    public func apply(_ point: Vec3) -> Vec3 {
        Vec3(
            x: point.x + translationX,
            y: point.y + translationY,
            z: maxZ - point.z
        )
    }
}

/// Namespace for cutter-geometry helpers used by planning.
public enum Geometry {
    /// The cutter shapes supported by the geometry helpers.
    ///
    /// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
    public enum CutterGeometry: Sendable, Equatable {
        /// A flat end mill with the given cutting diameter in millimetres.
        case flat(cuttingDiameter: Double)
        /// A ball-nose cutter with the given ball diameter in millimetres.
        case ballNose(ballDiameter: Double)
        /// A V-bit with the given tip diameter and included angle in degrees.
        case vBit(tipDiameter: Double, includedAngle: Double)
    }

    /// Returns the transform placing the model's front-left-top corner at the machine origin.
    ///
    /// - Precondition: `modelBounds` must be well formed.
    public static func modelToMachineTransform(modelBounds: AABB) -> Transform {
        // Front-left-top origin: X0 Y0 at front-left, Z0 at the top surface.
        // Map model min X,Y to 0 and model max Z down to 0 at the top surface.
        Transform(modelBounds: modelBounds)
    }

    /// Returns the cutter's effective cutting radius at the given stepover.
    ///
    /// Flat cutters use half the cutting diameter; ball-nose cutters use the chord height
    /// for the stepover; V-bits add the stepover's radial growth to half the tip diameter.
    ///
    /// - Precondition: `stepover` is non-negative; `includedAngle` is in degrees.
    public static func effectiveRadius(_ cutter: CutterGeometry, stepover: Double) -> Double {
        switch cutter {
        case .flat(let cuttingDiameter):
            return cuttingDiameter / 2
        case .ballNose(let ballDiameter):
            let r = ballDiameter / 2
            let s = min(stepover, r)
            return (2 * r * s - s * s).squareRoot()
        case .vBit(let tipDiameter, let includedAngle):
            let halfAngleRadians = (includedAngle / 2) * .pi / 180
            return tipDiameter / 2 + stepover * tan(halfAngleRadians)
        }
    }
}
