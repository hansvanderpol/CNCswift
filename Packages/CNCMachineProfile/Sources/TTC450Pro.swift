import Foundation

/// The machine's inclusive X/Y/Z working volume, in millimetres.
public struct Envelope: Equatable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Limits that all generated programs must respect, sourced from the profile document.
public struct MachineLimits: Equatable, Sendable, Codable {
    public let maxFeedRate: Double
    public let maxRapidRate: Double
    public let spindleMin: Double
    public let spindleMax: Double
    public let maxLineLength: Int

    public init(
        maxFeedRate: Double,
        maxRapidRate: Double,
        spindleMin: Double,
        spindleMax: Double,
        maxLineLength: Int
    ) {
        self.maxFeedRate = maxFeedRate
        self.maxRapidRate = maxRapidRate
        self.spindleMin = spindleMin
        self.spindleMax = spindleMax
        self.maxLineLength = maxLineLength
    }
}

/// Descriptive controller settings the operator applies once; never emitted as program text.
public struct ControllerSetup: Equatable, Sendable, Codable {
    public let spindleBuffer: [String: Int]
    public let rapidRate: [String: Int]

    public init(spindleBuffer: [String: Int], rapidRate: [String: Int]) {
        self.spindleBuffer = spindleBuffer
        self.rapidRate = rapidRate
    }
}

/// Machine-readable reasons a profile document cannot be used.
public enum ProfileError: Error, Equatable, Sendable {
    case invalidDocument(String)
    case unsupportedDialect(String)
    case invalidLimits
    case invertedSpindleRange
    case inconsistentRapidSetup
    case inconsistentSpindleBuffer
    case unsupportedToolActivation(String)
    case unsupportedOutputExtension(String)
    case unsupportedFeedMode
    case conflictingCommands
    case invalidBlocks
}

/// The immutable, versioned description of one supported machine and dialect.
public struct MachineProfile: Equatable, Sendable {
    public let profileID: String
    public let displayName: String
    public let version: String
    public let dialect: String
    public let envelope: Envelope
    public let limits: MachineLimits
    public let controllerSetup: ControllerSetup
    public let toolActivation: String
    public let clearanceZ: Double
    public let returnZ: Double
    public let outputExtension: String
    public let startBlock: [String]
    public let stopBlock: [String]
    public let supportedCommands: [String: [String]]
    public let unsupportedCommands: [String]

    public init(
        profileID: String,
        displayName: String,
        version: String,
        dialect: String,
        envelope: Envelope,
        limits: MachineLimits,
        controllerSetup: ControllerSetup,
        toolActivation: String,
        clearanceZ: Double,
        returnZ: Double,
        outputExtension: String,
        startBlock: [String],
        stopBlock: [String],
        supportedCommands: [String: [String]],
        unsupportedCommands: [String]
    ) {
        self.profileID = profileID
        self.displayName = displayName
        self.version = version
        self.dialect = dialect
        self.envelope = envelope
        self.limits = limits
        self.controllerSetup = controllerSetup
        self.toolActivation = toolActivation
        self.clearanceZ = clearanceZ
        self.returnZ = returnZ
        self.outputExtension = outputExtension
        self.startBlock = startBlock
        self.stopBlock = stopBlock
        self.supportedCommands = supportedCommands
        self.unsupportedCommands = unsupportedCommands
    }

    /// Decodes a profile document and rejects it when any startup invariant fails.
    public static func decode(_ data: Data) throws -> MachineProfile {
        let document: ProfileDocument
        do {
            document = try JSONDecoder().decode(ProfileDocument.self, from: data)
        } catch {
            throw ProfileError.invalidDocument(String(describing: error))
        }

        try validate(document)

        return MachineProfile(
            profileID: document.profileID,
            displayName: document.displayName,
            version: document.version,
            dialect: document.dialect,
            envelope: document.envelope,
            limits: document.limits,
            controllerSetup: document.controllerSetup,
            toolActivation: document.toolActivation,
            clearanceZ: document.clearanceZ,
            returnZ: document.returnZ,
            outputExtension: document.outputExtension,
            startBlock: document.startBlock,
            stopBlock: document.stopBlock,
            supportedCommands: document.supportedCommands,
            unsupportedCommands: document.unsupportedCommands
        )
    }

    private static func validate(_ document: ProfileDocument) throws {
        guard !document.profileID.isEmpty, !document.version.isEmpty else {
            throw ProfileError.invalidDocument("profileID and version must not be empty")
        }
        guard document.dialect == "grbl1_1" else {
            throw ProfileError.unsupportedDialect(document.dialect)
        }
        guard document.envelope.x > 0, document.envelope.y > 0, document.envelope.z > 0 else {
            throw ProfileError.invalidLimits
        }
        guard
            document.limits.maxFeedRate > 0,
            document.limits.maxRapidRate > 0,
            document.limits.maxLineLength > 0,
            document.limits.spindleMin > 0
        else {
            throw ProfileError.invalidLimits
        }
        guard document.limits.spindleMax >= document.limits.spindleMin else {
            throw ProfileError.invertedSpindleRange
        }
        guard
            !document.controllerSetup.rapidRate.isEmpty,
            document.controllerSetup.rapidRate.values.allSatisfy({
                $0 == Int(document.limits.maxRapidRate)
            })
        else {
            throw ProfileError.inconsistentRapidSetup
        }
        guard
            document.controllerSetup.spindleBuffer["$30"] == Int(document.limits.spindleMax),
            document.controllerSetup.spindleBuffer["$31"] == Int(document.limits.spindleMin)
        else {
            throw ProfileError.inconsistentSpindleBuffer
        }
        guard document.toolActivation == "spindle" else {
            throw ProfileError.unsupportedToolActivation(document.toolActivation)
        }
        guard document.outputExtension == "nc" else {
            throw ProfileError.unsupportedOutputExtension(document.outputExtension)
        }
        guard document.clearanceZ > 0, document.returnZ >= document.clearanceZ else {
            throw ProfileError.invalidLimits
        }
        guard document.supportedCommands["feedMode"] == ["G94"] else {
            throw ProfileError.unsupportedFeedMode
        }
        let supported = Set(document.supportedCommands.values.flatMap { $0 })
        guard Set(document.unsupportedCommands).isDisjoint(with: supported) else {
            throw ProfileError.conflictingCommands
        }
        guard substitutionCount(in: document.startBlock + document.stopBlock) == 1 else {
            throw ProfileError.invalidBlocks
        }
    }

    private static func substitutionCount(in lines: [String]) -> Int {
        lines.reduce(0) { total, line in
            total + line.components(separatedBy: "{spindleSpeed}").count - 1
        }
    }
}

/// The shipped TwoTrees TTC450 PRO profile, loaded from the bundled JSON document.
public enum TTC450Pro {
    /// The validated profile used throughout the app.
    public static let profile: MachineProfile = {
        guard
            let url = Bundle.module.url(forResource: "ttc450-pro", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let profile = try? MachineProfile.decode(data)
        else {
            fatalError("Bundled TTC450 PRO profile is invalid")
        }
        return profile
    }()
}

private struct ProfileDocument: Decodable {
    let profileID: String
    let displayName: String
    let version: String
    let dialect: String
    let envelope: Envelope
    let limits: MachineLimits
    let controllerSetup: ControllerSetup
    let toolActivation: String
    let clearanceZ: Double
    let returnZ: Double
    let outputExtension: String
    let startBlock: [String]
    let stopBlock: [String]
    let supportedCommands: [String: [String]]
    let unsupportedCommands: [String]
}
