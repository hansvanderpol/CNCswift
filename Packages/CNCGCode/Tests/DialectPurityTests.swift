import Foundation
import Testing

/// Dialect-purity guard for FR-015, FR-016 and FR-017 (C3, plan task-shaping note 12).
///
/// Every GRBL dialect token and machine limit belongs to the versioned profile document
/// (`CNCMachineProfile/Sources/Resources/ttc450-pro.json`). The toolpath and emitter stages consume
/// that profile; they must not hardcode a different machine's limits or an unsupported/laser token.
/// This test reads source as text so a literal added later is caught even if the output guard test
/// happens to miss the new path.
private let generationPackages = ["CNCToolpath", "CNCGCode"]

/// Tokens the configured dialect must never emit (FR-017, FR-031). They are listed in the profile's
/// `unsupportedCommands`; seeing one in the emission stages means a hardcoded code path.
private let forbiddenDialectTokens = [
    "\"M4\"", "\"$32\"", "\"G43\"", "\"G49\"", "\"G93\"", "\"M6\"", "\"M7\"",
]

/// Machine-specific limit numbers that must come from the profile, never from a stage constant.
private let machineLimitLiterals = ["460", "8000", "5000"]

private func repositoryRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        url = url.deletingLastPathComponent()
    }
    return url
}

private func swiftFiles(in package: String, root: URL) throws -> [URL] {
    let sources =
        root
        .appendingPathComponent("Packages", isDirectory: true)
        .appendingPathComponent(package, isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
    guard FileManager.default.fileExists(atPath: sources.path) else { return [] }
    return try FileManager.default.subpathsOfDirectory(atPath: sources.path)
        .filter { $0.hasSuffix(".swift") }
        .map { sources.appendingPathComponent($0) }
}

private func generationSource(root: URL) throws -> [(file: String, text: String)] {
    var result: [(file: String, text: String)] = []
    for package in generationPackages {
        for file in try swiftFiles(in: package, root: root) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let relative = file.path.replacingOccurrences(of: root.path + "/", with: "")
            result.append((relative, text))
        }
    }
    return result
}

@Test func profileIsTheSingleSourceOfDialectAndLimits() throws {
    let url = repositoryRoot()
        .appendingPathComponent("Packages", isDirectory: true)
        .appendingPathComponent("CNCMachineProfile", isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent("ttc450-pro.json")
    let profile = try String(contentsOf: url, encoding: .utf8)

    for limit in machineLimitLiterals {
        #expect(profile.contains(limit), "profile document must declare machine limit \(limit)")
    }
    for token in ["\"G43\"", "\"M4\"", "\"$32\""] {
        #expect(profile.contains(token), "profile must list unsupported token \(token)")
    }
    #expect(profile.contains("\"dialect\": \"grbl1_1\""))
}

@Test func emissionStagesDoNotHardcodeUnsupportedDialectTokens() throws {
    let sources = try generationSource(root: repositoryRoot())
    var findings: [String] = []
    for source in sources {
        for token in forbiddenDialectTokens where source.text.contains(token) {
            findings.append("\(source.file): \(token)")
        }
    }
    #expect(findings.isEmpty, "Unsupported dialect token hardcoded in emission stage: \(findings)")
}

@Test func emissionStagesDoNotHardcodeMachineLimitConstants() throws {
    let sources = try generationSource(root: repositoryRoot())
    // A literal assigned to a constant is a hardcoded machine limit. Quote-delimited numbers and
    // message strings (for example "460 x 460 x 80 mm") are documentation, not a limit constant.
    let assignmentPattern = #"(?:let|var)\s+\w+\s*(?::[^\n=]+)?=\s*(?:460|8000|5000)\b"#
    var findings: [String] = []
    for source in sources {
        for line in source.text.split(separator: "\n")
        where line.range(
            of: assignmentPattern,
            options: .regularExpression
        ) != nil {
            findings.append("\(source.file): \(line.trimmingCharacters(in: .whitespaces))")
        }
    }
    #expect(findings.isEmpty, "Machine limit hardcoded outside the profile: \(findings)")
}

@Test func emitterReadsBlocksAndLimitsFromTheProfile() throws {
    let root = repositoryRoot()
    let sources = try generationSource(root: root)
    let emitter = sources.filter { $0.file.contains("CNCGCode/Sources") }
    let combined = emitter.map(\.text).joined(separator: "\n")
    for reference in [
        "profile.startBlock", "profile.stopBlock", "profile.limits", "profile.controllerSetup",
    ] {
        #expect(combined.contains(reference), "emitter must read \(reference) from the profile")
    }
}
