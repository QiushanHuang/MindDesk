import Foundation

public struct WorkspaceReentryWorkspaceRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var lastOpenedAt: Date?
    public var updatedAt: Date

    public init(id: String, title: String, lastOpenedAt: Date?, updatedAt: Date) {
        self.id = id
        self.title = title
        self.lastOpenedAt = lastOpenedAt
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceReentryResourceRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceId: String?
    public var title: String
    public var status: String
    public var scope: String
    public var updatedAt: Date
    public var lastOpenedAt: Date?

    public init(
        id: String,
        workspaceId: String?,
        title: String,
        status: String,
        scope: String,
        updatedAt: Date,
        lastOpenedAt: Date?
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.status = status
        self.scope = scope
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
    }
}

public struct WorkspaceReentrySnippetRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceId: String?
    public var title: String
    public var scope: String
    public var updatedAt: Date
    public var lastCopiedAt: Date?
    public var lastUsedAt: Date?

    public init(
        id: String,
        workspaceId: String?,
        title: String,
        scope: String,
        updatedAt: Date,
        lastCopiedAt: Date?,
        lastUsedAt: Date?
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.scope = scope
        self.updatedAt = updatedAt
        self.lastCopiedAt = lastCopiedAt
        self.lastUsedAt = lastUsedAt
    }
}

public struct WorkspaceReentryTodoRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceId: String
    public var title: String
    public var isCompleted: Bool
    public var isPinned: Bool
    public var sortIndex: Int
    public var updatedAt: Date
    public var dueAt: Date?
    public var linkedResourceId: String?

    public init(
        id: String,
        workspaceId: String,
        title: String,
        isCompleted: Bool,
        isPinned: Bool,
        sortIndex: Int,
        updatedAt: Date,
        dueAt: Date?,
        linkedResourceId: String?
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.updatedAt = updatedAt
        self.dueAt = dueAt
        self.linkedResourceId = linkedResourceId
    }
}

public struct WorkspaceReentryCanvasRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceId: String
    public var updatedAt: Date

    public init(id: String, workspaceId: String, updatedAt: Date) {
        self.id = id
        self.workspaceId = workspaceId
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceReentryCanvasNodeRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var canvasId: String
    public var objectType: String?
    public var objectId: String?
    public var updatedAt: Date

    public init(id: String, canvasId: String, objectType: String?, objectId: String?, updatedAt: Date) {
        self.id = id
        self.canvasId = canvasId
        self.objectType = objectType
        self.objectId = objectId
        self.updatedAt = updatedAt
    }
}

public struct WorkspaceReentryCanvasEdgeRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var canvasId: String
    public var sourceNodeId: String
    public var targetNodeId: String
    public var updatedAt: Date

    public init(
        id: String,
        canvasId: String,
        sourceNodeId: String,
        targetNodeId: String,
        updatedAt: Date
    ) {
        self.id = id
        self.canvasId = canvasId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.updatedAt = updatedAt
    }
}

public enum WorkspaceReentryBadgeKind: String, Equatable, Identifiable, Sendable {
    case overdueTasks
    case dueSoonTasks
    case openTasks
    case resourceIssues

    public var id: String { rawValue }
}

public struct WorkspaceReentryBadge: Equatable, Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: WorkspaceReentryBadgeKind
    public var count: Int

    public init(kind: WorkspaceReentryBadgeKind, count: Int) {
        self.kind = kind
        self.count = count
    }
}

public struct WorkspaceReentryCanvasSummary: Equatable, Sendable {
    public var canvasCount: Int
    public var cardCount: Int
    public var validLinkCount: Int
    public var lastUpdatedAt: Date?

    public init(canvasCount: Int, cardCount: Int, validLinkCount: Int, lastUpdatedAt: Date?) {
        self.canvasCount = canvasCount
        self.cardCount = cardCount
        self.validLinkCount = validLinkCount
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public enum WorkspaceReentryBriefBudgetDefaults {
    public static let maximumDetailedNodeCount = 10_000
    public static let maximumDetailedEdgeCount = 20_000
    public static let maximumDetailedTodoCount = 10_000
}

public struct WorkspaceReentryBriefInputStats: Equatable, Sendable {
    public var nodeCount: Int
    public var edgeCount: Int
    public var todoCount: Int

    public init(nodeCount: Int, edgeCount: Int, todoCount: Int) {
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.todoCount = todoCount
    }
}

public enum WorkspaceReentryBriefBudgetMode: String, Equatable, Sendable {
    case detailed
    case countsOnly
}

public enum WorkspaceReentryBriefBudgetReason: String, Equatable, Sendable {
    case nodeLimitExceeded
    case edgeLimitExceeded
    case todoLimitExceeded
}

public struct WorkspaceReentryBriefBudgetDecision: Equatable, Sendable {
    public var mode: WorkspaceReentryBriefBudgetMode
    public var reasons: [WorkspaceReentryBriefBudgetReason]
    public var stats: WorkspaceReentryBriefInputStats
    public var nodeLimit: Int
    public var edgeLimit: Int
    public var todoLimit: Int

    public var shouldResolveReferences: Bool { mode == .detailed }
    public var shouldBuildDetailLists: Bool { mode == .detailed }
    public var shouldSortDetailLists: Bool { mode == .detailed }
    public var skipReferenceResolution: Bool { !shouldResolveReferences }
    public var skipDetailedLists: Bool { !shouldBuildDetailLists }
    public var skipCanvasRouting: Bool { mode == .countsOnly }
    public var skipLayout: Bool { mode == .countsOnly }

    public init(
        mode: WorkspaceReentryBriefBudgetMode,
        reasons: [WorkspaceReentryBriefBudgetReason],
        stats: WorkspaceReentryBriefInputStats,
        nodeLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedNodeCount,
        edgeLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedEdgeCount,
        todoLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedTodoCount
    ) {
        self.mode = mode
        self.reasons = reasons
        self.stats = stats
        self.nodeLimit = nodeLimit
        self.edgeLimit = edgeLimit
        self.todoLimit = todoLimit
    }
}

public enum WorkspaceReentryBriefBudgetPolicy {
    public static func decision(
        stats: WorkspaceReentryBriefInputStats,
        nodeLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedNodeCount,
        edgeLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedEdgeCount,
        todoLimit: Int = WorkspaceReentryBriefBudgetDefaults.maximumDetailedTodoCount
    ) -> WorkspaceReentryBriefBudgetDecision {
        var reasons: [WorkspaceReentryBriefBudgetReason] = []
        if stats.nodeCount > nodeLimit {
            reasons.append(.nodeLimitExceeded)
        }
        if stats.edgeCount > edgeLimit {
            reasons.append(.edgeLimitExceeded)
        }
        if stats.todoCount > todoLimit {
            reasons.append(.todoLimitExceeded)
        }
        return WorkspaceReentryBriefBudgetDecision(
            mode: reasons.isEmpty ? .detailed : .countsOnly,
            reasons: reasons,
            stats: stats,
            nodeLimit: nodeLimit,
            edgeLimit: edgeLimit,
            todoLimit: todoLimit
        )
    }
}

public struct WorkspaceReentryBrief: Equatable, Identifiable, Sendable {
    public var id: String { workspaceId }
    public var workspaceId: String
    public var badges: [WorkspaceReentryBadge]
    public var nextTaskIds: [String]
    public var resourceIssueIds: [String]
    public var recentSnippetIds: [String]
    public var canvasSummary: WorkspaceReentryCanvasSummary
    public var openTaskCount: Int
    public var overdueTaskCount: Int
    public var dueSoonTaskCount: Int
    public var resourceIssueCount: Int
    public var unresolvedReferenceCount: Int
    public var budgetDecision: WorkspaceReentryBriefBudgetDecision
    public var isLargeDataDegraded: Bool { budgetDecision.mode == .countsOnly }

    public init(
        workspaceId: String,
        badges: [WorkspaceReentryBadge],
        nextTaskIds: [String],
        resourceIssueIds: [String],
        recentSnippetIds: [String],
        canvasSummary: WorkspaceReentryCanvasSummary,
        openTaskCount: Int,
        overdueTaskCount: Int,
        dueSoonTaskCount: Int,
        resourceIssueCount: Int,
        unresolvedReferenceCount: Int,
        isLargeDataDegraded: Bool,
        budgetDecision: WorkspaceReentryBriefBudgetDecision? = nil
    ) {
        self.workspaceId = workspaceId
        self.badges = badges
        self.nextTaskIds = nextTaskIds
        self.resourceIssueIds = resourceIssueIds
        self.recentSnippetIds = recentSnippetIds
        self.canvasSummary = canvasSummary
        self.openTaskCount = openTaskCount
        self.overdueTaskCount = overdueTaskCount
        self.dueSoonTaskCount = dueSoonTaskCount
        self.resourceIssueCount = resourceIssueCount
        self.unresolvedReferenceCount = unresolvedReferenceCount
        self.budgetDecision = budgetDecision ?? WorkspaceReentryBriefBudgetDecision(
            mode: isLargeDataDegraded ? .countsOnly : .detailed,
            reasons: [],
            stats: WorkspaceReentryBriefInputStats(
                nodeCount: canvasSummary.cardCount,
                edgeCount: canvasSummary.validLinkCount,
                todoCount: openTaskCount
            )
        )
    }
}

public enum WorkspaceReentryBriefPolicy {
    public static let maximumDetailedNodeCount = WorkspaceReentryBriefBudgetDefaults.maximumDetailedNodeCount
    public static let maximumDetailedEdgeCount = WorkspaceReentryBriefBudgetDefaults.maximumDetailedEdgeCount
    public static let maximumDetailedTodoCount = WorkspaceReentryBriefBudgetDefaults.maximumDetailedTodoCount

    public static func brief(
        for workspace: WorkspaceReentryWorkspaceRecord,
        resources: [WorkspaceReentryResourceRecord],
        snippets: [WorkspaceReentrySnippetRecord],
        todos: [WorkspaceReentryTodoRecord],
        canvases: [WorkspaceReentryCanvasRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord],
        now: Date,
        taskLimit: Int = 3,
        resourceIssueLimit: Int = 2,
        snippetLimit: Int = 2,
        badgeLimit: Int = 2
    ) -> WorkspaceReentryBrief {
        brief(
            for: workspace,
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges,
            now: now,
            taskLimit: taskLimit,
            resourceIssueLimit: resourceIssueLimit,
            snippetLimit: snippetLimit,
            badgeLimit: badgeLimit,
            referenceResolutionProbe: nil
        )
    }

    static func brief(
        for workspace: WorkspaceReentryWorkspaceRecord,
        resources: [WorkspaceReentryResourceRecord],
        snippets: [WorkspaceReentrySnippetRecord],
        todos: [WorkspaceReentryTodoRecord],
        canvases: [WorkspaceReentryCanvasRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord],
        now: Date,
        taskLimit: Int = 3,
        resourceIssueLimit: Int = 2,
        snippetLimit: Int = 2,
        badgeLimit: Int = 2,
        referenceResolutionProbe: (() -> Void)?
    ) -> WorkspaceReentryBrief {
        let workspaceCanvases = canvases.filter { $0.workspaceId == workspace.id }
        let canvasIds = Set(workspaceCanvases.map(\.id))
        let workspaceNodes = nodes.filter { canvasIds.contains($0.canvasId) }
        let workspaceEdges = edges.filter { canvasIds.contains($0.canvasId) }

        let workspaceTodos = todos.filter { $0.workspaceId == workspace.id }
        let openTodos = workspaceTodos.filter { !$0.isCompleted }
        let overdueTaskCount = openTodos.filter { isOverdue($0, now: now) }.count
        let dueSoonTaskCount = openTodos.filter { isDueSoon($0, now: now) }.count
        let budgetDecision = WorkspaceReentryBriefBudgetPolicy.decision(
            stats: WorkspaceReentryBriefInputStats(
                nodeCount: workspaceNodes.count,
                edgeCount: workspaceEdges.count,
                todoCount: workspaceTodos.count
            )
        )
        let isLargeDataDegraded = budgetDecision.mode == .countsOnly

        if isLargeDataDegraded {
            let resourceIssueCount = degradedResourceIssueCount(
                workspaceId: workspace.id,
                resources: resources,
                openTodos: openTodos
            )
            return WorkspaceReentryBrief(
                workspaceId: workspace.id,
                badges: badges(
                    openTaskCount: openTodos.count,
                    overdueTaskCount: overdueTaskCount,
                    dueSoonTaskCount: dueSoonTaskCount,
                    resourceIssueCount: resourceIssueCount,
                    limit: badgeLimit
                ),
                nextTaskIds: [],
                resourceIssueIds: [],
                recentSnippetIds: [],
                canvasSummary: degradedCanvasSummary(
                    canvases: workspaceCanvases,
                    nodes: workspaceNodes,
                    edges: workspaceEdges
                ),
                openTaskCount: openTodos.count,
                overdueTaskCount: overdueTaskCount,
                dueSoonTaskCount: dueSoonTaskCount,
                resourceIssueCount: resourceIssueCount,
                unresolvedReferenceCount: 0,
                isLargeDataDegraded: true,
                budgetDecision: budgetDecision
            )
        }

        referenceResolutionProbe?()
        let nodeIdsByCanvasId = Dictionary(grouping: workspaceNodes, by: \.canvasId)
            .mapValues { Set($0.map(\.id)) }

        let resourcesById = Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let snippetsById = Dictionary(snippets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let associatedResourceIds = associatedResourceIDs(
            workspaceId: workspace.id,
            resources: resources,
            todos: openTodos,
            nodes: workspaceNodes
        )
        let resourceIssueCount = associatedResourceIds.reduce(into: 0) { count, resourceId in
            guard let resource = resourcesById[resourceId],
                  isVisible(resource, in: workspace.id),
                  resource.status != "available" else {
                return
            }
            count += 1
        }

        let canvasSummary = canvasSummary(
            canvases: workspaceCanvases,
            nodes: workspaceNodes,
            edges: workspaceEdges,
            nodeIdsByCanvasId: nodeIdsByCanvasId
        )
        let unresolvedReferenceCount = unresolvedReferenceCount(
            workspaceId: workspace.id,
            resourcesById: resourcesById,
            snippetsById: snippetsById,
            openTodos: openTodos,
            nodes: workspaceNodes,
            edges: workspaceEdges,
            nodeIdsByCanvasId: nodeIdsByCanvasId
        )
        let badges = badges(
            openTaskCount: openTodos.count,
            overdueTaskCount: overdueTaskCount,
            dueSoonTaskCount: dueSoonTaskCount,
            resourceIssueCount: resourceIssueCount,
            limit: badgeLimit
        )
        let resourceIssues = associatedResourceIds
            .compactMap { resourcesById[$0] }
            .filter { isVisible($0, in: workspace.id) && $0.status != "available" }
            .sorted(by: compareResources)

        return WorkspaceReentryBrief(
            workspaceId: workspace.id,
            badges: badges,
            nextTaskIds: cappedIDs(openTodos.sorted { compareTodos($0, $1, now: now) }, limit: taskLimit),
            resourceIssueIds: cappedIDs(resourceIssues, limit: resourceIssueLimit),
            recentSnippetIds: cappedIDs(
                recentSnippets(workspaceId: workspace.id, snippets: snippets, nodes: workspaceNodes),
                limit: snippetLimit
            ),
            canvasSummary: canvasSummary,
            openTaskCount: openTodos.count,
            overdueTaskCount: overdueTaskCount,
            dueSoonTaskCount: dueSoonTaskCount,
            resourceIssueCount: resourceIssueCount,
            unresolvedReferenceCount: unresolvedReferenceCount,
            isLargeDataDegraded: false,
            budgetDecision: budgetDecision
        )
    }

    private static func degradedCanvasSummary(
        canvases: [WorkspaceReentryCanvasRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord]
    ) -> WorkspaceReentryCanvasSummary {
        WorkspaceReentryCanvasSummary(
            canvasCount: canvases.count,
            cardCount: nodes.count,
            validLinkCount: 0,
            lastUpdatedAt: latestUpdatedAt(canvases: canvases, nodes: nodes, edges: edges)
        )
    }

    private static func canvasSummary(
        canvases: [WorkspaceReentryCanvasRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord],
        nodeIdsByCanvasId: [String: Set<String>]
    ) -> WorkspaceReentryCanvasSummary {
        let validLinkCount = edges.filter { edge in
            let nodeIds = nodeIdsByCanvasId[edge.canvasId, default: []]
            return nodeIds.contains(edge.sourceNodeId) && nodeIds.contains(edge.targetNodeId)
        }.count
        return WorkspaceReentryCanvasSummary(
            canvasCount: canvases.count,
            cardCount: nodes.count,
            validLinkCount: validLinkCount,
            lastUpdatedAt: latestUpdatedAt(canvases: canvases, nodes: nodes, edges: edges)
        )
    }

    private static func latestUpdatedAt(
        canvases: [WorkspaceReentryCanvasRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord]
    ) -> Date? {
        var latest: Date?
        for canvas in canvases {
            latest = later(latest, canvas.updatedAt)
        }
        for node in nodes {
            latest = later(latest, node.updatedAt)
        }
        for edge in edges {
            latest = later(latest, edge.updatedAt)
        }
        return latest
    }

    private static func later(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else { return candidate }
        return max(current, candidate)
    }

    private static func associatedResourceIDs(
        workspaceId: String,
        resources: [WorkspaceReentryResourceRecord],
        todos: [WorkspaceReentryTodoRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord]
    ) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []

        for resource in resources where resource.scope == "workspace" && resource.workspaceId == workspaceId {
            append(resource.id, to: &ids, seen: &seen)
        }
        for todo in todos {
            append(todo.linkedResourceId, to: &ids, seen: &seen)
        }
        for node in nodes where node.objectType == "resourcePin" {
            append(node.objectId, to: &ids, seen: &seen)
        }

        return ids
    }

    private static func degradedResourceIssueCount(
        workspaceId: String,
        resources: [WorkspaceReentryResourceRecord],
        openTodos: [WorkspaceReentryTodoRecord]
    ) -> Int {
        let resourcesById = Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var resourceIDs = Set(resources.filter { resource in
            resource.scope == "workspace" && resource.workspaceId == workspaceId
        }.map(\.id))
        for todo in openTodos {
            guard let linkedResourceId = todo.linkedResourceId else { continue }
            resourceIDs.insert(linkedResourceId)
        }
        return resourceIDs.reduce(into: 0) { count, resourceID in
            guard let resource = resourcesById[resourceID],
                  isVisible(resource, in: workspaceId),
                  resource.status != "available" else {
                return
            }
            count += 1
        }
    }

    private static func recentSnippets(
        workspaceId: String,
        snippets: [WorkspaceReentrySnippetRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord]
    ) -> [WorkspaceReentrySnippetRecord] {
        let canvasSnippetIds = Set(nodes.compactMap { node -> String? in
            node.objectType == "snippet" ? node.objectId : nil
        })
        return snippets
            .filter { snippet in
                (snippet.scope == "workspace" && snippet.workspaceId == workspaceId) ||
                    (canvasSnippetIds.contains(snippet.id) && isVisible(snippet, in: workspaceId))
            }
            .sorted(by: compareSnippets)
    }

    private static func unresolvedReferenceCount(
        workspaceId: String,
        resourcesById: [String: WorkspaceReentryResourceRecord],
        snippetsById: [String: WorkspaceReentrySnippetRecord],
        openTodos: [WorkspaceReentryTodoRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord],
        nodeIdsByCanvasId: [String: Set<String>]
    ) -> Int {
        let missingTodoResources = openTodos.filter { todo in
            guard let linkedResourceId = todo.linkedResourceId else { return false }
            guard let resource = resourcesById[linkedResourceId] else { return true }
            return !isVisible(resource, in: workspaceId)
        }.count
        let missingNodeResources = nodes.filter { node in
            guard node.objectType == "resourcePin" else { return false }
            guard let objectId = node.objectId else { return true }
            guard let resource = resourcesById[objectId] else { return true }
            return !isVisible(resource, in: workspaceId)
        }.count
        let missingNodeSnippets = nodes.filter { node in
            guard node.objectType == "snippet" else { return false }
            guard let objectId = node.objectId else { return true }
            guard let snippet = snippetsById[objectId] else { return true }
            return !isVisible(snippet, in: workspaceId)
        }.count
        let missingEdgeEndpoints = edges.filter { edge in
            let nodeIds = nodeIdsByCanvasId[edge.canvasId, default: []]
            return !nodeIds.contains(edge.sourceNodeId) || !nodeIds.contains(edge.targetNodeId)
        }.count
        return missingTodoResources + missingNodeResources + missingNodeSnippets + missingEdgeEndpoints
    }

    private static func badges(
        openTaskCount: Int,
        overdueTaskCount: Int,
        dueSoonTaskCount: Int,
        resourceIssueCount: Int,
        limit: Int
    ) -> [WorkspaceReentryBadge] {
        var badges: [WorkspaceReentryBadge] = []
        if overdueTaskCount > 0 {
            badges.append(WorkspaceReentryBadge(kind: .overdueTasks, count: overdueTaskCount))
        } else if dueSoonTaskCount > 0 {
            badges.append(WorkspaceReentryBadge(kind: .dueSoonTasks, count: dueSoonTaskCount))
        } else if openTaskCount > 0 {
            badges.append(WorkspaceReentryBadge(kind: .openTasks, count: openTaskCount))
        }
        if resourceIssueCount > 0 {
            badges.append(WorkspaceReentryBadge(kind: .resourceIssues, count: resourceIssueCount))
        }
        return Array(badges.prefix(max(0, limit)))
    }

    private static func compareTodos(
        _ lhs: WorkspaceReentryTodoRecord,
        _ rhs: WorkspaceReentryTodoRecord,
        now: Date
    ) -> Bool {
        let lhsBucket = todoBucket(lhs, now: now)
        let rhsBucket = todoBucket(rhs, now: now)
        if lhsBucket != rhsBucket { return lhsBucket < rhsBucket }
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        if lhs.title != rhs.title {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func compareResources(
        _ lhs: WorkspaceReentryResourceRecord,
        _ rhs: WorkspaceReentryResourceRecord
    ) -> Bool {
        let lhsDate = lhs.lastOpenedAt ?? lhs.updatedAt
        let rhsDate = rhs.lastOpenedAt ?? rhs.updatedAt
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        if lhs.title != rhs.title {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func compareSnippets(
        _ lhs: WorkspaceReentrySnippetRecord,
        _ rhs: WorkspaceReentrySnippetRecord
    ) -> Bool {
        let lhsDate = lhs.lastUsedAt ?? lhs.lastCopiedAt ?? lhs.updatedAt
        let rhsDate = rhs.lastUsedAt ?? rhs.lastCopiedAt ?? rhs.updatedAt
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        if lhs.title != rhs.title {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func todoBucket(_ todo: WorkspaceReentryTodoRecord, now: Date) -> Int {
        guard let dueAt = todo.dueAt else { return 2 }
        if dueAt < now { return 0 }
        if dueAt <= now.addingTimeInterval(24 * 60 * 60) { return 1 }
        return 2
    }

    private static func isOverdue(_ todo: WorkspaceReentryTodoRecord, now: Date) -> Bool {
        guard let dueAt = todo.dueAt else { return false }
        return dueAt < now
    }

    private static func isDueSoon(_ todo: WorkspaceReentryTodoRecord, now: Date) -> Bool {
        guard let dueAt = todo.dueAt else { return false }
        return dueAt >= now && dueAt <= now.addingTimeInterval(24 * 60 * 60)
    }

    private static func isVisible(_ resource: WorkspaceReentryResourceRecord, in workspaceId: String) -> Bool {
        resource.scope == "global" ||
            (resource.scope == "workspace" && resource.workspaceId == workspaceId)
    }

    private static func isVisible(_ snippet: WorkspaceReentrySnippetRecord, in workspaceId: String) -> Bool {
        snippet.scope == "global" ||
            (snippet.scope == "workspace" && snippet.workspaceId == workspaceId)
    }

    private static func append(_ id: String?, to ids: inout [String], seen: inout Set<String>) {
        guard let id, !seen.contains(id) else { return }
        ids.append(id)
        seen.insert(id)
    }

    private static func cappedIDs<Record: Identifiable>(_ records: [Record], limit: Int) -> [String]
        where Record.ID == String
    {
        Array(records.prefix(max(0, limit)).map(\.id))
    }
}
