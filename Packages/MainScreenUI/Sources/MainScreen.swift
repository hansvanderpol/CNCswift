import CNCCutters
import CNCMachineProfile
import CNCMaterials
import SwiftUI
import UniformTypeIdentifiers

/// The single G-code creation screen, composed of exactly three panels (FR-055).
@MainActor
public struct MainScreen: View {
    private let model: MainScreenModel
    private let cutters: [Cutter]
    private let materials: [CNCMaterials.Material]
    private let profile: MachineProfile

    private let stlType: UTType

    public init(
        model: MainScreenModel,
        cutters: [Cutter],
        materials: [CNCMaterials.Material],
        profile: MachineProfile
    ) {
        self.model = model
        self.cutters = cutters
        self.materials = materials
        self.profile = profile
        stlType = UTType(filenameExtension: "stl") ?? .data
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                HSplitView {
                    CutterPanel(model: model, cutters: cutters)
                        .frame(minWidth: 230, idealWidth: 280)
                        .accessibilitySortPriority(AccessibilityPriority.secondary)

                    ScrollView {
                        VStack(spacing: 16) {
                            MaterialPanel(
                                model: model,
                                materials: materials,
                                cutters: cutters,
                                profile: profile
                            )
                            GenerateControls(model: model)
                        }
                        .frame(minWidth: 340, idealWidth: 460)
                    }
                    .accessibilityIdentifier("main-screen-job-panel")
                    .accessibilityLabel("Carving material, job settings, and generation")
                    .accessibilitySortPriority(AccessibilityPriority.primary)

                    SimulationPanel(model: model)
                        .frame(minWidth: 230, idealWidth: 320)
                        .accessibilitySortPriority(AccessibilityPriority.footer)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("CNCswift job workspace")
            }
            .padding(16)
        }
        .accessibilityIdentifier("main-screen")
        .accessibilityLabel("CNCswift main screen")
        .sheet(
            isPresented: Binding(
                get: { model.isUnitsSheetPresented },
                set: { model.setUnitsSheetPresented($0) }
            )
        ) {
            ConfirmUnitsSheet(model: model, draft: model.unitsDraft)
        }
        .fileImporter(
            isPresented: Binding(
                get: { model.isFileImporterPresented },
                set: { model.setFileImporterPresented($0) }
            ),
            allowedContentTypes: [stlType],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task {
                _ = await model.loadModel?(url)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("CNCswift")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilitySortPriority(AccessibilityPriority.header)
                Text(profile.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Machine profile: \(profile.displayName)")
                    .accessibilitySortPriority(AccessibilityPriority.header)
            }
            Spacer()
            if let name = model.modelFileName {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Loaded model: \(name)")
                    .accessibilitySortPriority(AccessibilityPriority.status)
            }
            Button("Confirm units…") {
                model.setUnitsSheetPresented(true)
            }
            .disabled(!model.hasLoadedModel)
            .accessibilityLabel("Confirm units and orientation")
            .accessibilityHint("Confirm millimetres and Z-up before generating a program")
            .accessibilityIdentifier("confirm-units-button")
            .accessibilitySortPriority(AccessibilityPriority.primary)
            Button("Load STL…") {
                model.setFileImporterPresented(true)
            }
            .accessibilityLabel("Load STL file")
            .accessibilityHint("Choose an STL file from this Mac")
            .accessibilityIdentifier("load-stl-button")
            .accessibilitySortPriority(AccessibilityPriority.primary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CNCswift header")
    }
}
