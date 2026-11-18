import Testing

@testable import CNCMaterials

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
        try MaterialValidator.validate(material(id: "user-1", name: "Different oak"), against: [user])
    }
}

@Test func bandsOutsideMachineLimitsAreStillValidRecords() throws {
    let beyondMachine = material(feedLower: 900, feedUpper: 1000)
    try MaterialValidator.validate(beyondMachine, against: [])
    #expect(beyondMachine.feedBand.lowerBound == 900)
}
