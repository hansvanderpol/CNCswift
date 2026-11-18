import Foundation
import os

/// A stable identifier tying a typed stage error to its structured log record (FR-067).
public struct CorrelationID: Hashable, Sendable, CustomStringConvertible, Equatable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

/// The shape every stage error follows: one correlation identifier, one actionable message.
public protocol CNCError: Error, Sendable {
    /// The identifier shared with the matching `os.Logger` record.
    var correlationID: CorrelationID { get }

    /// A message naming the problem and the fix, shown to the user.
    var userMessage: String { get }
}

/// A typed failure from one pipeline stage.
public struct StageFailure: CNCError, Equatable, Sendable {
    public let stage: String
    public let reason: String
    public let fix: String
    public let correlationID: CorrelationID

    public init(stage: String, reason: String, fix: String, correlationID: CorrelationID) {
        self.stage = stage
        self.reason = reason
        self.fix = fix
        self.correlationID = correlationID
    }

    public init(stage: String, reason: String, fix: String) {
        self.stage = stage
        self.reason = reason
        self.fix = fix
        self.correlationID = CorrelationID(UUID().uuidString)
    }

    public var userMessage: String {
        "\(reason). \(fix)"
    }
}

/// One structured log record, returned so tests can assert what the logger emitted.
public struct DiagnosticLogRecord: Sendable, Equatable {
    public let correlationID: CorrelationID
    public let category: String
    public let message: String
}

/// The logging categories the app publishes, one per module and stage (FR-068).
///
/// Each domain package logs under its own category so a session can be filtered by stage without
/// parsing message text.
public enum DiagnosticCategory: String, CaseIterable, Sendable {
    case decode
    case plan
    case render
    case validate
    case simulate
    case pipeline
    case storage
    case cutters
    case materials
    case ui
}

/// The structured logger every module uses.
///
/// A logger is bound to one subsystem and one default category; pass a different category only
/// when one module reports on behalf of another stage.
public struct DiagnosticLogger: Sendable {
    /// The app's single logging subsystem.
    public static let defaultSubsystem = "com.hansvanderpol.CNCswift"

    public let subsystem: String
    public let category: DiagnosticCategory

    public init(
        subsystem: String = DiagnosticLogger.defaultSubsystem,
        category: DiagnosticCategory = .pipeline
    ) {
        self.subsystem = subsystem
        self.category = category
    }

    /// Logs a typed stage failure at error level and returns the emitted record.
    ///
    /// - Parameter category: Overrides the logger's default category for this record.
    @discardableResult
    public func record(_ error: any CNCError, category: String? = nil) -> DiagnosticLogRecord {
        let categoryName = category ?? self.category.rawValue
        let record = DiagnosticLogRecord(
            correlationID: error.correlationID,
            category: categoryName,
            message: "\(error.userMessage) [\(error.correlationID)]"
        )
        emit(record, level: .error)
        return record
    }

    /// Logs a failure described by text, generating a correlation identifier when none is supplied.
    @discardableResult
    public func error(
        _ message: String,
        correlationID: CorrelationID? = nil
    ) -> DiagnosticLogRecord {
        let identifier = correlationID ?? CorrelationID(UUID().uuidString)
        let record = DiagnosticLogRecord(
            correlationID: identifier,
            category: category.rawValue,
            message: "[\(identifier)] \(message)"
        )
        emit(record, level: .error)
        return record
    }

    /// Logs a non-failing event, such as a stage reaching completion.
    @discardableResult
    public func info(_ message: String) -> DiagnosticLogRecord {
        let record = DiagnosticLogRecord(
            correlationID: CorrelationID(UUID().uuidString),
            category: category.rawValue,
            message: message
        )
        emit(record, level: .info)
        return record
    }

    private func emit(_ record: DiagnosticLogRecord, level: OSLogType) {
        let logger = Logger(subsystem: subsystem, category: record.category)
        logger.log(level: level, "\(record.message, privacy: .public)")
    }
}
