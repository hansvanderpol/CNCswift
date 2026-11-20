import CNCCutters
import Foundation
import Synchronization

/// A change published by the cutter library.
///
/// Events say *what* changed, never the changed record, so the persisted document stays the only
/// source of truth (FR-060, research D14).
///
/// - Concurrency: `Sendable` value type; safe to pass across concurrency boundaries.
public enum LibraryChange: Sendable, Equatable {
    /// The library was written successfully.
    case saved

    /// One cutter was removed from the library.
    case deleted(id: CutterID)

    /// The library was reloaded from disk.
    case reloaded
}

/// Fans one change out to every current subscriber without dropping buffered events.
///
/// Each `makeStream()` call creates an independent, unbounded buffer, so an event published while
/// a consumer is between suspensions is delivered when it resumes.
final class LibraryChangeRegistry: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<LibraryChange>.Continuation]>([:])

    func makeStream() -> AsyncStream<LibraryChange> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<LibraryChange>.makeStream(
            bufferingPolicy: .unbounded
        )
        continuations.withLock { $0[identifier] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { _ = $0.removeValue(forKey: identifier) }
        }
        return stream
    }

    func publish(_ change: LibraryChange) {
        let current = continuations.withLock { Array($0.values) }
        for continuation in current {
            continuation.yield(change)
        }
    }
}
