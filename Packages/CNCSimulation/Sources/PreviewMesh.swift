import CNCGeometry

/// A deterministic, framework-neutral triangle mesh derived from a heightmap (FR-061).
///
/// `CNCSimulation` never imports RealityKit: this value type carries positions, computed unit
/// normals, and triangle indices, and the presentation module turns it into a `MeshResource`.
/// Vertices are laid out row-major, one per heightmap sample, at
/// `origin + (column * resolution, row * resolution, height)`. Two triangles are emitted per grid
/// quad, wound counter-clockwise when viewed from above so the untouched surface faces up.
///
/// - Concurrency: Sendable value safe to pass across concurrency boundaries.
public struct PreviewMesh: Sendable, Equatable {
    /// Row-major mesh positions, one per heightmap sample, in stock space.
    public let vertices: [Vec3]
    /// Computed unit surface normals parallel to `vertices`.
    public let normals: [Vec3]
    /// Triangle indices, six per grid quad, wound counter-clockwise from above.
    public let indices: [UInt32]

    /// Builds a triangle mesh from the heightmap's samples.
    ///
    /// Missing heights are treated as zero and edge samples clamp to the nearest cell.
    public init(heightmap: Heightmap) {
        let columns = max(0, heightmap.columns)
        let rows = max(0, heightmap.rows)
        let spacing = heightmap.resolution

        var positions: [Vec3] = []
        positions.reserveCapacity(heightmap.values.count)
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let height = index < heightmap.values.count ? heightmap.values[index] : 0
                positions.append(
                    Vec3(
                        x: heightmap.origin.x + Double(column) * spacing,
                        y: heightmap.origin.y + Double(row) * spacing,
                        z: heightmap.origin.z + height
                    )
                )
            }
        }

        var surfaceNormals: [Vec3] = []
        surfaceNormals.reserveCapacity(positions.count)
        for row in 0..<rows {
            for column in 0..<columns {
                let left = Self.height(heightmap, column: column - 1, row: row)
                let right = Self.height(heightmap, column: column + 1, row: row)
                let below = Self.height(heightmap, column: column, row: row - 1)
                let above = Self.height(heightmap, column: column, row: row + 1)
                let slopeX = (right - left) / (2 * spacing)
                let slopeY = (above - below) / (2 * spacing)
                surfaceNormals.append(Self.normalized(Vec3(x: -slopeX, y: -slopeY, z: 1)))
            }
        }

        var triangles: [UInt32] = []
        triangles.reserveCapacity(max(0, columns - 1) * max(0, rows - 1) * 6)
        for row in 0..<max(0, rows - 1) {
            for column in 0..<max(0, columns - 1) {
                let lowerLeft = UInt32(row * columns + column)
                let lowerRight = lowerLeft + 1
                let upperLeft = UInt32((row + 1) * columns + column)
                let upperRight = upperLeft + 1
                triangles.append(contentsOf: [lowerLeft, lowerRight, upperLeft])
                triangles.append(contentsOf: [lowerRight, upperRight, upperLeft])
            }
        }

        vertices = positions
        normals = surfaceNormals
        indices = triangles
    }

    /// A one-sided sample at the grid edge avoids inventing material outside the stock.
    private static func height(
        _ heightmap: Heightmap,
        column: Int,
        row: Int
    ) -> Double {
        guard heightmap.columns > 0, heightmap.rows > 0 else { return 0 }
        guard column >= 0, column < heightmap.columns, row >= 0, row < heightmap.rows else {
            let clampedColumn = min(max(0, column), heightmap.columns - 1)
            let clampedRow = min(max(0, row), heightmap.rows - 1)
            return heightmap.height(column: clampedColumn, row: clampedRow) ?? 0
        }
        return heightmap.height(column: column, row: row) ?? 0
    }

    private static func normalized(_ vector: Vec3) -> Vec3 {
        let length = (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z).squareRoot()
        guard length > 0 else { return Vec3(x: 0, y: 0, z: 1) }
        return Vec3(x: vector.x / length, y: vector.y / length, z: vector.z / length)
    }
}
