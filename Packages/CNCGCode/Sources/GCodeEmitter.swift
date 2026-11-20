import Foundation

/// Renders a toolpath as GRBL 1.1 text.
///
/// The model basename is injected so the same renderer can serve the committed golden fixtures and a
/// composition root that knows the source STL path. It is recorded in the header and used by the
/// writer when deriving the output filename.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct GCodeEmitter: GCodeRendering, Sendable {
    /// The model basename recorded in the header and used for the output filename.
    public let modelFileName: String
    /// The model scale recorded in the header.
    public let appliedScale: Double

    /// Creates an emitter with the basename and scale to record in the header.
    public init(modelFileName: String = "relief-demo-binary.stl", appliedScale: Double = 1) {
        self.modelFileName = modelFileName
        self.appliedScale = appliedScale
    }
}
