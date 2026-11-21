import CNCGeometry
import CNCMachineProfile
import CNCValidation
import Testing

private let profile = TTC450Pro.profile

private func program(_ text: String, moves: [ParsedMove] = []) -> ParsedProgram {
    ParsedProgram(text: text, moves: moves)
}

@Test func envelopeIsBoundaryInclusive() {
    let inside = program(
        "G1 X460.000 Y460.000 Z80.000 F800.000",
        moves: [
            ParsedMove(
                lineNumber: 1,
                mode: .cut,
                start: Vec3(x: 0, y: 0, z: 0),
                end: Vec3(x: 460, y: 460, z: 80),
                feedRate: 800
            )
        ]
    )
    #expect(
        ValidationRules().evaluate(inside, profile: profile).filter {
            $0.ruleIdentifier.contains("envelope")
                || $0.message.localizedCaseInsensitiveContains("envelope")
        }.isEmpty)

    let outside = program(
        "G1 X460.001 Y0.000 Z0.000 F800.000",
        moves: [
            ParsedMove(
                lineNumber: 1,
                mode: .cut,
                start: Vec3(x: 0, y: 0, z: 0),
                end: Vec3(x: 460.001, y: 0, z: 0),
                feedRate: 800
            )
        ]
    )
    let findings = ValidationRules().evaluate(outside, profile: profile)
    #expect(
        findings.contains {
            $0.severity == .error
                && ($0.message.localizedCaseInsensitiveContains("envelope")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("envelope")
                    || $0.message.localizedCaseInsensitiveContains("460"))
        })
}

@Test func feedAboveCeilingAndSpindleOutsideRangeAreRejected() {
    let overFeed = program(
        "G1 X10.000 Y0.000 Z0.000 F801.000",
        moves: [
            ParsedMove(
                lineNumber: 1,
                mode: .cut,
                start: Vec3(x: 0, y: 0, z: 0),
                end: Vec3(x: 10, y: 0, z: 0),
                feedRate: 801
            )
        ]
    )
    #expect(
        ValidationRules().evaluate(overFeed, profile: profile).contains {
            $0.severity == .error
                && ($0.message.contains("800")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("feed"))
        })

    let badSpindle = program("M3 S4999\nM3 S8001")
    let spindleFindings = ValidationRules().evaluate(badSpindle, profile: profile)
    #expect(
        spindleFindings.contains {
            $0.severity == .error
                && ($0.message.contains("4999") || $0.message.contains("5000")
                    || $0.message.localizedCaseInsensitiveContains("spindle"))
        })
    #expect(
        spindleFindings.contains {
            $0.severity == .error
                && ($0.message.contains("8001") || $0.message.contains("8000")
                    || $0.message.localizedCaseInsensitiveContains("spindle"))
        })
}

@Test func feedWordOnRapidIsRejected() {
    let text = "G0 Z10.000 F800.000"
    let findings = ValidationRules().evaluate(program(text), profile: profile)
    #expect(
        findings.contains {
            $0.severity == .error
                && ($0.ruleIdentifier.localizedCaseInsensitiveContains("rapid")
                    || $0.message.localizedCaseInsensitiveContains("rapid")
                    || $0.message.localizedCaseInsensitiveContains("F"))
        })
}

@Test func startAndStopBlockOrderAndFinalM30AreRequired() {
    let good = program(
        """
        G21
        G90
        G94
        G00 Z10.0
        M3 S8000
        G90
        G00 Z15.0
        M5
        G00 X0 Y0
        M30
        """
    )
    #expect(
        ValidationRules().evaluate(good, profile: profile).filter {
            $0.severity == .error
                && ($0.ruleIdentifier.contains("block") || $0.ruleIdentifier.contains("order")
                    || $0.message.localizedCaseInsensitiveContains("block")
                    || $0.message.localizedCaseInsensitiveContains("M30"))
        }.isEmpty)

    let badOrder = program(
        """
        G21
        G90
        G00 Z10.0
        G94
        M3 S8000
        G90
        G00 Z15.0
        M5
        G00 X0 Y0
        M30
        """
    )
    #expect(
        ValidationRules().evaluate(badOrder, profile: profile).contains { $0.severity == .error })

    let notFinal = program(
        """
        G21
        G90
        G94
        G00 Z10.0
        M3 S8000
        G90
        G00 Z15.0
        M5
        G00 X0 Y0
        M30
        G0 X1 Y1
        """
    )
    #expect(
        ValidationRules().evaluate(notFinal, profile: profile).contains {
            $0.severity == .error
                && ($0.message.localizedCaseInsensitiveContains("M30")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("final")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("m30"))
        })
}

@Test func spindleMustStopBeforeOriginReturn() {
    let text = """
        G21
        G90
        G94
        G00 Z10.0
        M3 S8000
        G90
        G00 Z15.0
        G00 X0 Y0
        M5
        M30
        """
    let findings = ValidationRules().evaluate(program(text), profile: profile)
    #expect(
        findings.contains {
            $0.severity == .error
                && ($0.message.localizedCaseInsensitiveContains("M5")
                    || $0.message.localizedCaseInsensitiveContains("origin")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("origin")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("spindle"))
        })
}

@Test func rasterRapidsThroughOriginBeforeTheStopBlockAreNotOriginReturns() {
    let text = """
        G21
        G90
        G94
        G00 Z10.0
        M3 S8000
        G0 X0 Y0
        G1 Z-1.000 F600.000
        G0 Z10.000
        G0 X0 Y0
        G90
        G00 Z15.0
        M5
        G00 X0 Y0
        M30
        """
    let findings = ValidationRules().evaluate(program(text), profile: profile)
    #expect(
        !findings.contains { $0.ruleIdentifier == "spindle-before-origin" },
        "a raster rapid through the origin is not the final origin return"
    )
}

@Test func sWordDetectionRuleRejectsLaserPowerButAcceptsSpindleSpeed() {
    // 2026-11-20 clarification (FR-031): S is a power word only alongside an already-rejected
    // laser token or dynamic-power comment, never on its own.
    let laserLines = [
        "M4 S6000",
        "$32=1",
        "M4 S6000 ; dynamic power",
    ]
    for line in laserLines {
        let findings = ValidationRules().evaluate(program("G21\n\(line)\nM30"), profile: profile)
        #expect(
            findings.contains { $0.severity == .error },
            "expected rejection for laser/dynamic-power line \(line)"
        )
    }

    let spindle = ValidationRules().evaluate(program("M3 S6000"), profile: profile)
    #expect(
        !spindle.contains {
            $0.ruleIdentifier.localizedCaseInsensitiveContains("power")
                || $0.ruleIdentifier.localizedCaseInsensitiveContains("laser")
                || $0.message.localizedCaseInsensitiveContains("power")
                || $0.message.localizedCaseInsensitiveContains("laser")
        },
        "a standalone spindle S word must not be rejected as laser power"
    )
    #expect(!spindle.contains { $0.ruleIdentifier == "spindle-range" })
}

@Test func forbiddenWordsAndSettingsAreRejected() {
    let tokens = ["$", "M4", "$32", "G93", "G43.1", "G49"]
    for token in tokens {
        let text = "G21\n\(token)\nM30"
        let findings = ValidationRules().evaluate(program(text), profile: profile)
        #expect(findings.contains { $0.severity == .error }, "expected rejection for \(token)")
        #expect(
            findings.contains {
                $0.message.contains(token)
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains(
                        token.replacingOccurrences(of: "$", with: ""))
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("unsupported")
                    || $0.ruleIdentifier.localizedCaseInsensitiveContains("forbidden")
                    || $0.message.localizedCaseInsensitiveContains("reject")
                    || $0.message.localizedCaseInsensitiveContains("unsupported")
                    || $0.message.localizedCaseInsensitiveContains("forbidden")
                    || $0.message.localizedCaseInsensitiveContains(token)
            }, "finding should identify \(token)")
    }
}
