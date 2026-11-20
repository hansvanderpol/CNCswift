import Foundation

/// One GRBL word: a letter (or `$`) plus its numeric payload.
struct GCodeWord: Equatable, Sendable {
    let letter: String
    let number: String

    /// A canonical form where `G00` and `G0` compare equal and trailing zeros are removed.
    var canonical: String {
        letter + GCodeLexer.normalizedNumber(number)
    }

    var value: Double? {
        guard !number.isEmpty else { return nil }
        return Double(number)
    }
}

/// The small, shared lexer used by the independent parser and the semantic rules (research D7).
enum GCodeLexer {
    static func commandText(_ line: String) -> String {
        let withoutComment =
            line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
        return withoutComment.trimmingCharacters(in: .whitespaces)
    }

    static func isCommentOrBlank(_ line: String) -> Bool {
        commandText(line).isEmpty
    }

    static func words(in line: String) -> [GCodeWord] {
        let text = commandText(line)
        var result: [GCodeWord] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == " " || character == "\t" {
                index = text.index(after: index)
                continue
            }

            var letter = ""
            if character == "$" {
                letter = "$"
                index = text.index(after: index)
            } else if character.isLetter {
                letter = String(character).uppercased()
                index = text.index(after: index)
            } else {
                index = text.index(after: index)
                continue
            }

            let numberStart = index
            while index < text.endIndex {
                let candidate = text[index]
                if candidate.isNumber || candidate == "."
                    || ((candidate == "-" || candidate == "+") && index == numberStart)
                {
                    index = text.index(after: index)
                } else {
                    break
                }
            }
            result.append(GCodeWord(letter: letter, number: String(text[numberStart..<index])))
        }

        return result
    }

    static func canonicalCommand(_ command: String) -> String {
        words(in: command).first?.canonical ?? command.uppercased()
    }

    fileprivate static func normalizedNumber(_ raw: String) -> String {
        guard !raw.isEmpty, let value = Double(raw), value.isFinite else { return raw }
        if value.rounded() == value {
            return String(Int(value.rounded()))
        }
        var trimmed = raw
        while trimmed.hasSuffix("0") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix(".") {
            trimmed.append("0")
        }
        return trimmed
    }
}
