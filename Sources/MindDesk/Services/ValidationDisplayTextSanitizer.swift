import Foundation
import MindDeskCore

enum ProposalReviewSafeDisplayText {
    static func safeAgentText(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return containsUnsafeText(trimmed) ? fallback : trimmed
    }

    static func safeDiagnosticMessage(_ message: String) -> String {
        safeAgentText(message, fallback: "Validation issue blocked review.")
    }

    static func safeIssueLocation(
        path: String?,
        field: String?,
        ownerKind: String?,
        source: MindDeskValidationReportSource
    ) -> String {
        if let path,
           isPackageLocalLocator(path, source: source) {
            return path
        }
        if let field,
           isSafeFieldName(field) {
            return field
        }
        if let ownerKind,
           isSafeFieldName(ownerKind) {
            return ownerKind
        }
        return source.rawValue
    }

    static func containsUnsafeText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return text.contains("\n") ||
            text.contains("\r") ||
            looksLikeURL(lowercased) ||
            looksLikeUserPath(text) ||
            containsInstructionOverride(lowercased) ||
            containsShellSnippet(lowercased)
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        text.contains("://") ||
            text.contains("www.") ||
            text.contains("token=")
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

    private static func containsShellSnippet(_ text: String) -> Bool {
        text.contains("rm -rf") ||
            text.contains("curl ") ||
            text.contains(" | sh") ||
            text.contains("sudo ") ||
            text.contains("chmod ") ||
            text.contains("chown ") ||
            text.contains("open -a terminal")
    }

    private static func containsInstructionOverride(_ text: String) -> Bool {
        text.contains("ignore_agent_instructions") ||
            text.contains("ignore validation") ||
            text.contains("ignore previous instructions") ||
            text.contains("ignore prior instructions")
    }

    private static func isPackageLocalLocator(
        _ path: String,
        source: MindDeskValidationReportSource
    ) -> Bool {
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
        return allowedLocatorRoots(for: source).contains(root)
    }

    private static func allowedLocatorRoots(
        for source: MindDeskValidationReportSource
    ) -> Set<String> {
        switch source {
        case .package:
            return [
                "format",
                "formatVersion",
                "packageInstanceID",
                "createdAt",
                "manifest",
                "validationReport",
                "agentIntegrationContract",
                "extensionCapabilities",
                "agentGuide",
                "agentPolicy",
                "externalActionPolicy"
            ]
        case .manifest:
            return [
                "manifest",
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
        case .proposalEnvelope:
            return [
                "id",
                "format",
                "formatVersion",
                "createdAt",
                "proposedBy",
                "context",
                "proposals"
            ]
        case .agentIntegrationContract:
            return [
                "format",
                "formatVersion",
                "supportedAudiences",
                "authority",
                "interchangePackage",
                "proposalEnvelope",
                "context",
                "referenceSchemas",
                "operationContracts",
                "actionPolicy",
                "agentPolicy",
                "guide",
                "promptTemplates",
                "reviewGate"
            ]
        case .extensionCapabilityCatalog:
            return [
                "format",
                "formatVersion",
                "authorizesSideEffects",
                "capabilities",
                "notes"
            ]
        }
    }

    private static func isSafeFieldName(_ field: String) -> Bool {
        guard !field.isEmpty,
              !containsUnsafeText(field) else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        return field.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
