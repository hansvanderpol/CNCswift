import CNCCutters
import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

/// Inputs shared by the planner, preflight, and feature-size tests.
///
/// Values mirror the shipped cutter fixture and the Hardwood preset so the assertions use
/// contract-sourced numbers. No test reads the real clock, filesystem, or machine.
enum ToolpathFixture {
    static let profile = TTC450Pro.profile
    static let cutterID = CutterID("8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10")

    static let cutter = Cutter(
        id: cutterID,
        name: "6mm flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )

    static let material = Presets.all[1]

    static let modelBounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 200, y: 150, z: 30)
    )

    static let stock = StockBlank(width: 200, depth: 150, height: 30)

    static func effective(
        feed: Double = 600,
        spindle: Double = 8000
    ) throws -> EffectiveCuttingValues {
        try EffectiveCuttingValues(
            feed: feed,
            spindle: spindle,
            source: .userChoice,
            material: material,
            profile: profile
        ).confirming()
    }

    static func ballNoseCutter() -> Cutter {
        Cutter(
            id: CutterID("ball-nose-1"),
            name: "6mm ball nose",
            type: .ballNose,
            shankDiameter: 6,
            cuttingLength: 20,
            fluteCount: 2,
            feedRate: 750,
            spindleSpeed: 8000,
            cuttingDiameter: nil,
            ballDiameter: 6,
            includedAngle: nil,
            tipDiameter: nil
        )
    }

    static func vBitCutter() -> Cutter {
        Cutter(
            id: CutterID("v-bit-1"),
            name: "60 degree V-bit",
            type: .vBit,
            shankDiameter: 8,
            cuttingLength: 5,
            fluteCount: 2,
            feedRate: 600,
            spindleSpeed: 8000,
            cuttingDiameter: nil,
            ballDiameter: nil,
            includedAngle: 60,
            tipDiameter: 2
        )
    }

    /// A flat top surface spanning the full model bounds.
    static func flatTopMesh(bounds: AABB = modelBounds) -> Mesh {
        let z = bounds.max.z
        let a = Vec3(x: bounds.min.x, y: bounds.min.y, z: z)
        let b = Vec3(x: bounds.max.x, y: bounds.min.y, z: z)
        let c = Vec3(x: bounds.min.x, y: bounds.max.y, z: z)
        let d = Vec3(x: bounds.max.x, y: bounds.max.y, z: z)
        return Mesh(triangles: [Triangle(a: a, b: b, c: c), Triangle(a: b, b: d, c: c)])
    }

    /// A top surface with a narrow slot; its width is `2 * radius` millimetres.
    static func notchedMesh(radius: Double) -> Mesh {
        let z = modelBounds.max.z
        let middle = modelBounds.max.x / 2
        let farY = modelBounds.max.y
        return Mesh(triangles: [
            Triangle(
                a: Vec3(x: 0, y: 0, z: z),
                b: Vec3(x: middle - radius, y: 0, z: z),
                c: Vec3(x: 0, y: farY, z: z)
            ),
            Triangle(
                a: Vec3(x: middle - radius, y: 0, z: z),
                b: Vec3(x: middle + radius, y: 0, z: z),
                c: Vec3(x: middle - radius, y: farY, z: z)
            ),
            Triangle(
                a: Vec3(x: middle + radius, y: 0, z: z),
                b: Vec3(x: modelBounds.max.x, y: 0, z: z),
                c: Vec3(x: modelBounds.max.x, y: farY, z: z)
            ),
        ])
    }

    static func job(
        mesh: Mesh? = nil,
        modelBounds bounds: AABB = ToolpathFixture.modelBounds,
        stock: StockBlank = ToolpathFixture.stock,
        cutterID: CutterID = cutterID,
        stepover: Double = 2.4,
        maxDepthPerPass: Double = 2,
        finishingAllowance: Double = 0.5,
        unitsConfirmed: Bool = true,
        orientationConfirmed: Bool = true,
        rapidRateConfirmed: Bool = true,
        confirmed: Bool = true,
        effective: EffectiveCuttingValues? = nil
    ) throws -> JobSettings {
        JobSettings(
            mesh: mesh ?? flatTopMesh(bounds: bounds),
            modelBounds: bounds,
            stock: stock,
            cutterID: cutterID,
            materialID: material.id,
            effective: try effective ?? effectiveValues(),
            stepover: stepover,
            maxDepthPerPass: maxDepthPerPass,
            finishingAllowance: finishingAllowance,
            unitsConfirmed: unitsConfirmed,
            orientationConfirmed: orientationConfirmed,
            rapidRateConfirmed: rapidRateConfirmed,
            confirmed: confirmed
        )
    }

    private static func effectiveValues() throws -> EffectiveCuttingValues {
        try EffectiveCuttingValues(
            feed: 600,
            spindle: 8000,
            source: .userChoice,
            material: material,
            profile: profile
        ).confirming()
    }

    static func progressSink() -> ProgressSink {
        ProgressSink(report: { _ in }, isCancelled: { false })
    }
}
