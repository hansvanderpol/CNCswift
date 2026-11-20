/// An axis-aligned bounding box defined by its minimum and maximum corners.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct AABB: Equatable, Sendable {
    /// The corner with the smallest coordinate values.
    public var min: Vec3
    /// The corner with the largest coordinate values.
    public var max: Vec3

    /// Creates a box from its minimum and maximum corners.
    ///
    /// - Precondition: Each component of `min` must be less than or equal to the matching
    ///   component of `max` for the box to be well formed.
    public init(min: Vec3, max: Vec3) {
        self.min = min
        self.max = max
    }

    /// Returns whether `point` lies inside the box, including its faces.
    public func contains(_ point: Vec3) -> Bool {
        point.x >= min.x && point.x <= max.x
            && point.y >= min.y && point.y <= max.y
            && point.z >= min.z && point.z <= max.z
    }

    /// Returns the smallest box containing both this box and `other`.
    public func union(_ other: AABB) -> AABB {
        AABB(
            min: Vec3(
                x: Swift.min(min.x, other.min.x),
                y: Swift.min(min.y, other.min.y),
                z: Swift.min(min.z, other.min.z)
            ),
            max: Vec3(
                x: Swift.max(max.x, other.max.x),
                y: Swift.max(max.y, other.max.y),
                z: Swift.max(max.z, other.max.z)
            )
        )
    }

    /// Returns the smallest box containing this box and `point`.
    public func expandedToInclude(_ point: Vec3) -> AABB {
        AABB(
            min: Vec3(
                x: Swift.min(min.x, point.x),
                y: Swift.min(min.y, point.y),
                z: Swift.min(min.z, point.z)
            ),
            max: Vec3(
                x: Swift.max(max.x, point.x),
                y: Swift.max(max.y, point.y),
                z: Swift.max(max.z, point.z)
            )
        )
    }
}
