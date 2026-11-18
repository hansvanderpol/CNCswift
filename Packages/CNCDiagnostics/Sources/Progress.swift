/// One progress report from a long-running stage.
public struct StageProgress: Sendable, Equatable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }
}

/// The seam every long stage accepts: report progress, observe cancellation (FR-069).
///
/// The sink is a value type so it can be captured by any stage without shared mutable state.
public struct ProgressSink: Sendable {
    public let report: @Sendable (StageProgress) -> Void
    public let isCancelled: @Sendable () -> Bool

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
public enum CooperativeOutcome: Sendable, Equatable {
    case completed
    case cancelled
}

/// Runs `units` work items, reporting after each and stopping between units on cancellation.
public enum CooperativeWork {
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
