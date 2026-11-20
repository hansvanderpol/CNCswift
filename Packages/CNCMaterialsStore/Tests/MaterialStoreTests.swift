import CNCMaterials
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CNCMaterialsStore

private struct MaterialDocument: Codable, Equatable, Sendable {
    var materials: [Material]
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

private func userMaterial(
    id: String = "user-walnut",
    name: String = "Walnut"
) -> Material {
    Material(
        id: id,
        name: name,
        feedBand: 450...650,
        spindleBand: 7000...8000,
        origin: .user,
        shippedVersion: nil
    )
}

private func documentURL() -> URL {
    URL(fileURLWithPath: "/sandbox/materials.json")
}

@Test func saveAndLoadRoundTripPreservesTheUserMaterial() async throws {
    let fs = FakeFileSystem()
    let url = documentURL()
    let material = userMaterial()
    let store = MaterialLibraryStore(fileSystem: fs)

    try await store.save([material], to: url)
    let outcome = try await store.load(from: url)

    guard case .loaded(let materials) = outcome else {
        Issue.record("expected loaded, got \(outcome)")
        return
    }
    #expect(materials == [material])
}

@Test func missingDocumentLoadsAsAbsent() async throws {
    let store = MaterialLibraryStore(fileSystem: FakeFileSystem())

    let outcome = try await store.load(from: documentURL())

    guard case .absent = outcome else {
        Issue.record("expected absent, got \(outcome)")
        return
    }
}

@Test func presetsMergeWithUserMaterialsWithoutShadowing() async throws {
    let fs = FakeFileSystem()
    let url = documentURL()
    let custom = userMaterial()
    let envelope = DocumentEnvelope(
        payload: MaterialDocument(materials: [custom]),
        schemaVersion: 1
    )
    try fs.write(try JSONEncoder().encode(envelope), to: url)

    let materials = try await MaterialLibraryStore(fileSystem: fs).resolvedMaterials(from: url)

    #expect(materials.count == Presets.all.count + 1)
    #expect(materials.contains(custom))
    for preset in Presets.all {
        #expect(materials.contains(preset), "shipped preset \(preset.name) must survive the merge")
    }
    #expect(Set(materials.map(\.name)).count == materials.count, "no material name may be shadowed")
}

@Test func aUserMaterialShadowingAPresetIsRejectedAtSave() async throws {
    let store = MaterialLibraryStore(fileSystem: FakeFileSystem())
    let shadow = userMaterial(id: "user-mdf", name: "MDF")

    do {
        try await store.save([shadow], to: documentURL())
        Issue.record("a user material may not shadow a shipped preset name")
    } catch MaterialValidationError.duplicateName(let name) {
        #expect(name == "MDF")
    } catch {
        Issue.record("expected duplicateName(\"MDF\"), got \(error)")
    }
}

@Test func newerSchemaIsRefusedAndTheDocumentIsLeftUntouched() async throws {
    let fs = FakeFileSystem()
    let url = documentURL()
    let envelope = DocumentEnvelope(
        payload: MaterialDocument(materials: [userMaterial()]),
        schemaVersion: 2
    )
    let originalBytes = try JSONEncoder().encode(envelope)
    try fs.write(originalBytes, to: url)

    let outcome = try await MaterialLibraryStore(fileSystem: fs).load(from: url)

    guard case .refused(let found) = outcome else {
        Issue.record("expected refused, got \(outcome)")
        return
    }
    #expect(found == 2)
    #expect(try fs.read(url) == originalBytes, "a newer document must not be rewritten")
}
