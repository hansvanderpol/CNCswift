import Synchronization

/// A cooperative cancellation flag that a `ProgressSink` reads.
///
/// `Task.cancel()` is bridged into this flag by `withCooperativeCancellation`, so a stage can
/// treat both sources identically: check between work units and return `.cancelled`.
public final class CancellationSource: Sendable {
    private let cancelled = Mutex(false)

    public init() {}

    /// Whether cancellation has been requested.
    public var isCancelled: Bool {
        cancelled.withLock { $0 }
    }

    /// Requests cancellation. Safe to call from any task or thread.
    public func cancel() {
        cancelled.withLock { $0 = true }
    }

    /// A progress sink that reflects this source's cancellation state.
    public func makeSink(report: @escaping @Sendable (StageProgress) -> Void) -> ProgressSink {
        ProgressSink(report: report, isCancelled: { self.isCancelled })
    }
}

extension ProgressSink {
    /// Creates a sink backed by a cancellation source.
    public init(
        source: CancellationSource,
        report: @escaping @Sendable (StageProgress) -> Void
    ) {
        self.init(report: report, isCancelled: { source.isCancelled })
    }
}

/// Runs `operation`, bridging `Task.cancel()` into `source` through structured cancellation.
///
/// The handler runs as soon as the enclosing task is cancelled, so long stages observe the flag
/// between work units instead of completing work nobody will use (research D10).
public func withCooperativeCancellation<T: Sendable>(
    source: CancellationSource,
    operation: @Sendable () async throws -> T
) async rethrows -> T {
    try await withTaskCancellationHandler {
        try await operation()
    } onCancel: {
        source.cancel()
    }
}
