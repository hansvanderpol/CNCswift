import Foundation

/// A three-component vector used for model points and directions.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct Vec3: Equatable, Sendable, Hashable {
    /// The component along the X axis.
    public var x: Double
    /// The component along the Y axis.
    public var y: Double
    /// The component along the Z axis.
    public var z: Double

    /// Creates a vector from its X, Y, and Z components.
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Returns the component-wise difference of two vectors.
    public static func - (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    /// Returns the component-wise sum of two vectors.
    public static func + (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    /// Returns the dot product of this vector and `other`.
    public func dot(_ other: Vec3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    /// Returns the cross product of this vector and `other`.
    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
}
