import CNCStorage
import Foundation

/// Writes rendered programs to disk. Full implementation is provided by task T059.
public struct FileWriter: ProgramWriter, Sendable {
    private let fileSystem: any FileSystem

    public init(fileSystem: any FileSystem = DiskFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func write(_ program: RenderedProgram, to url: URL) async throws {
        _ = program
        _ = url
    }
}
