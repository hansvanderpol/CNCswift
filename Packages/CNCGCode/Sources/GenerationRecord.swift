import Foundation

extension GenerationRecord {
    /// The injected clock rendered as UTC ISO-8601 seconds; the only header field allowed to vary.
    public var generatedAtHeaderValue: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return formatter.string(from: generatedAt)
    }
}

/// Deterministic 7-bit ASCII output name derived from the model basename (FR-018, FR-028).
///
/// The same rule is shared by the header and the writer so a committed file always matches the
/// program that was previewed.
public enum OutputFileName {
    public static func deriving(
        from modelFileName: String,
        fileExtension: String = "nc"
    ) -> String {
        let base = URL(fileURLWithPath: modelFileName)
            .deletingPathExtension()
            .lastPathComponent

        var mapped = ""
        mapped.reserveCapacity(base.unicodeScalars.count)
        var previousWasUnderscore = false
        for scalar in base.unicodeScalars {
            let character = isAllowed(scalar) ? String(scalar) : "_"
            if character == "_", previousWasUnderscore { continue }
            mapped.append(character)
            previousWasUnderscore = character == "_"
        }

        if mapped.isEmpty || mapped.allSatisfy({ $0 == "_" }) {
            mapped = "carve"
        }
        return "\(mapped).\(fileExtension)"
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 48 && value <= 57)
            || (value >= 65 && value <= 90)
            || (value >= 97 && value <= 122)
            || value == 0x2E  // .
            || value == 0x2D  // -
            || value == 0x5F  // _
    }
}
