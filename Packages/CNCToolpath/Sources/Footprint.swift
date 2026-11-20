import CNCCutters
import CNCGeometry
import CNCMachineProfile
import Foundation

/// The machine-space area a cutter must sweep, expanded by exactly one cutter radius (D6).
struct Footprint: Sendable, Equatable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    let floorZ: Double
    let clearanceZ: Double

    static func make(
        job: JobSettings,
        profile: MachineProfile
    ) throws -> Footprint {
        let radius = try CutterGeometrySupport.extent(of: job.cutter) / 2
        let transform = Geometry.modelToMachineTransform(modelBounds: job.modelBounds)
        let lowerLeft = transform.apply(job.modelBounds.min)
        let upperRight = transform.apply(job.modelBounds.max)

        // The cutter centre sweeps the model silhouette outward by exactly one radius (FR-038).
        // A model placed at the front-left corner expands past X0/Y0 and a model flush with the far
        // edge expands past the blank, so clip the margin to the stock and the machine envelope.
        // Every emitted centre then stays committable; the origin and stock remain authoritative
        // and no model coordinate is silently rescaled (research D6).
        let limitX = min(job.stock.width, profile.envelope.x)
        let limitY = min(job.stock.depth, profile.envelope.y)
        let minX = max(0, min(lowerLeft.x, upperRight.x) - radius)
        let minY = max(0, min(lowerLeft.y, upperRight.y) - radius)
        let maxX = min(limitX, max(lowerLeft.x, upperRight.x) + radius)
        let maxY = min(limitY, max(lowerLeft.y, upperRight.y) + radius)

        return Footprint(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            floorZ: -job.stock.height,
            clearanceZ: profile.clearanceZ
        )
    }

    var bounds: AABB {
        AABB(
            min: Vec3(x: minX, y: minY, z: floorZ),
            max: Vec3(x: maxX, y: maxY, z: clearanceZ)
        )
    }

    func rows(stepover: Double) -> [Double] {
        guard stepover > 0 else { return [] }
        var result: [Double] = []
        var y = minY
        let epsilon = 1e-9
        while y <= maxY + epsilon {
            result.append(min(y, maxY))
            y += stepover
        }
        if result.last != maxY {
            result.append(maxY)
        }
        return result
    }
}
