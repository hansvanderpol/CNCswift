import Foundation
import Synchronization
import Testing

@testable import CNCStorage

private struct Payload: Codable, Equatable, Sendable {
    var value: String
}

private enum FakeError: Error {
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
        let previous = files.withLock { $0[url] }
        files.withLock { storage in
            if let previous {
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

private func store(
    fileSystem: FakeFileSystem,
    currentVersion: Int = 2,
    migrations: [Int: @Sendable (Data) throws -> Data] = [:]
) -> VersionedStore<Payload> {
    VersionedStore(fileSystem: fileSystem, currentVersion: currentVersion, migrations: migrations)
}

@Test func saveStampsTheCurrentSchemaVersion() throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")

    try store(fileSystem: fs).save(Payload(value: "first"), to: url)

    let envelope = try JSONDecoder().decode(DocumentEnvelope<Payload>.self, from: fs.read(url))
    #expect(envelope.schemaVersion == 2)
    #expect(envelope.payload == Payload(value: "first"))
}

@Test func secondSaveKeepsThePreviousFileAsBackup() throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let backup = URL(fileURLWithPath: "/sandbox/library.json.backup")
    let sut = store(fileSystem: fs)

    try sut.save(Payload(value: "first"), to: url)
    try sut.save(Payload(value: "second"), to: url)

    let previous = try JSONDecoder().decode(DocumentEnvelope<Payload>.self, from: fs.read(backup))
    let current = try JSONDecoder().decode(DocumentEnvelope<Payload>.self, from: fs.read(url))
    #expect(previous.payload.value == "first")
    #expect(current.payload.value == "second")
}

@Test func missingDocumentLoadsAsAbsent() throws {
    let fs = FakeFileSystem()
    let outcome = try store(fileSystem: fs).load(from: URL(fileURLWithPath: "/sandbox/absent.json"))

    guard case .absent = outcome else {
        Issue.record("expected absent")
        return
    }
}

@Test func olderSchemaMigratesForwardWithoutRecordLoss() throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let old = DocumentEnvelope(payload: Payload(value: "legacy"), schemaVersion: 1)
    try fs.write(try JSONEncoder().encode(old), to: url)

    let migrations: [Int: @Sendable (Data) throws -> Data] = [
        1: { data in
            var envelope = try JSONDecoder().decode(DocumentEnvelope<Payload>.self, from: data)
            envelope.payload.value += "-migrated"
            return try JSONEncoder().encode(envelope)
        }
    ]
    let outcome = try store(fileSystem: fs, migrations: migrations).load(from: url)

    guard case .migrated(from: let version, document: let payload) = outcome else {
        Issue.record("expected migrated")
        return
    }
    #expect(version == 1)
    #expect(payload == Payload(value: "legacy-migrated"))
}

@Test func newerSchemaIsRefusedAndFileIsByteIdentical() throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let future = DocumentEnvelope(payload: Payload(value: "future"), schemaVersion: 3)
    let original = try JSONEncoder().encode(future)
    try fs.write(original, to: url)

    let outcome = try store(fileSystem: fs, currentVersion: 2).load(from: url)

    guard case .refused(found: let version) = outcome else {
        Issue.record("expected refused")
        return
    }
    #expect(version == 3)
    #expect(try fs.read(url) == original)
}

@Test func corruptDocumentIsReported() throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    try fs.write(Data("not json".utf8), to: url)

    let outcome = try store(fileSystem: fs).load(from: url)

    guard case .corrupt = outcome else {
        Issue.record("expected corrupt")
        return
    }
}
