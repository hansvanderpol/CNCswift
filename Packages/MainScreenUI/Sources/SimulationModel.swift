import CNCSimulation
import Foundation
import Observation

/// The UI state of one simulation and its post-preview write gate (FR-064, FR-066, FR-069).
///
/// A `.ready` pipeline run publishes its `SimulationResult` here through `showPreview`. The
/// simulation's own violations are shown before the write button becomes available; a cancelled
/// simulation never reaches that state. This object is main-actor isolated because SwiftUI reads
/// it directly, and it owns no pipeline or file-system reference.
@Observable
@MainActor
public final class SimulationModel {
    /// The last completed, non-cancelled simulation, when one is available for preview.
    public private(set) var result: SimulationResult?

    /// Named validation and simulation problems shown above the preview.
    public private(set) var findings: [String] = []

    /// Envelope and limit violations from the simulation that block the write (FR-064).
    public private(set) var violations: [SimulationViolation] = []

    public private(set) var progressCompleted: Int = 0
    public private(set) var progressTotal: Int = 0
    public private(set) var isCancelled: Bool = false
    public private(set) var previewShown: Bool = false
    public private(set) var findingsAcknowledged: Bool = false

    public init() {}

    /// Clears all preview and acknowledgement state before a new run.
    public func reset() {
        result = nil
        findings = []
        violations = []
        progressCompleted = 0
        progressTotal = 0
        isCancelled = false
        previewShown = false
        findingsAcknowledged = false
    }

    /// Publishes a completed simulation and marks the preview as shown (FR-065).
    ///
    /// When nothing needs acknowledgement, the flag is set automatically; otherwise the operator
    /// must explicitly acknowledge the listed findings before a commit can be requested.
    public func showPreview(_ simulation: SimulationResult, findings: [String] = []) {
        result = simulation
        violations = simulation.violations
        let combined = findings + simulation.violations.map(\.message)
        var seen: Set<String> = []
        self.findings = combined.filter { seen.insert($0).inserted }
        isCancelled = simulation.cancelled
        previewShown = !simulation.cancelled
        findingsAcknowledged = previewShown && self.findings.isEmpty
        if progressTotal > 0 {
            progressCompleted = progressTotal
        }
    }

    /// Records stage progress from the injected generation action.
    public func reportProgress(completed: Int, total: Int) {
        progressCompleted = completed
        progressTotal = total
    }

    /// Records that the operator stopped the simulation; cancellation is not a failure (FR-066).
    public func reportCancelled() {
        isCancelled = true
        previewShown = false
    }

    /// Records the operator's explicit acknowledgement of the displayed findings.
    public func acknowledgeFindings() {
        guard previewShown, !findings.isEmpty else { return }
        findingsAcknowledged = true
    }

    /// Whether the UI may request a commit. Simulation violations still block the pipeline write.
    public var canWrite: Bool {
        previewShown && !isCancelled && findingsAcknowledged && violations.isEmpty && result != nil
    }
}
