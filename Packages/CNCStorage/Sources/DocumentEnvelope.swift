import Foundation

/// The versioned wrapper every persisted document is stored in (FR-051).
///
/// `schemaVersion` lives at the document root so a newer document can be refused without
/// attempting a partial decode of its payload (FR-053).
public struct DocumentEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public var payload: Payload
    public var schemaVersion: Int

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
