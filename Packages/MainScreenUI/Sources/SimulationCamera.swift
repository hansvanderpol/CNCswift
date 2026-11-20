import Observation

/// A keyboard-and-pointer navigation command for the 3D preview (FR-070).
///
/// - Concurrency: Sendable value; safe to pass across tasks.
public enum CameraNavigation: Sendable, Equatable {
    case orbitLeft
    case orbitRight
    case orbitUp
    case orbitDown
    case zoomIn
    case zoomOut
    case reset
}

/// Discrete orbit state for the RealityKit preview (FR-070).
///
/// The camera itself is controlled by RealityView's built-in orbit controls for pointer gestures.
/// These commands rotate and scale the centered model root, so every view change is also reachable
/// by keyboard alone. State is main-actor isolated because SwiftUI observes it.
///
/// - Concurrency: Main-actor isolated; observed directly by SwiftUI.
@Observable
@MainActor
public final class SimulationCamera {
    /// The distance at which the preview is drawn at its natural scale.
    public static let referenceDistance: Float = 700

    private static let defaultYaw = 0.7
    private static let defaultPitch = 0.85
    private static let defaultDistance: Float = SimulationCamera.referenceDistance
    private static let minimumPitch = 0.12
    private static let maximumPitch = 1.5

    /// The horizontal orbit angle in radians.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public private(set) var yaw: Double = SimulationCamera.defaultYaw
    /// The vertical viewing angle in radians, clamped to usable bounds.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public private(set) var pitch: Double = SimulationCamera.defaultPitch
    /// The camera distance from the model, clamped while zooming.
    ///
    /// - Concurrency: Main-actor isolated observable state.
    public private(set) var distance: Float = SimulationCamera.defaultDistance

    /// Creates a camera at the default yaw, pitch, and reference distance.
    public init() {}

    /// Applies one navigation command, clamping the pitch and distance to usable bounds.
    public func navigate(_ command: CameraNavigation) {
        switch command {
        case .orbitLeft:
            yaw -= 0.15
        case .orbitRight:
            yaw += 0.15
        case .orbitUp:
            pitch = min(pitch + 0.12, Self.maximumPitch)
        case .orbitDown:
            pitch = max(pitch - 0.12, Self.minimumPitch)
        case .zoomIn:
            distance = max(distance * 0.85, 80)
        case .zoomOut:
            distance = min(distance * 1.18, 4_000)
        case .reset:
            yaw = Self.defaultYaw
            pitch = Self.defaultPitch
            distance = Self.defaultDistance
        }
    }
}
