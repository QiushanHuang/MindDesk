import XCTest
import MindDeskCore
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
        XCTAssertEqual(brief.unresolvedReferenceCount, 1)
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
}
