import CNCCutters
import CNCCuttersStore
import CNCDiagnostics
import CNCGCode
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCPipeline
import CNCStorage
import CNCToolpath
import CutterLibraryModalUI
import Foundation
import MainScreenUI
import Synchronization
import Testing

private enum ContractFixtureError: Error {
    case missing
}

private final class ContractFileSystem: FileSystem, @unchecked Sendable {
    let files = Mutex<[URL: Data]>([:])

    func read(_ url: URL) throws -> Data {
        guard let data = files.withLock({ $0[url] }) else {
            throw ContractFixtureError.missing
        }
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

private func contractCutter(name: String = "6mm flat") -> Cutter {
    Cutter(
        id: CutterID("8f3c1d2a-0b7e-4c55-9a1f-2d6e7c8b9a10"),
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

@Test @MainActor func modalCutterEditFlowsIntoTheNextHeaderWithoutRelaunch() async throws {
    let fileSystem = ContractFileSystem()
    let libraryURL = URL(fileURLWithPath: "/sandbox/library.json")
    let store = CutterLibraryStore(fileSystem: fileSystem)
    let modal = CutterLibraryCoordinator(store: store, libraryURL: libraryURL)
    let profile = TTC450Pro.profile
    let material = Presets.all[1]

    let original = contractCutter()
    try await modal.save(original)
    let edited = original.renamed(to: "6mm flat v2")
    try await modal.save(edited)

    let outcome = try await store.load(from: libraryURL)
    guard case .loaded(let library) = outcome else {
        Issue.record("expected the edited library to load, got \(outcome)")
        return
    }

    // The same main-screen instance is reused across the modal edit: no relaunch (SC-007).
    let mainScreen = MainScreenModel()
    mainScreen.selectCutter(edited.id)
    let resolved = mainScreen.resolvedCutter(in: library)
    #expect(resolved?.id == edited.id, "a stored edit must re-resolve by stable identifier")

    let selected = resolved ?? edited
    let effective: EffectiveCuttingValues
    switch EffectiveCuttingValues.resolve(material: material, cutter: selected, profile: profile) {
    case .resolved(let values):
        effective = values
    case .noOverlap(let conflicts):
        Issue.record("the preset material must overlap the profile, got \(conflicts)")
        return
    }
    let feedCeiling = min(material.feedBand.upperBound, profile.limits.maxFeedRate)
    let spindleFloor = max(material.spindleBand.lowerBound, profile.limits.spindleMin)
    let spindleCeiling = min(material.spindleBand.upperBound, profile.limits.spindleMax)
    #expect(
        effective.feed >= material.feedBand.lowerBound && effective.feed <= feedCeiling,
        "the prefilled feed must lie inside the feed intersection (FR-079)"
    )
    #expect(
        effective.spindle >= spindleFloor && effective.spindle <= spindleCeiling,
        "the prefilled spindle must lie inside the spindle intersection (FR-079)"
    )

    let bounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 200, y: 150, z: 30)
    )
    let mesh = Mesh(triangles: [
        Triangle(
            a: Vec3(x: 0, y: 0, z: 30),
            b: Vec3(x: 200, y: 0, z: 30),
            c: Vec3(x: 0, y: 150, z: 30)
        )
    ])
    let job = JobSettings(
        mesh: mesh,
        modelBounds: bounds,
        stock: StockBlank(width: 200, depth: 150, height: 30),
        cutter: selected,
        materialID: material.id,
        effective: effective.confirming(),
        stepover: 2.4,
        maxDepthPerPass: 2,
        finishingAllowance: 0.5,
        unitsConfirmed: true,
        orientationConfirmed: true,
        rapidRateConfirmed: true,
        confirmed: true
    )
    let toolpath = Toolpath(
        moves: [
            Move(
                from: Vec3(x: 0, y: 0, z: 10),
                to: Vec3(x: 10, y: 10, z: -1),
                mode: .cut
            )
        ],
        feedRate: job.effective.feed,
        bounds: bounds
    )
    let rendered = try GCodeEmitter().render(
        toolpath,
        cutter: selected,
        material: material,
        job: job,
        profile: profile,
        generatedAt: Date(timeIntervalSince1970: 0)
    )
    let header = rendered.text.components(separatedBy: "\n").prefix { $0.hasPrefix(";") }
    #expect(header.contains("; cutter: \(edited.id)"))
    #expect(header.contains("; cutter-name: 6mm flat v2"))
}
