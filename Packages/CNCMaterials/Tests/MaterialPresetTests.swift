import Foundation
import Testing

@testable import CNCMaterials

private struct PresetFixture: Decodable {
    struct Band: Decodable {
        let lower: Double
        let upper: Double
    }

    struct Preset: Decodable {
        let id: String
        let name: String
        let feedBand: Band
        let spindleBand: Band
        let shippedVersion: String?
    }

    let status: String
    let presets: [Preset]
}

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func presetFixtureURL() -> URL {
    repositoryRoot()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("materials", isDirectory: true)
        .appendingPathComponent("presets.json")
}

private func material(
    id: String = "user-1",
    name: String = "Reclaimed oak",
    feedLower: Double = 350,
    feedUpper: Double = 550,
    spindleLower: Double = 7000,
    spindleUpper: Double = 8000,
    origin: MaterialOrigin = .user,
    shippedVersion: String? = nil
) -> Material {
    Material(
        id: id,
        name: name,
        feedBand: MaterialBand(feedLower, feedUpper),
        spindleBand: MaterialBand(spindleLower, spindleUpper),
        origin: origin,
        shippedVersion: shippedVersion
    )
}

@Test func exactlyFourPresetsShipWithStableNamesAndOrderedBands() throws {
    let presets = Presets.all

    #expect(presets.count == 4)
    #expect(
        presets.map(\.name) == [
            "Softwood (pine/basswood)",
            "Hardwood (oak/maple)",
            "MDF",
            "Plywood",
        ])
    for preset in presets {
        try MaterialValidator.validate(preset, against: [])
        #expect(preset.origin == .builtIn)
        #expect(preset.feedBand.lowerBound > 0)
        #expect(preset.feedBand.upperBound >= preset.feedBand.lowerBound)
        #expect(preset.spindleBand.lowerBound > 0)
        #expect(preset.spindleBand.upperBound >= preset.spindleBand.lowerBound)
    }
}

@Test func presetBandsMatchTheShippedTable() {
    #expect(Presets.all[0].feedBand == 600...800)
    #expect(Presets.all[1].feedBand == 400...600)
    #expect(Presets.all[2].feedBand == 500...700)
    #expect(Presets.all[3].feedBand == 500...700)
    #expect(Presets.all.allSatisfy { $0.spindleBand == 7000...8000 })
}

@Test func presetFixtureMatchesTheShippedTableAndStaysProvisional() throws {
    let fixture = try JSONDecoder().decode(
        PresetFixture.self,
        from: Data(contentsOf: presetFixtureURL())
    )

    // Research D11: the fixture is provisional until T111 records cutting-experience sign-off.
    #expect(fixture.status == "provisional")
    #expect(fixture.presets.count == 4)
    #expect(Presets.all.count == fixture.presets.count)
    #expect(fixture.presets.map(\.name) == Presets.all.map(\.name))
    #expect(fixture.presets.map(\.id) == Presets.all.map(\.id))

    for (row, preset) in zip(fixture.presets, Presets.all) {
        #expect(row.feedBand.lower == preset.feedBand.lowerBound)
        #expect(row.feedBand.upper == preset.feedBand.upperBound)
        #expect(row.spindleBand.lower == preset.spindleBand.lowerBound)
        #expect(row.spindleBand.upper == preset.spindleBand.upperBound)
        #expect(row.shippedVersion == "provisional")
        #expect(preset.shippedVersion == row.shippedVersion)

        let bounds = [
            row.feedBand.lower, row.feedBand.upper,
            row.spindleBand.lower, row.spindleBand.upper,
        ]
        #expect(bounds.allSatisfy { $0 > 0 })
        #expect(row.feedBand.lower <= row.feedBand.upper)
        #expect(row.spindleBand.lower <= row.spindleBand.upper)
    }
}

@Test func invalidBandsAreRejectedAtEntry() {
    #expect(throws: MaterialValidationError.nonPositiveBound("feedBand")) {
        try MaterialValidator.validate(material(feedLower: 0), against: [])
    }
    #expect(throws: MaterialValidationError.invertedBand("spindleBand")) {
        try MaterialValidator.validate(
            material(spindleLower: 9000, spindleUpper: 8000), against: [])
    }
    #expect(throws: MaterialValidationError.emptyName) {
        try MaterialValidator.validate(material(name: "  "), against: [])
    }
}

@Test func duplicateNamesAndPresetShadowingAreRejected() throws {
    let user = material(name: "Reclaimed oak")
    #expect(throws: MaterialValidationError.duplicateName("Reclaimed oak")) {
        try MaterialValidator.validate(user, against: [user])
    }
    #expect(throws: MaterialValidationError.duplicateName("MDF")) {
        try MaterialValidator.validate(material(name: "MDF"), against: Presets.all)
    }
    #expect(throws: MaterialValidationError.duplicateIdentifier) {
        try MaterialValidator.validate(
            material(id: "user-1", name: "Different oak"), against: [user])
    }
}

@Test func bandsOutsideMachineLimitsAreStillValidRecords() throws {
    let beyondMachine = material(feedLower: 900, feedUpper: 1000)
    try MaterialValidator.validate(beyondMachine, against: [])
    #expect(beyondMachine.feedBand.lowerBound == 900)
}
