import CNCGeometry
import CNCMachineProfile
import CNCToolpath
import Foundation
import Testing

private let epsilon = 1e-6

@Test func roughingLayersNeverExceedTheDepthPerPassBound() async throws {
    let job = try ToolpathFixture.job()
    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )

    let cuts = toolpath.moves.filter { $0.mode == .cut }
    #expect(!cuts.isEmpty, "the planner must emit cutting moves")

    var deepest = 0.0
    var newLayers = 0
    for move in cuts where move.to.z < deepest - epsilon {
        let drop = deepest - move.to.z
        #expect(
            drop <= job.maxDepthPerPass + epsilon,
            "a \(drop) mm layer exceeds the \(job.maxDepthPerPass) mm per-pass bound"
        )
        deepest = move.to.z
        newLayers += 1
    }
    #expect(newLayers >= 2, "a 30 mm blank at 2 mm per pass needs several layers")
}

@Test func finishingAllowanceIsLeftBeforeTheFinishingPass() async throws {
    let job = try ToolpathFixture.job()
    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )

    let cuttingDepths = toolpath.moves.filter { $0.mode == .cut }.map(\.to.z)
    #expect(
        cuttingDepths.contains { abs($0 + job.stock.height) < epsilon },
        "finishing must reach the bottom of the stock"
    )
    #expect(
        cuttingDepths.contains {
            $0 >= -job.stock.height + job.finishingAllowance - epsilon && $0 < -epsilon
        },
        "roughing must stop at the finishing allowance, not at the stock bottom"
    )
}

@Test func finishingRowsNeverExceedTheStepoverBound() async throws {
    let job = try ToolpathFixture.job()
    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )

    let bottom = -job.stock.height
    let rows = Set(
        toolpath.moves
            .filter { $0.mode == .cut && abs($0.to.z - bottom) < epsilon }
            .map(\.to.y)
    ).sorted()
    #expect(rows.count >= 2, "finishing must raster more than one row")
    guard rows.count >= 2 else { return }
    for index in 1..<rows.count {
        let spacing = rows[index] - rows[index - 1]
        #expect(
            spacing <= job.stepover + epsilon,
            "a \(spacing) mm step exceeds the \(job.stepover) mm stepover"
        )
    }
}

@Test func movesStayInsideTheFootprintPlusOneCutterRadius() async throws {
    let job = try ToolpathFixture.job()
    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )
    let radius = (ToolpathFixture.cutter.cuttingDiameter ?? 0) / 2
    let bounds = toolpath.bounds
    let modelWidth = job.modelBounds.max.x - job.modelBounds.min.x
    let modelDepth = job.modelBounds.max.y - job.modelBounds.min.y

    #expect(bounds.min.x >= -epsilon)
    #expect(bounds.min.y >= -epsilon)
    #expect(bounds.max.x <= modelWidth + 2 * radius + epsilon)
    #expect(bounds.max.y <= modelDepth + 2 * radius + epsilon)
    #expect(bounds.max.z <= ToolpathFixture.profile.clearanceZ + epsilon)
    #expect(bounds.max.x >= modelWidth + radius - epsilon)
    #expect(bounds.max.y >= modelDepth + radius - epsilon)
}

@Test func rapidsStayAtClearanceHeightAndNeverEnterMaterial() async throws {
    let toolpath = try await ToolpathPlanner().plan(
        try ToolpathFixture.job(),
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )
    let clearance = ToolpathFixture.profile.clearanceZ
    let rapids = toolpath.moves.filter { $0.mode == .rapid }
    #expect(!rapids.isEmpty, "the planner must emit repositioning rapids")
    for move in rapids {
        #expect(move.from.z >= clearance - epsilon)
        #expect(move.to.z >= clearance - epsilon)
    }
}

@Test func everyCuttingMoveUsesTheConfirmedEffectiveFeed() async throws {
    let job = try ToolpathFixture.job()
    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )

    #expect(job.effective.confirmed, "the fixture must carry a confirmed effective value")
    #expect(toolpath.feedRate == job.effective.feed)
}

@Test func depthAboveTheCutterCuttingLengthIsRejected() async throws {
    let job = try ToolpathFixture.job(
        maxDepthPerPass: ToolpathFixture.cutter.cuttingLength + 1
    )
    do {
        _ = try await ToolpathPlanner().plan(
            job,
            profile: ToolpathFixture.profile,
            progress: ToolpathFixture.progressSink()
        )
        Issue.record("a pass deeper than the cutting length must be rejected")
    } catch PlanningError.depthExceedsCuttingLength {
        // Expected.
    } catch {
        Issue.record("expected depthExceedsCuttingLength, got \(error)")
    }
}

@Test func stepoverAndAllowanceOutsideTheirBoundsAreRejected() async throws {
    let planner = ToolpathPlanner()
    let tooWide = try ToolpathFixture.job(stepover: ToolpathFixture.cutter.cuttingDiameter ?? 6)
    do {
        _ = try await planner.plan(
            tooWide,
            profile: ToolpathFixture.profile,
            progress: ToolpathFixture.progressSink()
        )
        Issue.record("a stepover equal to the cutting diameter must be rejected")
    } catch PlanningError.invalidStepover {
        // Expected.
    } catch {
        Issue.record("expected invalidStepover, got \(error)")
    }

    let noAllowance = try ToolpathFixture.job(finishingAllowance: 30)
    do {
        _ = try await planner.plan(
            noAllowance,
            profile: ToolpathFixture.profile,
            progress: ToolpathFixture.progressSink()
        )
        Issue.record("an allowance equal to the stock height must be rejected")
    } catch PlanningError.invalidAllowance {
        // Expected.
    } catch {
        Issue.record("expected invalidAllowance, got \(error)")
    }
}

@Test func aModelPlacedWithOneCutterRadiusOfMarginStaysInsideTheStock() async throws {
    let stock = ToolpathFixture.stock
    let bounds = ToolpathFixture.modelBounds
    let job = try ToolpathFixture.job(
        mesh: ToolpathFixture.flatTopMesh(bounds: bounds),
        modelBounds: bounds,
        stock: stock
    )

    let toolpath = try await ToolpathPlanner().plan(
        job,
        profile: ToolpathFixture.profile,
        progress: ToolpathFixture.progressSink()
    )

    let radius = (ToolpathFixture.cutter.cuttingDiameter ?? 0) / 2
    let modelWidth = bounds.max.x - bounds.min.x
    let modelDepth = bounds.max.y - bounds.min.y
    #expect(abs(toolpath.bounds.min.x) < epsilon)
    #expect(abs(toolpath.bounds.min.y) < epsilon)
    #expect(abs(toolpath.bounds.max.x - (modelWidth + 2 * radius)) < epsilon)
    #expect(abs(toolpath.bounds.max.y - (modelDepth + 2 * radius)) < epsilon)

    for move in toolpath.moves {
        for point in [move.from, move.to] {
            #expect(
                point.x >= -epsilon && point.x <= stock.width + epsilon,
                "X \(point.x) leaves the \(stock.width) mm stock"
            )
            #expect(
                point.y >= -epsilon && point.y <= stock.depth + epsilon,
                "Y \(point.y) leaves the \(stock.depth) mm stock"
            )
        }
    }
    #expect(toolpath.bounds.max.x <= stock.width + epsilon)
    #expect(toolpath.bounds.max.y <= stock.depth + epsilon)
}

@Test func aModelWithoutCutterMarginIsRejectedByThePlanner() async throws {
    let flushStock = StockBlank(width: 200, depth: 150, height: 30)
    let job = try ToolpathFixture.job(stock: flushStock, cutter: ToolpathFixture.longCutter)
    do {
        _ = try await ToolpathPlanner().plan(
            job,
            profile: ToolpathFixture.profile,
            progress: ToolpathFixture.progressSink()
        )
        Issue.record("a model with no room for the cutter radius must be rejected")
    } catch PlanningError.insufficientCutterMargin(let required) {
        #expect(required == 3)
    } catch {
        Issue.record("expected insufficientCutterMargin, got \(error)")
    }
}
