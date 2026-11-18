import CNCCutters
import CNCStorage
import Foundation
import Synchronization
import Testing

@testable import CNCCuttersStore

private enum FakeError: Error, Equatable {
    case missing
    case write
}

private final class FakeFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])
    let failReplace = Mutex(false)

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw FakeError.missing }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        files.withLock { $0[url] = data }
    }

    func replace(_ data: Data, at url: URL, backupURL: URL) throws {
        guard !failReplace.withLock({ $0 }) else { throw FakeError.write }
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

private func cutter(id: String = "cutter-1", name: String = "6mm flat") -> Cutter {
    Cutter(
        id: CutterID(id),
        name: name,
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

@Test func changeStreamDeliversSavedDeletedAndReloadedInOrder() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let first = cutter(id: "cutter-1")
    let second = cutter(id: "cutter-2", name: "4mm flat")
    let store = CutterLibraryStore(fileSystem: fs, currentVersion: 1)
    let stream = await store.changes

    try await store.save([first, second], to: url)
    try await store.delete(id: first.id, from: url)
    _ = try await store.reload(from: url)

    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == .saved)
    #expect(await iterator.next() == .deleted(id: first.id))
    #expect(await iterator.next() == .reloaded)
}

@Test func bufferedStreamDoesNotDropEventsPublishedBeforeConsumption() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let first = cutter(id: "cutter-1")
    let second = cutter(id: "cutter-2", name: "4mm flat")
    let store = CutterLibraryStore(fileSystem: fs, currentVersion: 1)

    try await store.save([first], to: url)
    let stream = await store.changes
    try await store.save([first, second], to: url)
    try await store.delete(id: second.id, from: url)

    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == .saved)
    #expect(await iterator.next() == .deleted(id: second.id))
}

@Test func failedSaveDoesNotPublishASavedEvent() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let first = cutter(id: "cutter-1")
    let second = cutter(id: "cutter-2", name: "4mm flat")
    let store = CutterLibraryStore(fileSystem: fs, currentVersion: 1)
    let stream = await store.changes
    var iterator = stream.makeAsyncIterator()

    try await store.save([first], to: url)
    #expect(await iterator.next() == .saved)

    fs.failReplace.withLock { $0 = true }
    await #expect(throws: FakeError.self) {
        try await store.save([second], to: url)
    }
    fs.failReplace.withLock { $0 = false }

    try await store.delete(id: first.id, from: url)
    #expect(await iterator.next() == .deleted(id: first.id))
}

@Test func savedValuesAreNotSharedMutableState() async throws {
    let fs = FakeFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    var cutters = [cutter()]
    let store = CutterLibraryStore(fileSystem: fs, currentVersion: 1)

    try await store.save(cutters, to: url)
    cutters[0] = cutters[0].renamed(to: "Mutated after save")

    let outcome = try await store.load(from: url)
    guard case .loaded(let loaded) = outcome else {
        Issue.record("expected loaded")
        return
    }
    #expect(loaded.first?.name == "6mm flat")
    #expect(
        LibraryChange.deleted(id: cutters[0].id)
            == .deleted(id: loaded.first?.id ?? CutterID("none")))
}
