/// One progress report from a long-running stage.
///
/// - Concurrency: Immutable and `Sendable`; safe to pass between tasks.
public struct StageProgress: Sendable, Equatable {
    /// The number of work units completed so far.
    public let completed: Int
    /// The total number of work units in the stage.
    public let total: Int

    /// Creates a progress report for `completed` of `total` units.
    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }
}

/// The seam every long stage accepts: report progress, observe cancellation (FR-069).
///
/// The sink is a value type so it can be captured by any stage without shared mutable state.
///
/// - Concurrency: Immutable and `Sendable`; its `@Sendable` closures may be called
///   from any task.
public struct ProgressSink: Sendable {
    /// The closure that publishes each progress report.
    public let report: @Sendable (StageProgress) -> Void
    /// The closure that reports whether work should stop.
    public let isCancelled: @Sendable () -> Bool

    /// Creates a sink from a report callback and a cancellation query.
    public init(
        report: @escaping @Sendable (StageProgress) -> Void,
        isCancelled: @escaping @Sendable () -> Bool
    ) {
        self.report = report
        self.isCancelled = isCancelled
    }
}

/// The two outcomes of cooperative work: finished, or stopped on request.
///
/// Cancellation is deliberately not an error; callers map it to a cancellation outcome (FR-069).
///
/// - Concurrency: Immutable and `Sendable`; safe to pass between tasks.
public enum CooperativeOutcome: Sendable, Equatable {
    case completed
    case cancelled
}

/// Runs `units` work items, reporting after each and stopping between units on cancellation.
public enum CooperativeWork {
    /// Runs `body` for indices `0..<units`, reporting after each item.
    ///
    /// - Throws: Any error thrown by `body`; no further units run after an error.
    /// - Concurrency: Async; checks task and sink cancellation between work items and
    ///   accepts a `@Sendable` body.
    public static func run(
        units: Int,
        progress: ProgressSink,
        _ body: @Sendable (Int) async throws -> Void
    ) async throws -> CooperativeOutcome {
        for index in 0..<units {
            if Task.isCancelled || progress.isCancelled() {
                return .cancelled
            }
            try await body(index)
            progress.report(StageProgress(completed: index + 1, total: units))
            if Task.isCancelled || progress.isCancelled() {
                return .cancelled
            }
        }
        return .completed
    }
}
