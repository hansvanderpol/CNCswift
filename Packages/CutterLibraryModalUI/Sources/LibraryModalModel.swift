import CNCCutters
import CNCCuttersStore
import Foundation
import Observation

/// The cutter-library modal's own view model (FR-058, FR-059).
///
/// It holds the selected record's form state and persists through the one injected store. It has
/// no reference to the main screen: the store's change stream is the only bridge between them.
///
/// - Concurrency: Main-actor isolated; observed directly by SwiftUI.
@Observable
@MainActor
public final class LibraryModalModel {
    /// The cutters currently read from the persisted library.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public private(set) var cutters: [Cutter] = []

    /// An actionable description of the last failed load, save, or delete.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public private(set) var errorMessage: String?

    private let store: CutterLibraryStore
    private let libraryURL: URL
    private let coordinator: CutterLibraryCoordinator

    /// Creates the model with the injected `store` and `libraryURL`.
    public init(store: CutterLibraryStore, libraryURL: URL) {
        self.store = store
        self.libraryURL = libraryURL
        coordinator = CutterLibraryCoordinator(store: store, libraryURL: libraryURL)
    }

    /// Reloads the cutter list from the persisted document, reporting load states to the user.
    ///
    /// - Concurrency: Main-actor isolated; awaits the asynchronous store load.
    public func load() async {
        do {
            switch try await store.load(from: libraryURL) {
            case .loaded(let values), .migrated(_, let values):
                cutters = values
                errorMessage = nil
            case .absent:
                cutters = []
                errorMessage = nil
            case .refused(let found, let path):
                errorMessage =
                    "Library at \(path) uses schema \(found), newer than this app supports."
            case .corrupt(let path, let detail):
                errorMessage = "Library at \(path) could not be read: \(detail)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Creates or replaces one cutter by stable identifier, then refreshes the list.
    ///
    /// - Throws: An error from the coordinator when the cutter cannot be saved.
    /// - Concurrency: Main-actor isolated; awaits the asynchronous save and reload.
    public func save(_ cutter: Cutter) async throws {
        try await coordinator.save(cutter)
        await load()
    }

    /// Deletes one cutter by stable identifier, then refreshes the list.
    ///
    /// - Throws: An error from the store when the cutter cannot be deleted.
    /// - Concurrency: Main-actor isolated; awaits the asynchronous delete and reload.
    public func delete(id: CutterID) async throws {
        try await store.delete(id: id, from: libraryURL)
        await load()
    }
}
