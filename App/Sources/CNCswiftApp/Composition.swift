import CNCCutters
import CNCCuttersStore
import CNCDiagnostics
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCMaterialsStore
import CNCPipeline
import CNCSTL
import CNCSimulation
import CNCStorage
import CNCToolpath
import CNCValidation
import Foundation
import MainScreenUI
import Observation

/// A copyable, thread-safe cancellation flag for the `ProgressSink` closure.
private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}

/// Application composition root.
///
/// The app owns no domain state: it loads cutters and materials from the Foundational stores,
/// decodes the selected STL, and injects write-free generation into the main-screen model. US3
/// supplies the real material-removal simulator and keeps the write behind an explicit commit
/// after the preview has been shown and the findings acknowledged.
@MainActor
@Observable
final class AppComposition {
    let profile = TTC450Pro.profile
    let model: MainScreenModel

    private(set) var cutters: [Cutter] = []
    private(set) var materials: [Material] = Presets.all

    /// Whether the cutter-library modal is presented. Kept here so the command and the sheet share
    /// one observable source of truth without a cross-module view reference (FR-056, FR-059).
    var showingCutterLibrary = false

    private let fileSystem: any FileSystem
    let cutterStore: CutterLibraryStore
    private let materialStore: MaterialLibraryStore
    let cutterURL: URL
    private let materialURL: URL
    private let outputDirectory: URL
    private let cancellation = CancellationFlag()

    private var loadedModel: MeshDocument?
    private var pipeline: ToolpathService
    private var cutterChangeTask: Task<Void, Never>?

    /// The exact program prepared by the last `.ready` run. Only this value may be committed;
    /// a new run clears it so a stale preview cannot authorize a later write.
    private var preparedProgram: RenderedProgram?
    private var preparedDestination: URL?

    init(fileSystem: any FileSystem = DiskFileSystem()) {
        self.fileSystem = fileSystem
        let supportRoot =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appRoot = supportRoot.appendingPathComponent("CNCswift", isDirectory: true)
        try? FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)

        cutterURL = appRoot.appendingPathComponent("cutters.json")
        materialURL = appRoot.appendingPathComponent("materials.json")
        outputDirectory = appRoot.appendingPathComponent("gcode", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        cutterStore = CutterLibraryStore(fileSystem: fileSystem)
        materialStore = MaterialLibraryStore(fileSystem: fileSystem)
        model = MainScreenModel()
        pipeline = Self.makePipeline(
            modelFileName: "model.stl", appliedScale: 1, fileSystem: fileSystem)

        model.generate = { [weak self] in
            guard let self else { return .failed("The app composition is unavailable.") }
            return await self.generate()
        }
        model.cancel = { [weak self] in
            self?.cancelGeneration()
        }
        model.loadModel = { [weak self] url in
            await self?.loadModel(url: url) ?? false
        }
        model.commit = { [weak self] in
            guard let self, let program = self.preparedProgram,
                let destination = self.preparedDestination
            else { return false }
            let confirmation = WriteConfirmation(
                previewShown: self.model.simulation.previewShown,
                findingsAcknowledged: self.model.simulation.findingsAcknowledged
            )
            do {
                try await self.pipeline.commit(program, confirmation: confirmation, to: destination)
                self.preparedProgram = nil
                self.preparedDestination = nil
                return true
            } catch {
                self.model.reportFailure(error.localizedDescription)
                return false
            }
        }
    }

    /// Starts consuming library changes before the initial load so no event published by the modal
    /// can be missed (FR-058, FR-060). The stream is buffered per subscriber by the store.
    func startCutterChangeSubscription() {
        guard cutterChangeTask == nil else { return }
        cutterChangeTask = Task { [weak self] in
            guard let self else { return }
            let changes = await cutterStore.changes
            for await change in changes {
                await handleCutterChange(change)
            }
        }
    }

    /// Re-reads the persisted library after one event and re-resolves the selected cutter.
    ///
    /// Events carry only *what* changed, never a cutter payload, so the document stays the only
    /// source of truth (FR-060, research D14).
    private func handleCutterChange(_ change: LibraryChange) async {
        do {
            let fresh: [Cutter]
            switch try await cutterStore.load(from: cutterURL) {
            case .loaded(let values), .migrated(_, let values):
                fresh = values
            case .absent, .refused, .corrupt:
                fresh = []
            }
            cutters = fresh
            model.applyLibraryChange(change, library: fresh)
            refreshDerivedValues()
        } catch {
            model.reportFailure(error.localizedDescription)
        }
    }

    /// Loads the persisted libraries and primes selection, prefills, and suggestions.
    func loadLibraries() async {
        startCutterChangeSubscription()
        do {
            let loadedCutters: [Cutter]
            switch try await cutterStore.load(from: cutterURL) {
            case .loaded(let values), .migrated(_, let values):
                loadedCutters = values
            case .absent, .refused, .corrupt:
                loadedCutters = []
            }
            cutters = loadedCutters

            if let selected = model.selectedCutterID,
                !loadedCutters.contains(where: { $0.id == selected })
            {
                model.clearCutterSelection()
            } else if model.selectedCutterID == nil {
                model.selectCutter(loadedCutters.first?.id)
            }

            materials = try await materialStore.resolvedMaterials(from: materialURL)
            if model.selectedMaterialID == nil {
                model.selectMaterial(materials.first?.id ?? "")
            }
            refreshDerivedValues()
        } catch {
            model.reportFailure(error.localizedDescription)
        }
    }

    /// Decodes one STL, resets model-specific confirmations, and primes stock and strategy values.
    func loadModel(url: URL) async -> Bool {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let decoded = try await STLDecoder.decode(url: url, progress: progressSink())
            loadedModel = decoded
            preparedProgram = nil
            preparedDestination = nil
            model.simulation.reset()
            model.markModelLoaded(fileName: url.lastPathComponent)
            model.updateStock(
                width: max(1, decoded.bounds.max.x - decoded.bounds.min.x),
                depth: max(1, decoded.bounds.max.y - decoded.bounds.min.y),
                height: max(1, decoded.bounds.max.z - decoded.bounds.min.z)
            )
            pipeline = Self.makePipeline(
                modelFileName: url.lastPathComponent,
                appliedScale: model.appliedScale,
                fileSystem: fileSystem
            )
            refreshDerivedValues()
            return true
        } catch {
            loadedModel = nil
            preparedProgram = nil
            preparedDestination = nil
            model.simulation.reset()
            model.clearModel()
            model.reportFailure(error.localizedDescription)
            return false
        }
    }

    private func generate() async -> MainScreenGenerationStatus {
        guard let document = loadedModel,
            let cutter = model.resolvedCutter(in: cutters),
            let materialID = model.selectedMaterialID,
            let material = materials.first(where: { $0.id == materialID }),
            let effective = model.effectiveValues,
            effective.confirmed,
            let suggestion = model.appliedSuggestion
        else {
            return .failed("Finish the confirmations before generating.")
        }

        pipeline = Self.makePipeline(
            modelFileName: documentFileName ?? "model.stl",
            appliedScale: model.appliedScale,
            fileSystem: fileSystem
        )
        preparedProgram = nil
        preparedDestination = nil
        model.simulation.reset()

        let job = JobSettings(
            mesh: document.mesh,
            modelBounds: document.bounds,
            stock: model.stock,
            cutter: cutter,
            materialID: material.id,
            effective: effective,
            stepover: suggestion.stepover,
            maxDepthPerPass: suggestion.maxDepthPerPass,
            finishingAllowance: suggestion.finishingAllowance,
            unitsConfirmed: model.unitsConfirmed,
            orientationConfirmed: model.orientationConfirmed,
            rapidRateConfirmed: model.rapidRateConfirmed,
            confirmed: true
        )

        do {
            _ = try Preflight.check(job, cutter: cutter, profile: profile)
            cancellation.set(false)
            let request = GenerationRequest(
                model: document,
                job: job,
                cutter: cutter,
                material: material,
                profile: profile,
                destination: outputDirectory.appendingPathComponent("generated.nc"),
                generatedAt: Date()
            )
            let outcome = try await pipeline.run(request, progress: progressSink())
            switch outcome {
            case .ready(let program, let report, let simulation):
                preparedProgram = program
                preparedDestination = request.destination
                model.simulation.showPreview(
                    simulation,
                    findings: report.findings.map(\.message)
                )
                return .ready
            case .blocked(let findings):
                model.simulation.reset()
                return .blocked(findings.map(\.message))
            case .cancelled:
                model.simulation.reportCancelled()
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func cancelGeneration() {
        cancellation.set(true)
    }

    private func refreshDerivedValues() {
        guard let cutter = model.resolvedCutter(in: cutters),
            let materialID = model.selectedMaterialID,
            let material = materials.first(where: { $0.id == materialID })
        else { return }

        switch EffectiveCuttingValues.resolve(material: material, cutter: cutter, profile: profile)
        {
        case .resolved(let values):
            model.setEffectiveValues(values)
            model.setMaterialOverlap(true)
        case .noOverlap:
            model.setEffectiveValues(nil)
            model.setMaterialOverlap(false)
        }

        let suggestion = JobSuggestionEngine().suggestion(
            cutter: cutter,
            stock: model.stock,
            profile: profile
        )
        model.setSuggestion(suggestion)
    }

    private var documentFileName: String? {
        model.modelFileName
    }

    private func progressSink() -> ProgressSink {
        ProgressSink { [weak model] stage in
            Task { @MainActor in
                model?.reportProgress(completed: stage.completed, total: stage.total)
            }
        } isCancelled: { [cancellation] in
            cancellation.get()
        }
    }

    private static func makePipeline(
        modelFileName: String,
        appliedScale: Double,
        fileSystem: any FileSystem
    ) -> ToolpathService {
        ToolpathService(
            planner: ToolpathPlanner(),
            renderer: GCodeEmitter(modelFileName: modelFileName, appliedScale: appliedScale),
            validator: GRBLValidator(),
            simulator: ZMapSimulator(resolution: 2),
            writer: FileWriter(fileSystem: fileSystem)
        )
    }
}
