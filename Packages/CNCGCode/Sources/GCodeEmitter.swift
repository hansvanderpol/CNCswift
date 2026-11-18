import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

/// Renders a toolpath as GRBL 1.1 text. Full implementation is provided by task T057.
public struct GCodeEmitter: GCodeRendering, Sendable {
    public init() {}

    public func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram {
        let record = GenerationRecord(
            cutter: cutter,
            material: material,
            job: job,
            profile: profile,
            appliedScale: 1.0,
            modelFileName: "",
            generatedAt: generatedAt
        )
        return RenderedProgram(text: "", record: record)
    }
}
