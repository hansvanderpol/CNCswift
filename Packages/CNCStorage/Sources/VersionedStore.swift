import Foundation

/// Reads and writes one versioned JSON document with atomic replacement, a retained backup, and
/// forward-only migrations (FR-051, FR-052, FR-053, FR-054, research D9).
///
/// The store owns no policy about the payload. The cutter library and the material library both
/// use this type so their durability contract cannot drift.
public struct VersionedStore<Payload: Codable & Sendable>: Sendable {
    private let fileSystem: any FileSystem
    private let currentVersion: Int
    private let migrations: [Int: @Sendable (Data) throws -> Data]

    /// Creates a store for a payload type.
    ///
    /// - Parameters:
    ///   - fileSystem: The filesystem seam; production uses `DiskFileSystem`.
    ///   - currentVersion: The schema version this app writes and understands.
    ///   - migrations: One data-to-data step per source version, applied in ascending order.
    public init(
        fileSystem: any FileSystem,
        currentVersion: Int,
        migrations: [Int: @Sendable (Data) throws -> Data] = [:]
    ) {
        self.fileSystem = fileSystem
        self.currentVersion = currentVersion
        self.migrations = migrations
    }

    /// Reads the document at `url`, migrating an older version forward when possible.
    ///
    /// - Returns: `.absent` when nothing exists, `.loaded` at the current version, `.migrated`
    ///   after a successful forward migration, `.refused` for a newer schema, and `.corrupt`
    ///   when the payload cannot be decoded.
    /// - Throws: `StorageError.migrationFailed` when a required migration step is missing or
    ///   fails. The file is never written to during a load, so the original bytes survive.
    public func load(from url: URL) throws -> LoadOutcome<Payload> {
        guard fileSystem.exists(url) else {
            return .absent
        }

        let data = try fileSystem.read(url)

        let header: SchemaHeader
        do {
            header = try JSONDecoder().decode(SchemaHeader.self, from: data)
        } catch {
            return .corrupt(detail: String(describing: error))
        }

        if header.schemaVersion > currentVersion {
            return .refused(found: header.schemaVersion)
        }

        if header.schemaVersion < currentVersion {
            let migratedData = try migrate(data, from: header.schemaVersion)
            guard let payload = try? decodePayload(from: migratedData) else {
                return .corrupt(detail: "Migrated document is not decodable")
            }
            return .migrated(from: header.schemaVersion, document: payload)
        }

        guard let payload = try? decodePayload(from: data) else {
            return .corrupt(detail: "Document payload is not decodable")
        }
        return .loaded(payload)
    }

    /// Writes `payload` at the current schema version.
    ///
    /// The write replaces the document in one step and retains the previous file at
    /// `<url>.backup` (FR-051, FR-054).
    public func save(_ payload: Payload, to url: URL) throws {
        let envelope = DocumentEnvelope(payload: payload, schemaVersion: currentVersion)
        let data = try encoder.encode(envelope)

        if fileSystem.exists(url) {
            try fileSystem.replace(data, at: url, backupURL: Self.backupURL(for: url))
        } else {
            try fileSystem.write(data, to: url)
        }
    }

    /// The recovery path retained beside a stored document.
    public static func backupURL(for url: URL) -> URL {
        url.appendingPathExtension("backup")
    }

    private func decodePayload(from data: Data) throws -> Payload {
        try JSONDecoder().decode(DocumentEnvelope<Payload>.self, from: data).payload
    }

    private func migrate(_ data: Data, from version: Int) throws -> Data {
        var migrated = data
        var sourceVersion = version

        while sourceVersion < currentVersion {
            guard let step = migrations[sourceVersion] else {
                throw StorageError.migrationFailed(
                    version: sourceVersion,
                    detail: "No migration registered from schema version \(sourceVersion)"
                )
            }
            do {
                migrated = try step(migrated)
            } catch {
                throw StorageError.migrationFailed(
                    version: sourceVersion,
                    detail: String(describing: error)
                )
            }
            sourceVersion += 1
        }

        return migrated
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
