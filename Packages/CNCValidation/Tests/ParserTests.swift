import CNCGeometry
import CNCMachineProfile
import CNCValidation
import Testing

private let profile = TTC450Pro.profile

@Test func parsesBasicGRBLSubsetAndTracksModalState() {
    let text = """
        G21
        G90
        G94
        G0 Z10.000
        G1 X10.000 Y5.000 F600.000
        X20.000
        G0 Z15.000
        M30
        """

    let result = GRBLParser().parse(text, profile: profile)

    #expect(result.program.text == text)
    #expect(result.findings.isEmpty)

    // Moves should reflect absolute modal positioning and carry feed on cutting moves.
    #expect(result.program.moves.count == 4)
    guard result.program.moves.count == 4 else { return }

    let m0 = result.program.moves[0]
    #expect(m0.mode == .rapid)
    #expect(m0.end == Vec3(x: 0, y: 0, z: 10))

    let m1 = result.program.moves[1]
    #expect(m1.mode == .cut)
    #expect(m1.start == Vec3(x: 0, y: 0, z: 10))
    #expect(m1.end == Vec3(x: 10, y: 5, z: 10))
    #expect(m1.feedRate == 600)

    let m2 = result.program.moves[2]
    #expect(m2.mode == .cut)
    #expect(m2.end == Vec3(x: 20, y: 5, z: 10))
    #expect(m2.feedRate == 600, "modal feed and motion mode remain in effect")

    let m3 = result.program.moves[3]
    #expect(m3.mode == .rapid)
    #expect(m3.end == Vec3(x: 20, y: 5, z: 15))
}

@Test func reportsUnknownWords() {
    let text = """
        G21
        G90
        G999 X1.000
        Q10
        M30
        """

    let result = GRBLParser().parse(text, profile: profile)

    #expect(
        result.findings.contains {
            $0.severity == .error && $0.message.localizedCaseInsensitiveContains("unknown")
                || $0.ruleIdentifier.localizedCaseInsensitiveContains("unknown")
        })
    #expect(result.findings.contains { $0.lineNumber == 3 })
}

@Test func reportsLinesLongerThanProfileLimit() {
    let longComment = "; " + String(repeating: "A", count: 120)
    let text = "G21\n\(longComment)\nM30\n"

    let result = GRBLParser().parse(text, profile: profile)

    let finding = result.findings.first {
        $0.ruleIdentifier == "line-length" || $0.message.localizedCaseInsensitiveContains("80")
    }
    #expect(finding != nil)
    #expect(finding?.severity == .error)
    #expect(finding?.lineNumber == 2)
}

@Test func tracksModalStateAcrossRapidAndCutTransitions() {
    let text = """
        G90
        G1 X0.000 Y0.000 Z-1.000 F500.000
        G0 Z10.000
        X5.000 Y5.000
        G1 Z-1.000
        """

    let result = GRBLParser().parse(text, profile: profile)

    #expect(result.program.moves.count == 4)
    guard result.program.moves.count == 4 else { return }
    #expect(result.program.moves[0].mode == .cut)
    #expect(result.program.moves[1].mode == .rapid)
    #expect(result.program.moves[2].mode == .rapid)
    #expect(result.program.moves[3].mode == .cut)
    #expect(result.program.moves[3].end == Vec3(x: 5, y: 5, z: -1))
    #expect(result.program.moves[3].feedRate == 500)
}
