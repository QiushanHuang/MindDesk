import Foundation

enum ValidationDisplayTextSanitizer {
    private static let manifestLocatorRoots: Set<String> = [
        "manifest",
        "format",
        "formatVersion",
        "schemaVersion",
        "exportedAt",
        "workspaces",
        "resources",
        "snippets",
        "canvases",
        "nodes",
        "edges",
        "aliases",
        "todoGroups",
        "todos"
    ]

    static func safeDiagnosticMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !containsUnsafeText(trimmed) else {
            return "Validation issue."
        }
        return trimmed
    }

    static func safeIssueLocation(
        path: String?,
        field: String?,
        ownerKind: String?
    ) -> String {
        if let path, isSafeManifestPath(path) {
            return path
        }
        if let field, isSafeFieldName(field) {
            return field
        }
        if let ownerKind, isSafeFieldName(ownerKind) {
            return ownerKind
        }
        return "manifest"
    }

    static func containsUnsafeText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return text.contains("\n") ||
            text.contains("\r") ||
            lowercased.contains("://") ||
            lowercased.contains("www.") ||
            lowercased.contains("token=") ||
            looksLikeUserPath(text) ||
            containsInstructionOverride(lowercased) ||
            containsShellSnippet(lowercased)
    }

    private static func isSafeManifestPath(_ path: String) -> Bool {
        guard path.hasPrefix("/"),
              !containsUnsafeText(path),
              !path.contains("\\"),
              !path.contains("..") else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/_.-")
        guard path.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              let root = path.split(separator: "/", omittingEmptySubsequences: true).first.map(String.init) else {
            return false
        }
        return manifestLocatorRoots.contains(root)
    }

    private static func isSafeFieldName(_ field: String) -> Bool {
        guard !field.isEmpty, !containsUnsafeText(field) else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        return field.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func looksLikeUserPath(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("~/") ||
            lowercased.contains("/users/") ||
            lowercased.contains("/tmp/") ||
            lowercased.contains("/private/") ||
            lowercased.contains("/var/") ||
            lowercased.contains("/volumes/") ||
            lowercased.range(of: #"[A-Za-z]:[\\/]"#, options: .regularExpression) != nil
    }

    private static func containsInstructionOverride(_ text: String) -> Bool {
        text.contains("ignore validation") ||
            text.contains("ignore previous instructions") ||
            text.contains("ignore prior instructions")
    }

    private static func containsShellSnippet(_ text: String) -> Bool {
        text.contains("rm -rf") ||
            text.contains("curl ") ||
            text.contains(" | sh") ||
            text.contains("sudo ") ||
            text.contains("chmod ") ||
            text.contains("chown ") ||
            text.contains("open -a terminal")
    }
}
