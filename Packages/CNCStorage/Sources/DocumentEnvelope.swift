import Foundation

/// The versioned wrapper every persisted document is stored in (FR-051).
///
/// `schemaVersion` lives at the document root so a newer document can be refused without
/// attempting a partial decode of its payload (FR-053).
///
/// - Concurrency: A `Sendable` value; safe to pass between tasks when `Payload` is.
public struct DocumentEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    /// The decoded document content.
    public var payload: Payload
    /// The document root schema version read before decoding the payload.
    public var schemaVersion: Int

    /// Wraps `payload` at `schemaVersion`.
    public init(payload: Payload, schemaVersion: Int) {
        self.payload = payload
        self.schemaVersion = schemaVersion
    }
}

extension DocumentEnvelope: Equatable where Payload: Equatable {}

/// Reads only the schema version, before the payload shape is known to be compatible.
struct SchemaHeader: Decodable, Sendable {
    let schemaVersion: Int
}
