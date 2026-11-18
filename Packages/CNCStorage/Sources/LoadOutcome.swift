import Foundation

/// The result of reading one versioned document.
///
/// `absent`, `refused`, and `corrupt` are reported rather than thrown, because they are states a
/// store must surface to the user while keeping the on-disk bytes intact (FR-053, FR-054).
public enum LoadOutcome<Document: Sendable>: Sendable {
    /// No document exists at the expected path; the caller starts from its empty state.
    case absent

    /// The document was read at the current schema version.
    case loaded(Document)

    /// The document was migrated forward from `from` without losing records.
    case migrated(from: Int, document: Document)

    /// The document declares a newer schema version than this app supports.
    case refused(found: Int)

    /// The document could not be decoded; the original bytes are untouched.
    case corrupt(detail: String)
}

extension LoadOutcome: Equatable where Document: Equatable {}
