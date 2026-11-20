/// A triangle defined by three corner points.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct Triangle: Equatable, Sendable {
    /// The first corner of the triangle.
    public let a: Vec3
    /// The second corner of the triangle.
    public let b: Vec3
    /// The third corner of the triangle.
    public let c: Vec3

    /// Creates a triangle from its three corners.
    public init(a: Vec3, b: Vec3, c: Vec3) {
        self.a = a
        self.b = b
        self.c = c
    }

    /// The axis-aligned bounding box enclosing all three corners.
    public var bounds: AABB {
        var box = AABB(min: a, max: a)
        box = box.expandedToInclude(b)
        box = box.expandedToInclude(c)
        return box
    }
}

/// A triangle mesh used for surface queries.
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public struct Mesh: Equatable, Sendable {
    /// The triangles that make up the mesh.
    public let triangles: [Triangle]

    /// Creates a mesh from a list of triangles.
    public init(triangles: [Triangle]) {
        self.triangles = triangles
    }

    /// The number of triangles in the mesh.
    public var triangleCount: Int { triangles.count }

    /// The mesh's combined bounding box, or `nil` when the mesh has no triangles.
    public var bounds: AABB? {
        guard let first = triangles.first else { return nil }
        var box = first.bounds
        for tri in triangles.dropFirst() {
            box = box.union(tri.bounds)
        }
        return box
    }
}
