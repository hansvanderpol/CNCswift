import Foundation

public struct CorrelationID: Hashable, Sendable, CustomStringConvertible, Equatable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public protocol CNCError: Error, Sendable {
    var correlationID: CorrelationID { get }
    var userMessage: String { get }
}

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

public struct DiagnosticLogRecord: Sendable, Equatable {
    public let correlationID: CorrelationID
    public let category: String
    public let message: String
}

public struct DiagnosticLogger: Sendable {
    public let subsystem: String

    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func record(_ error: any CNCError, category: String) -> DiagnosticLogRecord {
        let message = "\(error.userMessage) [\(error.correlationID)]"
        return DiagnosticLogRecord(
            correlationID: error.correlationID,
            category: category,
            message: message
        )
    }
}
