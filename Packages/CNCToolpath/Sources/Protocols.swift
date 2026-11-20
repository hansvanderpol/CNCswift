import CNCCutters
import CNCDiagnostics
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import Foundation

/// The blank the model is carved from.
///
/// Dimensions are millimetres. The origin is fixed at the front-left top corner: X0 Y0 at that
/// corner and Z0 at the top surface (FR-009).
public struct StockBlank: Sendable, Equatable {
    public let width: Double
    public let depth: Double
    public let height: Double

    public init(width: Double, depth: Double, height: Double) {
        self.width = width
        self.depth = depth
        self.height = height
    }
}

/// Whether a move removes material or repositions the cutter.
public enum MoveMode: String, Sendable, Equatable, Codable {
    /// A rapid traverse. GRBL ignores any feed word on it, so it never carries one (FR-024).
    case rapid

    /// A cutting move at the job's confirmed effective feed.
    case cut
}

/// One ordered machine-space move.
public struct Move: Sendable, Equatable {
    public let from: Vec3
    public let to: Vec3
    public let mode: MoveMode

    public init(from: Vec3, to: Vec3, mode: MoveMode) {
        self.from = from
        self.to = to
        self.mode = mode
    }
}

/// The planner's output: ordered moves plus the feed every cutting move uses.
///
/// Roughing moves come first, deepest layer first, then the finishing raster, so the order of
/// `moves` is the program order. The toolpath is a pure function of the job inputs (FR-036).
public struct Toolpath: Sendable, Equatable {
    public let moves: [Move]

    /// The job's confirmed effective feed, applied to every cutting move (FR-040).
    public let feedRate: Double

    /// The machine-space box the moves occupy; it must lie inside the envelope and the stock.
    public let bounds: AABB

    public init(moves: [Move], feedRate: Double, bounds: AABB) {
        self.moves = moves
        self.feedRate = feedRate
        self.bounds = bounds
    }
}

/// The confirmed choices binding one model, stock, material, cutter, and strategy to a job.
///
/// Every field is a value: the planner never reads the library, the UI, or the clock.
public struct JobSettings: Sendable, Equatable {
    /// The model mesh in model space; the planner applies the explicit machine transform.
    public let mesh: Mesh

    /// The model's bounds in model units, used for footprint and fit checks.
    public let modelBounds: AABB

    public let stock: StockBlank

    /// The stored cutter this job references, resolved from the library before planning.
    ///
    /// `cutterID` remains the stable identity used by headers and library events; `cutter` carries
    /// the authoritative dimensions so the planner never invents or defaults geometry (FR-043,
    /// FR-049).
    public let cutter: Cutter

    /// The stable identifier of `cutter`.
    public let cutterID: CutterID

    /// The preset or user material this job references.
    public let materialID: String

    /// The resolved and confirmed feed and spindle for this job (FR-079).
    public let effective: EffectiveCuttingValues

    /// Raster spacing, greater than zero and below the cutter's cutting diameter (FR-035).
    public let stepover: Double

    /// Maximum depth removed in one pass; at most the cutter's cutting length (FR-033).
    public let maxDepthPerPass: Double

    /// Material left for the finishing pass; at least zero and below the stock height (FR-034).
    public let finishingAllowance: Double

    /// The user confirmed the model's units and orientation (FR-005).
    public let unitsConfirmed: Bool

    /// The user confirmed the model's orientation (FR-005).
    public let orientationConfirmed: Bool

    /// The operator confirmed the controller rapid-rate settings (FR-024).
    public let rapidRateConfirmed: Bool

    /// The user confirmed the suggested strategy values (FR-037).
    public let confirmed: Bool

    public init(
        mesh: Mesh,
        modelBounds: AABB,
        stock: StockBlank,
        cutter: Cutter,
        materialID: String,
        effective: EffectiveCuttingValues,
        stepover: Double,
        maxDepthPerPass: Double,
        finishingAllowance: Double,
        unitsConfirmed: Bool,
        orientationConfirmed: Bool,
        rapidRateConfirmed: Bool,
        confirmed: Bool
    ) {
        self.mesh = mesh
        self.modelBounds = modelBounds
        self.stock = stock
        self.cutter = cutter
        self.cutterID = cutter.id
        self.materialID = materialID
        self.effective = effective
        self.stepover = stepover
        self.maxDepthPerPass = maxDepthPerPass
        self.finishingAllowance = finishingAllowance
        self.unitsConfirmed = unitsConfirmed
        self.orientationConfirmed = orientationConfirmed
        self.rapidRateConfirmed = rapidRateConfirmed
        self.confirmed = confirmed
    }
}

/// Machine-readable reasons planning was refused.
///
/// Errors name the failing precondition; the UI maps each case to an actionable message (FR-067).
public enum PlanningError: Error, Equatable, Sendable {
    /// The model is larger than the stock on at least one axis (FR-011).
    case modelOutsideStock

    /// The cutter cannot reproduce the smallest feature (FR-041).
    case featureTooSmall(smallestConcaveRadius: Double, effectiveRadius: Double)

    /// A requested depth exceeds the cutter's cutting length (FR-033).
    case depthExceedsCuttingLength

    /// The stepover is not positive or not below the cutting diameter (FR-035).
    case invalidStepover

    /// The finishing allowance is negative or not below the stock height (FR-034).
    case invalidAllowance

    /// The toolpath would leave the machine envelope (FR-025).
    case envelopeExceeded

    /// Effective feed or spindle has not been confirmed (FR-079).
    case unconfirmedEffectiveValues

    /// The controller rapid-rate settings have not been confirmed (FR-024).
    case rapidSetupUnconfirmed

    /// Units or orientation has not been confirmed (FR-005).
    case unconfirmedModel

    /// Suggested strategy values have not been confirmed (FR-037).
    case unconfirmedSettings

    /// The cutter record lacks an attribute the chosen strategy requires (FR-049).
    case missingCutterAttribute(String)

    /// The selected cutter cannot reach the bottom of the stock (FR-049).
    case cutterTooShort(requiredCuttingLength: Double)

    /// A stock dimension is not positive or exceeds the machine envelope (FR-010).
    case invalidStock(String)

    /// An actionable message for the UI, naming measurements in millimetres (FR-067).
    public var userMessage: String {
        switch self {
        case .modelOutsideStock:
            return
                "The model does not fit inside the stock. Reduce the model scale or choose a larger blank."
        case .featureTooSmall(let smallest, let effective):
            return
                "Smallest concave feature \(format(smallest)) mm is below the cutter's effective radius \(format(effective)) mm. Choose a smaller cutter."
        case .depthExceedsCuttingLength:
            return
                "Maximum depth per pass exceeds the cutter's cutting length. Lower the depth per pass."
        case .invalidStepover:
            return "Stepover must be positive and smaller than the cutter's cutting diameter."
        case .invalidAllowance:
            return "Finishing allowance must be at least zero and smaller than the stock height."
        case .envelopeExceeded:
            return "The stock exceeds the machine envelope of 460 x 460 x 80 mm."
        case .unconfirmedEffectiveValues:
            return "Confirm the effective feed and spindle values before generating."
        case .rapidSetupUnconfirmed:
            return
                "Confirm that the controller rapid-rate settings ($110-$112) are applied before generating."
        case .unconfirmedModel:
            return "Confirm the model's units and orientation before generating."
        case .unconfirmedSettings:
            return "Confirm the suggested job settings before generating."
        case .missingCutterAttribute(let name):
            return "The selected cutter is missing \(name). Edit the cutter in the library."
        case .cutterTooShort(let required):
            return
                "The selected cutter cannot reach the stock bottom. Select a cutter with a cutting length of at least \(format(required)) mm."
        case .invalidStock(let dimension):
            return "Stock \(dimension) must be positive and inside the machine envelope."
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// The planning stage boundary (FR-032 – FR-041).
public protocol ToolpathPlanning: Sendable {
    /// Produces ordered roughing and finishing moves.
    ///
    /// - Preconditions: model units and orientation confirmed, cutter and material resolved,
    ///   effective values confirmed, rapid setup confirmed, stock inside the envelope, and the
    ///   cutter long enough to reach the stock bottom.
    /// - Throws: `PlanningError` for every failed precondition.
    /// - Note: Pure; no I/O, no clock, no randomness. Cancellation is reported through `progress`.
    func plan(
        _ job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> Toolpath
}
