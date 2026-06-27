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

    public init(
        workspaceTitle: String,
        canvasTitle: String,
        userInstruction: String,
        nodes: [CanvasCodexPromptNodeRecord],
        edges: [CanvasCodexPromptEdgeRecord],
        selectedNodeIDs: [String] = [],
        selectedEdgeIDs: [String] = []
    ) {
        self.workspaceTitle = workspaceTitle
        self.canvasTitle = canvasTitle
        self.userInstruction = userInstruction
        self.nodes = nodes
        self.edges = edges
        self.selectedNodeIDs = selectedNodeIDs
        self.selectedEdgeIDs = selectedEdgeIDs
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
}

public enum CanvasCodexCommandBuilder {
    public static let requiredPrefix = "codex --sandbox read-only --ask-for-approval untrusted --"

    public static func command(prompt: String) -> String {
        "\(requiredPrefix) \(ShellQuoter.singleQuote(singleLinePromptArgument(prompt)))"
    }

    public static func singleLinePromptArgument(_ prompt: String) -> String {
        prompt
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{2028}", with: " ")
            .replacingOccurrences(of: "\u{2029}", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
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
