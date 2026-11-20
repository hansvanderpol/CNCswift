import CNCStorage
import Foundation

/// Writes a rendered program as exactly one deterministic ASCII `.nc` file (FR-018, FR-027).
///
/// The destination URL contributes only its parent directory. The file name is derived from the
/// generation record's model basename under `contracts/gcode-output.md`. Existing files are
/// replaced atomically through the injected file system; cancellation is checked before any bytes
/// are made visible.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct FileWriter: ProgramWriter, Sendable {
    private let fileSystem: any FileSystem

    /// Creates a writer backed by the given file system.
    ///
    /// - Parameter fileSystem: The file-system seam used for existence checks and atomic writes.
    public init(fileSystem: any FileSystem = DiskFileSystem()) {
        self.fileSystem = fileSystem
    }

    /// Writes one atomically replaced `.nc` file.
    ///
    /// - Parameters:
    ///   - program: The validated program whose exact text is written.
    ///   - url: A URL whose parent directory receives the derived output file.
    /// - Throws: `CancellationError` if cancelled before the write, or the file system's error if
    ///   the atomic write fails. No partial file is left behind on failure.
    /// - Concurrency: `async`; checks cancellation before exposure of the written file.
    public func write(_ program: RenderedProgram, to url: URL) async throws {
        try Task.checkCancellation()

        let fileName = OutputFileName.deriving(
            from: program.record.modelFileName,
            fileExtension: program.record.profile.outputExtension
        )
        let target = url.deletingLastPathComponent().appendingPathComponent(fileName)
        let data = Data(program.text.utf8)

        try Task.checkCancellation()
        if fileSystem.exists(target) {
            try fileSystem.replace(
                data,
                at: target,
                backupURL: target.appendingPathExtension("backup")
            )
        } else {
            try fileSystem.write(data, to: target)
        }
    }
}
