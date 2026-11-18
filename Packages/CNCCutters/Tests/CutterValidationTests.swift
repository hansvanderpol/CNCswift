import Foundation
import Testing

@testable import CNCCutters

private func cutter(
    id: String = "cutter-1",
    name: String = "6mm flat",
    type: CutterType = .flat,
    shankDiameter: Double = 6,
    cuttingLength: Double = 20,
    fluteCount: Int = 2,
    feedRate: Double = 750,
    spindleSpeed: Double = 8000,
    cuttingDiameter: Double? = 6,
    ballDiameter: Double? = nil,
    includedAngle: Double? = nil,
    tipDiameter: Double? = nil
) -> Cutter {
    Cutter(
        id: CutterID(id),
        name: name,
        type: type,
        shankDiameter: shankDiameter,
        cuttingLength: cuttingLength,
        fluteCount: fluteCount,
        feedRate: feedRate,
        spindleSpeed: spindleSpeed,
        cuttingDiameter: cuttingDiameter,
        ballDiameter: ballDiameter,
        includedAngle: includedAngle,
        tipDiameter: tipDiameter
    )
}

@Test func closedTaxonomyHasThreeTypesWithTypeSpecificDimensions() throws {
    let flat = cutter(type: .flat, cuttingDiameter: 6)
    let ball = cutter(type: .ballNose, cuttingDiameter: nil, ballDiameter: 6)
    let vBit = cutter(
        type: .vBit,
        shankDiameter: 16,
        cuttingDiameter: nil,
        includedAngle: 30,
        tipDiameter: 1
    )

    try CutterValidator.validate(flat)
    try CutterValidator.validate(ball)
    try CutterValidator.validate(vBit)

    #expect(CutterType.allCases == [.flat, .ballNose, .vBit])
    #expect(flat.maxCuttingExtent == 6)
    #expect(ball.maxCuttingExtent == 6)
    #expect(abs(vBit.maxCuttingExtent - (1 + 40 * tan(15 * .pi / 180))) < 1e-9)
}

@Test func requiredAndForbiddenFieldsAreEnforcedPerType() {
    #expect(throws: CutterValidationError.missingField("cuttingDiameter")) {
        try CutterValidator.validate(cutter(cuttingDiameter: nil))
    }
    #expect(throws: CutterValidationError.forbiddenField("ballDiameter")) {
        try CutterValidator.validate(cutter(ballDiameter: 6))
    }
    #expect(throws: CutterValidationError.missingField("includedAngle")) {
        try CutterValidator.validate(
            cutter(type: .vBit, shankDiameter: 16, cuttingDiameter: nil, tipDiameter: 1)
        )
    }
    #expect(throws: CutterValidationError.forbiddenField("cuttingDiameter")) {
        try CutterValidator.validate(
            cutter(type: .ballNose, cuttingDiameter: 6, ballDiameter: 6)
        )
    }
}

@Test func entryRulesRejectOutOfRangeValues() {
    #expect(throws: CutterValidationError.nonPositive("shankDiameter")) {
        try CutterValidator.validate(cutter(shankDiameter: 0))
    }
    #expect(throws: CutterValidationError.invalidFluteCount) {
        try CutterValidator.validate(cutter(fluteCount: 0))
    }
    #expect(throws: CutterValidationError.invalidFluteCount) {
        try CutterValidator.validate(cutter(fluteCount: 9))
    }
    #expect(throws: CutterValidationError.feedOutOfRange) {
        try CutterValidator.validate(cutter(feedRate: 801))
    }
    #expect(throws: CutterValidationError.spindleOutOfRange) {
        try CutterValidator.validate(cutter(spindleSpeed: 4999))
    }
    #expect(throws: CutterValidationError.emptyName) {
        try CutterValidator.validate(cutter(name: "   "))
    }
}

@Test func shankDominanceRequiresAtLeastMaxCuttingExtent() {
    #expect(throws: CutterValidationError.shankTooSmall(required: 8)) {
        try CutterValidator.validate(cutter(shankDiameter: 6, cuttingDiameter: 8))
    }
}

@Test func vBitTipFittingTheShankIsNotSufficient() {
    let tooSmallShank = cutter(
        type: .vBit,
        shankDiameter: 6,
        cuttingDiameter: nil,
        includedAngle: 30,
        tipDiameter: 3
    )

    #expect(throws: CutterValidationError.self) {
        try CutterValidator.validate(tooSmallShank)
    }
    #expect(throws: CutterValidationError.invalidAngle) {
        try CutterValidator.validate(
            cutter(
                type: .vBit, shankDiameter: 16, cuttingDiameter: nil, includedAngle: 180,
                tipDiameter: 1)
        )
    }
}

@Test func identifierSurvivesEdits() {
    let original = cutter(id: "stable-id", name: "Old name")
    let renamed = original.renamed(to: "New name")
    let retuned = original.withFeedRate(700)

    #expect(original.id == CutterID("stable-id"))
    #expect(renamed.id == original.id)
    #expect(retuned.id == original.id)
    #expect(renamed.name == "New name")
    #expect(retuned.feedRate == 700)
}
