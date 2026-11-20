import Foundation
import Testing

@testable import CNCDiagnostics

@Test func sensitiveValueNeverAppearsInClearText() {
    let secret = "customer-project-secret-token"
    let value = SensitiveValue(secret)

    #expect(SensitiveValue.redactedMarker == "[redacted]")
    #expect(value.logDescription == SensitiveValue.redactedMarker)
    #expect(!value.logDescription.contains(secret))
}

@Test func loggerRedactsExplicitSensitivePayloads() {
    let logger = DiagnosticLogger(subsystem: "com.hansvanderpol.CNCswift", category: .decode)
    let secret = "customer-project-secret-token"

    let record = logger.error(
        "decode failed",
        correlationID: CorrelationID("corr-redact-001"),
        sensitive: [SensitiveValue(secret)]
    )

    #expect(record.message.contains("decode failed"))
    #expect(record.message.contains("corr-redact-001"))
    #expect(record.message.contains(SensitiveValue.redactedMarker))
    #expect(!record.message.contains(secret))
}

@Test func typedFailureWithSensitivePayloadKeepsStableMetadata() {
    let logger = DiagnosticLogger()
    let secret = "secret-path-value"
    let error = StageFailure(
        stage: "storage",
        reason: "library unreadable",
        fix: "Restore the backup",
        correlationID: CorrelationID("corr-redact-002")
    )

    let record = logger.record(error, sensitive: [SensitiveValue(secret)])

    #expect(record.correlationID == error.correlationID)
    #expect(record.category == "pipeline")
    #expect(record.message.contains("library unreadable"))
    #expect(!record.message.contains(secret))
}

@Test func emitterDoesNotLogTheWholeMessageWithPublicPrivacy() throws {
    let packages = try packageRoot()
    let emitter =
        packages
        .appendingPathComponent("CNCDiagnostics", isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("Diagnostics.swift")
    let source = try String(contentsOf: emitter, encoding: .utf8)

    #expect(!source.contains("record.message, privacy: .public"))
    #expect(source.contains("privacy: .private"))
}

@Test func shippingSourcesDoNotConstructLoggersDirectly() throws {
    let packages = try packageRoot()
    var offenders: [String] = []

    let directories = try FileManager.default.contentsOfDirectory(
        at: packages, includingPropertiesForKeys: nil
    )
    for package in directories
    where package.hasDirectoryPath && !package.lastPathComponent.hasPrefix(".") {
        guard package.lastPathComponent != "CNCDiagnostics" else { continue }
        let sources = package.appendingPathComponent("Sources", isDirectory: true)
        guard FileManager.default.fileExists(atPath: sources.path) else { continue }

        for relative in try FileManager.default.subpathsOfDirectory(atPath: sources.path) {
            guard relative.hasSuffix(".swift") else { continue }
            let text = try String(
                contentsOf: sources.appendingPathComponent(relative), encoding: .utf8
            )
            if text.contains("Logger(") || text.contains("privacy: .public") {
                offenders.append("\(package.lastPathComponent)/Sources/\(relative)")
            }
        }
    }

    #expect(offenders.isEmpty, "Offending sources: \(offenders.joined(separator: ", "))")
}

private func packageRoot() throws -> URL {
    let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let diagnostics = tests.deletingLastPathComponent()
    return diagnostics.deletingLastPathComponent()
}
