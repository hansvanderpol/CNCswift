import Observation

/// A keyboard-and-pointer navigation command for the 3D preview (FR-070).
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

    public private(set) var yaw: Double = SimulationCamera.defaultYaw
    public private(set) var pitch: Double = SimulationCamera.defaultPitch
    public private(set) var distance: Float = SimulationCamera.defaultDistance

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
