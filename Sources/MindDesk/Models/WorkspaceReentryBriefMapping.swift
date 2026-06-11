import Foundation
import MindDeskCore

enum WorkspaceReentryBriefMapper {
    static func brief(
        for workspace: WorkspaceModel,
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        todos: [WorkspaceTodoModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel],
        now: Date
    ) -> WorkspaceReentryBrief {
        WorkspaceReentryBriefPolicy.brief(
            for: workspaceRecord(workspace),
            resources: resources.map(resourceRecord),
            snippets: snippets.map(snippetRecord),
            todos: todos.map(todoRecord),
            canvases: canvases.map(canvasRecord),
            nodes: nodes.map(nodeRecord),
            edges: edges.map(edgeRecord),
            now: now
        )
    }

    static func briefsByWorkspaceID(
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        todos: [WorkspaceTodoModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel],
        now: Date
    ) -> [String: WorkspaceReentryBrief] {
        let cappedWorkspaces = Array(workspaces.prefix(6))
        let cappedWorkspaceIDs = Set(cappedWorkspaces.map(\.id))
        let cappedTodos = todos.filter { cappedWorkspaceIDs.contains($0.workspaceId) }
        let cappedCanvases = canvases.filter { cappedWorkspaceIDs.contains($0.workspaceId) }
        let cappedCanvasIDs = Set(cappedCanvases.map(\.id))
        let cappedNodes = nodes.filter { cappedCanvasIDs.contains($0.canvasId) }
        let cappedEdges = edges.filter { cappedCanvasIDs.contains($0.canvasId) }

        let resourceRecords = resources.map(resourceRecord)
        let snippetRecords = snippets.map(snippetRecord)
        let todoRecords = cappedTodos.map(todoRecord)
        let canvasRecords = cappedCanvases.map(canvasRecord)
        let nodeRecords = cappedNodes.map(nodeRecord)
        let edgeRecords = cappedEdges.map(edgeRecord)

        var briefs: [String: WorkspaceReentryBrief] = [:]
        for workspace in cappedWorkspaces where briefs[workspace.id] == nil {
            briefs[workspace.id] = WorkspaceReentryBriefPolicy.brief(
                for: workspaceRecord(workspace),
                resources: resourceRecords,
                snippets: snippetRecords,
                todos: todoRecords,
                canvases: canvasRecords,
                nodes: nodeRecords,
                edges: edgeRecords,
                now: now
            )
        }
        return briefs
    }

    private static func workspaceRecord(_ workspace: WorkspaceModel) -> WorkspaceReentryWorkspaceRecord {
        WorkspaceReentryWorkspaceRecord(
            id: workspace.id,
            title: workspace.title,
            lastOpenedAt: workspace.lastOpenedAt,
            updatedAt: workspace.updatedAt
        )
    }

    private static func resourceRecord(_ resource: ResourcePinModel) -> WorkspaceReentryResourceRecord {
        WorkspaceReentryResourceRecord(
            id: resource.id,
            workspaceId: resource.workspaceId,
            title: resource.displayName,
            status: resource.statusRaw,
            scope: resource.scopeRaw,
            updatedAt: resource.updatedAt,
            lastOpenedAt: resource.lastOpenedAt
        )
    }

    private static func snippetRecord(_ snippet: SnippetModel) -> WorkspaceReentrySnippetRecord {
        WorkspaceReentrySnippetRecord(
            id: snippet.id,
            workspaceId: snippet.workspaceId,
            title: snippet.title,
            scope: snippet.scopeRaw,
            updatedAt: snippet.updatedAt,
            lastCopiedAt: snippet.lastCopiedAt,
            lastUsedAt: snippet.lastUsedAt
        )
    }

    private static func todoRecord(_ todo: WorkspaceTodoModel) -> WorkspaceReentryTodoRecord {
        WorkspaceReentryTodoRecord(
            id: todo.id,
            workspaceId: todo.workspaceId,
            title: todo.title,
            isCompleted: todo.isCompleted,
            isPinned: todo.isPinned,
            sortIndex: todo.sortIndex,
            updatedAt: todo.updatedAt,
            dueAt: todo.dueAt,
            linkedResourceId: todo.linkedResourceId
        )
    }

    private static func canvasRecord(_ canvas: CanvasModel) -> WorkspaceReentryCanvasRecord {
        WorkspaceReentryCanvasRecord(
            id: canvas.id,
            workspaceId: canvas.workspaceId,
            updatedAt: canvas.updatedAt
        )
    }

    private static func nodeRecord(_ node: CanvasNodeModel) -> WorkspaceReentryCanvasNodeRecord {
        WorkspaceReentryCanvasNodeRecord(
            id: node.id,
            canvasId: node.canvasId,
            objectType: node.objectType,
            objectId: node.objectId,
            updatedAt: node.updatedAt
        )
    }

    private static func edgeRecord(_ edge: CanvasEdgeModel) -> WorkspaceReentryCanvasEdgeRecord {
        WorkspaceReentryCanvasEdgeRecord(
            id: edge.id,
            canvasId: edge.canvasId,
            sourceNodeId: edge.sourceNodeId,
            targetNodeId: edge.targetNodeId,
            updatedAt: edge.updatedAt
        )
    }
}
