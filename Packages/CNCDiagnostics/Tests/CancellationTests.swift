import Synchronization
import Testing

@testable import CNCDiagnostics

private enum WorkFailure: Error, Equatable {
    case boom
}

@Test func progressSinkReportsEveryUnit() async throws {
    let reports = Mutex<[StageProgress]>([])
    let sink = ProgressSink(
        report: { progress in reports.withLock { $0.append(progress) } },
        isCancelled: { false }
    )

    let outcome = try await CooperativeWork.run(units: 3, progress: sink) { _ in }

    #expect(outcome == .completed)
    #expect(reports.withLock { $0.count } == 3)
    #expect(reports.withLock { $0.last?.completed } == 3)
    #expect(reports.withLock { $0.last?.total } == 3)
}

@Test func cancellationIsDistinctFromFailure() async throws {
    let cancelled = Mutex(false)
    let sink = ProgressSink(
        report: { _ in },
        isCancelled: { cancelled.withLock { $0 } }
    )

    let outcome = try await CooperativeWork.run(units: 5, progress: sink) { index in
        if index == 1 {
            cancelled.withLock { $0 = true }
        }
    }

    #expect(outcome == .cancelled)
}

@Test(.timeLimit(.minutes(1))) func taskCancellationBridgesIntoTheProgressSink() async {
    let source = CancellationSource()
    let sink = source.makeSink(report: { _ in })
    #expect(!sink.isCancelled())

    let task = Task {
        await withCooperativeCancellation(source: source) {
            while !source.isCancelled {
                await Task.yield()
            }
        }
    }
    task.cancel()
    await task.value

    #expect(source.isCancelled)
    #expect(sink.isCancelled())
}

@Test func thrownWorkPropagatesAsFailure() async {
    let sink = ProgressSink(report: { _ in }, isCancelled: { false })

    await #expect(throws: WorkFailure.boom) {
        try await CooperativeWork.run(units: 2, progress: sink) { _ in
            throw WorkFailure.boom
        }
    }
}
