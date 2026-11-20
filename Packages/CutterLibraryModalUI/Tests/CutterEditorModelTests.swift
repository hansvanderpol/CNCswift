import CNCCutters
import CutterLibraryModalUI
import Testing

/// Tests for the modal editor's per-type forms and field-level entry validation (FR-044 – FR-048).
///
/// The contract under test is a single `CutterEditorModel` whose `requiredFields()` follow the
/// selected cutter type and whose `fieldError(_:)` names the broken rule and its limit before
/// anything is persisted. T083 and T084 own the implementation.

private func validFields(for type: CutterType) -> [CutterField: String] {
    var fields: [CutterField: String] = [
        .name: "6mm flat",
        .shankDiameter: "6",
        .cuttingLength: "20",
        .fluteCount: "2",
        .feedRate: "750",
        .spindleSpeed: "8000",
    ]
    switch type {
    case .flat:
        fields[.cuttingDiameter] = "6"
    case .ballNose:
        fields[.name] = "6mm ball nose"
        fields[.ballDiameter] = "6"
    case .vBit:
        fields[.name] = "30 degree V-bit"
        fields[.cuttingLength] = "8"
        fields[.includedAngle] = "30"
        fields[.tipDiameter] = "0.5"
    }
    return fields
}

@Test @MainActor func flatFormRequestsOnlyTheFlatDimension() {
    let model = CutterEditorModel()
    model.type = .flat

    let fields = model.requiredFields()

    #expect(fields.contains(.cuttingDiameter))
    #expect(!fields.contains(.ballDiameter))
    #expect(!fields.contains(.includedAngle))
    #expect(!fields.contains(.tipDiameter))
}

@Test @MainActor func ballNoseFormRequestsOnlyTheBallDiameter() {
    let model = CutterEditorModel()
    model.type = .ballNose

    let fields = model.requiredFields()

    #expect(fields.contains(.ballDiameter))
    #expect(!fields.contains(.cuttingDiameter))
    #expect(!fields.contains(.includedAngle))
    #expect(!fields.contains(.tipDiameter))
}

@Test @MainActor func vBitFormRequestsAngleAndTip() {
    let model = CutterEditorModel()
    model.type = .vBit

    let fields = model.requiredFields()

    #expect(fields.contains(.includedAngle))
    #expect(fields.contains(.tipDiameter))
    #expect(!fields.contains(.cuttingDiameter))
    #expect(!fields.contains(.ballDiameter))
}

@Test @MainActor func fieldErrorsNameTheRuleAndItsLimit() throws {
    let model = CutterEditorModel()
    model.type = .flat
    var fields = validFields(for: .flat)
    fields[.fluteCount] = "0"
    fields[.feedRate] = "900"
    fields[.spindleSpeed] = "4500"
    model.fields = fields

    let fluteError = try #require(model.fieldError(.fluteCount))
    #expect(fluteError.contains("1"), "the flute-count rule must name its lower bound")
    #expect(fluteError.contains("8"), "the flute-count rule must name its upper bound")

    let feedError = try #require(model.fieldError(.feedRate))
    #expect(feedError.contains("800"), "the feed rule must name the 800 mm/min ceiling")

    let spindleError = try #require(model.fieldError(.spindleSpeed))
    #expect(
        spindleError.contains("5,000") || spindleError.contains("5000"),
        "the spindle rule must name the 5,000 RPM floor"
    )
    #expect(
        spindleError.contains("8,000") || spindleError.contains("8000"),
        "the spindle rule must name the 8,000 RPM ceiling"
    )
}

@Test @MainActor func anotherTypesDimensionIsRejectedAtTheField() throws {
    let model = CutterEditorModel()
    model.type = .flat
    var fields = validFields(for: .flat)
    fields[.cuttingDiameter] = ""
    fields[.ballDiameter] = "6"
    model.fields = fields

    let missing = try #require(model.fieldError(.cuttingDiameter))
    #expect(missing.contains("cuttingDiameter"))
    let forbidden = try #require(model.fieldError(.ballDiameter))
    #expect(
        forbidden.localizedCaseInsensitiveContains("ballDiameter"),
        "a forbidden field must be rejected, not silently borrowed as a substitute"
    )
    #expect(throws: CutterValidationError.self) {
        try model.makeCutter()
    }
}

@Test @MainActor func vBitShankDominanceIsCheckedAtEntry() throws {
    let model = CutterEditorModel()
    model.type = .vBit
    var fields = validFields(for: .vBit)
    // A tip that fits the shank is not enough: the cone must also fit before the shank.
    fields[.shankDiameter] = "2.5"
    fields[.tipDiameter] = "2"
    model.fields = fields

    let error = try #require(model.fieldError(.shankDiameter))
    #expect(error.localizedCaseInsensitiveContains("shank"))
    #expect(throws: CutterValidationError.self) {
        try model.makeCutter()
    }
}

@Test @MainActor func completeValidFormProducesAValidCutter() throws {
    let model = CutterEditorModel()
    for type in CutterType.allCases {
        model.type = type
        model.fields = validFields(for: type)

        for field in model.requiredFields() {
            #expect(model.fieldError(field) == nil, "\(field) should be accepted for \(type)")
        }
        let cutter = try model.makeCutter()
        try CutterValidator.validate(cutter)
        #expect(cutter.type == type)
        #expect(cutter.id.rawValue.isEmpty == false)
    }
}
