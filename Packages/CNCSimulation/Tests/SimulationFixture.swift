import CNCCutters
import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import CNCValidation
import Foundation

/// Deterministic inputs shared by the US3 simulation tests (FR-061 – FR-066).
///
/// These tests define the contract T096 – T098 must satisfy. No test reads the real clock, the real
/// filesystem, or the machine. Stock-space Z0 is the untouched top of the stock, so a cut to Z=-d
/// lowers the affected heightmap cells to -d while rapids leave them at zero.
enum SimulationFixture {
    static let profile = TTC450Pro.profile

    static let cutter = Cutter(
        id: CutterID("8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10"),
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

    static let bounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 200, y: 150, z: 30)
    )

    static let stock = StockBlank(width: 200, depth: 150, height: 30)

    static func effective() throws -> EffectiveCuttingValues {
        try EffectiveCuttingValues(
            feed: 600,
            spindle: 8000,
            source: .userChoice,
            material: material,
            profile: profile
        ).confirming()
    }

    /// A confirmed job whose flat top surface matches `bounds`.
    static func job() throws -> JobSettings {
        let z = bounds.max.z
        let mesh = Mesh(triangles: [
            Triangle(
                a: Vec3(x: bounds.min.x, y: bounds.min.y, z: z),
                b: Vec3(x: bounds.max.x, y: bounds.min.y, z: z),
                c: Vec3(x: bounds.min.x, y: bounds.max.y, z: z)
            ),
            Triangle(
                a: Vec3(x: bounds.max.x, y: bounds.min.y, z: z),
                b: Vec3(x: bounds.max.x, y: bounds.max.y, z: z),
                c: Vec3(x: bounds.min.x, y: bounds.max.y, z: z)
            ),
        ])
        return JobSettings(
            mesh: mesh,
            modelBounds: bounds,
            stock: stock,
            cutter: cutter,
            materialID: material.id,
            effective: try effective(),
            stepover: 2.4,
            maxDepthPerPass: 2,
            finishingAllowance: 0.5,
            unitsConfirmed: true,
            orientationConfirmed: true,
            rapidRateConfirmed: true,
            confirmed: true
        )
    }

    static func progress(
        cancelled: Bool = false,
        report: @escaping @Sendable (StageProgress) -> Void = { _ in }
    ) -> ProgressSink {
        ProgressSink(report: report, isCancelled: { cancelled })
    }

    static func move(
        line: Int = 1,
        mode: ParsedMoveMode = .cut,
        from: Vec3,
        to: Vec3,
        feedRate: Double? = 600
    ) -> ParsedMove {
        ParsedMove(
            lineNumber: line,
            mode: mode,
            start: from,
            end: to,
            feedRate: feedRate
        )
    }

    /// Builds a validated program whose text reflects its moves, so a simulator cannot rely on a
    /// canned string instead of the parsed move list.
    static func program(_ moves: [ParsedMove]) -> ParsedProgram {
        let text = moves.map { move in
            let command = move.mode == .rapid ? "G0" : "G1"
            let feed = move.feedRate.map { String(format: " F%.3f", $0) } ?? ""
            return
                "\(command) X\(format(move.end.x)) Y\(format(move.end.y)) Z\(format(move.end.z))\(feed)"
        }.joined(separator: "\n")
        return ParsedProgram(text: text, moves: moves)
    }

    static func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url = url.deletingLastPathComponent()
        }
        return url
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
