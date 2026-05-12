import Foundation

public enum ShellQuoter {
    public static func singleQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func appleScriptString(_ value: String) -> String {
        var parts: [String] = []
        var segment = ""

        func flushSegment() {
            guard !segment.isEmpty else { return }
            parts.append(quotedAppleScriptSegment(segment))
            segment = ""
        }

        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 13, 8232, 8233:
                flushSegment()
                parts.append("character id \(scalar.value)")
            default:
                segment.unicodeScalars.append(scalar)
            }
        }
        flushSegment()

        if parts.isEmpty {
            return "\"\""
        }
        return parts.joined(separator: " & ")
    }

    private static func quotedAppleScriptSegment(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    public static func changeDirectoryCommand(workingDirectory: String) -> String {
        "cd -- \(singleQuote(workingDirectory))"
    }

    public static func terminalCommand(command: String, workingDirectory: String) -> String {
        "\(changeDirectoryCommand(workingDirectory: workingDirectory)) && \(command)"
    }
}
