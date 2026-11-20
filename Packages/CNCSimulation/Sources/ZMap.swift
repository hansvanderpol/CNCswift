import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCToolpath
import CNCValidation
import Foundation

/// A cutter-sweep simulator over a stock-space height field (FR-061, FR-062, FR-063).
///
/// The heightmap is a row-major grid of surface heights in millimetres. Its origin is the stock's
/// front-left-top corner: Z0 is the untouched top surface, so removing material lowers a cell's
/// value below zero. `resolution` is the distance in millimetres between adjacent sample points on
/// both axes; it is recorded in the result because it determines preview fidelity. Each cell is
/// stamped with the cutter's maximum cutting extent (its diameter for a flat cutter), which is a
/// deliberately conservative footprint: the preview never shows more remaining material than the
/// real cutter could leave behind.
///
/// The simulator consumes the validator's `ParsedProgram` and ignores its text. Rapids are never
/// swept, so they cannot remove material (FR-063). Cancellation is an outcome, not an error
/// (FR-066): a stop on request returns a result with `cancelled` set, alongside whatever partial
/// heightmap was produced up to that point.
///
/// - Concurrency: Sendable value; `simulate` is async and cancellation-aware.
public struct ZMapSimulator: MaterialRemovalSimulating, Sendable {
    /// Stock-space millimetres per grid cell. Must be finite and greater than zero.
    public let resolution: Double

    /// Creates a simulator with the given stock-space grid spacing.
    ///
    /// - Precondition: `resolution` is finite and greater than zero; enforced by `precondition`.
    public init(resolution: Double) {
        precondition(resolution.isFinite && resolution > 0, "resolution must be a positive number")
        self.resolution = resolution
    }

    /// Sweeps cutting moves into a heightmap and reports stage progress.
    ///
    /// - Throws: No errors are raised locally; cancellation is reported in the result.
    /// - Concurrency: `async`; checks cancellation between moves and yields every 32 moves.
    public func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult {
        let columns = max(1, Int(job.stock.width / resolution))
        let rows = max(1, Int(job.stock.depth / resolution))
        var values = [Double](repeating: 0, count: columns * rows)
        let violations = SimulationViolations().collect(program, job: job, profile: profile)
        let rapids = rapidSegments(in: program)
        let total = max(1, program.moves.count)
        let radius = max(0, job.cutter.maxCuttingExtent / 2)

        progress.report(StageProgress(completed: 0, total: total))
        if isCancelled(progress) {
            return result(
                values: values,
                columns: columns,
                rows: rows,
                violations: violations,
                rapids: rapids,
                cancelled: true
            )
        }

        for (index, move) in program.moves.enumerated() {
            if isCancelled(progress) {
                return result(
                    values: values,
                    columns: columns,
                    rows: rows,
                    violations: violations,
                    rapids: rapids,
                    cancelled: true
                )
            }
            if move.mode == .cut {
                sweep(move, radius: radius, columns: columns, rows: rows, values: &values)
            }
            progress.report(StageProgress(completed: index + 1, total: total))
            if index % 32 == 31 {
                await Task.yield()
            }
        }

        return result(
            values: values,
            columns: columns,
            rows: rows,
            violations: violations,
            rapids: rapids,
            cancelled: false
        )
    }

    private func isCancelled(_ progress: ProgressSink) -> Bool {
        Task.isCancelled || progress.isCancelled()
    }

    private func rapidSegments(in program: ParsedProgram) -> [SimulationSegment] {
        program.moves.compactMap { move in
            guard move.mode == .rapid else { return nil }
            return SimulationSegment(start: move.start, end: move.end, lineNumber: move.lineNumber)
        }
    }

    /// Sweeps the cutter footprint along one cut, sampling at half a cell so a fast move cannot
    /// leave unswept gaps, and keeps the deepest Z reached at every covered cell.
    private func sweep(
        _ move: ParsedMove,
        radius: Double,
        columns: Int,
        rows: Int,
        values: inout [Double]
    ) {
        let delta = move.end - move.start
        let planarLength = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let reach = max(planarLength, abs(delta.z))
        let steps = max(1, Int(ceil(reach / (resolution / 2))))

        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            stamp(
                x: move.start.x + delta.x * fraction,
                y: move.start.y + delta.y * fraction,
                z: move.start.z + delta.z * fraction,
                radius: radius,
                columns: columns,
                rows: rows,
                values: &values
            )
        }
    }

    /// Lowers every cell whose sample point falls inside the cutter footprint to `z`.
    private func stamp(
        x: Double,
        y: Double,
        z: Double,
        radius: Double,
        columns: Int,
        rows: Int,
        values: inout [Double]
    ) {
        let minColumn = max(0, Int(floor((x - radius) / resolution)))
        let maxColumn = min(columns - 1, Int(ceil((x + radius) / resolution)))
        let minRow = max(0, Int(floor((y - radius) / resolution)))
        let maxRow = min(rows - 1, Int(ceil((y + radius) / resolution)))
        guard minColumn <= maxColumn, minRow <= maxRow else { return }
        let radiusSquared = radius * radius

        for row in minRow...maxRow {
            let cellY = Double(row) * resolution
            for column in minColumn...maxColumn {
                let cellX = Double(column) * resolution
                let offsetX = cellX - x
                let offsetY = cellY - y
                guard offsetX * offsetX + offsetY * offsetY <= radiusSquared else { continue }
                let index = row * columns + column
                if z < values[index] {
                    values[index] = z
                }
            }
        }
    }

    private func result(
        values: [Double],
        columns: Int,
        rows: Int,
        violations: [SimulationViolation],
        rapids: [SimulationSegment],
        cancelled: Bool
    ) -> SimulationResult {
        let cellArea = resolution * resolution
        let removed = values.reduce(0.0) { total, height in
            total + max(0, -height) * cellArea
        }
        let heightmap = Heightmap(
            columns: columns,
            rows: rows,
            resolution: resolution,
            origin: Vec3(x: 0, y: 0, z: 0),
            values: values
        )
        return SimulationResult(
            heightmap: heightmap,
            resolution: resolution,
            removedVolume: removed,
            violations: violations,
            rapids: rapids,
            cancelled: cancelled
        )
    }
}
