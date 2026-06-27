import Foundation
import MindDeskCore

struct WorkspaceReentryBriefMapperScopedInputStats: Equatable {
    var resourceRecordCount: Int
    var snippetRecordCount: Int
    var todoRecordCount: Int
    var canvasRecordCount: Int
    var nodeRecordCount: Int
    var edgeRecordCount: Int
}

private struct WorkspaceReentryBriefMapperScopedInputs {
    var workspace: WorkspaceReentryWorkspaceRecord
    var resources: [WorkspaceReentryResourceRecord]
    var snippets: [WorkspaceReentrySnippetRecord]
    var todos: [WorkspaceReentryTodoRecord]
    var canvases: [WorkspaceReentryCanvasRecord]
    var nodes: [WorkspaceReentryCanvasNodeRecord]
    var edges: [WorkspaceReentryCanvasEdgeRecord]

    var stats: WorkspaceReentryBriefMapperScopedInputStats {
        WorkspaceReentryBriefMapperScopedInputStats(
            resourceRecordCount: resources.count,
            snippetRecordCount: snippets.count,
            todoRecordCount: todos.count,
            canvasRecordCount: canvases.count,
            nodeRecordCount: nodes.count,
            edgeRecordCount: edges.count
        )
    }
}

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
        let inputs = scopedInputsByWorkspaceID(
            workspaces: [workspace],
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges
        )[workspace.id] ?? emptyScopedInputs(for: workspace)

        return WorkspaceReentryBriefPolicy.brief(
            for: inputs.workspace,
            resources: inputs.resources,
            snippets: inputs.snippets,
            todos: inputs.todos,
            canvases: inputs.canvases,
            nodes: inputs.nodes,
            edges: inputs.edges,
            now: now
        )
    }

    static func scopedInputStats(
        for workspace: WorkspaceModel,
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        todos: [WorkspaceTodoModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel]
    ) -> WorkspaceReentryBriefMapperScopedInputStats {
        let inputs = scopedInputsByWorkspaceID(
            workspaces: [workspace],
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges
        )[workspace.id] ?? emptyScopedInputs(for: workspace)
        return inputs.stats
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
        let inputsByWorkspaceID = scopedInputsByWorkspaceID(
            workspaces: cappedWorkspaces,
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges
        )

        var briefs: [String: WorkspaceReentryBrief] = [:]
        for workspace in cappedWorkspaces where briefs[workspace.id] == nil {
            let inputs = inputsByWorkspaceID[workspace.id] ?? emptyScopedInputs(for: workspace)
            briefs[workspace.id] = WorkspaceReentryBriefPolicy.brief(
                for: inputs.workspace,
                resources: inputs.resources,
                snippets: inputs.snippets,
                todos: inputs.todos,
                canvases: inputs.canvases,
                nodes: inputs.nodes,
                edges: inputs.edges,
                now: now
            )
        }
        return briefs
    }

    static func scopedInputStatsByWorkspaceID(
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        todos: [WorkspaceTodoModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel]
    ) -> [String: WorkspaceReentryBriefMapperScopedInputStats] {
        scopedInputsByWorkspaceID(
            workspaces: Array(workspaces.prefix(6)),
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges
        )
        .mapValues(\.stats)
    }

    private static func scopedInputsByWorkspaceID(
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        todos: [WorkspaceTodoModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel]
    ) -> [String: WorkspaceReentryBriefMapperScopedInputs] {
        let scopedWorkspaces = uniqueWorkspacesPreservingFirstOccurrence(Array(workspaces.prefix(6)))
        let workspaceIDs = Set(scopedWorkspaces.map(\.id))
        let workspaceIDOrder = scopedWorkspaces.map(\.id)
        guard !workspaceIDs.isEmpty else { return [:] }

        var todosByWorkspaceID: [String: [WorkspaceTodoModel]] = [:]
        var resourceReferenceIDsByWorkspaceID: [String: Set<String>] = [:]
        for todo in todos where workspaceIDs.contains(todo.workspaceId) {
            todosByWorkspaceID[todo.workspaceId, default: []].append(todo)
            if !todo.isCompleted, let linkedResourceId = todo.linkedResourceId {
                resourceReferenceIDsByWorkspaceID[todo.workspaceId, default: []].insert(linkedResourceId)
            }
        }

        var canvasesByWorkspaceID: [String: [CanvasModel]] = [:]
        var workspaceIDByCanvasID: [String: String] = [:]
        for canvas in canvases where workspaceIDs.contains(canvas.workspaceId) {
            canvasesByWorkspaceID[canvas.workspaceId, default: []].append(canvas)
            workspaceIDByCanvasID[canvas.id] = canvas.workspaceId
        }

        var nodesByWorkspaceID: [String: [CanvasNodeModel]] = [:]
        var snippetReferenceIDsByWorkspaceID: [String: Set<String>] = [:]
        for node in nodes {
            guard let workspaceID = workspaceIDByCanvasID[node.canvasId] else { continue }
            nodesByWorkspaceID[workspaceID, default: []].append(node)
        }

        var edgesByWorkspaceID: [String: [CanvasEdgeModel]] = [:]
        for edge in edges {
            guard let workspaceID = workspaceIDByCanvasID[edge.canvasId] else { continue }
            edgesByWorkspaceID[workspaceID, default: []].append(edge)
        }

        let detailedWorkspaceIDs = Set(workspaceIDs.filter { workspaceID in
            WorkspaceReentryBriefBudgetPolicy.decision(
                stats: WorkspaceReentryBriefInputStats(
                    nodeCount: nodesByWorkspaceID[workspaceID, default: []].count,
                    edgeCount: edgesByWorkspaceID[workspaceID, default: []].count,
                    todoCount: todosByWorkspaceID[workspaceID, default: []].count
                )
            ).mode == .detailed
        })
        for workspaceID in detailedWorkspaceIDs {
            for node in nodesByWorkspaceID[workspaceID, default: []] {
                if node.objectType == "resourcePin", let objectID = node.objectId {
                    resourceReferenceIDsByWorkspaceID[workspaceID, default: []].insert(objectID)
                }
                if node.objectType == "snippet", let objectID = node.objectId {
                    snippetReferenceIDsByWorkspaceID[workspaceID, default: []].insert(objectID)
                }
            }
        }

        var resourcesByWorkspaceID: [String: [ResourcePinModel]] = [:]
        for resource in resources {
            if resource.scopeRaw == WorkbenchScope.workspace.rawValue,
               let workspaceID = resource.workspaceId,
               workspaceIDs.contains(workspaceID) {
                resourcesByWorkspaceID[workspaceID, default: []].append(resource)
            } else if resource.scopeRaw == WorkbenchScope.global.rawValue {
                for workspaceID in workspaceIDOrder
                    where resourceReferenceIDsByWorkspaceID[workspaceID, default: []].contains(resource.id) {
                    resourcesByWorkspaceID[workspaceID, default: []].append(resource)
                }
            }
        }

        var snippetsByWorkspaceID: [String: [SnippetModel]] = [:]
        for snippet in snippets {
            if snippet.scopeRaw == WorkbenchScope.workspace.rawValue,
               let workspaceID = snippet.workspaceId,
               workspaceIDs.contains(workspaceID) {
                snippetsByWorkspaceID[workspaceID, default: []].append(snippet)
            } else if snippet.scopeRaw == WorkbenchScope.global.rawValue {
                for workspaceID in workspaceIDOrder
                    where snippetReferenceIDsByWorkspaceID[workspaceID, default: []].contains(snippet.id) {
                    snippetsByWorkspaceID[workspaceID, default: []].append(snippet)
                }
            }
        }

        return Dictionary(uniqueKeysWithValues: scopedWorkspaces.map { workspace in
            let workspaceID = workspace.id
            return (
                workspaceID,
                WorkspaceReentryBriefMapperScopedInputs(
                    workspace: workspaceRecord(workspace),
                    resources: resourcesByWorkspaceID[workspaceID, default: []].map(resourceRecord),
                    snippets: snippetsByWorkspaceID[workspaceID, default: []].map(snippetRecord),
                    todos: todosByWorkspaceID[workspaceID, default: []].map(todoRecord),
                    canvases: canvasesByWorkspaceID[workspaceID, default: []].map(canvasRecord),
                    nodes: nodesByWorkspaceID[workspaceID, default: []].map(nodeRecord),
                    edges: edgesByWorkspaceID[workspaceID, default: []].map(edgeRecord)
                )
            )
        })
    }

    private static func uniqueWorkspacesPreservingFirstOccurrence(
        _ workspaces: [WorkspaceModel]
    ) -> [WorkspaceModel] {
        var seen = Set<String>()
        var unique: [WorkspaceModel] = []
        for workspace in workspaces where !seen.contains(workspace.id) {
            unique.append(workspace)
            seen.insert(workspace.id)
        }
        return unique
    }

    private static func emptyScopedInputs(
        for workspace: WorkspaceModel
    ) -> WorkspaceReentryBriefMapperScopedInputs {
        WorkspaceReentryBriefMapperScopedInputs(
            workspace: workspaceRecord(workspace),
            resources: [],
            snippets: [],
            todos: [],
            canvases: [],
            nodes: [],
            edges: []
        )
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
