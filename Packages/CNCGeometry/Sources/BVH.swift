import Foundation

public struct BVH: Sendable {
    private let root: Node?

    private indirect enum Node: Sendable {
        case leaf(bounds: AABB, triangles: [Triangle])
        case branch(bounds: AABB, left: Node, right: Node)

        var bounds: AABB {
            switch self {
            case .leaf(let bounds, _): return bounds
            case .branch(let bounds, _, _): return bounds
            }
        }
    }

    public init(mesh: Mesh) {
        self.root = BVH.build(Array(mesh.triangles))
    }

    public func surfaceHeight(x: Double, y: Double) -> Double? {
        guard let root else { return nil }
        var highest: Double?
        BVH.query(node: root, x: x, y: y, highest: &highest)
        return highest
    }

    private static func build(_ triangles: [Triangle]) -> Node? {
        guard !triangles.isEmpty else { return nil }
        let bounds = triangles.dropFirst().reduce(triangles[0].bounds) { $0.union($1.bounds) }
        if triangles.count <= 4 {
            return .leaf(bounds: bounds, triangles: triangles)
        }

        let extentX = bounds.max.x - bounds.min.x
        let extentY = bounds.max.y - bounds.min.y
        let extentZ = bounds.max.z - bounds.min.z
        let axis: Int
        if extentX >= extentY && extentX >= extentZ {
            axis = 0
        } else if extentY >= extentZ {
            axis = 1
        } else {
            axis = 2
        }

        let sorted = triangles.sorted { centroid($0, axis: axis) < centroid($1, axis: axis) }
        let mid = sorted.count / 2
        let leftTris = Array(sorted[..<mid])
        let rightTris = Array(sorted[mid...])
        if leftTris.isEmpty || rightTris.isEmpty {
            return .leaf(bounds: bounds, triangles: sorted)
        }
        guard let left = build(leftTris), let right = build(rightTris) else {
            return .leaf(bounds: bounds, triangles: sorted)
        }
        return .branch(bounds: left.bounds.union(right.bounds), left: left, right: right)
    }

    private static func centroid(_ triangle: Triangle, axis: Int) -> Double {
        let c = (
            x: (triangle.a.x + triangle.b.x + triangle.c.x) / 3,
            y: (triangle.a.y + triangle.b.y + triangle.c.y) / 3,
            z: (triangle.a.z + triangle.b.z + triangle.c.z) / 3
        )
        switch axis {
        case 0: return c.x
        case 1: return c.y
        default: return c.z
        }
    }

    private static func query(node: Node, x: Double, y: Double, highest: inout Double?) {
        let bounds = node.bounds
        guard x >= bounds.min.x && x <= bounds.max.x && y >= bounds.min.y && y <= bounds.max.y else {
            return
        }
        if let current = highest, bounds.max.z <= current {
            return
        }
        switch node {
        case .leaf(_, let triangles):
            let origin = Vec3(x: x, y: y, z: 1_000_000)
            let direction = Vec3(x: 0, y: 0, z: -1)
            for tri in triangles {
                if let z = rayHitZ(origin: origin, direction: direction, tri: tri) {
                    if let current = highest {
                        if z > current { highest = z }
                    } else {
                        highest = z
                    }
                }
            }
        case .branch(_, let left, let right):
            // Visit higher-Z child first for potential pruning, but we must be correct.
            let leftMax = left.bounds.max.z
            let rightMax = right.bounds.max.z
            if leftMax >= rightMax {
                query(node: left, x: x, y: y, highest: &highest)
                query(node: right, x: x, y: y, highest: &highest)
            } else {
                query(node: right, x: x, y: y, highest: &highest)
                query(node: left, x: x, y: y, highest: &highest)
            }
        }
    }

    private static func rayHitZ(origin: Vec3, direction: Vec3, tri: Triangle) -> Double? {
        let edge1 = tri.b - tri.a
        let edge2 = tri.c - tri.a
        let h = direction.cross(edge2)
        let determinant = edge1.dot(h)
        guard abs(determinant) > 1e-12 else { return nil }
        let f = 1 / determinant
        let s = origin - tri.a
        let u = f * s.dot(h)
        guard u >= 0, u <= 1 else { return nil }
        let q = s.cross(edge1)
        let v = f * direction.dot(q)
        guard v >= 0, u + v <= 1 else { return nil }
        let t = f * edge2.dot(q)
        guard t > 0 else { return nil }
        return origin.z + t * direction.z
    }
}
