public struct StageProgress: Sendable, Equatable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }
}

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

public enum CooperativeOutcome: Sendable, Equatable {
    case completed
    case cancelled
}

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
