import Foundation
import Testing

@testable import CNCGeometry

private func triangle(_ a: Vec3, _ b: Vec3, _ c: Vec3) -> Triangle {
    Triangle(a: a, b: b, c: c)
}

private func bruteForceHeight(_ mesh: Mesh, x: Double, y: Double) -> Double? {
    let origin = Vec3(x: x, y: y, z: 1_000)
    let direction = Vec3(x: 0, y: 0, z: -1)
    var highest: Double?

    for tri in mesh.triangles {
        let edge1 = tri.b - tri.a
        let edge2 = tri.c - tri.a
        let h = direction.cross(edge2)
        let determinant = edge1.dot(h)
        guard abs(determinant) > 1e-9 else { continue }
        let f = 1 / determinant
        let s = origin - tri.a
        let u = f * s.dot(h)
        guard u >= 0, u <= 1 else { continue }
        let q = s.cross(edge1)
        let v = f * direction.dot(q)
        guard v >= 0, u + v <= 1 else { continue }
        let t = f * edge2.dot(q)
        guard t > 0 else { continue }
        let z = origin.z + t * direction.z
        highest = max(highest ?? -.infinity, z)
    }
    return highest
}

@Test func meshInvariantsAreComputedFromTriangles() {
    let mesh = Mesh(triangles: [
        triangle(Vec3(x: 0, y: 0, z: 0), Vec3(x: 4, y: 0, z: 0), Vec3(x: 4, y: 3, z: 0))
    ])

    #expect(mesh.triangleCount == 1)
    #expect(mesh.bounds == AABB(min: Vec3(x: 0, y: 0, z: 0), max: Vec3(x: 4, y: 3, z: 0)))
    #expect(mesh.bounds?.contains(Vec3(x: 2, y: 1, z: 0)) == true)
    #expect(mesh.bounds?.contains(Vec3(x: 5, y: 1, z: 0)) == false)
}

@Test func frontLeftTopTransformMapsModelCornersOntoMachineOrigin() {
    let bounds = AABB(min: Vec3(x: -10, y: -20, z: 0), max: Vec3(x: 10, y: 20, z: 30))
    let transform = Geometry.modelToMachineTransform(modelBounds: bounds)

    #expect(transform.apply(Vec3(x: -10, y: -20, z: 0)) == Vec3(x: 0, y: 0, z: 30))
    #expect(transform.apply(Vec3(x: 10, y: 20, z: 30)) == Vec3(x: 20, y: 40, z: 0))
}

@Test func bvhHeightsMatchBruteForceRayCast() {
    let z5 = [
        Vec3(x: 0, y: 0, z: 5), Vec3(x: 10, y: 0, z: 5),
        Vec3(x: 10, y: 10, z: 5), Vec3(x: 0, y: 10, z: 5),
    ]
    let z9 = [
        Vec3(x: 4, y: 4, z: 9), Vec3(x: 6, y: 4, z: 9),
        Vec3(x: 6, y: 6, z: 9), Vec3(x: 4, y: 6, z: 9),
    ]
    let mesh = Mesh(triangles: [
        triangle(z5[0], z5[1], z5[2]), triangle(z5[0], z5[2], z5[3]),
        triangle(z9[0], z9[1], z9[2]), triangle(z9[0], z9[2], z9[3]),
    ])
    let bvh = BVH(mesh: mesh)

    for point in [(1.0, 1.0), (5.0, 5.0), (9.0, 8.0), (4.5, 5.5)] {
        let actual = bvh.surfaceHeight(x: point.0, y: point.1)
        let expected = bruteForceHeight(mesh, x: point.0, y: point.1)
        #expect(actual == expected, "height mismatch at \(point)")
    }
    #expect(bvh.surfaceHeight(x: 5, y: 5) == 9)
    #expect(bvh.surfaceHeight(x: 1, y: 1) == 5)
}

@Test func effectiveRadiusFollowsCutterGeometryFormulas() {
    #expect(
        Geometry.effectiveRadius(.flat(cuttingDiameter: 6), stepover: 2) == 3
    )

    let ball = Geometry.effectiveRadius(.ballNose(ballDiameter: 6), stepover: 2)
    #expect(abs(ball - sqrt(8)) < 1e-9)

    let clamped = Geometry.effectiveRadius(.ballNose(ballDiameter: 6), stepover: 10)
    #expect(abs(clamped - 3) < 1e-9)

    let vBit = Geometry.effectiveRadius(
        .vBit(tipDiameter: 1, includedAngle: 60),
        stepover: 1
    )
    #expect(abs(vBit - (0.5 + tan(30 * .pi / 180))) < 1e-9)
}
