# Workspace Resume Brief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `Workspace Resume Brief v0 + Home status badges`, a lightweight re-entry surface that summarizes next tasks, known resource issues, canvas counts, and recently used snippets without adding a dashboard or external side effects.

**Architecture:** Add a pure `MindDeskCore` policy that accepts Sendable records and returns ids, counts, badges, and degradation flags. Add a small app-target mapper from SwiftData models to those core records, then render read-only SwiftUI components in `HomeView` and `WorkspaceDetailView`. Do not change SwiftData schema, manifest/import/export, Canvas gesture/rendering, or system services.

**Tech Stack:** Swift 6, SwiftUI, SwiftData model objects, MindDeskCore pure policies, XCTest, SwiftPM.

---

## File Structure

- Create `Sources/MindDeskCore/WorkspaceReentryBrief.swift`
  - Owns pure record types, output types, status badges, stable sorting, scope filtering, and large-data degradation.
- Modify `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`
  - Adds failing tests for current-workspace aggregation, badge priority, caps, empty state, dangling references, and large-data degradation.
- Create `Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift`
  - Converts `WorkspaceModel`, `ResourcePinModel`, `SnippetModel`, `WorkspaceTodoModel`, `CanvasModel`, `CanvasNodeModel`, and `CanvasEdgeModel` into core records.
  - Caps Home badge calculation to the existing six Recent Workspaces.
- Modify `Tests/MindDeskTests/AppBehaviorTests.swift`
  - Adds app-target tests for mapping model values into core records.
- Modify `Sources/MindDesk/Views/ContentView.swift`
  - Wires briefs into `HomeView` and `WorkspaceDetailView`.
  - Adds read-only UI components for Home badges and the Workspace Resume row.
- Modify `docs/feature-checklist.md`
  - Adds focused manual regression items for the new resume brief behavior.

---

### Task 1: Core Failing Tests

**Files:**
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Add failing tests for workspace-only aggregation, badges, caps, dangling references, empty state, and degradation**

Append these tests before the final closing brace of `CoreBehaviorTests`:

```swift
    func testWorkspaceReentryBriefAggregatesCurrentWorkspaceOnly() {
        let now = Date(timeIntervalSince1970: 1_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace-a", title: "A", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "global-used", workspaceId: nil, title: "Global Used", status: "available", scope: "global", updatedAt: now, lastOpenedAt: now),
                WorkspaceReentryResourceRecord(id: "workspace-issue", workspaceId: "workspace-a", title: "Workspace Issue", status: "missingVolume", scope: "workspace", updatedAt: now, lastOpenedAt: nil),
                WorkspaceReentryResourceRecord(id: "other-private", workspaceId: "workspace-b", title: "Other", status: "missingVolume", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "workspace-snippet", workspaceId: "workspace-a", title: "Workspace Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "other-snippet", workspaceId: "workspace-b", title: "Other Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [
                WorkspaceReentryTodoRecord(id: "todo-a", workspaceId: "workspace-a", title: "Todo A", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "workspace-issue"),
                WorkspaceReentryTodoRecord(id: "todo-b", workspaceId: "workspace-b", title: "Todo B", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "other-private")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas-a", workspaceId: "workspace-a", updatedAt: now),
                WorkspaceReentryCanvasRecord(id: "canvas-b", workspaceId: "workspace-b", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "node-a", canvasId: "canvas-a", objectType: "resourcePin", objectId: "global-used", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "node-b", canvasId: "canvas-b", objectType: "resourcePin", objectId: "other-private", updatedAt: now)
            ],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, "workspace-a")
        XCTAssertEqual(brief.nextTaskIds, ["todo-a"])
        XCTAssertEqual(brief.resourceIssueIds, ["workspace-issue"])
        XCTAssertEqual(brief.recentSnippetIds, ["workspace-snippet"])
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
    }

    func testWorkspaceReentryBriefBadgePriorityUsesOverdueDueOpenAndResourceIssues() {
        let now = Date(timeIntervalSince1970: 10_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "issue", workspaceId: "workspace", title: "Issue", status: "unavailable", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "overdue", workspaceId: "workspace", title: "Overdue", isCompleted: false, isPinned: false, sortIndex: 3, updatedAt: now, dueAt: now.addingTimeInterval(-86_400), linkedResourceId: nil),
                WorkspaceReentryTodoRecord(id: "due", workspaceId: "workspace", title: "Due", isCompleted: false, isPinned: false, sortIndex: 2, updatedAt: now, dueAt: now.addingTimeInterval(2_000), linkedResourceId: nil),
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: nil)
            ],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.openTaskCount, 3)
        XCTAssertEqual(brief.overdueTaskCount, 1)
        XCTAssertEqual(brief.dueSoonTaskCount, 1)
        XCTAssertEqual(brief.badges.map(\.kind), [.overdueTasks, .resourceIssues])
        XCTAssertEqual(brief.badges.map(\.count), [1, 1])
    }

    func testWorkspaceReentryBriefCapsAndOrdersItemsDeterministically() {
        let now = Date(timeIntervalSince1970: 20_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let todos = [
            WorkspaceReentryTodoRecord(id: "z", workspaceId: "workspace", title: "Same", isCompleted: false, isPinned: true, sortIndex: 2, updatedAt: now, dueAt: nil, linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "a", workspaceId: "workspace", title: "Same", isCompleted: false, isPinned: true, sortIndex: 2, updatedAt: now, dueAt: nil, linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "due", workspaceId: "workspace", title: "Due", isCompleted: false, isPinned: false, sortIndex: 9, updatedAt: now, dueAt: now.addingTimeInterval(100), linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "later", workspaceId: "workspace", title: "Later", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: nil)
        ]
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: todos,
            canvases: [],
            nodes: [],
            edges: [],
            now: now,
            taskLimit: 3
        )

        XCTAssertEqual(brief.nextTaskIds, ["due", "a", "z"])
    }

    func testWorkspaceReentryBriefIgnoresCompletedAndDanglingReferences() {
        let now = Date(timeIntervalSince1970: 30_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "done", workspaceId: "workspace", title: "Done", isCompleted: true, isPinned: true, sortIndex: 0, updatedAt: now, dueAt: now.addingTimeInterval(-1), linkedResourceId: "missing-resource"),
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: "missing-resource")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "node", canvasId: "canvas", objectType: "resourcePin", objectId: "missing-resource", updatedAt: now)
            ],
            edges: [
                WorkspaceReentryCanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "missing-node", updatedAt: now)
            ],
            now: now
        )

        XCTAssertEqual(brief.nextTaskIds, ["open"])
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 0)
        XCTAssertEqual(brief.unresolvedReferenceCount, 2)
    }

    func testWorkspaceReentryBriefHandlesEmptyWorkspace() {
        let now = Date(timeIntervalSince1970: 40_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, "workspace")
        XCTAssertTrue(brief.badges.isEmpty)
        XCTAssertTrue(brief.nextTaskIds.isEmpty)
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, 0)
        XCTAssertFalse(brief.isLargeDataDegraded)
    }

    func testWorkspaceReentryBriefDegradesLargeInputsToCountsOnly() {
        let now = Date(timeIntervalSince1970: 50_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let nodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            WorkspaceReentryCanvasNodeRecord(id: "node-\(index)", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: now)
        }
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: nodes,
            edges: [],
            now: now
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
        XCTAssertTrue(brief.nextTaskIds.isEmpty)
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, nodes.count)
    }
```

- [ ] **Step 2: Run the focused core tests and confirm they fail**

Run:

```bash
swift test --filter CoreBehaviorTests/testWorkspaceReentryBrief
```

Expected: build fails because `WorkspaceReentryWorkspaceRecord`, `WorkspaceReentryBriefPolicy`, and related types do not exist.

- [ ] **Step 3: Commit the red tests**

```bash
git add Tests/MindDeskCoreTests/CoreBehaviorTests.swift
git commit -m "test: define workspace resume brief behavior"
```

---

### Task 2: Core Policy Implementation

**Files:**
- Create: `Sources/MindDeskCore/WorkspaceReentryBrief.swift`
- Modify: `Tests/MindDeskCoreTests/CoreBehaviorTests.swift`

- [ ] **Step 1: Create the pure core policy file**

Create `Sources/MindDeskCore/WorkspaceReentryBrief.swift` with this implementation:

```swift
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

    public init(id: String, workspaceId: String?, title: String, status: String, scope: String, updatedAt: Date, lastOpenedAt: Date?) {
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

    public init(id: String, workspaceId: String?, title: String, scope: String, updatedAt: Date, lastCopiedAt: Date?, lastUsedAt: Date?) {
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

    public init(id: String, workspaceId: String, title: String, isCompleted: Bool, isPinned: Bool, sortIndex: Int, updatedAt: Date, dueAt: Date?, linkedResourceId: String?) {
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

    public init(id: String, canvasId: String, sourceNodeId: String, targetNodeId: String, updatedAt: Date) {
        self.id = id
        self.canvasId = canvasId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.updatedAt = updatedAt
    }
}

public enum WorkspaceReentryBadgeKind: String, Equatable, Sendable {
    case overdueTasks
    case dueSoonTasks
    case openTasks
    case resourceIssues
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
    public var isLargeDataDegraded: Bool

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
        isLargeDataDegraded: Bool
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
        self.isLargeDataDegraded = isLargeDataDegraded
    }
}

public enum WorkspaceReentryBriefPolicy {
    public static let maximumDetailedNodeCount = 10_000
    public static let maximumDetailedEdgeCount = 20_000
    public static let maximumDetailedTodoCount = 10_000

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
        let workspaceCanvases = canvases
            .filter { $0.workspaceId == workspace.id }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.id < rhs.id
            }
        let canvasIds = Set(workspaceCanvases.map(\.id))
        let workspaceNodes = nodes.filter { canvasIds.contains($0.canvasId) }
        let workspaceNodeIds = Set(workspaceNodes.map(\.id))
        let validLinkCount = edges.filter { edge in
            canvasIds.contains(edge.canvasId) &&
                workspaceNodeIds.contains(edge.sourceNodeId) &&
                workspaceNodeIds.contains(edge.targetNodeId)
        }.count
        let lastCanvasUpdate = ([workspace.updatedAt] +
            workspaceCanvases.map(\.updatedAt) +
            workspaceNodes.map(\.updatedAt) +
            edges.filter { canvasIds.contains($0.canvasId) }.map(\.updatedAt)
        ).max()
        let canvasSummary = WorkspaceReentryCanvasSummary(
            canvasCount: workspaceCanvases.count,
            cardCount: workspaceNodes.count,
            validLinkCount: validLinkCount,
            lastUpdatedAt: lastCanvasUpdate
        )
        let openTodos = todos.filter { $0.workspaceId == workspace.id && !$0.isCompleted }
        let overdueCount = openTodos.filter { todo in
            guard let dueAt = todo.dueAt else { return false }
            return dueAt < now
        }.count
        let dueSoonCount = openTodos.filter { todo in
            guard let dueAt = todo.dueAt else { return false }
            return dueAt >= now && dueAt <= now.addingTimeInterval(24 * 60 * 60)
        }.count
        let associatedResourceIds = associatedResourceIDs(
            workspaceId: workspace.id,
            resources: resources,
            todos: openTodos,
            nodes: workspaceNodes
        )
        let resourcesById = Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resourceIssues = associatedResourceIds
            .compactMap { resourcesById[$0] }
            .filter { $0.status != "available" }
            .sorted { lhs, rhs in
                let lhsDate = lhs.lastOpenedAt ?? lhs.updatedAt
                let rhsDate = rhs.lastOpenedAt ?? rhs.updatedAt
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                if lhs.title != rhs.title { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
                return lhs.id < rhs.id
            }
        let unresolvedReferences = unresolvedReferenceCount(
            associatedResourceIds: associatedResourceIds,
            resourcesById: resourcesById,
            workspaceNodes: workspaceNodes,
            edges: edges.filter { canvasIds.contains($0.canvasId) },
            workspaceNodeIds: workspaceNodeIds
        )
        let degraded = nodes.count > maximumDetailedNodeCount ||
            edges.count > maximumDetailedEdgeCount ||
            todos.count > maximumDetailedTodoCount
        let badges = badges(
            openTaskCount: openTodos.count,
            overdueTaskCount: overdueCount,
            dueSoonTaskCount: dueSoonCount,
            resourceIssueCount: resourceIssues.count,
            limit: badgeLimit
        )
        guard !degraded else {
            return WorkspaceReentryBrief(
                workspaceId: workspace.id,
                badges: badges,
                nextTaskIds: [],
                resourceIssueIds: [],
                recentSnippetIds: [],
                canvasSummary: canvasSummary,
                openTaskCount: openTodos.count,
                overdueTaskCount: overdueCount,
                dueSoonTaskCount: dueSoonCount,
                resourceIssueCount: resourceIssues.count,
                unresolvedReferenceCount: unresolvedReferences,
                isLargeDataDegraded: true
            )
        }
        return WorkspaceReentryBrief(
            workspaceId: workspace.id,
            badges: badges,
            nextTaskIds: Array(openTodos.sorted { compareTodos($0, $1, now: now) }.map(\.id).prefix(max(taskLimit, 0))),
            resourceIssueIds: Array(resourceIssues.map(\.id).prefix(max(resourceIssueLimit, 0))),
            recentSnippetIds: Array(recentSnippets(workspaceId: workspace.id, snippets: snippets, nodes: workspaceNodes).map(\.id).prefix(max(snippetLimit, 0))),
            canvasSummary: canvasSummary,
            openTaskCount: openTodos.count,
            overdueTaskCount: overdueCount,
            dueSoonTaskCount: dueSoonCount,
            resourceIssueCount: resourceIssues.count,
            unresolvedReferenceCount: unresolvedReferences,
            isLargeDataDegraded: false
        )
    }

    private static func associatedResourceIDs(
        workspaceId: String,
        resources: [WorkspaceReentryResourceRecord],
        todos: [WorkspaceReentryTodoRecord],
        nodes: [WorkspaceReentryCanvasNodeRecord]
    ) -> Set<String> {
        var ids = Set(resources.compactMap { resource -> String? in
            resource.scope == "workspace" && resource.workspaceId == workspaceId ? resource.id : nil
        })
        ids.formUnion(todos.compactMap(\.linkedResourceId))
        ids.formUnion(nodes.compactMap { node -> String? in
            node.objectType == "resourcePin" ? node.objectId : nil
        })
        return ids
    }

    private static func unresolvedReferenceCount(
        associatedResourceIds: Set<String>,
        resourcesById: [String: WorkspaceReentryResourceRecord],
        workspaceNodes: [WorkspaceReentryCanvasNodeRecord],
        edges: [WorkspaceReentryCanvasEdgeRecord],
        workspaceNodeIds: Set<String>
    ) -> Int {
        let missingResources = associatedResourceIds.filter { resourcesById[$0] == nil }.count
        let missingNodeObjects = workspaceNodes.filter { node in
            guard node.objectType == "resourcePin", let objectId = node.objectId else { return false }
            return resourcesById[objectId] == nil
        }.count
        let missingEdgeEndpoints = edges.filter { edge in
            !workspaceNodeIds.contains(edge.sourceNodeId) || !workspaceNodeIds.contains(edge.targetNodeId)
        }.count
        return missingResources + missingNodeObjects + missingEdgeEndpoints
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
                snippet.scope == "workspace" && snippet.workspaceId == workspaceId ||
                    canvasSnippetIds.contains(snippet.id)
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.lastUsedAt ?? lhs.lastCopiedAt ?? lhs.updatedAt
                let rhsDate = rhs.lastUsedAt ?? rhs.lastCopiedAt ?? rhs.updatedAt
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                if lhs.title != rhs.title { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
                return lhs.id < rhs.id
            }
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
        return Array(badges.prefix(max(limit, 0)))
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
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.title != rhs.title { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
        return lhs.id < rhs.id
    }

    private static func todoBucket(_ todo: WorkspaceReentryTodoRecord, now: Date) -> Int {
        guard let dueAt = todo.dueAt else { return 2 }
        if dueAt < now { return 0 }
        if dueAt <= now.addingTimeInterval(24 * 60 * 60) { return 1 }
        return 2
    }
}
```

- [ ] **Step 2: Run the focused tests and fix compile issues only inside the new core file**

Run:

```bash
swift test --filter CoreBehaviorTests/testWorkspaceReentryBrief
```

Expected: all workspace reentry brief tests pass.

- [ ] **Step 3: Run all core tests**

Run:

```bash
swift test --filter MindDeskCoreTests
```

Expected: all core tests pass.

- [ ] **Step 4: Commit the core policy**

```bash
git add Sources/MindDeskCore/WorkspaceReentryBrief.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift
git commit -m "feat: add workspace resume brief policy"
```

---

### Task 3: App Mapping Tests And Implementation

**Files:**
- Create: `Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift`
- Modify: `Tests/MindDeskTests/AppBehaviorTests.swift`

- [ ] **Step 1: Add failing app mapping tests**

Append these tests before the final closing brace of `AppBehaviorTests`:

```swift
    func testWorkspaceReentryMapperBuildsCoreRecordsFromModels() {
        let now = Date(timeIntervalSince1970: 1_000)
        let workspace = WorkspaceModel(id: "workspace", title: "Workspace", updatedAt: now)
        let resource = ResourcePinModel(
            id: "resource",
            workspaceId: "workspace",
            title: "Resource",
            targetType: .folder,
            displayPath: "/tmp/resource",
            lastResolvedPath: "/tmp/resource",
            scope: .workspace,
            status: .unavailable,
            updatedAt: now
        )
        let snippet = SnippetModel(
            id: "snippet",
            workspaceId: "workspace",
            title: "Snippet",
            kind: .prompt,
            body: "Prompt",
            scope: .workspace,
            lastCopiedAt: now,
            updatedAt: now
        )
        let todo = WorkspaceTodoModel(
            id: "todo",
            workspaceId: "workspace",
            title: "Task",
            isCompleted: false,
            updatedAt: now,
            linkedResourceId: "resource"
        )
        let canvas = CanvasModel(id: "canvas", workspaceId: "workspace", updatedAt: now)
        let node = CanvasNodeModel(id: "node", canvasId: "canvas", title: "Node", nodeType: .resource, objectType: "resourcePin", objectId: "resource", x: 0, y: 0, updatedAt: now)
        let edge = CanvasEdgeModel(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", updatedAt: now)

        let brief = WorkspaceReentryBriefMapper.brief(
            for: workspace,
            resources: [resource],
            snippets: [snippet],
            todos: [todo],
            canvases: [canvas],
            nodes: [node],
            edges: [edge],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, "workspace")
        XCTAssertEqual(brief.nextTaskIds, ["todo"])
        XCTAssertEqual(brief.resourceIssueIds, ["resource"])
        XCTAssertEqual(brief.recentSnippetIds, ["snippet"])
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 1)
    }

    func testWorkspaceReentryMapperDoesNotLeakOtherWorkspacePrivateRecords() {
        let now = Date(timeIntervalSince1970: 2_000)
        let workspace = WorkspaceModel(id: "workspace-a", title: "A", updatedAt: now)
        let otherResource = ResourcePinModel(
            id: "other-resource",
            workspaceId: "workspace-b",
            title: "Other",
            targetType: .folder,
            displayPath: "/tmp/other",
            lastResolvedPath: "/tmp/other",
            scope: .workspace,
            status: .unavailable,
            updatedAt: now
        )
        let otherSnippet = SnippetModel(
            id: "other-snippet",
            workspaceId: "workspace-b",
            title: "Other Snippet",
            kind: .prompt,
            body: "Prompt",
            scope: .workspace,
            lastCopiedAt: now,
            updatedAt: now
        )

        let brief = WorkspaceReentryBriefMapper.brief(
            for: workspace,
            resources: [otherResource],
            snippets: [otherSnippet],
            todos: [],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
    }
```

- [ ] **Step 2: Run app tests and confirm they fail**

Run:

```bash
swift test --filter MindDeskTests.AppBehaviorTests/testWorkspaceReentryMapper
```

Expected: build fails because `WorkspaceReentryBriefMapper` does not exist.

- [ ] **Step 3: Create the app mapper**

Create `Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift`:

```swift
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
        now: Date = .now
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
        now: Date = .now
    ) -> [String: WorkspaceReentryBrief] {
        let cappedWorkspaces = Array(workspaces.prefix(6))
        let workspaceIDs = Set(cappedWorkspaces.map(\.id))
        let resourceRecords = resources.map(resourceRecord)
        let snippetRecords = snippets.map(snippetRecord)
        let todoRecords = todos.filter { workspaceIDs.contains($0.workspaceId) }.map(todoRecord)
        let canvasModels = canvases.filter { workspaceIDs.contains($0.workspaceId) }
        let canvasRecords = canvasModels.map(canvasRecord)
        let canvasIDs = Set(canvasModels.map(\.id))
        let nodeModels = nodes.filter { canvasIDs.contains($0.canvasId) }
        let nodeRecords = nodeModels.map(nodeRecord)
        let edgeRecords = edges.filter { canvasIDs.contains($0.canvasId) }.map(edgeRecord)
        return Dictionary(uniqueKeysWithValues: cappedWorkspaces.map { workspace in
            let brief = WorkspaceReentryBriefPolicy.brief(
                for: workspaceRecord(workspace),
                resources: resourceRecords,
                snippets: snippetRecords,
                todos: todoRecords,
                canvases: canvasRecords,
                nodes: nodeRecords,
                edges: edgeRecords,
                now: now
            )
            return (workspace.id, brief)
        })
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
        WorkspaceReentryCanvasRecord(id: canvas.id, workspaceId: canvas.workspaceId, updatedAt: canvas.updatedAt)
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
```

- [ ] **Step 4: Run app tests**

Run:

```bash
swift test --filter MindDeskTests.AppBehaviorTests/testWorkspaceReentryMapper
```

Expected: the new app mapping tests pass.

- [ ] **Step 5: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 6: Commit the mapper**

```bash
git add Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift Tests/MindDeskTests/AppBehaviorTests.swift
git commit -m "feat: map workspace resume brief inputs"
```

---

### Task 4: Home Badges And Workspace Resume UI

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`

- [ ] **Step 1: Add a Home brief dictionary and pass it into HomeView**

In `ContentView`, add this computed property near `recentWorkspaces`:

```swift
    private var homeWorkspaceBriefsByID: [String: WorkspaceReentryBrief] {
        WorkspaceReentryBriefMapper.briefsByWorkspaceID(
            workspaces: Array(recentWorkspaces.prefix(6)),
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges
        )
    }
```

Update the `HomeView(` call in `detailView` to include:

```swift
                workspaceBriefsByID: homeWorkspaceBriefsByID,
```

- [ ] **Step 2: Pass a workspace brief into WorkspaceDetailView**

In the `WorkspaceDetailView(` call, add:

```swift
                    reentryBrief: WorkspaceReentryBriefMapper.brief(
                        for: workspace,
                        resources: resources,
                        snippets: snippets,
                        todos: todos,
                        canvases: canvases,
                        nodes: nodes,
                        edges: edges
                    ),
```

Add this stored property to `WorkspaceDetailView`:

```swift
    let reentryBrief: WorkspaceReentryBrief
```

- [ ] **Step 3: Update HomeView signature and Recent Workspaces cards**

Add this stored property to `HomeView`:

```swift
    let workspaceBriefsByID: [String: WorkspaceReentryBrief]
```

Replace the current Recent Workspaces `DashboardCard` block with:

```swift
                            HomeWorkspaceResumeCard(
                                workspace: workspace,
                                brief: workspaceBriefsByID[workspace.id],
                                onSelect: {
                                    onSelectWorkspace(workspace)
                                }
                            )
```

- [ ] **Step 4: Add read-only resume UI components to ContentView.swift**

Add these components near `HomeView`:

```swift
private struct HomeWorkspaceResumeCard: View {
    let workspace: WorkspaceModel
    let brief: WorkspaceReentryBrief?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workspace.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(workspace.details.isEmpty ? "Workspace" : workspace.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                if let brief, !brief.badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(brief.badges) { badge in
                            WorkspaceResumeBadgeView(badge: badge)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Open workspace")
    }
}

private struct WorkspaceResumeBriefView: View {
    let brief: WorkspaceReentryBrief
    let resourcesByID: [String: ResourcePinModel]
    let snippetsByID: [String: SnippetModel]
    let todosByID: [String: WorkspaceTodoModel]
    let onOpenCanvas: () -> Void
    let onOpenResources: () -> Void
    let onOpenSnippets: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpenCanvas) {
                Label(canvasText, systemImage: "point.3.connected.trianglepath.dotted")
                    .lineLimit(1)
            }
            .buttonStyle(.borderless)
            .help("Resume canvas")

            if !brief.nextTaskIds.isEmpty {
                resumeGroup(systemImage: "checklist", title: "Next", values: brief.nextTaskIds.compactMap { todosByID[$0]?.title }, action: onOpenCanvas)
            }

            if !brief.resourceIssueIds.isEmpty {
                resumeGroup(systemImage: "exclamationmark.triangle", title: "Resources", values: brief.resourceIssueIds.compactMap { resourcesByID[$0]?.displayName }, action: onOpenResources)
                    .foregroundStyle(.red)
            }

            if !brief.recentSnippetIds.isEmpty {
                resumeGroup(systemImage: "text.quote", title: "Snippets", values: brief.recentSnippetIds.compactMap { snippetsByID[$0]?.title }, action: onOpenSnippets)
            }

            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(accessibilitySummary)
    }

    private var canvasText: String {
        if brief.isLargeDataDegraded {
            return "Large workspace"
        }
        return "\(brief.canvasSummary.cardCount) cards · \(brief.canvasSummary.validLinkCount) links"
    }

    private var accessibilitySummary: String {
        "\(brief.openTaskCount) open tasks, \(brief.resourceIssueCount) resource issues, \(brief.canvasSummary.cardCount) canvas cards"
    }

    private func resumeGroup(systemImage: String, title: String, values: [String], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text("\(title): \(values.prefix(2).joined(separator: ", "))")
                    .lineLimit(1)
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(.borderless)
    }
}

private struct WorkspaceResumeBadgeView: View {
    let badge: WorkspaceReentryBadge

    var body: some View {
        Label(labelText, systemImage: systemImage)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
            .help(labelText)
    }

    private var labelText: String {
        switch badge.kind {
        case .overdueTasks:
            "\(badge.count) overdue"
        case .dueSoonTasks:
            "\(badge.count) due"
        case .openTasks:
            "\(badge.count) open"
        case .resourceIssues:
            "\(badge.count) issue\(badge.count == 1 ? "" : "s")"
        }
    }

    private var systemImage: String {
        switch badge.kind {
        case .overdueTasks, .dueSoonTasks:
            "calendar.badge.exclamationmark"
        case .openTasks:
            "checklist"
        case .resourceIssues:
            "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch badge.kind {
        case .overdueTasks, .resourceIssues:
            .red
        case .dueSoonTasks:
            .orange
        case .openTasks:
            .secondary
        }
    }
}
```

- [ ] **Step 5: Render the resume view in WorkspaceDetailView**

Inside `WorkspaceDetailView.body`, between the header `HStack` and the `switch tab`, insert:

```swift
            WorkspaceResumeBriefView(
                brief: reentryBrief,
                resourcesByID: Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                snippetsByID: Dictionary(snippets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                todosByID: Dictionary(workspaceTodos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                onOpenCanvas: { tab = "Canvas" },
                onOpenResources: { tab = "Resources" },
                onOpenSnippets: { tab = "Snippets" }
            )
```

- [ ] **Step 6: Build and fix SwiftUI compile issues**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 7: Run all tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 8: Commit UI integration**

```bash
git add Sources/MindDesk/Views/ContentView.swift
git commit -m "feat: show workspace resume brief"
```

---

### Task 5: Polish And Regression Checklist

**Files:**
- Modify: `Sources/MindDesk/Views/ContentView.swift`
- Modify: `docs/feature-checklist.md`

- [ ] **Step 1: Tighten text and layout behavior**

Update the workspace title/details area in `WorkspaceDetailView`:

```swift
                    Text(workspace.title)
                        .font(.title.bold())
                        .lineLimit(1)
                    Text(workspace.details)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
```

If the header overlaps at narrow widths, wrap the action buttons and segmented picker with `ViewThatFits`:

```swift
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        workspaceActionButtons
                        workspaceViewPicker
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        workspaceViewPicker
                        workspaceActionButtons
                    }
                }
```

Add `workspaceActionButtons` and `workspaceViewPicker` private computed views inside `WorkspaceDetailView` using the same button actions and picker options already present in the header.

- [ ] **Step 2: Add regression checklist items**

Add these items to `docs/feature-checklist.md` under Home / Workspace / Performance sections:

```markdown
- [ ] Home Recent Workspaces can show at most two resume badges and does not become a cross-workspace task list.
- [ ] Workspace Resume Brief shows next tasks, known resource issues, canvas counts, and recent snippets without opening Finder, Terminal, or command execution paths.
- [ ] Empty workspaces show a quiet resume state and do not create task groups.
- [ ] Large workspaces degrade the resume brief to count-only status without running Canvas routing or layout.
```

- [ ] **Step 3: Run build and tests**

Run:

```bash
swift test
swift build
```

Expected: both commands succeed.

- [ ] **Step 4: Commit polish**

```bash
git add Sources/MindDesk/Views/ContentView.swift docs/feature-checklist.md
git commit -m "polish: tighten workspace resume brief UI"
```

---

### Task 6: Hardening And Safety Verification

**Files:**
- Verify: `Sources/MindDeskCore/WorkspaceReentryBrief.swift`
- Verify: `Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift`
- Verify: `Sources/MindDesk/Views/ContentView.swift`
- Verify unchanged: `Sources/MindDeskCore/ExportManifest.swift`
- Verify unchanged: `Sources/MindDesk/Models/WorkbenchModels.swift`

- [ ] **Step 1: Run full tests and builds**

Run:

```bash
swift test
swift build
```

Expected: both commands succeed.

- [ ] **Step 2: Run bundle verification**

Run:

```bash
./script/build_and_run.sh --verify-bundle
```

Expected: the app bundle builds and verifies. If the command fails because local signing, app launch, or macOS permissions are unavailable, capture the exact failure and continue with `swift build` and `swift test` results.

- [ ] **Step 3: Run safety grep against new brief files**

Run:

```bash
rg -n "NSWorkspace\\.shared\\.open|FinderService\\(|TerminalService\\(|AppleScriptRunner|BookmarkService\\(|resolveAuthorizedBookmark|startAccessingSecurityScopedResource|FileManager\\.default\\.enumerator|FileDialogs|NSOpenPanel|NSSavePanel|Process\\(" Sources/MindDeskCore/WorkspaceReentryBrief.swift Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift Sources/MindDesk/Views/ContentView.swift
rg -n "CanvasEdgeRoutePlanner|CanvasLayoutEngine\\.autoArrange|usesObstacleRouting" Sources/MindDeskCore/WorkspaceReentryBrief.swift Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift Sources/MindDesk/Views/ContentView.swift
```

Expected: no matches in the new brief policy, mapper, or brief UI. Existing matches elsewhere in `ContentView.swift` are acceptable only if they predate the brief and are not referenced by the new components.

- [ ] **Step 4: Confirm schema and manifest files were not changed**

Run:

```bash
git diff --exit-code -- Sources/MindDeskCore/ExportManifest.swift Sources/MindDesk/Models/WorkbenchModels.swift
```

Expected: no diff.

- [ ] **Step 5: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 6: Commit hardening fixes if any were needed**

If Task 6 required code or checklist changes:

```bash
git add Sources/MindDeskCore/WorkspaceReentryBrief.swift Sources/MindDesk/Models/WorkspaceReentryBriefMapping.swift Sources/MindDesk/Views/ContentView.swift Tests/MindDeskCoreTests/CoreBehaviorTests.swift Tests/MindDeskTests/AppBehaviorTests.swift docs/feature-checklist.md
git commit -m "test: harden workspace resume brief"
```

If Task 6 required no changes, do not create an empty commit.

---

## Manual Smoke Checklist

- [ ] Fresh store launches and Home renders without crashes.
- [ ] Empty workspace shows a quiet resume row and no fake health/progress score.
- [ ] Workspace with overdue/open tasks shows at most three next tasks.
- [ ] Workspace with unavailable resources shows at most two known issue items.
- [ ] Workspace with canvas cards and links shows count-only Canvas summary.
- [ ] Home recent workspace cards show at most two badges.
- [ ] Clicking Home workspace cards still opens the workspace.
- [ ] Clicking Resume Canvas, Resource, or Snippet groups only changes internal tabs.
- [ ] The brief does not open Finder, launch Terminal, copy commands, or request bookmark authorization.
- [ ] Narrow window layout does not overlap title, buttons, picker, and resume row.
- [ ] Long titles and details are line-limited.
