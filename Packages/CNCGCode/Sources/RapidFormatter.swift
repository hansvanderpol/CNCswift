import CNCGeometry
import CNCMachineProfile

/// Formats rapid moves so a `G0` line never carries feed or spindle words and never crosses
/// material (FR-024, FR-039).
///
/// A descending rapid is expanded into a retract to the profile clearance height, an XY traverse at
/// that height, and a final plunge. The caller resets modal `G1` after the sequence so the next
/// cutting move re-declares its feed explicitly.
enum RapidFormatter {
    static func lines(
        from current: Vec3,
        to target: Vec3,
        profile: MachineProfile
    ) -> [String] {
        var position = current
        var result: [String] = []
        let xyChanged = target.x != position.x || target.y != position.y
        let zChanged = target.z != position.z

        if zChanged && target.z < position.z {
            if position.z != profile.clearanceZ {
                result.append(axisCommand("G0", axes: [("Z", profile.clearanceZ)]))
                position.z = profile.clearanceZ
            }
            if xyChanged {
                result.append(axisCommand("G0", axes: [("X", target.x), ("Y", target.y)]))
                position.x = target.x
                position.y = target.y
            }
            if target.z != position.z {
                result.append(axisCommand("G0", axes: [("Z", target.z)]))
                position.z = target.z
            }
        } else {
            var axes: [(String, Double)] = []
            if zChanged { axes.append(("Z", target.z)) }
            if xyChanged {
                axes.append(("X", target.x))
                axes.append(("Y", target.y))
            }
            if !axes.isEmpty { result.append(axisCommand("G0", axes: axes)) }
        }

        return result
    }

    private static func axisCommand(_ code: String, axes: [(String, Double)]) -> String {
        ([code] + axes.map { "\($0.0)\(NumericFormatting.fixed3($0.1))" })
            .joined(separator: " ")
    }
}
