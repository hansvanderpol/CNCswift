import CNCCutters
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CNCCuttersStore

private struct LibraryDocument: Codable, Equatable, Sendable {
    var cutters: [Cutter]
}

private struct DocumentEnvelope<Payload: Codable>: Codable {
    var payload: Payload
    var schemaVersion: Int
}

private enum FakeError: Error, Equatable {
    case missing
}

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw FakeError.missing }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        files.withLock { storage in
            if let previous = storage[url] {
                storage[backupURL] = previous
            }
            storage[url] = data
        }
    }

    func exists(_ url: URL) -> Bool {
        files.withLock { $0[url] != nil }
    }

    func remove(_ url: URL) throws {
        files.withLock { $0[url] = nil }
    }
}

private func cutter() -> Cutter {
    Cutter(
        id: CutterID("cutter-1"),
        name: "6mm flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
}

@Test func newerSchemaIsRefusedWithPathAndOriginalBytesIntact() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let future = DocumentEnvelope(payload: LibraryDocument(cutters: [cutter()]), schemaVersion: 2)
    let original = try JSONEncoder().encode(future)
    try fs.write(original, to: url)

    let sut = CutterLibraryStore(fileSystem: fs, currentVersion: 1)
    let outcome = try await sut.load(from: url)

    guard case .refused(found: let version, path: let path) = outcome else {
        Issue.record("expected refused")
        return
    }
    #expect(version == 2)
    #expect(path == url.path)
    #expect(try fs.read(url) == original)
}

@Test func corruptDocumentIsReportedWithPathAndOriginalBytesIntact() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let original = Data("not json".utf8)
    try fs.write(original, to: url)

    let sut = CutterLibraryStore(fileSystem: fs, currentVersion: 1)
    let outcome = try await sut.load(from: url)

    guard case .corrupt(path: let path, detail: let detail) = outcome else {
        Issue.record("expected corrupt")
        return
    }
    #expect(path == url.path)
    #expect(!detail.isEmpty)
    #expect(try fs.read(url) == original)
}
