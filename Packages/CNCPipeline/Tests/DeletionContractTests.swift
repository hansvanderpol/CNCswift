import CNCCutters
import CNCCuttersStore
import CNCMachineProfile
import CNCMaterials
import CNCStorage
import CNCToolpath
import Foundation
import MainScreenUI
import Synchronization
import Testing

/// Cutter-deletion contract from the neutral pipeline target (FR-060, SC-007).
///
/// The pipeline test target may import both presentation modules, so it is the right home for this
/// cross-module test. The main screen must consume the store's change stream, re-resolve by stable
/// identifier, clear a deleted selection and block generation until a stored cutter is chosen.
/// T086 owns the model-side implementation.

private enum ContractError: Error, Equatable {
    case missing
}

private final class ContractFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else { throw ContractError.missing }
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

private func cutter(id: String, name: String) -> Cutter {
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

@MainActor private func readyModel() throws -> MainScreenModel {
    let values = try EffectiveCuttingValues(
        feed: 600,
        spindle: 8000,
        source: .userChoice,
        material: Presets.all[1],
        profile: TTC450Pro.profile
    ).confirming()
    return MainScreenModel(
        effectiveValues: values,
        suggestion: JobSuggestion(
            stepover: 2.4,
            maxDepthPerPass: 2,
            finishingAllowance: 0.5,
            confirmed: true
        ),
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )
}

private func storedCutters(
    in store: CutterLibraryStore,
    at url: URL
) async throws -> [Cutter] {
    switch try await store.load(from: url) {
    case .loaded(let cutters), .migrated(_, let cutters):
        return cutters
    case .absent, .refused, .corrupt:
        Issue.record("expected a readable cutter library")
        return []
    }
}

@Test @MainActor func deletingTheSelectedCutterClearsSelectionAndBlocksGeneration() async throws {
    let fileSystem = ContractFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let changes = await store.changes
    let first = cutter(id: "cutter-1", name: "6mm flat")
    let second = cutter(id: "cutter-2", name: "4mm flat")
    try await store.save([first, second], to: url)

    let model = try readyModel()
    model.selectCutter(first.id)
    #expect(!model.blockers().contains(.emptyCutterSelection))

    try await store.delete(id: first.id, from: url)

    var iterator = changes.makeAsyncIterator()
    #expect(await iterator.next() == .saved)
    let change = await iterator.next()
    #expect(change == .deleted(id: first.id))

    let library = try await storedCutters(in: store, at: url)
    guard let change else {
        Issue.record("the deletion must be published on the change stream")
        return
    }
    model.applyLibraryChange(change, library: library)

    #expect(model.selectedCutterID == nil, "a deleted selection must be cleared")
    #expect(model.resolvedCutter(in: library) == nil)
    #expect(model.blockers().contains(.emptyCutterSelection))

    model.selectCutter(second.id)
    #expect(!model.blockers().contains(.emptyCutterSelection))
    #expect(model.resolvedCutter(in: library)?.id == second.id)
}

@Test @MainActor func savedCutterEventReResolvesTheSelectedIdentifier() async throws {
    let fileSystem = ContractFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let changes = await store.changes
    let original = cutter(id: "cutter-1", name: "6mm flat")
    let edited = original.renamed(to: "6mm flat, sharpened")
    try await store.save([original], to: url)
    try await store.save([edited], to: url)

    let model = try readyModel()
    model.selectCutter(original.id)

    var iterator = changes.makeAsyncIterator()
    #expect(await iterator.next() == .saved)
    let change = await iterator.next()
    #expect(change == .saved)
    let library = try await storedCutters(in: store, at: url)
    guard let change else {
        Issue.record("the save must be published on the change stream")
        return
    }
    model.applyLibraryChange(change, library: library)

    #expect(model.selectedCutterID == original.id, "the stable identifier survives an edit")
    #expect(model.resolvedCutter(in: library)?.name == edited.name)
    #expect(!model.blockers().contains(.emptyCutterSelection))
}

@Test @MainActor func deletingAnotherCutterLeavesTheSelectionIntact() async throws {
    let fileSystem = ContractFileSystem()
    let url = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let changes = await store.changes
    let selected = cutter(id: "cutter-1", name: "6mm flat")
    let other = cutter(id: "cutter-2", name: "4mm flat")
    try await store.save([selected, other], to: url)

    let model = try readyModel()
    model.selectCutter(selected.id)
    try await store.delete(id: other.id, from: url)

    var iterator = changes.makeAsyncIterator()
    #expect(await iterator.next() == .saved)
    let change = await iterator.next()
    #expect(change == .deleted(id: other.id))
    let library = try await storedCutters(in: store, at: url)
    guard let change else {
        Issue.record("the deletion must be published on the change stream")
        return
    }
    model.applyLibraryChange(change, library: library)

    #expect(model.selectedCutterID == selected.id)
    #expect(model.resolvedCutter(in: library)?.id == selected.id)
    #expect(!model.blockers().contains(.emptyCutterSelection))
}
