import CNCDiagnostics
import CNCGeometry
import Foundation

/// Final raster finishing at the bottom of the stock (T063, D6).
enum FinishingPlanner {
    static func moves(
        job: JobSettings,
        footprint: Footprint,
        progress: ProgressSink
    ) throws -> [Move] {
        let rows = footprint.rows(stepover: job.stepover)
        var sequencer = MoveSequencer(
            start: Vec3(x: 0, y: 0, z: footprint.clearanceZ),
            clearanceZ: footprint.clearanceZ
        )

        for (index, row) in rows.enumerated() {
            try checkCancellation(progress)
            sequencer.addPass(
                y: row,
                from: footprint.minX,
                to: footprint.maxX,
                depth: footprint.floorZ
            )
            progress.report(StageProgress(completed: index + 1, total: max(1, rows.count)))
        }

        return sequencer.finish()
    }

    private static func checkCancellation(_ progress: ProgressSink) throws {
        try Task.checkCancellation()
        guard !progress.isCancelled() else { throw CancellationError() }
    }
}
