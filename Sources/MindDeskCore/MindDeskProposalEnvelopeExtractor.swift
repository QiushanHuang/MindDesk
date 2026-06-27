import Foundation

public enum MindDeskProposalEnvelopeExtractor {
    private static let formatMarker = "minddesk.proposal.envelope"

    public static func latestEnvelopeData(in transcript: String) -> Data? {
        let cleaned = strippedTerminalControlSequences(from: transcript)
        let openingBraceIndexes = cleaned.indices.filter { cleaned[$0] == "{" }
        for openingBrace in openingBraceIndexes.reversed() {
            guard let candidate = balancedJSONObject(in: cleaned, startingAt: openingBrace),
                  candidate.contains(formatMarker),
                  isProposalEnvelope(candidate) else {
                continue
            }
            return Data(candidate.utf8)
        }
        return nil
    }

    private static func balancedJSONObject(in text: String, startingAt openingBrace: String.Index) -> String? {
        var index = openingBrace
        var depth = 0
        var isInString = false
        var isEscaped = false
        while index < text.endIndex {
            let character = text[index]
            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInString = false
                }
            } else {
                if character == "\"" {
                    isInString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[openingBrace...index])
                    }
                    if depth < 0 {
                        return nil
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func isProposalEnvelope(_ candidate: String) -> Bool {
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["format"] as? String == formatMarker else {
            return false
        }
        return true
    }

    private static func strippedTerminalControlSequences(from text: String) -> String {
        let pattern = #"\u{001B}\[[0-?]*[ -/]*[@-~]"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
