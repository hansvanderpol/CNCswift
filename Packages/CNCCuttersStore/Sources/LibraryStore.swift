import CNCCutters
import CNCStorage
import Foundation

/// The persisted cutter library payload.
///
/// The document is `{ "schemaVersion": n, "payload": { "cutters": [...] } }`; the schema version
/// and durability rules are owned by `CNCStorage` (FR-051).
public struct CutterLibraryDocument: Codable, Equatable, Sendable {
    public var cutters: [Cutter]

    public init(cutters: [Cutter]) {
        self.cutters = cutters
    }
}

/// Every state a load can report.
///
/// Only a migration failure throws; `absent`, `refused`, and `corrupt` are reported with the path
/// that produced them so the UI can explain what happened (FR-053, FR-054).
public enum CutterLibraryLoadOutcome: Sendable, Equatable {
    /// The document was read at the current schema version.
    case loaded([Cutter])

    /// The document was migrated forward from `from` without losing any cutter.
    case migrated(from: Int, cutters: [Cutter])

    /// No document exists yet; the library starts empty.
    case absent

    /// The document is newer than this app supports and was left byte-identical.
    case refused(found: Int, path: String)

    /// The document could not be decoded and was left byte-identical.
    case corrupt(path: String, detail: String)
}

/// The single cutter-library store injected into both presentation modules (FR-058).
///
/// The actor owns the change stream and all reads and writes, so no view or planner can mutate the
/// library directly. Reads and writes are path-parameterised: the composition root decides where
/// the library lives (FR-051).
public actor CutterLibraryStore {
    private let store: VersionedStore<CutterLibraryDocument>
    private let changeRegistry = LibraryChangeRegistry()

    /// Creates a store over one filesystem.
    ///
    /// - Parameters:
    ///   - fileSystem: The filesystem seam; production uses `DiskFileSystem`.
    ///   - currentVersion: The cutter schema version this app writes and understands.
    ///   - migrations: One data-to-data step per source version, applied in ascending order.
    public init(
        fileSystem: any FileSystem,
        currentVersion: Int = 1,
        migrations: [Int: @Sendable (Data) throws -> Data] = [:]
    ) {
        self.store = VersionedStore(
            fileSystem: fileSystem,
            currentVersion: currentVersion,
            migrations: migrations
        )
    }

    /// A buffered stream of library changes, one independent buffer per call.
    ///
    /// Consumers re-resolve by identifier after each event (FR-060).
    public var changes: AsyncStream<LibraryChange> {
        changeRegistry.makeStream()
    }

    /// Reads the library, reporting every load state with its path.
    ///
    /// - Throws: `StorageError.migrationFailed` when a forward migration cannot complete; the
    ///   stored file is never modified by a load.
    public func load(from url: URL) async throws -> CutterLibraryLoadOutcome {
        switch try store.load(from: url) {
        case .absent:
            return .absent
        case .loaded(let document):
            return .loaded(document.cutters)
        case .migrated(from: let version, let document):
            return .migrated(from: version, cutters: document.cutters)
        case .refused(found: let version):
            return .refused(found: version, path: url.path)
        case .corrupt(let detail):
            return .corrupt(path: url.path, detail: detail)
        }
    }

    /// Writes the whole library atomically and publishes `.saved` only after the write succeeds.
    ///
    /// - Throws: A storage error when the write fails; no event is published in that case.
    public func save(_ cutters: [Cutter], to url: URL) async throws {
        try store.save(CutterLibraryDocument(cutters: cutters), to: url)
        changeRegistry.publish(.saved)
    }

    /// Removes one cutter and publishes `.deleted(id:)` only after the atomic save succeeds.
    ///
    /// An unreadable document is never overwritten: a refused or corrupt library is left exactly
    /// as it was until the user resolves it.
    public func delete(id: CutterID, from url: URL) async throws {
        let existing: [Cutter]
        switch try store.load(from: url) {
        case .loaded(let document), .migrated(_, let document):
            existing = document.cutters
        case .absent:
            existing = []
        case .refused, .corrupt:
            return
        }

        try store.save(
            CutterLibraryDocument(cutters: existing.filter { $0.id != id }),
            to: url
        )
        changeRegistry.publish(.deleted(id: id))
    }

    /// Re-reads the library and publishes `.reloaded`.
    public func reload(from url: URL) async throws -> CutterLibraryLoadOutcome {
        let outcome = try await load(from: url)
        changeRegistry.publish(.reloaded)
        return outcome
    }
}
