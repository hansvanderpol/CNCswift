import CNCCutters
import CNCGeometry
import CNCMachineProfile
import CNCToolpath
import Foundation
import Testing

private func assertRejected(
    _ expected: PlanningError,
    job: JobSettings,
    cutter: Cutter,
    profile: MachineProfile
) {
    do {
        _ = try Preflight.check(job, cutter: cutter, profile: profile)
        Issue.record("expected \(expected) but preflight accepted the job")
    } catch let error as PlanningError {
        #expect(error == expected)
    } catch {
        Issue.record("expected \(expected), got \(error)")
    }
}

@Test func unconfirmedUnitsAndOrientationAreRejected() throws {
    let profile = ToolpathFixture.profile
    let cutter = ToolpathFixture.cutter
    assertRejected(
        .unconfirmedModel,
        job: try ToolpathFixture.job(unitsConfirmed: false),
        cutter: cutter,
        profile: profile
    )
    assertRejected(
        .unconfirmedModel,
        job: try ToolpathFixture.job(orientationConfirmed: false),
        cutter: cutter,
        profile: profile
    )
}

@Test func nonPositiveStockDimensionsAreRejected() throws {
    let profile = ToolpathFixture.profile
    let cutter = ToolpathFixture.cutter
    for stock in [
        StockBlank(width: 0, depth: 150, height: 30),
        StockBlank(width: 200, depth: -1, height: 30),
        StockBlank(width: 200, depth: 150, height: 0),
    ] {
        assertRejected(
            .invalidStock("dimension"),
            job: try ToolpathFixture.job(stock: stock),
            cutter: cutter,
            profile: profile
        )
    }
}

@Test func stockOutsideTheMachineEnvelopeIsRejected() throws {
    let profile = ToolpathFixture.profile
    let cutter = ToolpathFixture.cutter
    assertRejected(
        .envelopeExceeded,
        job: try ToolpathFixture.job(stock: StockBlank(width: 461, depth: 150, height: 30)),
        cutter: cutter,
        profile: profile
    )
    assertRejected(
        .envelopeExceeded,
        job: try ToolpathFixture.job(stock: StockBlank(width: 200, depth: 150, height: 81)),
        cutter: cutter,
        profile: profile
    )
}

@Test func aModelOutsideTheStockIsRejected() throws {
    let oversizeBounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 250, y: 150, z: 30)
    )
    assertRejected(
        .modelOutsideStock,
        job: try ToolpathFixture.job(modelBounds: oversizeBounds),
        cutter: ToolpathFixture.cutter,
        profile: ToolpathFixture.profile
    )
}

@Test func aMissingCutterAttributeIsRejected() throws {
    let incomplete = Cutter(
        id: ToolpathFixture.cutterID,
        name: "incomplete flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: 750,
        spindleSpeed: 8000,
        cuttingDiameter: nil,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
    assertRejected(
        .missingCutterAttribute("cuttingDiameter"),
        job: try ToolpathFixture.job(),
        cutter: incomplete,
        profile: ToolpathFixture.profile
    )
}

@Test func unconfirmedRapidSetupIsRejected() throws {
    assertRejected(
        .rapidSetupUnconfirmed,
        job: try ToolpathFixture.job(rapidRateConfirmed: false),
        cutter: ToolpathFixture.cutter,
        profile: ToolpathFixture.profile
    )
}

@Test func aCutterShorterThanTheStockIsRejectedAndNamesTheRequiredLength() throws {
    let stock = ToolpathFixture.stock
    let error = PlanningError.cutterTooShort(requiredCuttingLength: stock.height)
    assertRejected(
        error,
        job: try ToolpathFixture.job(stock: stock),
        cutter: ToolpathFixture.cutter,
        profile: ToolpathFixture.profile
    )
    #expect(error.userMessage.contains("30.000 mm"))
}

@Test func theExactMaximumEnvelopeIsAccepted() throws {
    let stock = StockBlank(width: 460, depth: 460, height: 80)
    let bounds = AABB(
        min: Vec3(x: 0, y: 0, z: 0),
        max: Vec3(x: 460, y: 460, z: 80)
    )
    let longCutter = Cutter(
        id: CutterID("long-flat"),
        name: "long flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 80,
        fluteCount: 2,
        feedRate: 600,
        spindleSpeed: 8000,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
    let job = try ToolpathFixture.job(
        mesh: ToolpathFixture.flatTopMesh(bounds: bounds),
        modelBounds: bounds,
        stock: stock
    )

    let report = try Preflight.check(
        job,
        cutter: longCutter,
        profile: ToolpathFixture.profile
    )
    #expect(report.isAchievable)
}
