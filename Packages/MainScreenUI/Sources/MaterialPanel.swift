import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import SwiftUI

/// The material, stock, effective-value, and job-settings panel (FR-008, FR-009, FR-010, FR-024,
/// FR-055, FR-077, FR-079, FR-080).
///
/// The rapid-rate acknowledgement is part of this job section and the pre-generation checklist; it
/// is deliberately not a fourth panel.
@MainActor
public struct MaterialPanel: View {
    private let model: MainScreenModel
    private let materials: [CNCMaterials.Material]
    private let cutters: [Cutter]
    private let profile: MachineProfile

    public init(
        model: MainScreenModel,
        materials: [CNCMaterials.Material],
        cutters: [Cutter],
        profile: MachineProfile
    ) {
        self.model = model
        self.materials = materials
        self.cutters = cutters
        self.profile = profile
    }

    public var body: some View {
        GroupBox {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    materialSection
                    stockSection
                    effectiveValuesSection
                    jobSettingsSection
                    rapidRateSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear(perform: seedFromModel)
            .onChange(of: model.selectedMaterialID) { _, _ in refreshDerivedValues() }
            .onChange(of: model.selectedCutterID) { _, _ in refreshDerivedValues() }
        } label: {
            Label("Carving material and job", systemImage: "square.grid.3x3")
        }
        .accessibilityIdentifier("material-panel")
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Material").font(.headline)
            Picker(
                "Material",
                selection: Binding(
                    get: { model.selectedMaterialID ?? "" },
                    set: { model.selectMaterial($0) }
                )
            ) {
                Text("Choose a material").tag("")
                ForEach(materials, id: \.id) { material in
                    Text(material.name).tag(material.id)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Carving material")

            if let material = selectedMaterial {
                Text(bandDescription(for: material))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if material.origin == .user {
                    Text("User material").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ForEach(conflicts, id: \.message) { conflict in
                Text(conflict.message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("material-conflict")
            }
        }
    }

    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stock blank (mm)").font(.headline)
            HStack(spacing: 10) {
                dimensionField(
                    "Width",
                    text: Binding(
                        get: { model.stockDraft.width },
                        set: {
                            model.stockDraft.width = $0
                            commitStock()
                        }
                    )
                )
                dimensionField(
                    "Depth",
                    text: Binding(
                        get: { model.stockDraft.depth },
                        set: {
                            model.stockDraft.depth = $0
                            commitStock()
                        }
                    )
                )
                dimensionField(
                    "Height",
                    text: Binding(
                        get: { model.stockDraft.height },
                        set: {
                            model.stockDraft.height = $0
                            commitStock()
                        }
                    )
                )
            }
        }
    }

    private var effectiveValuesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Effective cutting values").font(.headline)
            if let values = model.effectiveValues ?? prefilledValues {
                HStack(spacing: 16) {
                    Text("Feed: \(formatted(values.feed)) mm/min")
                    Text("Spindle: \(formatted(values.spindle)) RPM")
                }
                Text("Source: \(values.source.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if values.confirmed {
                    Label("Confirmed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Confirm feed and spindle") {
                        guard let prefilledValues else { return }
                        model.confirmEffectiveValues(prefilledValues)
                    }
                    .disabled(prefilledValues == nil)
                    .accessibilityIdentifier("confirm-effective-values")
                }
            } else {
                Text("Select a stored cutter and a material to resolve feed and spindle values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var jobSettingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Job settings").font(.headline)
            if let suggestion = model.pendingSuggestion ?? computedSuggestion {
                HStack(spacing: 12) {
                    Text("Stepover \(formatted(suggestion.stepover)) mm")
                    Text("Depth \(formatted(suggestion.maxDepthPerPass)) mm")
                    Text("Allowance \(formatted(suggestion.finishingAllowance)) mm")
                }
                .font(.caption)
                if model.appliedSuggestion?.confirmed == true {
                    Label("Suggested values confirmed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("Confirm suggested job values") {
                        model.applySuggestion(suggestion.confirming())
                    }
                    .accessibilityIdentifier("confirm-job-settings")
                }
            } else {
                Text("Select a cutter and enter stock dimensions to see suggested job values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rapidRateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Controller setup").font(.headline)
            Toggle(
                "Rapid settings applied (\(rapidSetupDescription))",
                isOn: Binding(
                    get: { model.rapidRateConfirmed },
                    set: { model.confirmRapidRate($0) }
                )
            )
            .accessibilityLabel("Controller rapid-rate settings applied")
            Text("The app never reads or changes controller settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func dimensionField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption)
            TextField("0", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)
                .accessibilityLabel("Stock \(title) in millimetres")
        }
    }

    private var selectedMaterial: CNCMaterials.Material? {
        guard let id = model.selectedMaterialID else { return nil }
        return materials.first { $0.id == id }
    }

    private var selectedCutter: Cutter? {
        model.resolvedCutter(in: cutters)
    }

    private var resolution: ResolutionOutcome? {
        guard let material = selectedMaterial, let cutter = selectedCutter else { return nil }
        return EffectiveCuttingValues.resolve(material: material, cutter: cutter, profile: profile)
    }

    private var prefilledValues: EffectiveCuttingValues? {
        guard case .resolved(let values)? = resolution else { return nil }
        return values
    }

    private var conflicts: [BandConflict] {
        guard case .noOverlap(let conflicts)? = resolution else { return [] }
        return conflicts
    }

    private var computedSuggestion: JobSuggestion? {
        guard let cutter = selectedCutter,
            model.stock.width > 0, model.stock.depth > 0, model.stock.height > 0
        else { return nil }
        return JobSuggestionEngine().suggestion(
            cutter: cutter,
            stock: model.stock,
            profile: profile
        )
    }

    private var rapidSetupDescription: String {
        profile.controllerSetup.rapidRate.keys.sorted().map { key in
            "\(key)=\(profile.controllerSetup.rapidRate[key] ?? 0)"
        }.joined(separator: ", ")
    }

    private func seedFromModel() {
        guard model.stock.width > 0, model.stock.depth > 0, model.stock.height > 0 else {
            commitStock()
            return
        }
        model.stockDraft.width = formatted(model.stock.width)
        model.stockDraft.depth = formatted(model.stock.depth)
        model.stockDraft.height = formatted(model.stock.height)
    }

    private func commitStock() {
        guard let width = Double(model.stockDraft.width),
            let depth = Double(model.stockDraft.depth),
            let height = Double(model.stockDraft.height)
        else { return }
        model.updateStock(width: width, depth: depth, height: height)
        refreshDerivedValues()
    }

    private func refreshDerivedValues() {
        if let values = prefilledValues {
            model.setEffectiveValues(values)
            model.setMaterialOverlap(true)
        } else if selectedMaterial != nil {
            model.setEffectiveValues(nil)
            model.setMaterialOverlap(false)
        }
        if let suggestion = computedSuggestion {
            model.setSuggestion(suggestion)
        }
    }

    private func bandDescription(for material: CNCMaterials.Material) -> String {
        "Feed \(formatted(material.feedBand.lowerBound))–\(formatted(material.feedBand.upperBound)) mm/min · "
            + "spindle \(formatted(material.spindleBand.lowerBound))–\(formatted(material.spindleBand.upperBound)) RPM"
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
