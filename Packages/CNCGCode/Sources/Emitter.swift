import CNCCutters
import CNCGeometry
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

extension GCodeEmitter {
    /// Renders one deterministic program: fixed header, profile start block, move lines, profile
    /// stop block, and a trailing newline after `M30`.
    public func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram {
        guard !toolpath.moves.isEmpty else { throw RenderingError.emptyToolpath }

        let record = GenerationRecord(
            cutter: cutter,
            material: material,
            job: job,
            profile: profile,
            appliedScale: appliedScale,
            modelFileName: modelFileName,
            generatedAt: generatedAt
        )

        let maxLength = profile.limits.maxLineLength
        var lines = HeaderBuilder.lines(for: record, profile: profile, maxLength: maxLength)
        lines.append(
            contentsOf: ProfileBlockRenderer.start(profile, spindle: job.effective.spindle))
        lines.append(contentsOf: MoveRenderer.lines(for: toolpath, profile: profile))
        lines.append(contentsOf: ProfileBlockRenderer.stop(profile))

        return RenderedProgram(
            text: try LineGuard.join(lines, maxLength: maxLength), record: record)
    }
}

/// Builds the fixed-order header from one immutable generation record (FR-029).
private enum HeaderBuilder {
    static func lines(
        for record: GenerationRecord,
        profile: MachineProfile,
        maxLength: Int
    ) -> [String] {
        let rapidKeys = profile.controllerSetup.rapidRate.keys.sorted()
        let rapidReferences =
            rapidKeys.first.map { first in
                "\(first)-\(rapidKeys.last ?? first)"
            } ?? "$110-$112"

        let profileID = sanitize(profile.profileID)
        let version = sanitize(profile.version)
        let dialect = sanitize(profile.dialect)
        let model = sanitize(record.modelFileName)
        let cutterID = sanitize(record.cutter.id.rawValue)
        let cutterName = sanitize(record.cutter.name)
        let cutterType = sanitize(record.cutter.type.rawValue)
        let materialName = sanitize(record.material.name)

        let feedLower = NumericFormatting.fixed3(record.material.feedBand.lowerBound)
        let feedUpper = NumericFormatting.fixed3(record.material.feedBand.upperBound)
        let feedBand = "\(feedLower)-\(feedUpper)"
        let spindleLower = NumericFormatting.integer(record.material.spindleBand.lowerBound)
        let spindleUpper = NumericFormatting.integer(record.material.spindleBand.upperBound)
        let spindleBand = "\(spindleLower)-\(spindleUpper)"
        let rapidRate = NumericFormatting.integer(profile.limits.maxRapidRate)
        let stockWidth = NumericFormatting.fixed3(record.job.stock.width)
        let stockDepth = NumericFormatting.fixed3(record.job.stock.depth)
        let stockHeight = NumericFormatting.fixed3(record.job.stock.height)
        let stock = "\(stockWidth) x \(stockDepth) x \(stockHeight)"

        let lines = [
            "; CNCswift 1.0",
            "; profile: \(profileID) \(version)",
            "; dialect: \(dialect)",
            "; units: mm  origin: stock front-left top",
            "; model: \(model)",
            "; cutter: \(cutterID)",
            "; cutter-name: \(cutterName)",
            "; cutter-type: \(cutterType)",
            "; cutting-diameter: \(NumericFormatting.fixed3(record.cutter.maxCuttingExtent))",
            "; shank-diameter: \(NumericFormatting.fixed3(record.cutter.shankDiameter))",
            "; cutting-length: \(NumericFormatting.fixed3(record.cutter.cuttingLength))",
            "; flutes: \(record.cutter.fluteCount)",
            "; cutter-feed: \(NumericFormatting.fixed3(record.cutter.feedRate))",
            "; cutter-spindle: \(NumericFormatting.integer(record.cutter.spindleSpeed))",
            "; material: \(materialName)",
            "; material-feed-band: \(feedBand)",
            "; material-spindle-band: \(spindleBand)",
            "; feed: \(NumericFormatting.fixed3(record.job.effective.feed))",
            "; spindle: \(NumericFormatting.integer(record.job.effective.spindle))",
            "; rapid-rate: controller \(rapidRate) (see \(rapidReferences))",
            "; stock: \(stock)",
            "; stepover: \(NumericFormatting.fixed3(record.job.stepover))",
            "; max-depth: \(NumericFormatting.fixed3(record.job.maxDepthPerPass))",
            "; allowance: \(NumericFormatting.fixed3(record.job.finishingAllowance))",
            "; scale: \(NumericFormatting.fixed3(record.appliedScale))",
            "; generated: \(record.generatedAtHeaderValue)",
            ";",
        ]

        return lines.map { fit($0, maxLength: maxLength) }
    }

    /// Replaces header-only separators with `_`; any remaining non-ASCII scalar is left for the
    /// final line guard to reject with its exact line number. Over-long comments are trimmed to
    /// `maxLength - 3` characters plus the three ASCII ellipsis dots.
    private static func sanitize(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.unicodeScalars.count)
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x00...0x1F, 0x3B, 0x7F:
                result.append("_")
            default:
                result.append(String(scalar))
            }
        }
        return result
    }

    private static func fit(_ line: String, maxLength: Int) -> String {
        guard line.count > maxLength else { return line }
        return String(line.prefix(maxLength - 3)) + "..."
    }
}

/// Emits the profile's fixed start and stop blocks, substituting only the spindle-speed placeholder.
private enum ProfileBlockRenderer {
    static func start(_ profile: MachineProfile, spindle: Double) -> [String] {
        let speed = NumericFormatting.integer(spindle)
        return profile.startBlock.map {
            $0.replacingOccurrences(of: "{spindleSpeed}", with: speed)
        }
    }

    static func stop(_ profile: MachineProfile) -> [String] {
        profile.stopBlock
    }
}

/// Emits ordered move lines with modal `G1`, changed axes only, and no feed or spindle word on a
/// rapid (FR-024, FR-039).
private enum MoveRenderer {
    static func lines(for toolpath: Toolpath, profile: MachineProfile) -> [String] {
        var current = toolpath.moves[0].from
        var modalCut = false
        var commandedFeed: Double?
        var result: [String] = []

        for move in toolpath.moves {
            switch move.mode {
            case .rapid:
                result.append(
                    contentsOf: RapidFormatter.lines(from: current, to: move.to, profile: profile))
                current = move.to
                modalCut = false

            case .cut:
                let needsModal = !modalCut
                var words: [String] = []
                if needsModal { words.append("G1") }
                if move.to.x != current.x {
                    words.append("X\(NumericFormatting.fixed3(move.to.x))")
                }
                if move.to.y != current.y {
                    words.append("Y\(NumericFormatting.fixed3(move.to.y))")
                }
                if move.to.z != current.z {
                    words.append("Z\(NumericFormatting.fixed3(move.to.z))")
                }
                if needsModal || commandedFeed == nil || commandedFeed != toolpath.feedRate {
                    words.append("F\(NumericFormatting.fixed3(toolpath.feedRate))")
                }
                commandedFeed = toolpath.feedRate
                modalCut = true
                result.append(words.joined(separator: " "))
                current = move.to
            }
        }

        return result
    }
}

/// Invariant, fixed-point number formatting with negative zero normalised away (research D8).
enum NumericFormatting {
    static func fixed3(_ value: Double) -> String {
        let normalised = value.isZero ? 0 : value
        return String(
            format: "%.3f",
            locale: Locale(identifier: "en_US_POSIX"),
            normalised
        )
    }

    static func integer(_ value: Double) -> String {
        let normalised = value.isZero ? 0 : value
        return String(Int(normalised.rounded()))
    }
}

/// Final guard: every emitted line must be 7-bit ASCII and within the profile's line limit.
private enum LineGuard {
    static func join(_ lines: [String], maxLength: Int) throws -> String {
        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            guard line.unicodeScalars.allSatisfy({ $0.value <= 0x7F }) else {
                throw RenderingError.nonASCIILine(lineNumber: lineNumber)
            }
            guard line.count <= maxLength else {
                throw RenderingError.lineTooLong(lineNumber: lineNumber, length: line.count)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
