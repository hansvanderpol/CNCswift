import CNCDiagnostics
import CNCGCode
import CNCMachineProfile
import CNCMaterials
import CNCSTL
import CNCSimulation
import CNCToolpath
import CNCValidation
import Foundation

/// Machine-readable reasons a pipeline operation was refused.
public enum PipelineError: Error, Equatable, Sendable {
    case notReady
    case incompleteConfirmation
    case blockedProgram
    case cancelledProgram
    case unacknowledgedViolations

    public var userMessage: String {
        switch self {
        case .notReady:
            return "A program must be prepared by a successful run before it can be written."
        case .incompleteConfirmation:
            return "Show the preview and acknowledge all findings before writing the file."
        case .blockedProgram:
            return "The validated program has errors and cannot be written."
        case .cancelledProgram:
            return "Generation was cancelled; no file was written."
        case .unacknowledgedViolations:
            return "Resolve every simulation violation before writing the file."
        }
    }
}

/// Orchestrates plan, render, validate, and simulate, then writes only on explicit commit.
///
/// The actor owns the provenance of programs it prepared so a `.blocked` or `.cancelled` run can
/// never be turned into a file by a later commit (D10). No stage other than `ProgramWriter` touches
/// the filesystem, and `run` never calls it.
public actor ToolpathService: PipelineRunning {
    private let planner: any ToolpathPlanning
    private let renderer: any GCodeRendering
    private let validator: any ProgramValidating
    private let simulator: any MaterialRemovalSimulating
    private let writer: any ProgramWriter
    private var prepared: [ProgramKey: Preparation] = [:]

    public init(
        planner: any ToolpathPlanning,
        renderer: any GCodeRendering,
        validator: any ProgramValidating,
        simulator: any MaterialRemovalSimulating,
        writer: any ProgramWriter
    ) {
        self.planner = planner
        self.renderer = renderer
        self.validator = validator
        self.simulator = simulator
        self.writer = writer
    }

    /// Prepares one program for preview without writing anything.
    ///
    /// - Throws: A stage error for a planning, rendering, or simulation failure. Cancellation is
    ///   returned as `.cancelled`, not thrown.
    public func run(
        _ request: GenerationRequest,
        progress: ProgressSink
    ) async throws -> PipelineOutcome {
        guard !isCancelled(progress) else { return .cancelled }
        progress.report(StageProgress(completed: 0, total: 4))

        let toolpath = try await planner.plan(
            request.job,
            profile: request.profile,
            progress: progress
        )
        guard !isCancelled(progress) else { return .cancelled }
        progress.report(StageProgress(completed: 1, total: 4))

        let program = try renderer.render(
            toolpath,
            cutter: request.cutter,
            material: request.material,
            job: request.job,
            profile: request.profile,
            generatedAt: request.generatedAt
        )
        guard !isCancelled(progress) else { return .cancelled }
        progress.report(StageProgress(completed: 2, total: 4))

        let report = validator.validate(program.text, profile: request.profile)
        let key = ProgramKey(program)
        if report.hasErrors {
            prepared[key] = .blocked(report.findings)
            return .blocked(report.findings)
        }
        guard !isCancelled(progress) else {
            prepared[key] = .cancelled
            return .cancelled
        }
        progress.report(StageProgress(completed: 3, total: 4))

        let simulation = try await simulator.simulate(
            report.program,
            job: request.job,
            profile: request.profile,
            progress: progress
        )
        guard !isCancelled(progress), !simulation.cancelled else {
            prepared[key] = .cancelled
            return .cancelled
        }

        prepared[key] = .ready(report, simulation)
        progress.report(StageProgress(completed: 4, total: 4))
        return .ready(program, report, simulation)
    }

    /// Writes one validated program after an explicit post-preview confirmation.
    ///
    /// - Throws: `PipelineError` when confirmation, provenance, or validation refuses the write;
    ///   the writer's error when the atomic write fails.
    public func commit(
        _ program: RenderedProgram,
        confirmation: WriteConfirmation,
        to destination: URL
    ) async throws {
        guard confirmation.previewShown, confirmation.findingsAcknowledged else {
            throw PipelineError.incompleteConfirmation
        }

        let report = validator.validate(program.text, profile: program.record.profile)
        guard !report.hasErrors else { throw PipelineError.blockedProgram }

        switch prepared[ProgramKey(program)] {
        case .ready(let validatedReport, let simulation):
            guard !simulation.cancelled else { throw PipelineError.cancelledProgram }
            guard simulation.violations.isEmpty else {
                throw PipelineError.unacknowledgedViolations
            }
            guard !validatedReport.hasErrors else { throw PipelineError.blockedProgram }
        case .blocked:
            throw PipelineError.blockedProgram
        case .cancelled:
            throw PipelineError.cancelledProgram
        case nil:
            throw PipelineError.notReady
        }

        try await writer.write(program, to: destination)
    }

    private func isCancelled(_ progress: ProgressSink) -> Bool {
        Task.isCancelled || progress.isCancelled()
    }

    private enum Preparation: Sendable {
        case ready(ValidationReport, SimulationResult)
        case blocked([Finding])
        case cancelled
    }

    /// Identity of one generation, independent of the transient preview text.
    ///
    /// The record's model name and injected timestamp identify the previewed artefact. Keying on
    /// raw text would let a caller that re-serialises the same preview bypass cancellation or
    /// blocked provenance (D10).
    private struct ProgramKey: Hashable, Sendable {
        let modelFileName: String
        let generatedAt: Date

        init(_ program: RenderedProgram) {
            modelFileName = program.record.modelFileName
            generatedAt = program.record.generatedAt
        }
    }
}
