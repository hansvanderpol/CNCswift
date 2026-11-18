import CNCCutters
import CNCMachineProfile
import Testing

@testable import CNCMaterials

private func bandMaterial(
    name: String = "Test wood",
    feed: ClosedRange<Double> = 500...800,
    spindle: ClosedRange<Double> = 6000...8000
) -> Material {
    Material(
        id: "material-1",
        name: name,
        feedBand: feed,
        spindleBand: spindle,
        origin: .user,
        shippedVersion: nil
    )
}

private func cutter(feedRate: Double, spindleSpeed: Double) -> Cutter {
    Cutter(
        id: CutterID("cutter-1"),
        name: "6mm flat",
        type: .flat,
        shankDiameter: 6,
        cuttingLength: 20,
        fluteCount: 2,
        feedRate: feedRate,
        spindleSpeed: spindleSpeed,
        cuttingDiameter: 6,
        ballDiameter: nil,
        includedAngle: nil,
        tipDiameter: nil
    )
}

@Test func cutterValueInsideIntersectionIsPrefilledButUnconfirmed() throws {
    let values = EffectiveCuttingValues.resolve(
        material: bandMaterial(),
        cutter: cutter(feedRate: 750, spindleSpeed: 7500),
        profile: TTC450Pro.profile
    )

    guard case .resolved(let effective) = values else {
        Issue.record("expected a resolved value")
        return
    }
    #expect(effective.feed == 750)
    #expect(effective.spindle == 7500)
    #expect(effective.source == .cutterPrefill)
    #expect(!effective.confirmed)
}

@Test func cutterValueOutsideIntersectionUsesNearestBound() throws {
    let values = EffectiveCuttingValues.resolve(
        material: bandMaterial(),
        cutter: cutter(feedRate: 900, spindleSpeed: 4500),
        profile: TTC450Pro.profile
    )

    guard case .resolved(let effective) = values else {
        Issue.record("expected a resolved value")
        return
    }
    #expect(effective.feed == 800)
    #expect(effective.spindle == 6000)
    #expect(effective.source == .nearestBound)
    #expect(!effective.confirmed)
}

@Test func userChoiceInsideIntersectionIsConstructibleAndOutOfRangeIsNot() throws {
    let material = bandMaterial()

    let chosen = try EffectiveCuttingValues(
        feed: 700,
        spindle: 7800,
        source: .userChoice,
        material: material,
        profile: TTC450Pro.profile
    )
    #expect(chosen.source == .userChoice)
    #expect(chosen.confirmed == false)

    #expect(throws: MaterialResolutionError.outsideIntersection) {
        try EffectiveCuttingValues(
            feed: 850,
            spindle: 7800,
            source: .userChoice,
            material: material,
            profile: TTC450Pro.profile
        )
    }
}

@Test func emptyFeedOverlapNamesMaterialBandAndCeiling() throws {
    let material = bandMaterial(name: "Exotic hardwood", feed: 900...1000)

    guard
        case .noOverlap(let conflicts) = EffectiveCuttingValues.resolve(
            material: material,
            cutter: cutter(feedRate: 700, spindleSpeed: 7500),
            profile: TTC450Pro.profile
        )
    else {
        Issue.record("expected noOverlap")
        return
    }

    let feedConflict = try #require(conflicts.first { $0.band == .feed })
    #expect(feedConflict.message.contains("Exotic hardwood"))
    #expect(feedConflict.message.contains("900"))
    #expect(feedConflict.message.contains("800"))
}

@Test func emptySpindleOverlapNamesMaterialBandAndFloor() throws {
    let material = bandMaterial(name: "Low-RPM resin", spindle: 1000...2000)

    guard
        case .noOverlap(let conflicts) = EffectiveCuttingValues.resolve(
            material: material,
            cutter: cutter(feedRate: 700, spindleSpeed: 7500),
            profile: TTC450Pro.profile
        )
    else {
        Issue.record("expected noOverlap")
        return
    }

    let spindleConflict = try #require(conflicts.first { $0.band == .spindle })
    #expect(spindleConflict.message.contains("Low-RPM resin"))
    #expect(spindleConflict.message.contains("5000") || spindleConflict.message.contains("5,000"))
}
