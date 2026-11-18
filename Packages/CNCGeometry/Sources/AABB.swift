public struct AABB: Equatable, Sendable {
    public var min: Vec3
    public var max: Vec3

    public init(min: Vec3, max: Vec3) {
        self.min = min
        self.max = max
    }

    public func contains(_ point: Vec3) -> Bool {
        point.x >= min.x && point.x <= max.x
            && point.y >= min.y && point.y <= max.y
            && point.z >= min.z && point.z <= max.z
    }

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
