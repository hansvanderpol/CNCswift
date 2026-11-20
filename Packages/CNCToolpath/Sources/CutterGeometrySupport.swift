import CNCCutters
import CNCGeometry
import Foundation

/// Resolves a stored cutter's required dimensions and derives conservative feature geometry.
///
/// This is the single place that maps the closed `CutterType` set to `Geometry.CutterGeometry`, so
/// a missing attribute blocks generation instead of being replaced by a default (FR-036, FR-049).
enum CutterGeometrySupport {
    static func extent(of cutter: Cutter) throws -> Double {
        let extent = cutter.maxCuttingExtent
        guard extent.isFinite, extent > 0 else {
            throw PlanningError.missingCutterAttribute(requiredAttributeName(cutter))
        }
        return extent
    }

    static func geometry(of cutter: Cutter) throws -> Geometry.CutterGeometry {
        switch cutter.type {
        case .flat:
            guard let diameter = cutter.cuttingDiameter, diameter.isFinite, diameter > 0 else {
                throw PlanningError.missingCutterAttribute("cuttingDiameter")
            }
            return .flat(cuttingDiameter: diameter)
        case .ballNose:
            guard let diameter = cutter.ballDiameter, diameter.isFinite, diameter > 0 else {
                throw PlanningError.missingCutterAttribute("ballDiameter")
            }
            return .ballNose(ballDiameter: diameter)
        case .vBit:
            guard let tip = cutter.tipDiameter, tip.isFinite, tip > 0 else {
                throw PlanningError.missingCutterAttribute("tipDiameter")
            }
            guard let angle = cutter.includedAngle, angle.isFinite, angle > 0 else {
                throw PlanningError.missingCutterAttribute("includedAngle")
            }
            return .vBit(tipDiameter: tip, includedAngle: angle)
        }
    }

    /// A conservative smallest-concave-radius proxy derived from the mesh itself.
    ///
    /// The shortest exposed boundary edge of the top surface bounds the smallest feature the
    /// cutter can enter. Half that length is reported so a one-millimetre slot yields a 0.5 mm
    /// radius without ever hard-coding a fixture value. A closed surface has no exposed top edge
    /// and is treated as unbounded.
    static func smallestConcaveRadius(in mesh: Mesh) -> Double {
        guard let topZ = mesh.triangles.map(\.a.z).max() else {
            return .infinity
        }
        let highest = mesh.triangles.filter { triangle in
            triangle.a.z == topZ && triangle.b.z == topZ && triangle.c.z == topZ
        }
        guard !highest.isEmpty
        else {
            return .infinity
        }

        var edgeCounts: [SegmentKey: Int] = [:]
        var edges: [SegmentKey: Double] = [:]
        for triangle in highest {
            for edge in [triangle.a, triangle.b, triangle.c].enumerated() {
                let next = [triangle.a, triangle.b, triangle.c][(edge.offset + 1) % 3]
                let key = SegmentKey(edge.element, next)
                edgeCounts[key, default: 0] += 1
                edges[key] = distance(edge.element, next)
            }
        }

        let boundaryLengths = edges.compactMap { key, length -> Double? in
            edgeCounts[key] == 1 ? length : nil
        }
        guard let shortest = boundaryLengths.min(), shortest.isFinite, shortest > 0 else {
            return .infinity
        }
        return shortest / 2
    }

    private static func requiredAttributeName(_ cutter: Cutter) -> String {
        switch cutter.type {
        case .flat: return "cuttingDiameter"
        case .ballNose: return "ballDiameter"
        case .vBit: return "tipDiameter"
        }
    }

    private static func distance(_ lhs: Vec3, _ rhs: Vec3) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private struct SegmentKey: Hashable {
        let first: PointKey
        let second: PointKey

        init(_ lhs: Vec3, _ rhs: Vec3) {
            let a = PointKey(lhs)
            let b = PointKey(rhs)
            if a <= b {
                first = a
                second = b
            } else {
                first = b
                second = a
            }
        }
    }

    private struct PointKey: Hashable, Comparable {
        let x: Int64
        let y: Int64
        let z: Int64

        init(_ point: Vec3) {
            x = Int64((point.x * 1_000_000).rounded())
            y = Int64((point.y * 1_000_000).rounded())
            z = Int64((point.z * 1_000_000).rounded())
        }

        static func < (lhs: PointKey, rhs: PointKey) -> Bool {
            if lhs.x != rhs.x { return lhs.x < rhs.x }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.z < rhs.z
        }
    }
}
