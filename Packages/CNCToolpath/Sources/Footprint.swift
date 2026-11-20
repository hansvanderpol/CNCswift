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

        // The model is placed one cutter radius inside the stock's front-left corner, then the
        // cutter centre sweeps the silhouette outward by exactly one radius (FR-009, FR-038). The
        // lower edge therefore lands on X0/Y0 and the upper edge sits one radius past the model;
        // no clipping or rescaling is applied. Preflight rejects a stock too small to hold the full
        // margin, so every emitted centre is committable by construction (FR-011, FR-025).
        let placement = radius
        let minX = min(lowerLeft.x, upperRight.x) + placement - radius
        let minY = min(lowerLeft.y, upperRight.y) + placement - radius
        let maxX = max(lowerLeft.x, upperRight.x) + placement + radius
        let maxY = max(lowerLeft.y, upperRight.y) + placement + radius

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
