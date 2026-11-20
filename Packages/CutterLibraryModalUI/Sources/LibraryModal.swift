import CNCCutters
import CNCCuttersStore
import SwiftUI

/// The cutter-library modal's module entry point (FR-056, FR-057, FR-059).
///
/// It depends only on the cutter domain, the cutter store, and SwiftUI. It neither imports nor
/// references the main screen, so it can be presented independently of G-code creation.
@MainActor
public struct LibraryModal: View {
    private let store: CutterLibraryStore
    private let libraryURL: URL
    private let model: LibraryModalModel
    private let editor: CutterEditorModel

    public init(store: CutterLibraryStore, libraryURL: URL) {
        self.store = store
        self.libraryURL = libraryURL
        model = LibraryModalModel(store: store, libraryURL: libraryURL)
        editor = CutterEditorModel()
    }

    /// Reads the persisted cutters directly, independent of any presented view state.
    public func loadCutters() async throws -> [Cutter] {
        switch try await store.load(from: libraryURL) {
        case .loaded(let cutters), .migrated(_, let cutters):
            return cutters
        case .absent, .refused, .corrupt:
            return []
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let message = model.errorMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("library-modal-error")
                }

                List {
                    Section("Stored cutters") {
                        if model.cutters.isEmpty {
                            Text("No cutters yet. Add one below.")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("library-modal-empty")
                        } else {
                            ForEach(model.cutters, id: \.id) { cutter in
                                cutterRow(cutter)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("library-modal-list")

                CutterEditor(model: editor)

                Button {
                    addCutter()
                } label: {
                    Label("Add cutter", systemImage: "plus")
                }
                .disabled(editorHasErrors())
                .accessibilityIdentifier("library-modal-add")
            }
            .padding(12)
            .navigationTitle("Cutter Library")
            .task {
                await model.load()
            }
        }
        .frame(minWidth: 480, minHeight: 560)
        .accessibilityIdentifier("cutter-library-modal")
    }

    @ViewBuilder
    private func cutterRow(_ cutter: Cutter) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cutter.name).font(.headline)
                Text(
                    "\(cutter.type.rawValue) · shank \(formatted(cutter.shankDiameter)) mm · "
                        + "cut \(formatted(cutter.maxCuttingExtent)) mm"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                Task {
                    try? await model.delete(id: cutter.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete \(cutter.name)")
        }
    }

    private func addCutter() {
        Task {
            guard let cutter = try? editor.makeCutter() else { return }
            try? await model.save(cutter)
            editor.fields = [:]
        }
    }

    private func editorHasErrors() -> Bool {
        editor.requiredFields().contains { editor.fieldError($0) != nil }
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.3f", value)
    }
}
