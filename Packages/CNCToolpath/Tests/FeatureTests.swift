import CNCGeometry
import CNCMachineProfile
import CNCToolpath
import Foundation
import Testing

private func assertClose(_ actual: Double, _ expected: Double, _ label: String) {
    #expect(
        abs(actual - expected) < 1e-6,
        "\(label): expected \(expected) mm, got \(actual) mm"
    )
}

@Test func flatEffectiveRadiusIsHalfTheCuttingDiameter() {
    let radius = Geometry.effectiveRadius(.flat(cuttingDiameter: 6), stepover: 2.4)
    assertClose(radius, 3, "flat effective radius")
}

@Test func ballNoseEffectiveRadiusUsesTheInscribedCircleAtTheStepover() {
    let radius = Geometry.effectiveRadius(.ballNose(ballDiameter: 6), stepover: 2.4)
    let expected = (2 * 3 * 2.4 - 2.4 * 2.4).squareRoot()
    assertClose(radius, expected, "ball-nose effective radius")
}

@Test func vBitEffectiveRadiusUsesTheHalfAngleTangent() {
    let radius = Geometry.effectiveRadius(
        .vBit(tipDiameter: 2, includedAngle: 60),
        stepover: 2.4
    )
    let expected = 1 + 2.4 * tan(30 * .pi / 180)
    assertClose(radius, expected, "V-bit effective radius")
}

@Test func aFeatureSmallerThanTheEffectiveRadiusBlocksGenerationAndReportsBothRadii() throws {
    let stepover = 2.4
    let smallest = 0.5
    let effective = Geometry.effectiveRadius(.flat(cuttingDiameter: 6), stepover: stepover)
    let report = FeatureReport(smallestConcaveRadius: smallest, effectiveRadius: effective)

    #expect(smallest < effective)
    #expect(!report.isAchievable)
    let job = try ToolpathFixture.job(
        mesh: ToolpathFixture.notchedMesh(radius: smallest),
        stepover: stepover
    )

    do {
        _ = try Preflight.check(
            job,
            cutter: ToolpathFixture.cutter,
            profile: ToolpathFixture.profile
        )
        Issue.record("a feature smaller than the effective radius must block generation")
    } catch let error as PlanningError {
        guard case .featureTooSmall(let reportedSmallest, let reportedEffective) = error else {
            Issue.record("expected featureTooSmall, got \(error)")
            return
        }
        #expect(reportedSmallest == smallest)
        assertClose(reportedEffective, effective, "reported effective radius")
        #expect(error.userMessage.contains("0.500 mm"))
        #expect(error.userMessage.contains("3.000 mm"))
    } catch {
        Issue.record("expected PlanningError.featureTooSmall, got \(error)")
    }
}

@Test func aFeatureAtLeastAsLargeAsTheEffectiveRadiusIsAchievable() {
    let effective = Geometry.effectiveRadius(.flat(cuttingDiameter: 6), stepover: 2.4)
    let report = FeatureReport(smallestConcaveRadius: effective, effectiveRadius: effective)
    #expect(report.isAchievable, "boundary-inclusive: equal radii are achievable")
}
