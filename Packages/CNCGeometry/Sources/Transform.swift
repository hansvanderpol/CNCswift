import Foundation

public struct Transform: Equatable, Sendable {
    private let translationX: Double
    private let translationY: Double
    private let maxZ: Double

    public init(modelBounds: AABB) {
        self.translationX = -modelBounds.min.x
        self.translationY = -modelBounds.min.y
        self.maxZ = modelBounds.max.z
    }

    public func apply(_ point: Vec3) -> Vec3 {
        Vec3(
            x: point.x + translationX,
            y: point.y + translationY,
            z: maxZ - point.z
        )
    }
}

public enum Geometry {
    public enum CutterGeometry: Sendable, Equatable {
        case flat(cuttingDiameter: Double)
        case ballNose(ballDiameter: Double)
        case vBit(tipDiameter: Double, includedAngle: Double)
    }

    public static func modelToMachineTransform(modelBounds: AABB) -> Transform {
        // Front-left-top origin: X0 Y0 at front-left, Z0 at the top surface.
        // Map model min X,Y to 0 and model max Z down to 0 at the top surface.
        Transform(modelBounds: modelBounds)
    }

    public static func effectiveRadius(_ cutter: CutterGeometry, stepover: Double) -> Double {
        switch cutter {
        case .flat(let cuttingDiameter):
            return cuttingDiameter / 2
        case .ballNose(let ballDiameter):
            let r = ballDiameter / 2
            let s = min(stepover, r)
            return (2 * r * s - s * s).squareRoot()
        case .vBit(let tipDiameter, let includedAngle):
            let halfAngleRadians = (includedAngle / 2) * .pi / 180
            return tipDiameter / 2 + stepover * tan(halfAngleRadians)
        }
    }
}
