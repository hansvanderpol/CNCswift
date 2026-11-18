public struct Triangle: Equatable, Sendable {
    public let a: Vec3
    public let b: Vec3
    public let c: Vec3

    public init(a: Vec3, b: Vec3, c: Vec3) {
        self.a = a
        self.b = b
        self.c = c
    }

    public var bounds: AABB {
        var box = AABB(min: a, max: a)
        box = box.expandedToInclude(b)
        box = box.expandedToInclude(c)
        return box
    }
}

public struct Mesh: Equatable, Sendable {
    public let triangles: [Triangle]

    public init(triangles: [Triangle]) {
        self.triangles = triangles
    }

    public var triangleCount: Int { triangles.count }

    public var bounds: AABB? {
        guard let first = triangles.first else { return nil }
        var box = first.bounds
        for tri in triangles.dropFirst() {
            box = box.union(tri.bounds)
        }
        return box
    }
}
