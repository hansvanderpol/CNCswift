import CNCCutters
import CNCCuttersStore
import Foundation

/// The modal's write path to the one shared persisted cutter library (FR-056, FR-058).
///
/// The editor does not keep its own copy of the library: both the modal and the main screen
/// re-resolve cutters from the store (research D14).
public struct CutterLibraryCoordinator: Sendable {
    private let store: CutterLibraryStore
    private let libraryURL: URL

    public init(store: CutterLibraryStore, libraryURL: URL) {
        self.store = store
        self.libraryURL = libraryURL
    }

    /// Creates or replaces one cutter by stable identifier without relaunch (FR-042, FR-050).
    public func save(_ cutter: Cutter) async throws {
        let existing: [Cutter]
        switch try await store.load(from: libraryURL) {
        case .loaded(let cutters), .migrated(_, let cutters):
            existing = cutters
        case .absent, .refused, .corrupt:
            existing = []
        }
        var updated = existing.filter { $0.id != cutter.id }
        updated.append(cutter)
        try await store.save(updated, to: libraryURL)
    }
}
