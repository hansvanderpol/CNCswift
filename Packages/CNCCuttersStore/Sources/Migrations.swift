import CNCCutters
import CNCStorage
import Foundation

/// The forward-only cutter-library migration chain (FR-052, SC-008).
///
/// The version this build writes is v2. A v1 document is stepped forward by validating every
/// stored cutter and stamping the new schema version; no field is added, removed, or rewritten.
/// A record that cannot be validated aborts the load, and `CNCStorage` leaves the original bytes
/// untouched because migrations never write during a load.
public enum CutterMigrations {
    /// The schema version this build writes and reads without migration.
    public static let currentVersion = 2

    /// One migration step per older schema version, keyed by the version it upgrades from.
    public static let steps: [Int: @Sendable (Data) throws -> Data] = [
        1: migrateV1ToV2
    ]

    /// Validates a v1 payload and restamps it as v2 without changing any cutter value.
    ///
    /// - Parameter data: A versioned cutter-library document at schema version 1.
    /// - Throws: `CutterValidationError` for any record that cannot be preserved under v2.
    /// - Returns: The same cutters in a document stamped at schema version 2.
    private static func migrateV1ToV2(_ data: Data) throws -> Data {
        var envelope = try JSONDecoder().decode(
            DocumentEnvelope<CutterLibraryDocument>.self,
            from: data
        )
        for cutter in envelope.payload.cutters {
            try CutterValidator.validate(cutter)
        }
        envelope.schemaVersion = currentVersion

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(envelope)
    }
}
