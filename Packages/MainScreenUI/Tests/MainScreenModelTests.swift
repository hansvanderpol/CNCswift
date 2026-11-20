import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import MainScreenUI
import Testing

private func effectiveValues(confirmed: Bool) throws -> EffectiveCuttingValues {
    let values = try EffectiveCuttingValues(
        feed: 600,
        spindle: 8000,
        source: .userChoice,
        material: Presets.all[1],
        profile: TTC450Pro.profile
    )
    return confirmed ? values.confirming() : values
}

private func suggestion(confirmed: Bool) -> JobSuggestion {
    JobSuggestion(
        stepover: 2.4,
        maxDepthPerPass: 2,
        finishingAllowance: 0.5,
        confirmed: confirmed
    )
}

@Test @MainActor func unconfirmedEffectiveValuesBlockGeneration() throws {
    let model = MainScreenModel(
        selectedCutterID: CutterID("cutter-1"),
        effectiveValues: try effectiveValues(confirmed: false),
        suggestion: suggestion(confirmed: true),
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )

    #expect(
        model.blockers() == [.unconfirmedEffectiveValues],
        "an unconfirmed cutting value must be its own blocker (FR-079)"
    )
}

@Test @MainActor func unconfirmedJobStrategyBlocksGenerationSeparately() throws {
    let model = MainScreenModel(
        selectedCutterID: CutterID("cutter-1"),
        effectiveValues: try effectiveValues(confirmed: true),
        suggestion: suggestion(confirmed: false),
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )

    #expect(
        model.blockers() == [.unconfirmedJobSettings],
        "suggested job values are not applied until confirmed (FR-037)"
    )
}

@Test @MainActor func unconfirmedRapidSetupBlocksGeneration() throws {
    let model = MainScreenModel(
        selectedCutterID: CutterID("cutter-1"),
        effectiveValues: try effectiveValues(confirmed: true),
        suggestion: suggestion(confirmed: true),
        rapidRateConfirmed: false,
        materialHasOverlap: true
    )

    #expect(model.blockers() == [.unconfirmedRapidSetup])
}

@Test @MainActor func emptyMaterialOverlapBlocksGeneration() throws {
    let model = MainScreenModel(
        selectedCutterID: CutterID("cutter-1"),
        effectiveValues: try effectiveValues(confirmed: true),
        suggestion: suggestion(confirmed: true),
        rapidRateConfirmed: true,
        materialHasOverlap: false
    )

    #expect(model.blockers() == [.emptyMaterialOverlap])
}

@Test @MainActor func emptyCutterSelectionBlocksGeneration() throws {
    let model = MainScreenModel(
        selectedCutterID: nil,
        effectiveValues: try effectiveValues(confirmed: true),
        suggestion: suggestion(confirmed: true),
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )

    #expect(model.blockers() == [.emptyCutterSelection])
}
