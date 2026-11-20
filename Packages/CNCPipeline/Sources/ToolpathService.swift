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
        }
    }
}

/// Orchestrates decode, plan, render, validate, and simulate, then writes only on explicit commit.
///
/// The real stage order and commit gate are added by tasks T067 and T068. The type exists now so the
/// first pipeline test compiles and fails for the missing orchestration, not for a missing symbol.
public actor ToolpathService: PipelineRunning {
    private let planner: any ToolpathPlanning
    private let renderer: any GCodeRendering
    private let validator: any ProgramValidating
    private let simulator: any MaterialRemovalSimulating
    private let writer: any ProgramWriter

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

    public func run(
        _ request: GenerationRequest,
        progress: ProgressSink
    ) async throws -> PipelineOutcome {
        _ = (planner, renderer, validator, simulator, writer, request, progress)
        return .cancelled
    }

    public func commit(
        _ program: RenderedProgram,
        confirmation: WriteConfirmation,
        to destination: URL
    ) async throws {
        _ = (program, confirmation, destination)
        throw PipelineError.notReady
    }
}
