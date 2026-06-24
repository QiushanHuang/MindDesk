import XCTest
import MindDeskCore
import SwiftData
@testable import MindDesk

final class AppBehaviorTests: XCTestCase {
    func testWorkspaceReentryMapperBuildsBriefFromAppModels() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let alphaResource = ResourcePinModel(
            id: "resource-alpha",
            workspaceId: workspace.id,
            title: "Zulu Title",
            targetType: .file,
            displayPath: "/tmp/alpha.md",
            lastResolvedPath: "/tmp/alpha.md",
            scope: .workspace,
            originalName: "Alpha.md",
            status: .missingVolume,
            updatedAt: now.addingTimeInterval(-10)
        )
        let zuluResource = ResourcePinModel(
            id: "resource-zulu",
            workspaceId: workspace.id,
            title: "Alpha Title",
            targetType: .file,
            displayPath: "/tmp/zulu.md",
            lastResolvedPath: "/tmp/zulu.md",
            scope: .workspace,
            originalName: "Zulu.md",
            status: .staleAuthorization,
            updatedAt: now.addingTimeInterval(-10)
        )
        let todo = WorkspaceTodoModel(
            id: "todo-linked-resource",
            workspaceId: workspace.id,
            title: "Review linked resource",
            isPinned: true,
            sortIndex: 4,
            updatedAt: now.addingTimeInterval(-20),
            dueAt: now.addingTimeInterval(60 * 60),
            linkedResourceId: alphaResource.id
        )
        let snippet = SnippetModel(
            id: "snippet-workspace",
            workspaceId: workspace.id,
            title: "Workspace prompt",
            kind: .prompt,
            body: "Summarize",
            scope: .workspace,
            lastCopiedAt: now.addingTimeInterval(-100),
            lastUsedAt: now.addingTimeInterval(-50),
            updatedAt: now.addingTimeInterval(-200)
        )
        let canvas = CanvasModel(
            id: "canvas-a",
            workspaceId: workspace.id,
            updatedAt: now.addingTimeInterval(-30)
        )
        let node = CanvasNodeModel(
            id: "node-a",
            canvasId: canvas.id,
            title: "Resource",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: alphaResource.id,
            x: 0,
            y: 0,
            updatedAt: now.addingTimeInterval(-25)
        )
        let edge = CanvasEdgeModel(
            id: "edge-self",
            canvasId: canvas.id,
            sourceNodeId: node.id,
            targetNodeId: node.id,
            updatedAt: now.addingTimeInterval(-15)
        )

        let brief = WorkspaceReentryBriefMapper.brief(
            for: workspace,
            resources: [zuluResource, alphaResource],
            snippets: [snippet],
            todos: [todo],
            canvases: [canvas],
            nodes: [node],
            edges: [edge],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, workspace.id)
        XCTAssertEqual(brief.nextTaskIds, [todo.id])
        XCTAssertEqual(brief.resourceIssueIds, [alphaResource.id, zuluResource.id])
        XCTAssertEqual(brief.recentSnippetIds, [snippet.id])
        XCTAssertEqual(brief.canvasSummary.canvasCount, 1)
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 1)
        XCTAssertEqual(brief.unresolvedReferenceCount, 0)
    }

    func testWorkspaceReentryMapperDoesNotLeakWorkspaceScopedPrivateRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let selectedWorkspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let otherWorkspace = WorkspaceModel(id: "workspace-b", title: "Workspace B", updatedAt: now)
        let privateResource = ResourcePinModel(
            id: "resource-private-b",
            workspaceId: otherWorkspace.id,
            title: "Private B",
            targetType: .file,
            displayPath: "/tmp/private-b.md",
            lastResolvedPath: "/tmp/private-b.md",
            scope: .workspace,
            status: .missingVolume,
            updatedAt: now.addingTimeInterval(-10)
        )
        let privateSnippet = SnippetModel(
            id: "snippet-private-b",
            workspaceId: otherWorkspace.id,
            title: "Private B Prompt",
            kind: .prompt,
            body: "Private",
            scope: .workspace,
            lastUsedAt: now.addingTimeInterval(-20),
            updatedAt: now.addingTimeInterval(-30)
        )
        let todo = WorkspaceTodoModel(
            id: "todo-a-links-private-b",
            workspaceId: selectedWorkspace.id,
            title: "Check missing link",
            updatedAt: now.addingTimeInterval(-40),
            linkedResourceId: privateResource.id
        )
        let canvas = CanvasModel(id: "canvas-a", workspaceId: selectedWorkspace.id, updatedAt: now)
        let snippetNode = CanvasNodeModel(
            id: "node-private-snippet",
            canvasId: canvas.id,
            title: "Private snippet",
            nodeType: .snippet,
            objectType: "snippet",
            objectId: privateSnippet.id,
            x: 0,
            y: 0,
            updatedAt: now
        )

        let brief = WorkspaceReentryBriefMapper.brief(
            for: selectedWorkspace,
            resources: [privateResource],
            snippets: [privateSnippet],
            todos: [todo],
            canvases: [canvas],
            nodes: [snippetNode],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.resourceIssueIds, [])
        XCTAssertEqual(brief.resourceIssueCount, 0)
        XCTAssertEqual(brief.recentSnippetIds, [])
        XCTAssertEqual(brief.unresolvedReferenceCount, 2)
    }

    func testWorkspaceReentryMapperBriefsByWorkspaceIDCapsToFirstSixWorkspaces() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaces = (1...7).map { index in
            WorkspaceModel(id: "workspace-\(index)", title: "Workspace \(index)", updatedAt: now)
        }
        let cappedTodo = WorkspaceTodoModel(
            id: "todo-six",
            workspaceId: "workspace-6",
            title: "Visible capped todo",
            updatedAt: now
        )
        let omittedTodo = WorkspaceTodoModel(
            id: "todo-seven",
            workspaceId: "workspace-7",
            title: "Omitted seventh todo",
            updatedAt: now
        )

        let briefs = WorkspaceReentryBriefMapper.briefsByWorkspaceID(
            workspaces: workspaces,
            resources: [],
            snippets: [],
            todos: [cappedTodo, omittedTodo],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(Set(briefs.keys), Set(workspaces.prefix(6).map(\.id)))
        XCTAssertNil(briefs["workspace-7"])
        XCTAssertEqual(briefs["workspace-6"]?.nextTaskIds, [cappedTodo.id])
    }

    func testResourceTagsPreserveCommaContainingValues() {
        let resource = ResourcePinModel(
            title: "Paper",
            targetType: .file,
            displayPath: "/tmp/Paper.pdf",
            lastResolvedPath: "/tmp/Paper.pdf",
            tags: ["research, 2026", "draft"],
            scope: .global
        )

        XCTAssertEqual(resource.tags, ["research, 2026", "draft"])

        resource.tags = ["field, notes", "archive"]

        XCTAssertEqual(resource.tags, ["field, notes", "archive"])
    }

    func testSnippetTagsPreserveCommaContainingValues() {
        let snippet = SnippetModel(
            title: "Prompt",
            kind: .prompt,
            body: "Summarize",
            tags: ["llm, review", "writing"],
            scope: .global
        )

        XCTAssertEqual(snippet.tags, ["llm, review", "writing"])

        snippet.tags = ["analysis, qa", "saved"]

        XCTAssertEqual(snippet.tags, ["analysis, qa", "saved"])
    }

    func testResourceRenameApplicationPreservesClearedCustomName() {
        let resource = ResourcePinModel(
            title: "Docs",
            targetType: .folder,
            displayPath: "/tmp/Docs",
            lastResolvedPath: "/tmp/Docs",
            scope: .global,
            originalName: "Docs",
            customName: "Project Docs"
        )

        resource.applyRename(titleInput: "   ", note: "Keep note")

        XCTAssertEqual(resource.title, "Docs")
        XCTAssertEqual(resource.customName, "")
        XCTAssertEqual(resource.note, "Keep note")
    }

    @MainActor
    func testSeedDataDoesNotCreateCanvasBeforeExplicitCanvasEntry() throws {
        let container = try makeInMemoryModelContainer()
        let context = ModelContext(container)

        try SeedData.seedIfNeeded(
            context: context,
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: []
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceModel>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SnippetModel>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasNodeModel>()), 0)
    }

    func testResourceRemovalImpactMessageListsAllCleanupPlanEffects() {
        let cleanup = CleanupPlan(
            canvasNodeIdsToDelete: ["node-a", "node-b"],
            canvasEdgeIdsToDelete: ["edge-a"],
            todoIdsClearingLinkedResource: ["todo-a", "todo-b", "todo-c"],
            snippetIdsClearingWorkingDirectory: ["snippet-a"],
            aliasIdsMarkingMissing: ["alias-a", "alias-b"]
        )
        let message = ResourceRemovalImpactMessage.text(displayName: "Project Docs", cleanup: cleanup)

        XCTAssertEqual(message, expectedResourceRemovalMessage(displayName: "Project Docs", cleanup: cleanup))
    }

    func testResourceRemovalRequestSnapshotsCleanupAndMessage() {
        let resource = ResourcePinModel(
            id: "resource",
            title: "Docs",
            targetType: .folder,
            displayPath: "/tmp/Docs",
            lastResolvedPath: "/tmp/Docs",
            scope: .global,
            customName: "Project Docs"
        )
        let cleanup = CleanupPlan(
            canvasNodeIdsToDelete: ["node"],
            canvasEdgeIdsToDelete: ["edge"],
            todoIdsClearingLinkedResource: ["todo"],
            snippetIdsClearingWorkingDirectory: ["snippet"],
            aliasIdsMarkingMissing: ["alias"]
        )
        let displayName = resource.displayName

        let request = ResourceRemovalRequest(resource: resource, cleanup: cleanup)
        resource.customName = "Renamed After Alert"

        XCTAssertEqual(request.id, "resource")
        XCTAssertEqual(request.displayName, displayName)
        XCTAssertEqual(request.cleanup, cleanup)
        XCTAssertEqual(request.message, expectedResourceRemovalMessage(displayName: displayName, cleanup: cleanup))
    }

    func testWorkspaceCanvasLookupLimitsExistingCanvasFetch() {
        let descriptor = WorkspaceCanvasLookup.descriptor(for: "workspace")

        XCTAssertEqual(descriptor.fetchLimit, 1)
    }

    @MainActor
    func testWorkspaceCanvasLookupFetchesOnlyRequestedWorkspace() throws {
        let container = try makeInMemoryModelContainer()
        let context = ModelContext(container)
        let otherCanvas = CanvasModel(id: "canvas-other", workspaceId: "workspace-other")
        let requestedCanvas = CanvasModel(id: "canvas-requested", workspaceId: "workspace-requested")
        context.insert(otherCanvas)
        context.insert(requestedCanvas)
        try context.save()

        let canvases = try context.fetch(WorkspaceCanvasLookup.descriptor(for: "workspace-requested"))

        XCTAssertEqual(canvases.map(\.id), ["canvas-requested"])
    }

    func testWorkspaceDetailTabDefaultsToOverviewAndKeepsCanvasExplicit() {
        XCTAssertEqual(WorkspaceDetailTab.defaultTab, .overview)
        XCTAssertEqual(WorkspaceDetailTab.allCases.map(\.title), ["Overview", "Tasks", "Canvas", "Resources", "Snippets"])
        XCTAssertEqual(WorkspaceDetailTab.tabAfterWorkspaceChange(from: .canvas), .overview)
        XCTAssertFalse(WorkspaceDetailTab.overview.activatesCanvas)
        XCTAssertFalse(WorkspaceDetailTab.tasks.activatesCanvas)
        XCTAssertTrue(WorkspaceDetailTab.canvas.activatesCanvas)
    }

    func testWorkspaceTodoBoardPresentationSeparatesCanvasPanelFromFullHeightTab() {
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.usesFixedHeight)
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.showsCollapseControl)
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.usesPanelChrome)

        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.usesFixedHeight)
        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.showsCollapseControl)
        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.usesPanelChrome)
    }

    @MainActor
    private func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            WorkspaceTodoModel.self,
            WorkspaceTodoGroupModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func expectedResourceRemovalMessage(displayName: String, cleanup: CleanupPlan) -> String {
        """
        This removes \(displayName) from MindDesk metadata only.

        Canvas cards removed: \(cleanup.canvasNodeIdsToDelete.count)
        Canvas links removed: \(cleanup.canvasEdgeIdsToDelete.count)
        Todo linked resources cleared: \(cleanup.todoIdsClearingLinkedResource.count)
        Command working directories cleared: \(cleanup.snippetIdsClearingWorkingDirectory.count)
        Alias records marked missing: \(cleanup.aliasIdsMarkingMissing.count)
        Finder items affected: 0
        """
    }
}
