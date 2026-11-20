import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

/// A reason generation is blocked on the main screen (FR-024, FR-037, FR-040, FR-080).
public enum GenerationBlocker: String, Sendable, Equatable, Hashable {
    case unconfirmedEffectiveValues
    case unconfirmedJobSettings
    case unconfirmedRapidSetup
    case emptyMaterialOverlap
    case emptyCutterSelection
}

/// A suggested job strategy that must be confirmed before it is applied (FR-037).
public struct JobSuggestion: Sendable, Equatable {
    public let stepover: Double
    public let maxDepthPerPass: Double
    public let finishingAllowance: Double
    public let confirmed: Bool

    public init(
        stepover: Double,
        maxDepthPerPass: Double,
        finishingAllowance: Double,
        confirmed: Bool = false
    ) {
        self.stepover = stepover
        self.maxDepthPerPass = maxDepthPerPass
        self.finishingAllowance = finishingAllowance
        self.confirmed = confirmed
    }

    /// Returns the same suggestion with the user's explicit confirmation recorded.
    public func confirming() -> JobSuggestion {
        JobSuggestion(
            stepover: stepover,
            maxDepthPerPass: maxDepthPerPass,
            finishingAllowance: finishingAllowance,
            confirmed: true
        )
    }
}

/// Suggests a starting job strategy without applying it (FR-037).
///
/// Full derivation is added by T073; this seam lets the confirmation test compile and fail first.
public struct JobSuggestionEngine: Sendable {
    public init() {}

    /// Suggests values for `cutter` and `stock`; the caller must confirm them before use.
    public func suggestion(
        cutter: Cutter,
        stock: StockBlank,
        profile: MachineProfile
    ) -> JobSuggestion {
        _ = (cutter, stock, profile)
        return JobSuggestion(stepover: 0, maxDepthPerPass: 0, finishingAllowance: 0)
    }
}

/// The main-screen state that gates one generation job.
///
/// Behaviour is added by T073; the state and seams exist so T054–T056 can pin the contract.
@MainActor
public final class MainScreenModel {
    public private(set) var selectedCutterID: CutterID?
    public private(set) var effectiveValues: EffectiveCuttingValues?
    public private(set) var appliedSuggestion: JobSuggestion?
    public private(set) var rapidRateConfirmed: Bool
    public private(set) var materialHasOverlap: Bool

    public init(
        selectedCutterID: CutterID? = nil,
        effectiveValues: EffectiveCuttingValues? = nil,
        suggestion: JobSuggestion? = nil,
        rapidRateConfirmed: Bool = false,
        materialHasOverlap: Bool = true
    ) {
        self.selectedCutterID = selectedCutterID
        self.effectiveValues = effectiveValues
        self.appliedSuggestion = suggestion?.confirmed == true ? suggestion : nil
        self.rapidRateConfirmed = rapidRateConfirmed
        self.materialHasOverlap = materialHasOverlap
    }

    /// Selects a stored cutter by identifier; the library remains the source of truth (FR-060).
    public func selectCutter(_ id: CutterID?) {
        selectedCutterID = id
    }

    /// Records an explicit confirmation of resolved cutting values (FR-079).
    public func confirmEffectiveValues(_ values: EffectiveCuttingValues) {
        effectiveValues = values.confirming()
    }

    /// Applies a job strategy only after the user confirms it (FR-037).
    public func applySuggestion(_ suggestion: JobSuggestion) {
        guard suggestion.confirmed else { return }
        appliedSuggestion = suggestion
    }

    /// Records the operator's rapid-rate controller-setting confirmation (FR-024).
    public func confirmRapidRate(_ confirmed: Bool) {
        rapidRateConfirmed = confirmed
    }

    /// Returns every currently blocking condition.
    public func blockers() -> [GenerationBlocker] {
        []
    }

    /// Re-resolves the selected cutter identifier against the freshly loaded library (FR-060).
    public func resolvedCutter(in library: [Cutter]) -> Cutter? {
        _ = (selectedCutterID, library)
        return nil
    }
}
