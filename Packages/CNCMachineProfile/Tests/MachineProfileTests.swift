import Foundation
import Testing

@testable import CNCMachineProfile

private let profileJSON = """
    {
      "profileID": "twotrees-ttc450-pro",
      "displayName": "TwoTrees TTC450 PRO",
      "version": "1.0.0",
      "dialect": "grbl1_1",
      "envelope": { "x": 460.0, "y": 460.0, "z": 80.0 },
      "limits": {
        "maxFeedRate": 800.0,
        "maxRapidRate": 800.0,
        "spindleMin": 5000.0,
        "spindleMax": 8000.0,
        "maxLineLength": 80
      },
      "controllerSetup": {
        "spindleBuffer": { "$30": 8000, "$31": 5000 },
        "rapidRate": { "$110": 800, "$111": 800, "$112": 800 }
      },
      "toolActivation": "spindle",
      "clearanceZ": 10.0,
      "returnZ": 15.0,
      "outputExtension": "nc",
      "startBlock": ["G21", "G90", "G94", "G00 Z10.0", "M3 S{spindleSpeed}"],
      "stopBlock": ["G90", "G00 Z15.0", "M5", "G00 X0 Y0", "M30"],
      "supportedCommands": {
        "motion": ["G0", "G1", "G2", "G3"],
        "feedMode": ["G94"],
        "units": ["G20", "G21"],
        "distance": ["G90", "G91"],
        "plane": ["G17", "G18", "G19"],
        "spindle": ["M3", "M5"],
        "program": ["M0", "M1", "M2", "M30"],
        "other": [
          "G4", "G10", "G28", "G30", "G38.2", "G38.3", "G38.4", "G38.5",
          "G40", "G53", "G54", "G55", "G56", "G57", "G58", "G59",
          "G61", "G80", "G91.1", "G92", "G92.1"
        ]
      },
      "unsupportedCommands": ["G43", "G43.1", "G49", "G93", "M4", "M6", "M7", "$32"]
    }
    """

private func decodedProfile() throws -> MachineProfile {
    try MachineProfile.decode(Data(profileJSON.utf8))
}

@Test func shippedProfileDecodesWithExpectedValues() throws {
    let profile = try decodedProfile()

    #expect(profile.profileID == "twotrees-ttc450-pro")
    #expect(profile.version == "1.0.0")
    #expect(profile.dialect == "grbl1_1")
    #expect(profile.envelope == Envelope(x: 460, y: 460, z: 80))
    #expect(profile.limits.maxFeedRate == 800)
    #expect(profile.limits.maxRapidRate == 800)
    #expect(profile.limits.maxLineLength == 80)
    #expect(profile.outputExtension == "nc")
    #expect(profile.clearanceZ == 10)
    #expect(profile.returnZ == 15)
}

@Test func blocksAreOrderedAndContainOnlyTheDocumentedSubstitution() throws {
    let profile = try decodedProfile()

    #expect(
        profile.startBlock == ["G21", "G90", "G94", "G00 Z10.0", "M3 S{spindleSpeed}"]
    )
    #expect(profile.stopBlock == ["G90", "G00 Z15.0", "M5", "G00 X0 Y0", "M30"])
    #expect(profile.startBlock.last?.contains("{spindleSpeed}") == true)
}

@Test func controllerSetupIsDescriptiveAndUsesProfileLimits() throws {
    let profile = try decodedProfile()

    #expect(profile.controllerSetup.rapidRate == ["$110": 800, "$111": 800, "$112": 800])
    #expect(profile.controllerSetup.spindleBuffer == ["$30": 8000, "$31": 5000])
    #expect(
        profile.controllerSetup.rapidRate.values.allSatisfy {
            $0 == Int(profile.limits.maxRapidRate)
        })
}

@Test func feedModeIsG94OnlyAndLaserTokensAreUnsupported() throws {
    let profile = try decodedProfile()

    #expect(profile.supportedCommands["feedMode"] == ["G94"])
    #expect(profile.supportedCommands["spindle"] == ["M3", "M5"])
    for token in ["G43", "G43.1", "G49", "G93", "M4", "M6", "M7", "$32"] {
        #expect(profile.unsupportedCommands.contains(token), "\(token) must be unsupported")
    }
    #expect(!(profile.supportedCommands["spindle"] ?? []).contains("M4"))
}

@Test func tt450ProDataMatchesTheDecodedContract() throws {
    #expect(try TTC450Pro.profile == decodedProfile())
}

@Test func unknownDialectIsRejected() throws {
    var data = Data(profileJSON.utf8)
    let json = try #require(String(data: data, encoding: .utf8))
    data = Data(json.replacingOccurrences(of: "grbl1_1", with: "marlin").utf8)

    #expect(throws: ProfileError.self) {
        try MachineProfile.decode(data)
    }
}

@Test func inconsistentRapidSetupIsRejected() throws {
    let json = try #require(String(data: Data(profileJSON.utf8), encoding: .utf8))
    let altered = json.replacingOccurrences(of: "\"$110\": 800", with: "\"$110\": 900")
    let data = Data(altered.utf8)

    #expect(throws: ProfileError.inconsistentRapidSetup) {
        try MachineProfile.decode(data)
    }
}

@Test func invalidLimitsAndInvertedSpindleRangeAreRejected() throws {
    let json = try #require(String(data: Data(profileJSON.utf8), encoding: .utf8))
    let badEnvelope = Data(json.replacingOccurrences(of: "\"z\": 80.0", with: "\"z\": 0").utf8)
    #expect(throws: ProfileError.self) { try MachineProfile.decode(badEnvelope) }

    let inverted = Data(
        json.replacingOccurrences(of: "\"spindleMin\": 5000.0", with: "\"spindleMin\": 9000.0").utf8
    )
    #expect(throws: ProfileError.invertedSpindleRange) { try MachineProfile.decode(inverted) }

    let zeroFeed = Data(
        json.replacingOccurrences(of: "\"maxFeedRate\": 800.0", with: "\"maxFeedRate\": 0").utf8)
    #expect(throws: ProfileError.invalidLimits) { try MachineProfile.decode(zeroFeed) }
}
