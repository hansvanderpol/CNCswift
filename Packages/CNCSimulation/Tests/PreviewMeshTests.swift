import CNCGeometry
import CNCSimulation
import Testing

/// Deterministic heightmap-to-mesh conversion for the RealityKit preview (FR-061).
///
/// These tests define the contract T097 must satisfy: `PreviewMesh(heightmap:)` is a pure value
/// type carrying positions, computed normals, and triangle indices. `CNCSimulation` stays free of
/// SwiftUI and RealityKit (BoundaryTests), so the UI turns this value into a `MeshResource`.
private func flatHeightmap() -> Heightmap {
    Heightmap(
        columns: 3,
        rows: 2,
        resolution: 1,
        origin: Vec3(x: 0, y: 0, z: 0),
        values: [0, 0, 0, 0, 0, 0]
    )
}

private func slopedHeightmap() -> Heightmap {
    Heightmap(
        columns: 3,
        rows: 2,
        resolution: 1,
        origin: Vec3(x: 0, y: 0, z: 0),
        values: [0, -1, -2, -3, -4, -5]
    )
}

@Test func previewMeshIsDeterministicForAKnownHeightmap() {
    let first = PreviewMesh(heightmap: slopedHeightmap())
    let second = PreviewMesh(heightmap: slopedHeightmap())

    #expect(first == second, "the same heightmap must always produce the same mesh")
    #expect(first != PreviewMesh(heightmap: flatHeightmap()))
}

@Test func previewMeshHasValidPositionsNormalsAndIndices() {
    let heightmap = slopedHeightmap()
    let mesh = PreviewMesh(heightmap: heightmap)

    #expect(
        mesh.vertices.count >= heightmap.values.count,
        "a 3 x 2 heightmap needs at least six vertices"
    )
    #expect(mesh.normals.count == mesh.vertices.count)
    #expect(!mesh.indices.isEmpty)
    #expect(mesh.indices.count % 3 == 0, "indices must describe whole triangles")
    #expect(
        mesh.indices.allSatisfy { Int($0) >= 0 && Int($0) < mesh.vertices.count },
        "every index must reference a real vertex"
    )
    #expect(
        mesh.normals.allSatisfy { normal in
            let length = (normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
                .squareRoot()
            return abs(length - 1) < 1e-3
        },
        "computed normals must be unit length"
    )
}

@Test func aFlatHeightmapHasUpwardNormalsAndOneSurfaceLevel() {
    let mesh = PreviewMesh(heightmap: flatHeightmap())

    #expect(Set(mesh.vertices.map(\.z)).count == 1, "a flat stock must have one surface level")
    #expect(
        mesh.normals.allSatisfy { $0.z > 0.99 },
        "an untouched surface must face up"
    )
}
