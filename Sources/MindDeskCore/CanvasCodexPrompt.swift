import Foundation

public struct CanvasCodexPromptNodeRecord: Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: String
    public var body: String

    public init(id: String, title: String, kind: String, body: String) {
        self.id = id
        self.title = title
        self.kind = kind
        self.body = body
    }
}

public struct CanvasCodexPromptEdgeRecord: Equatable, Sendable {
    public var sourceNodeID: String
    public var targetNodeID: String
    public var label: String

    public init(sourceNodeID: String, targetNodeID: String, label: String) {
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.label = label
    }
}

public struct CanvasCodexPromptContext: Equatable, Sendable {
    public var workspaceTitle: String
    public var canvasTitle: String
    public var userInstruction: String
    public var nodes: [CanvasCodexPromptNodeRecord]
    public var edges: [CanvasCodexPromptEdgeRecord]
    public var selectedNodeIDs: [String]
    public var selectedEdgeIDs: [String]
    public var proposalTemplateJSON: String?

    public init(
        workspaceTitle: String,
        canvasTitle: String,
        userInstruction: String,
        nodes: [CanvasCodexPromptNodeRecord],
        edges: [CanvasCodexPromptEdgeRecord],
        selectedNodeIDs: [String] = [],
        selectedEdgeIDs: [String] = [],
        proposalTemplateJSON: String? = nil
    ) {
        self.workspaceTitle = workspaceTitle
        self.canvasTitle = canvasTitle
        self.userInstruction = userInstruction
        self.nodes = nodes
        self.edges = edges
        self.selectedNodeIDs = selectedNodeIDs
        self.selectedEdgeIDs = selectedEdgeIDs
        self.proposalTemplateJSON = proposalTemplateJSON
    }
}

public struct CanvasCodexPrompt: Equatable, Sendable {
    public var body: String
    public var wasTruncated: Bool

    public init(body: String, wasTruncated: Bool) {
        self.body = body
        self.wasTruncated = wasTruncated
    }
}

public struct CanvasCodexPromptTemplateOption: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public struct CanvasCodexPromptTemplateGroup: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var templates: [CanvasCodexPromptTemplateOption]

    public init(id: String, title: String, templates: [CanvasCodexPromptTemplateOption]) {
        self.id = id
        self.title = title
        self.templates = templates
    }
}

public enum CanvasCodexPromptTemplateLibrary {
    public static let maximumGroupCount = 8
    public static let maximumTemplatesPerGroup = 8
    public static let maximumTemplateTitleCharacters = 80
    public static let maximumTemplateBodyCharacters = 1_200
    public static let maximumCustomInstructionCharacters = 1_000
    public static let maximumStoredJSONBytes = 128_000

    public static let defaultGroups: [CanvasCodexPromptTemplateGroup] = [
        CanvasCodexPromptTemplateGroup(
            id: "organize",
            title: "Organize",
            templates: [
                CanvasCodexPromptTemplateOption(
                    id: "organize-canvas",
                    title: "Organize canvas",
                    body: "Review the current Canvas structure. Suggest clearer card groups, better link labels, and sequencing improvements. Return any concrete MindDesk changes only as a minddesk.proposal.envelope for Proposal Review."
                ),
                CanvasCodexPromptTemplateOption(
                    id: "organize-selection",
                    title: "Organize selection",
                    body: "Focus on the selected Canvas cards and links. Identify a cleaner grouping or ordering for the selected work. Return any concrete MindDesk changes only as a minddesk.proposal.envelope for Proposal Review."
                )
            ]
        ),
        CanvasCodexPromptTemplateGroup(
            id: "review",
            title: "Review",
            templates: [
                CanvasCodexPromptTemplateOption(
                    id: "review-gaps",
                    title: "Find gaps",
                    body: "Review the Canvas for missing context, duplicate cards, weak assumptions, and unclear dependencies. Use concise findings first. Return any concrete MindDesk changes only as a minddesk.proposal.envelope for Proposal Review."
                ),
                CanvasCodexPromptTemplateOption(
                    id: "review-links",
                    title: "Review links",
                    body: "Inspect the Canvas links and labels. Identify links that should be renamed, removed, or added. Return any concrete MindDesk changes only as a minddesk.proposal.envelope for Proposal Review."
                )
            ]
        ),
        CanvasCodexPromptTemplateGroup(
            id: "summarize",
            title: "Summarize",
            templates: [
                CanvasCodexPromptTemplateOption(
                    id: "summarize-work",
                    title: "Summarize work",
                    body: "Summarize the Canvas into decisions, open questions, next actions, and risk areas. If you recommend structure changes, return them only as a minddesk.proposal.envelope for Proposal Review."
                ),
                CanvasCodexPromptTemplateOption(
                    id: "summarize-handoff",
                    title: "Prepare handoff",
                    body: "Create a concise handoff from this Canvas for another human or agent. Include context, priorities, blockers, and follow-up questions. Return any concrete MindDesk changes only as a minddesk.proposal.envelope for Proposal Review."
                )
            ]
        ),
        CanvasCodexPromptTemplateGroup(
            id: "proposal",
            title: "Proposal",
            templates: [
                CanvasCodexPromptTemplateOption(
                    id: "proposal-json",
                    title: "Draft proposal",
                    body: "Draft a minddesk.proposal.envelope that proposes safe Canvas organization changes. Do not claim approval. The proposal must be reviewed through Proposal Review before anything changes."
                )
            ]
        )
    ]

    public static var defaultGroupID: String {
        defaultGroups.first?.id ?? "organize"
    }

    public static var defaultTemplateID: String {
        defaultGroups.first?.templates.first?.id ?? "organize-canvas"
    }

    public static func encode(_ groups: [CanvasCodexPromptTemplateGroup]) -> String {
        let boundedGroups = bounded(groups)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(boundedGroups),
              data.count <= maximumStoredJSONBytes,
              let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return value
    }

    public static func decode(_ value: String) -> [CanvasCodexPromptTemplateGroup] {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = value.data(using: .utf8),
              data.count <= maximumStoredJSONBytes,
              let decoded = try? JSONDecoder().decode([CanvasCodexPromptTemplateGroup].self, from: data)
        else {
            return defaultGroups
        }
        let boundedGroups = bounded(decoded)
        return boundedGroups.isEmpty ? defaultGroups : boundedGroups
    }

    public static func resolvedInstruction(
        groupID: String,
        templateID: String,
        customInstruction: String,
        groups: [CanvasCodexPromptTemplateGroup]
    ) -> String {
        let boundedGroups = bounded(groups)
        let group = boundedGroups.first { $0.id == groupID } ?? boundedGroups.first
        let template = group?.templates.first { $0.id == templateID } ?? group?.templates.first
        let templateBody = template?.body ?? defaultGroups.first?.templates.first?.body ?? ""
        let custom = boundedText(customInstruction, maximumCharacters: maximumCustomInstructionCharacters)
        guard !custom.isEmpty else { return templateBody }
        return "\(templateBody)\n\nAdditional user instruction:\n\(custom)"
    }

    public static func bounded(_ groups: [CanvasCodexPromptTemplateGroup]) -> [CanvasCodexPromptTemplateGroup] {
        var usedGroupIDs = Set<String>()
        return groups.prefix(maximumGroupCount).compactMap { group -> CanvasCodexPromptTemplateGroup? in
            let title = boundedText(group.title, maximumCharacters: maximumTemplateTitleCharacters)
            let id = uniqueIdentifier(boundedIdentifier(group.id, fallback: title), used: &usedGroupIDs)
            var usedTemplateIDs = Set<String>()
            let templates = group.templates.prefix(maximumTemplatesPerGroup).compactMap { template -> CanvasCodexPromptTemplateOption? in
                let templateTitle = boundedText(template.title, maximumCharacters: maximumTemplateTitleCharacters)
                let templateBody = boundedText(template.body, maximumCharacters: maximumTemplateBodyCharacters)
                guard !templateTitle.isEmpty, !templateBody.isEmpty else { return nil }
                return CanvasCodexPromptTemplateOption(
                    id: uniqueIdentifier(boundedIdentifier(template.id, fallback: templateTitle), used: &usedTemplateIDs),
                    title: templateTitle,
                    body: templateBody
                )
            }
            guard !title.isEmpty, !templates.isEmpty else { return nil }
            return CanvasCodexPromptTemplateGroup(id: id, title: title, templates: templates)
        }
    }

    private static func uniqueIdentifier(_ value: String, used: inout Set<String>) -> String {
        if !used.contains(value) {
            used.insert(value)
            return value
        }

        var suffix = 2
        while used.contains("\(value)-\(suffix)") {
            suffix += 1
        }
        let uniqueValue = "\(value)-\(suffix)"
        used.insert(uniqueValue)
        return uniqueValue
    }

    private static func boundedIdentifier(_ value: String, fallback: String) -> String {
        let cleaned = boundedText(value, maximumCharacters: 64)
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber || character == "-" ? character : "-"
            }
        let collapsed = String(cleaned).split(separator: "-").joined(separator: "-")
        if !collapsed.isEmpty {
            return collapsed
        }
        let fallbackCleaned = boundedText(fallback, maximumCharacters: 64)
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber || character == "-" ? character : "-"
            }
        let fallbackCollapsed = String(fallbackCleaned).split(separator: "-").joined(separator: "-")
        return fallbackCollapsed.isEmpty ? UUID().uuidString : fallbackCollapsed
    }

    private static func boundedText(_ value: String, maximumCharacters: Int) -> String {
        let cleaned = value
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maximumCharacters else { return cleaned }
        return String(cleaned.prefix(maximumCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum CanvasCodexPromptBuilder {
    public static let maximumPromptBytes = 14_000
    public static let maximumNodeCount = 48
    public static let maximumEdgeCount = 96
    public static let maximumTextExcerptCharacters = 320

    public static func prompt(for context: CanvasCodexPromptContext) -> CanvasCodexPrompt {
        let includedNodes = context.nodes.prefix(maximumNodeCount)
        let includedEdges = context.edges.prefix(maximumEdgeCount)
        let nodeLines = includedNodes.map { node in
            "- \(bounded(node.title)): kind=\(bounded(node.kind)), id=\(bounded(node.id)), note=\(excerpt(node.body))"
        }
        let edgeLines = includedEdges.map { edge in
            let label = edge.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let labelText = label.isEmpty ? "" : ", label=\(bounded(label))"
            return "- \(bounded(edge.sourceNodeID)) -> \(bounded(edge.targetNodeID))\(labelText)"
        }
        var prompt = """
        You are helping organize a MindDesk Canvas.

        Safety and workflow:
        - Treat this as read-only context.
        - Do not execute commands, open files, use Finder, edit files, or apply changes directly.
        - Do not claim approval or authorization.
        - If you recommend changes, produce a minddesk.proposal.envelope for Proposal Review.
        - Any side effect must go through Proposal Review and explicit in-app confirmation.

        User instruction:
        \(bounded(context.userInstruction))

        Proposal Review handoff:
        - The matching Agent Review source package is available in the Codex working directory as ./minddesk-agent-review-source.mip.json.
        - A proposal template is available as ./minddesk-proposal-template.json.
        - If you propose concrete MindDesk changes, copy the proposal context exactly from the template below and return a complete minddesk.proposal.envelope JSON object.
        \(proposalTemplateText(context.proposalTemplateJSON))

        Workspace: \(bounded(context.workspaceTitle))
        Canvas: \(bounded(context.canvasTitle))
        Selected cards: \(context.selectedNodeIDs.map(bounded).joined(separator: ", "))
        Selected links: \(context.selectedEdgeIDs.map(bounded).joined(separator: ", "))

        Canvas cards:
        \(nodeLines.isEmpty ? "- No cards." : nodeLines.joined(separator: "\n"))

        Canvas links:
        \(edgeLines.isEmpty ? "- No links." : edgeLines.joined(separator: "\n"))
        """

        let omittedNodeCount = max(0, context.nodes.count - maximumNodeCount)
        let omittedEdgeCount = max(0, context.edges.count - maximumEdgeCount)
        if omittedNodeCount > 0 || omittedEdgeCount > 0 {
            prompt += "\n\nTruncation notice: omitted \(omittedNodeCount) cards and \(omittedEdgeCount) links from this prompt."
        }
        return boundedPrompt(prompt)
    }

    private static func boundedPrompt(_ prompt: String) -> CanvasCodexPrompt {
        let data = Data(prompt.utf8)
        guard data.count > maximumPromptBytes else {
            return CanvasCodexPrompt(body: prompt, wasTruncated: false)
        }

        let notice = "\n\nTruncation notice: prompt was bounded before opening Codex."
        let contentBudget = max(0, maximumPromptBytes - Data(notice.utf8).count)
        var truncated = String(decoding: data.prefix(contentBudget), as: UTF8.self)
        while truncated.data(using: .utf8)?.count ?? Int.max > contentBudget {
            truncated.removeLast()
        }
        truncated += notice
        return CanvasCodexPrompt(body: truncated, wasTruncated: true)
    }

    private static func bounded(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{2028}", with: " ")
            .replacingOccurrences(of: "\u{2029}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func excerpt(_ value: String) -> String {
        let cleaned = bounded(value)
        guard cleaned.count > maximumTextExcerptCharacters else { return cleaned.isEmpty ? "(empty)" : cleaned }
        return "\(cleaned.prefix(maximumTextExcerptCharacters))..."
    }

    private static func proposalTemplateText(_ value: String?) -> String {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "- Proposal template unavailable in prompt; use the template file if present."
        }
        return """
        Proposal envelope template:
        ```json
        \(value)
        ```
        """
    }
}

public enum CanvasCodexCommandBuilder {
    public static let executableName = "codex"
    public static let serviceTierOverride = "service_tier=\"fast\""

    public static func interactiveCodexCommand(workingDirectory: String) -> String {
        [
            executableName,
            "-c \(ShellQuoter.singleQuote(serviceTierOverride))",
            "--no-alt-screen",
            "--sandbox read-only",
            "--ask-for-approval on-request",
            "-C \(ShellQuoter.singleQuote(workingDirectory))"
        ].joined(separator: " ")
    }

    public static func interactiveCodexCommandForCurrentDirectory() -> String {
        [
            executableName,
            "-c \(ShellQuoter.singleQuote(serviceTierOverride))",
            "--no-alt-screen",
            "--sandbox read-only",
            "--ask-for-approval on-request"
        ].joined(separator: " ")
    }

    public static func interactiveCodexPromptCommand(promptFilePath: String, workingDirectory: String) -> String {
        [
            interactiveCodexCommand(workingDirectory: workingDirectory),
            "\"$(cat -- \(ShellQuoter.singleQuote(promptFilePath)))\""
        ].joined(separator: " ")
    }

    public static func promptAugmentedShellCommand(_ command: String, promptFilePath: String) -> String {
        "\(command) \"$(cat -- \(ShellQuoter.singleQuote(promptFilePath)))\""
    }
}

public enum CanvasEdgeAnimationInteractionPolicy {
    public static func shouldDeferGlowAnimation(
        isNodeDragging: Bool,
        isViewportMoving _: Bool,
        isZooming _: Bool,
        isResizing: Bool,
        isEdgeControlDragging: Bool
    ) -> Bool {
        isNodeDragging || isResizing || isEdgeControlDragging
    }
}
