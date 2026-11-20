import CNCGeometry
import Foundation

/// Turns horizontal raster passes into continuous, ordered machine moves (D6).
///
/// Repositioning rapids stay at clearance height. Descending to and returning from a cut depth is
/// modelled as a cutting move, so no rapid ever enters the material.
struct MoveSequencer: Sendable {
    private var current: Vec3
    private let clearanceZ: Double
    private var moves: [Move] = []

    init(start: Vec3, clearanceZ: Double) {
        current = start
        self.clearanceZ = clearanceZ
    }

    mutating func addPass(y: Double, from startX: Double, to endX: Double, depth: Double) {
        repositionToClearance(x: startX, y: y)
        append(to: Vec3(x: startX, y: y, z: depth), mode: .cut)
        append(to: Vec3(x: endX, y: y, z: depth), mode: .cut)
        append(to: Vec3(x: endX, y: y, z: clearanceZ), mode: .cut)
    }

    mutating func finish() -> [Move] {
        moves
    }

    private mutating func repositionToClearance(x: Double, y: Double) {
        if current.z < clearanceZ {
            append(to: Vec3(x: current.x, y: current.y, z: clearanceZ), mode: .cut)
        }
        let target = Vec3(x: x, y: y, z: clearanceZ)
        guard target != current else { return }
        append(to: target, mode: .rapid)
    }

    private mutating func append(to target: Vec3, mode: MoveMode) {
        guard target != current else { return }
        moves.append(Move(from: current, to: target, mode: mode))
        current = target
    }
}
