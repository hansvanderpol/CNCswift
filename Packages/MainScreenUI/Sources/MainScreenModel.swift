import CNCCutters
import CNCCuttersStore
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation
import Observation

/// A reason generation is blocked on the main screen (FR-024, FR-037, FR-040, FR-080).
public enum GenerationBlocker: String, Sendable, Equatable, Hashable {
    case unconfirmedModel
    case unconfirmedScale
    case unconfirmedEffectiveValues
    case unconfirmedJobSettings
    case unconfirmedRapidSetup
    case emptyMaterialOverlap
    case emptyCutterSelection

    /// Text suitable for the pre-generation checklist; every blocker names the required action.
    public var message: String {
        switch self {
        case .unconfirmedModel:
            return "Confirm the model units and orientation."
        case .unconfirmedScale:
            return "Apply an explicit scale to convert file units to millimetres."
        case .unconfirmedEffectiveValues:
            return "Confirm the effective feed and spindle values."
        case .unconfirmedJobSettings:
            return "Confirm the suggested stepover, depth per pass, and finishing allowance."
        case .unconfirmedRapidSetup:
            return "Confirm the controller rapid-rate settings are applied."
        case .emptyMaterialOverlap:
            return "Choose a material whose bands overlap the machine limits."
        case .emptyCutterSelection:
            return "Choose a stored cutter."
        }
    }
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
public struct JobSuggestionEngine: Sendable {
    public init() {}

    /// Suggests values for `cutter` and `stock`; the caller must confirm them before use.
    ///
    /// The ratios are derived from the cutter's authoritative cutting extent, so changing the
    /// selected cutter changes the suggestion without any stored default (FR-036, FR-049).
    public func suggestion(
        cutter: Cutter,
        stock: StockBlank,
        profile: MachineProfile
    ) -> JobSuggestion {
        _ = profile
        let extent = cutter.maxCuttingExtent
        guard extent.isFinite, extent > 0, stock.height > 0 else {
            return JobSuggestion(stepover: 0, maxDepthPerPass: 0, finishingAllowance: 0)
        }
        return JobSuggestion(
            // 40% is written as an exact rational so a 6 mm cutter suggests 2.4 mm, not 2.4000000000000004 mm.
            stepover: extent * 2 / 5,
            maxDepthPerPass: min(extent / 3, cutter.cuttingLength, stock.height),
            finishingAllowance: min(extent / 12, stock.height / 2)
        )
    }
}

/// Mutable form state for the units confirmation sheet.
///
/// It lives in the main-screen model because SwiftUI's `@State` macro is unavailable with the
/// Command Line Tools toolchain; an `@Observable` object provides the same stable storage without a
/// missing macro plugin.
@Observable
@MainActor
public final class UnitsConfirmationDraft {
    public var unitsAreMillimetres = false
    public var orientationIsZUp = false
    public var scaleText = ""

    public init() {}
}

/// Mutable text state for the stock dimension fields.
@Observable
@MainActor
public final class StockDraft {
    public var width = "200"
    public var depth = "150"
    public var height = "30"

    public init() {}
}

/// The outcome of one UI-initiated generation attempt.
public enum MainScreenGenerationStatus: Sendable, Equatable {
    case idle
    case running
    case ready
    case blocked([String])
    case cancelled
    case failed(String)
}

/// The main-screen state that gates one generation job (FR-037, FR-040, FR-069).
@Observable
@MainActor
public final class MainScreenModel {
    public private(set) var selectedCutterID: CutterID?
    public private(set) var effectiveValues: EffectiveCuttingValues?
    public private(set) var appliedSuggestion: JobSuggestion?
    public private(set) var rapidRateConfirmed: Bool
    public private(set) var materialHasOverlap: Bool

    public private(set) var selectedMaterialID: String?
    public private(set) var stock: StockBlank
    public private(set) var hasLoadedModel: Bool
    public private(set) var modelFileName: String?
    public private(set) var unitsConfirmed: Bool
    public private(set) var orientationConfirmed: Bool
    public private(set) var appliedScale: Double
    public private(set) var scaleConfirmed: Bool
    public private(set) var pendingSuggestion: JobSuggestion?
    public let unitsDraft = UnitsConfirmationDraft()
    public let stockDraft = StockDraft()
    public private(set) var isUnitsSheetPresented = false
    public private(set) var isFileImporterPresented = false
    public private(set) var generationStatus: MainScreenGenerationStatus
    public private(set) var progressCompleted: Int
    public private(set) var progressTotal: Int
    public private(set) var isCancellationRequested: Bool

    /// The live preview state and orbit controls for the third main-screen panel (FR-061, FR-070).
    /// They are owned here so the panel views stay free of pipeline and file-system references.
    public let simulation = SimulationModel()
    public let camera = SimulationCamera()

    /// Injected by the composition root; the UI never imports the pipeline package directly.
    ///
    /// These closures are main-actor isolated because the state they read and write belongs to the
    /// main screen. They cross no actor boundary until they reach the pipeline actor.
    public var generate: (@MainActor () async -> MainScreenGenerationStatus)?
    public var cancel: (@MainActor () -> Void)?
    public var loadModel: (@MainActor (URL) async -> Bool)?
    public var commit: (@MainActor () async -> Bool)?

    public init(
        selectedCutterID: CutterID? = nil,
        effectiveValues: EffectiveCuttingValues? = nil,
        suggestion: JobSuggestion? = nil,
        rapidRateConfirmed: Bool = false,
        materialHasOverlap: Bool = true
    ) {
        self.selectedCutterID = selectedCutterID
        self.effectiveValues = effectiveValues
        self.pendingSuggestion = suggestion
        self.appliedSuggestion = suggestion?.confirmed == true ? suggestion : nil
        self.rapidRateConfirmed = rapidRateConfirmed
        self.materialHasOverlap = materialHasOverlap
        selectedMaterialID = nil
        stock = StockBlank(width: 0, depth: 0, height: 0)
        hasLoadedModel = false
        modelFileName = nil
        unitsConfirmed = false
        orientationConfirmed = false
        appliedScale = 1
        scaleConfirmed = false
        generationStatus = .idle
        progressCompleted = 0
        progressTotal = 0
        isCancellationRequested = false
    }

    /// Selects a stored cutter by identifier; the library remains the source of truth (FR-060).
    public func selectCutter(_ id: CutterID?) {
        selectedCutterID = id
    }

    /// Clears a selection whose cutter was deleted from the persisted library (FR-060).
    public func clearCutterSelection() {
        selectedCutterID = nil
    }

    /// Stores prefilled, unconfirmed cutting values from material resolution (FR-079).
    public func setEffectiveValues(_ values: EffectiveCuttingValues?) {
        effectiveValues = values
    }

    /// Records an explicit confirmation of resolved cutting values (FR-079).
    public func confirmEffectiveValues(_ values: EffectiveCuttingValues) {
        effectiveValues = values.confirming()
    }

    /// Stores a suggested strategy without applying it (FR-037).
    public func setSuggestion(_ suggestion: JobSuggestion) {
        pendingSuggestion = suggestion
    }

    /// Applies a job strategy only after the user confirms it (FR-037).
    public func applySuggestion(_ suggestion: JobSuggestion) {
        guard suggestion.confirmed else { return }
        pendingSuggestion = suggestion
        appliedSuggestion = suggestion
    }

    /// Records the operator's rapid-rate controller-setting confirmation (FR-024).
    public func confirmRapidRate(_ confirmed: Bool) {
        rapidRateConfirmed = confirmed
    }

    /// Selects a material and clears any stale effective-value confirmation (FR-008).
    public func selectMaterial(_ id: String) {
        selectedMaterialID = id
        effectiveValues = nil
    }

    /// Updates the blank dimensions after explicit entry (FR-010).
    public func updateStock(width: Double, depth: Double, height: Double) {
        stock = StockBlank(width: width, depth: depth, height: height)
    }

    /// Records that a model was decoded and resets every model-specific confirmation (FR-005, FR-006).
    public func markModelLoaded(fileName: String) {
        hasLoadedModel = true
        modelFileName = fileName
        unitsConfirmed = false
        orientationConfirmed = false
        appliedScale = 1
        scaleConfirmed = false
    }

    /// Clears the loaded model and its confirmations.
    public func clearModel() {
        hasLoadedModel = false
        modelFileName = nil
        unitsConfirmed = false
        orientationConfirmed = false
        appliedScale = 1
        scaleConfirmed = false
    }

    /// Records unit and orientation confirmation from the dedicated sheet (FR-005).
    public func confirmUnitsAndOrientation(units: Bool, orientation: Bool) {
        unitsConfirmed = units
        orientationConfirmed = orientation
    }

    /// Applies an explicit scale; no scale is inferred from a file (FR-006).
    public func applyScale(_ scale: Double) {
        guard scale.isFinite, scale > 0 else { return }
        appliedScale = scale
        scaleConfirmed = true
    }

    /// Records a generated material-resolution failure (FR-079).
    public func setMaterialOverlap(_ hasOverlap: Bool) {
        materialHasOverlap = hasOverlap
    }

    /// Controls the units sheet without a SwiftUI `@State` macro.
    public func setUnitsSheetPresented(_ presented: Bool) {
        isUnitsSheetPresented = presented
    }

    /// Controls the STL importer without a SwiftUI `@State` macro.
    public func setFileImporterPresented(_ presented: Bool) {
        isFileImporterPresented = presented
    }

    /// Returns every currently blocking condition.
    public func blockers() -> [GenerationBlocker] {
        var result: [GenerationBlocker] = []
        if selectedCutterID == nil {
            result.append(.emptyCutterSelection)
        }
        if !materialHasOverlap {
            result.append(.emptyMaterialOverlap)
        }
        if effectiveValues?.confirmed != true {
            result.append(.unconfirmedEffectiveValues)
        }
        if appliedSuggestion?.confirmed != true {
            result.append(.unconfirmedJobSettings)
        }
        if !rapidRateConfirmed {
            result.append(.unconfirmedRapidSetup)
        }
        if hasLoadedModel {
            if !unitsConfirmed || !orientationConfirmed {
                result.append(.unconfirmedModel)
            }
            if !scaleConfirmed {
                result.append(.unconfirmedScale)
            }
        }
        return result
    }

    /// Re-resolves the selected cutter identifier against the freshly loaded library (FR-060).
    public func resolvedCutter(in library: [Cutter]) -> Cutter? {
        guard let selectedCutterID else { return nil }
        return library.first { $0.id == selectedCutterID }
    }

    /// Applies one persisted-library change to the current selection (FR-060, SC-007).
    ///
    /// `deleted` clears the selection only when it names the stored cutter currently chosen.
    /// `saved` and `reloaded` re-resolve the stable identifier, so an edit reaches the next job
    /// without relaunch while a missing identifier blocks generation until one is chosen again.
    /// The caller supplies the freshly loaded library; no cutter payload travels in the event.
    public func applyLibraryChange(_ change: LibraryChange, library: [Cutter]) {
        guard let currentID = self.selectedCutterID else { return }
        switch change {
        case .deleted(let deletedID):
            if deletedID == currentID {
                clearCutterSelection()
            }
        case .saved, .reloaded:
            if !library.contains(where: { $0.id == currentID }) {
                clearCutterSelection()
            }
        }
    }

    /// Runs the injected write-free generation action (FR-069).
    public func startGeneration() async {
        guard blockers().isEmpty, let generate else { return }
        generationStatus = .running
        isCancellationRequested = false
        generationStatus = await generate()
    }

    /// Reports stage progress from the injected generation action.
    public func reportProgress(completed: Int, total: Int) {
        progressCompleted = completed
        progressTotal = total
        simulation.reportProgress(completed: completed, total: total)
    }

    /// Surfaces a composition or generation failure without changing confirmation state.
    public func reportFailure(_ message: String) {
        generationStatus = .failed(message)
    }

    /// Requests cancellation through the injected seam.
    public func requestCancellation() {
        isCancellationRequested = true
        cancel?()
    }

    /// Commits the previewed program through the injected, post-preview write seam (FR-026).
    ///
    /// The write itself is enforced by the pipeline's commit gate; this method only forwards the
    /// operator's intent and returns whether the file was written.
    @discardableResult
    public func commitProgram() async -> Bool {
        guard let commit else { return false }
        return await commit()
    }
}
