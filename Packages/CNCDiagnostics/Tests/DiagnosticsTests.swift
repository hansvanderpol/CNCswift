import Testing

@testable import CNCDiagnostics

@Test func stageFailureCarriesStableCorrelationID() {
    let id = CorrelationID("corr-decode-001")
    let error = StageFailure(
        stage: "decode",
        reason: "truncated STL",
        fix: "Re-export the model as a complete STL file",
        correlationID: id
    )

    #expect(error is any CNCError)
    #expect(error.correlationID == id)
    #expect(error.userMessage.contains("truncated STL"))
    #expect(error.userMessage.contains("Re-export the model"))
}

@Test func loggerRecordSharesCorrelationIDAndCategory() {
    let error: any CNCError = StageFailure(
        stage: "validate",
        reason: "line exceeds 80 characters",
        fix: "Shorten the comment or split the row",
        correlationID: CorrelationID("corr-validate-002")
    )
    let logger = DiagnosticLogger(subsystem: "com.hansvanderpol.CNCswift")

    let record = logger.record(error, category: "validate")

    #expect(record.correlationID == error.correlationID)
    #expect(record.category == "validate")
    #expect(record.message.contains("line exceeds 80 characters"))
    #expect(record.message.contains("corr-validate-002"))
}

@Test func distinctFailuresReceiveDistinctCorrelationIDs() {
    let first = StageFailure(stage: "plan", reason: "stock too small", fix: "Increase the stock")
    let second = StageFailure(stage: "plan", reason: "stock too small", fix: "Increase the stock")

    #expect(first.correlationID != second.correlationID)
    #expect(first.stage == "plan")
}
