import CNCDiagnostics
import CNCGeometry
import Foundation

/// Layered roughing clears the stock down to the finishing allowance (T062, D6).
enum RoughingPlanner {
    static func depths(job: JobSettings) -> [Double] {
        let total = job.stock.height - job.finishingAllowance
        guard total > 0, job.maxDepthPerPass > 0 else { return [] }
        let layerCount = Int((total / job.maxDepthPerPass).rounded(.up))
        return (1...layerCount).map { index in
            -min(Double(index) * job.maxDepthPerPass, total)
        }
    }

    static func moves(
        job: JobSettings,
        footprint: Footprint,
        progress: ProgressSink
    ) throws -> [Move] {
        let rows = footprint.rows(stepover: job.stepover)
        let layers = depths(job: job)
        var sequencer = MoveSequencer(
            start: Vec3(x: 0, y: 0, z: footprint.clearanceZ),
            clearanceZ: footprint.clearanceZ
        )
        let total = max(1, layers.count * rows.count)
        var completed = 0

        for depth in layers {
            for row in rows {
                try checkCancellation(progress)
                sequencer.addPass(
                    y: row,
                    from: footprint.minX,
                    to: footprint.maxX,
                    depth: depth
                )
                completed += 1
                progress.report(StageProgress(completed: completed, total: total))
            }
        }

        return sequencer.finish()
    }

    private static func checkCancellation(_ progress: ProgressSink) throws {
        try Task.checkCancellation()
        guard !progress.isCancelled() else { throw CancellationError() }
    }
}
