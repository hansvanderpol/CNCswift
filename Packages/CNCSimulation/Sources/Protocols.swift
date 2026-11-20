import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCToolpath
import CNCValidation

/// A rectangular grid of stock-space surface heights, in millimetres.
///
/// `values` is row-major: `values[row * columns + column]`. `origin` is the grid's front-left
/// corner at stock Z0. The resolution is recorded with the result because it drives preview
/// fidelity (FR-061).
public struct Heightmap: Sendable, Equatable {
    public let columns: Int
    public let rows: Int
    public let resolution: Double
    public let origin: Vec3
    public let values: [Double]

    public init(
        columns: Int,
        rows: Int,
        resolution: Double,
        origin: Vec3,
        values: [Double]
    ) {
        self.columns = columns
        self.rows = rows
        self.resolution = resolution
        self.origin = origin
        self.values = values
    }

    /// The height at a grid coordinate, when it is inside the grid.
    public func height(column: Int, row: Int) -> Double? {
        guard column >= 0, column < columns, row >= 0, row < rows else { return nil }
        return values[row * columns + column]
    }
}

/// A named envelope or limit problem surfaced by simulation before writing (FR-064).
public struct SimulationViolation: Sendable, Equatable {
    /// The stable kind, such as `envelope` or `feed-ceiling`.
    public let kind: String
    public let message: String

    /// The program line that produced the violation, when one line is responsible.
    public let lineNumber: Int?

    public init(kind: String, message: String, lineNumber: Int? = nil) {
        self.kind = kind
        self.message = message
        self.lineNumber = lineNumber
    }
}

/// A rapid traverse retained for the preview only (FR-063, FR-070).
///
/// Rapids never remove material, but showing them in a distinct colour lets the operator see that
/// the preview's surface was carved by cutting moves alone.
public struct SimulationSegment: Sendable, Equatable {
    public let start: Vec3
    public let end: Vec3
    public let lineNumber: Int?

    public init(start: Vec3, end: Vec3, lineNumber: Int? = nil) {
        self.start = start
        self.end = end
        self.lineNumber = lineNumber
    }
}

/// The result of simulating the validated program.
///
/// `cancelled` is distinct from failure: a cancelled simulation produces no preview and cannot be
/// committed, but it is reported as cancelled, not as an error (FR-066, FR-069).
public struct SimulationResult: Sendable, Equatable {
    public let heightmap: Heightmap

    /// The stock-space resolution of `heightmap`, in millimetres per cell.
    public let resolution: Double

    /// Derived material volume; informational, never a pass/fail signal.
    public let removedVolume: Double

    /// Envelope and limit findings surfaced before writing.
    public let violations: [SimulationViolation]

    /// Rapid traverses, preserved for visual distinction in the preview. Never swept into `heightmap`.
    public let rapids: [SimulationSegment]

    /// Whether simulation stopped on request before completion.
    public let cancelled: Bool

    public init(
        heightmap: Heightmap,
        resolution: Double,
        removedVolume: Double,
        violations: [SimulationViolation],
        rapids: [SimulationSegment] = [],
        cancelled: Bool
    ) {
        self.heightmap = heightmap
        self.resolution = resolution
        self.removedVolume = removedVolume
        self.violations = violations
        self.rapids = rapids
        self.cancelled = cancelled
    }
}

/// The simulation stage boundary.
///
/// Consumes the validator's `ParsedProgram`, never the emitter's toolpath (FR-065). Rapids never
/// modify the heightmap (FR-063).
public protocol MaterialRemovalSimulating: Sendable {
    /// Sweeps the cutter through the validated program and produces the preview heightmap.
    ///
    /// - Returns: A result whose `cancelled` flag distinguishes a stop on request from a failure.
    /// - Note: Checks `progress` between moves and cooperates with `Task.cancel()` (FR-069).
    func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult
}
