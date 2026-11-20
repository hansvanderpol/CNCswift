import Foundation

/// Renders a toolpath as GRBL 1.1 text.
///
/// The model basename is injected so the same renderer can serve the committed golden fixtures and a
/// composition root that knows the source STL path. It is recorded in the header and used by the
/// writer when deriving the output filename.
public struct GCodeEmitter: GCodeRendering, Sendable {
    public let modelFileName: String
    public let appliedScale: Double

    public init(modelFileName: String = "relief-demo-binary.stl", appliedScale: Double = 1) {
        self.modelFileName = modelFileName
        self.appliedScale = appliedScale
    }
}
