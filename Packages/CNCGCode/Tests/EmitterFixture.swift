import CNCCutters
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

/// Inputs shared by the emitter tests.
///
/// The values mirror the example in `specs/001-stl-to-gcode/contracts/gcode-output.md` so the
/// golden text is contract-sourced rather than invented. The material name and model filename come
/// from the shipped preset table and the reference fixture set, and the contract example spells the
/// material name in lower case only as an illustration.
///
/// `GCodeEmitter` is the concrete `GCodeRendering` implementation that task T057 adds; these tests
/// are written first and are expected to fail until it exists.
enum EmitterFixture {
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

    /// The shipped Hardwood preset: feed band 400-600 mm/min, spindle band 7000-8000 RPM.
    static let material = Presets.all[1]

    static let modelBounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 200, y: 150, z: 30)
    )

    static let stock = StockBlank(width: 200, depth: 150, height: 30)

    static func effectiveValues() throws -> EffectiveCuttingValues {
        try EffectiveCuttingValues(
            feed: 600,
            spindle: 8000,
            source: .userChoice,
            material: material,
            profile: TTC450Pro.profile
        )
    }

    static func job() throws -> JobSettings {
        JobSettings(
            mesh: Mesh(triangles: [
                Triangle(
                    a: Vec3(x: 0, y: 0, z: 30),
                    b: Vec3(x: 200, y: 0, z: 30),
                    c: Vec3(x: 0, y: 150, z: 30)
                )
            ]),
            modelBounds: modelBounds,
            stock: stock,
            cutterID: cutterID,
            materialID: material.id,
            effective: try effectiveValues(),
            stepover: 2.4,
            maxDepthPerPass: 2,
            finishingAllowance: 0.5,
            unitsConfirmed: true,
            orientationConfirmed: true,
            rapidRateConfirmed: true,
            confirmed: true
        )
    }

    /// One plunge, two raster cuts, a retract, a step-over rapid, a second plunge, one cut, and a
    /// final retract.
    ///
    /// Four rapid moves and five cutting moves, so the rapid and feed assertions have something to
    /// fail on. No rapid enters material: every retract is at clearance and the step-over stays at
    /// clearance before descending (FR-039).
    static let toolpath = Toolpath(
        moves: [
            Move(
                from: Vec3(x: 0, y: 0, z: 10),
                to: Vec3(x: 10, y: 10, z: 10),
                mode: .rapid
            ),
            Move(
                from: Vec3(x: 10, y: 10, z: 10),
                to: Vec3(x: 10, y: 10, z: -1),
                mode: .cut
            ),
            Move(
                from: Vec3(x: 10, y: 10, z: -1),
                to: Vec3(x: 12.4, y: 10, z: -1),
                mode: .cut
            ),
            Move(
                from: Vec3(x: 12.4, y: 10, z: -1),
                to: Vec3(x: 14.8, y: 10, z: -1.18),
                mode: .cut
            ),
            Move(
                from: Vec3(x: 14.8, y: 10, z: -1.18),
                to: Vec3(x: 14.8, y: 10, z: 10),
                mode: .rapid
            ),
            Move(
                from: Vec3(x: 14.8, y: 10, z: 10),
                to: Vec3(x: 14.8, y: 12.4, z: 10),
                mode: .rapid
            ),
            Move(
                from: Vec3(x: 14.8, y: 12.4, z: 10),
                to: Vec3(x: 14.8, y: 12.4, z: -1.42),
                mode: .cut
            ),
            Move(
                from: Vec3(x: 14.8, y: 12.4, z: -1.42),
                to: Vec3(x: 17.2, y: 12.4, z: -1.42),
                mode: .cut
            ),
            Move(
                from: Vec3(x: 17.2, y: 12.4, z: -1.42),
                to: Vec3(x: 17.2, y: 12.4, z: 10),
                mode: .rapid
            ),
        ],
        feedRate: 600,
        bounds: AABB(
            min: Vec3(x: 0, y: 0, z: -1.42),
            max: Vec3(x: 17.2, y: 12.4, z: 10)
        )
    )

    static let modelFileName = "relief-demo-binary.stl"

    static func date(_ iso8601: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: iso8601) else {
            preconditionFailure("Fixture date is not ISO-8601: \(iso8601)")
        }
        return date
    }

    static func render(generatedAt date: Date) throws -> RenderedProgram {
        try GCodeEmitter().render(
            toolpath,
            cutter: cutter,
            material: material,
            job: job(),
            profile: TTC450Pro.profile,
            generatedAt: date
        )
    }

    /// The emitted lines without the required trailing newline (FR-021).
    static func emittedLines(of text: String) -> [String] {
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        return lines
    }
}
