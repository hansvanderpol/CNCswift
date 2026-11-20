/// A payload whose contents must never reach a log in clear text (FR-084).
///
/// Wrap any secret, credential, identifying value, or user-supplied path in this type before
/// passing it to a ``DiagnosticLogger``. The wrapper's ``logDescription`` is a stable redaction
/// marker, so the original content cannot reach an emitted record even when the record is
/// formatted into a message string.
///
/// - Concurrency: Immutable and `Sendable`; safe to pass between tasks.
public struct SensitiveValue: Sendable, Equatable {
    /// The marker emitted in place of a sensitive payload.
    public static let redactedMarker = "[redacted]"

    /// The private payload, retained by the wrapper but never included in ``logDescription``.
    private let value: String

    /// Wraps `value` so it is redacted whenever it is formatted for logging.
    public init(_ value: String) {
        self.value = value
    }

    /// The stable marker used in place of the private payload.
    public var logDescription: String { Self.redactedMarker }
}
