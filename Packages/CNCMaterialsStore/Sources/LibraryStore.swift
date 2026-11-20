import CNCMaterials
import CNCStorage
import Foundation

/// The state of a stored user-material document.
///
/// `absent`, `refused`, and `corrupt` are reported, not thrown, so the original bytes stay intact.
public enum MaterialLibraryLoadOutcome: Sendable, Equatable {
    case absent
    case loaded([Material])
    case migrated(from: Int, materials: [Material])
    case refused(found: Int)
    case corrupt(path: String)
}

/// Persistence for user-defined materials; built-in presets are merged at load time.
public protocol MaterialLibraryStoring: Sendable {
    func load(from url: URL) async throws -> MaterialLibraryLoadOutcome
    func save(_ materials: [Material], to url: URL) async throws

    /// The shipped presets plus every stored user material, with no preset shadowed.
    func resolvedMaterials(from url: URL) async throws -> [Material]
}

private struct MaterialLibraryDocument: Codable, Equatable, Sendable {
    var materials: [Material]
}

/// Stores user materials over the shared versioned document primitive (FR-077).
///
/// Presets are code-shipped and never written to the document. A stored material that collides with
/// a preset is ignored on load and rejected on save, so user data can never shadow a shipped band.
public struct MaterialLibraryStore: MaterialLibraryStoring {
    private let store: VersionedStore<MaterialLibraryDocument>

    /// Creates a material store backed by the supplied file-system seam.
    ///
    /// - Parameters:
    ///   - fileSystem: The filesystem used for atomic reads and writes.
    ///   - currentVersion: The schema version this app writes.
    ///   - migrations: Forward migrations for older documents.
    public init(
        fileSystem: any FileSystem = DiskFileSystem(),
        currentVersion: Int = 1,
        migrations: [Int: @Sendable (Data) throws -> Data] = [:]
    ) {
        store = VersionedStore(
            fileSystem: fileSystem,
            currentVersion: currentVersion,
            migrations: migrations
        )
    }

    /// Loads only user materials from a versioned document.
    ///
    /// - Throws: `StorageError.migrationFailed` when a required forward migration is missing.
    public func load(from url: URL) async throws -> MaterialLibraryLoadOutcome {
        switch try store.load(from: url) {
        case .absent:
            return .absent
        case .loaded(let document):
            return .loaded(document.materials)
        case .migrated(let from, let document):
            return .migrated(from: from, materials: document.materials)
        case .refused(let found):
            return .refused(found: found)
        case .corrupt(let detail):
            _ = detail
            return .corrupt(path: url.path)
        }
    }

    /// Validates and atomically saves user materials.
    ///
    /// - Throws: `MaterialValidationError` for empty names, inverted bands, or collisions with a
    ///   preset or another saved material; `StorageError` when the atomic write fails.
    public func save(_ materials: [Material], to url: URL) async throws {
        var accepted = Presets.all
        for material in materials {
            try MaterialValidator.validate(material, against: accepted)
            accepted.append(material)
        }
        try store.save(MaterialLibraryDocument(materials: materials), to: url)
    }

    /// Returns presets first, then safely stored user materials.
    ///
    /// Documents that are absent, corrupt, or from a newer schema are never rewritten; the shipped
    /// presets are still returned so the UI can start in a usable state.
    public func resolvedMaterials(from url: URL) async throws -> [Material] {
        let stored: [Material]
        switch try await load(from: url) {
        case .loaded(let materials), .migrated(_, let materials):
            stored = materials
        case .absent, .refused, .corrupt:
            stored = []
        }

        let presetNames = Set(Presets.all.map(\.name))
        let presetIDs = Set(Presets.all.map(\.id))
        var seenNames = presetNames
        var seenIDs = presetIDs
        var merged = Presets.all

        for material in stored
        where !seenNames.contains(material.name) && !seenIDs.contains(material.id) {
            merged.append(material)
            seenNames.insert(material.name)
            seenIDs.insert(material.id)
        }

        return merged
    }
}
