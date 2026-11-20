import Foundation

/// The minimal file-system surface the stores depend on.
///
/// Tests inject an in-memory implementation so persistence behaviour is proven without touching
/// real time or the real Application Support directory (Principle III, research D9).
///
/// - Concurrency: Conformers are `Sendable` so stores can be captured across tasks.
public protocol FileSystem: Sendable {
    /// Reads the complete contents of `url`.
    func read(_ url: URL) throws -> Data

    /// Writes `data` to `url`, creating missing parent directories.
    ///
    /// The implementation makes the new bytes visible in one step; a partially written file is
    /// never observable.
    func write(_ data: Data, to url: URL) throws

    /// Atomically replaces `url` with `data`, retaining the previous bytes at `backupURL`.
    func replace(_ data: Data, at url: URL, backupURL: URL) throws

    /// Reports whether `url` exists.
    func exists(_ url: URL) -> Bool

    /// Removes `url` when it exists.
    func remove(_ url: URL) throws
}

/// Errors the versioned store raises when durability cannot be guaranteed (FR-052, FR-054).
///
/// - Concurrency: Immutable and `Sendable`; safe to throw across task boundaries.
public enum StorageError: Error, Equatable, Sendable {
    /// A forward migration step failed, so the document was left untouched.
    case migrationFailed(version: Int, detail: String)

    /// The document could not be written or replaced.
    case writeFailed(path: String, detail: String)
}

/// The production file system, backed by `FileManager`.
///
/// - Concurrency: Immutable and `Sendable`; safe to share across tasks.
public struct DiskFileSystem: FileSystem {
    /// Creates a file system backed by the process `FileManager`.
    public init() {}

    /// Reads the complete contents at `url`.
    ///
    /// - Throws: The underlying `Data(contentsOf:)` error when the file cannot be read.
    public func read(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    /// Atomically writes `data` to `url`, creating parent directories as needed.
    ///
    /// - Throws: `StorageError.writeFailed` when the temporary write or move fails, or a
    ///   `FileManager` error when a parent directory cannot be created.
    public func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let temporary = temporaryURL(for: url)
        do {
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.moveItem(at: temporary, to: url)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw StorageError.writeFailed(path: url.path, detail: String(describing: error))
        }
    }

    /// Replaces `url` with `data`, copying the previous bytes to `backupURL`.
    ///
    /// - Throws: `StorageError.writeFailed` when the write or replacement fails, or a
    ///   `FileManager` error when a parent directory cannot be created.
    public func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            try write(data, to: url)
            return
        }

        let temporary = temporaryURL(for: url)
        do {
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: url, to: backupURL)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw StorageError.writeFailed(path: url.path, detail: String(describing: error))
        }
    }

    /// Reports whether a file exists at `url`.
    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Removes the file at `url` if one exists.
    ///
    /// - Throws: The underlying `FileManager` error when removal fails.
    public func remove(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func temporaryURL(for url: URL) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
    }
}
