import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import MainScreenUI
import Testing

private func confirmedValues() throws -> EffectiveCuttingValues {
    try EffectiveCuttingValues(
        feed: 600,
        spindle: 8000,
        source: .userChoice,
        material: Presets.all[1],
        profile: TTC450Pro.profile
    ).confirming()
}

@Test @MainActor func jobStrategyIsSuggestedButNotAppliedUntilConfirmed() throws {
    let cutter = Cutter(
        id: CutterID("cutter-1"),
        name: "6mm flat",
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
    let stock = StockBlank(width: 200, depth: 150, height: 30)
    let suggested = JobSuggestionEngine().suggestion(
        cutter: cutter,
        stock: stock,
        profile: TTC450Pro.profile
    )

    #expect(suggested.stepover == 2.4)
    #expect(suggested.maxDepthPerPass == 2)
    #expect(suggested.finishingAllowance == 0.5)
    #expect(!suggested.confirmed)

    let suggestedModel = MainScreenModel(
        selectedCutterID: cutter.id,
        effectiveValues: try confirmedValues(),
        suggestion: suggested,
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )
    #expect(suggestedModel.appliedSuggestion == nil)
    #expect(suggestedModel.blockers().contains(.unconfirmedJobSettings))

    let confirmed = suggested.confirming()
    let confirmedModel = MainScreenModel(
        selectedCutterID: cutter.id,
        effectiveValues: try confirmedValues(),
        suggestion: confirmed,
        rapidRateConfirmed: true,
        materialHasOverlap: true
    )
    #expect(confirmedModel.appliedSuggestion == confirmed)
    #expect(!confirmedModel.blockers().contains(.unconfirmedJobSettings))
    #expect(
        confirmedModel.effectiveValues?.confirmed == true,
        "cutting values stay separately confirmed")
}
