import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class ManifestImportServiceTests: XCTestCase {
    func testManifestImportServiceImportsCompleteManifestAndRewritesReferences() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let manifest = makeCompleteManifest()

        let summary = try ManifestImportService().importRecords(from: manifest, into: context)

        XCTAssertEqual(summary.workspaces, 1)
        XCTAssertEqual(summary.resources, 1)
        XCTAssertEqual(summary.snippets, 1)
        XCTAssertEqual(summary.canvases, 1)
        XCTAssertEqual(summary.nodes, 2)
        XCTAssertEqual(summary.edges, 1)
        XCTAssertEqual(summary.aliases, 1)
        XCTAssertEqual(summary.todoGroups, 1)
        XCTAssertEqual(summary.todos, 1)
        XCTAssertEqual(
            summary.statusText,
            "1 workspace, 1 resource, 1 snippet, 1 canvas, 2 cards, 1 link, 1 alias, 1 task group, 1 task"
        )

        let workspace = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkspaceModel>()).first)
        XCTAssertEqual(workspace.title, "Imported Workspace")
        XCTAssertEqual(workspace.schemaVersion, 2)
        XCTAssertNotEqual(workspace.id, "workspace-source")

        let resource = try XCTUnwrap(try context.fetch(FetchDescriptor<ResourcePinModel>()).first)
        XCTAssertEqual(resource.workspaceId, workspace.id)
        XCTAssertEqual(resource.title, "Resource")
        XCTAssertEqual(resource.status, .unavailable)
        XCTAssertNil(resource.securityScopedBookmarkData)
        XCTAssertNotEqual(resource.id, "resource-source")

        let snippet = try XCTUnwrap(try context.fetch(FetchDescriptor<SnippetModel>()).first)
        XCTAssertEqual(snippet.workspaceId, workspace.id)
        XCTAssertEqual(snippet.kind, .command)
        XCTAssertEqual(snippet.workingDirectoryRef, resource.id)
        XCTAssertTrue(snippet.requiresConfirmation)
        XCTAssertNotEqual(snippet.id, "snippet-source")

        let canvas = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasModel>()).first)
        XCTAssertEqual(canvas.workspaceId, workspace.id)
        XCTAssertNotEqual(canvas.id, "canvas-source")

        let nodes = try context.fetch(FetchDescriptor<CanvasNodeModel>())
        XCTAssertEqual(nodes.count, 2)
        let frame = try XCTUnwrap(nodes.first { $0.title == "Frame" })
        let resourceNode = try XCTUnwrap(nodes.first { $0.title == "Resource Card" })
        XCTAssertNotEqual(frame.id, "frame-source")
        XCTAssertNotEqual(resourceNode.id, "resource-node-source")
        XCTAssertEqual(resourceNode.canvasId, canvas.id)
        XCTAssertEqual(resourceNode.objectId, resource.id)
        XCTAssertEqual(resourceNode.parentNodeId, frame.id)

        let edge = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasEdgeModel>()).first)
        XCTAssertNotEqual(edge.id, "edge-source")
        XCTAssertEqual(edge.canvasId, canvas.id)
        XCTAssertEqual(edge.sourceNodeId, frame.id)
        XCTAssertEqual(edge.targetNodeId, resourceNode.id)

        let alias = try XCTUnwrap(try context.fetch(FetchDescriptor<FinderAliasRecordModel>()).first)
        XCTAssertNotEqual(alias.id, "alias-source")
        XCTAssertEqual(alias.sourceObjectType, "resourcePin")
        XCTAssertEqual(alias.sourceObjectId, resource.id)
        XCTAssertEqual(alias.status, .missing)

        let todoGroup = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkspaceTodoGroupModel>()).first)
        XCTAssertNotEqual(todoGroup.id, "todo-group-source")
        XCTAssertEqual(todoGroup.workspaceId, workspace.id)

        let todo = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkspaceTodoModel>()).first)
        XCTAssertNotEqual(todo.id, "todo-source")
        XCTAssertEqual(todo.workspaceId, workspace.id)
        XCTAssertEqual(todo.groupId, todoGroup.id)
        XCTAssertEqual(todo.linkedResourceId, resource.id)
        XCTAssertEqual(todo.details, "Imported details")
        XCTAssertTrue(todo.isCompleted)
        XCTAssertEqual(todo.completedAt, Date(timeIntervalSince1970: 171))
        XCTAssertEqual(todo.dueAt, Date(timeIntervalSince1970: 181))
    }

    func testManifestImportServiceImportsLegacyV1ManifestWithoutTodoCollectionsAsEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let data = Data("""
        {
          "schemaVersion": 1,
          "exportedAt": "1970-01-01T00:00:00Z",
          "workspaces": [
            {
              "id": "workspace-source",
              "title": "Legacy Workspace",
              "details": "",
              "createdAt": "1970-01-01T00:00:00Z",
              "updatedAt": "1970-01-01T00:00:00Z",
              "lastOpenedAt": null
            }
          ],
          "resources": [],
          "snippets": [],
          "canvases": [],
          "nodes": [],
          "edges": [],
          "aliases": []
        }
        """.utf8)

        let manifest = try ImportExportService().decodeManifest(from: data)
        let summary = try ManifestImportService().importRecords(from: manifest, into: context)

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertTrue(manifest.todoGroups.isEmpty)
        XCTAssertTrue(manifest.todos.isEmpty)
        XCTAssertEqual(summary.workspaces, 1)
        XCTAssertEqual(summary.todoGroups, 0)
        XCTAssertEqual(summary.todos, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceModel>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceTodoGroupModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceTodoModel>()), 0)
    }

    func testExportedManifestJSONCanBeDecodedAndImportedIntoEmptyStore() throws {
        let destinationContainer = try makeInMemoryContainer()
        let destinationContext = ModelContext(destinationContainer)
        let now = Date(timeIntervalSince1970: 500)
        let workspace = WorkspaceModel(
            id: "workspace-source",
            title: "Round Trip Workspace",
            details: "Workspace details",
            createdAt: now,
            updatedAt: now.addingTimeInterval(1),
            lastOpenedAt: now.addingTimeInterval(2),
            isPinned: true,
            sortIndex: 3,
            schemaVersion: 2
        )
        let resource = ResourcePinModel(
            id: "resource-source",
            workspaceId: workspace.id,
            title: "Round Trip Resource",
            targetType: .folder,
            displayPath: "/tmp/round-trip",
            lastResolvedPath: "/tmp/round-trip",
            note: "Resource note",
            tags: ["alpha", "beta"],
            scope: .workspace,
            sortIndex: 4,
            isPinned: true,
            originalName: "round-trip",
            customName: "Custom",
            searchText: "round trip",
            status: .available,
            createdAt: now.addingTimeInterval(3),
            updatedAt: now.addingTimeInterval(4),
            lastOpenedAt: now.addingTimeInterval(5)
        )
        let snippet = SnippetModel(
            id: "snippet-source",
            workspaceId: workspace.id,
            title: "Round Trip Command",
            kind: .command,
            body: "pwd",
            details: "Command details",
            tags: ["shell"],
            scope: .workspace,
            workingDirectoryRef: resource.id,
            requiresConfirmation: false,
            lastCopiedAt: now.addingTimeInterval(6),
            lastUsedAt: now.addingTimeInterval(7),
            createdAt: now.addingTimeInterval(8),
            updatedAt: now.addingTimeInterval(9)
        )
        let canvas = CanvasModel(
            id: "canvas-source",
            workspaceId: workspace.id,
            title: "Round Trip Canvas",
            viewportX: 12,
            viewportY: 34,
            zoom: 1.2,
            linkAnimationThemeRaw: "blue",
            animationsEnabled: true,
            createdAt: now.addingTimeInterval(10),
            updatedAt: now.addingTimeInterval(11)
        )
        let frame = CanvasNodeModel(
            id: "frame-source",
            canvasId: canvas.id,
            title: "Frame",
            nodeType: .groupFrame,
            x: 0,
            y: 0,
            width: 320,
            height: 240,
            zIndex: 1,
            createdAt: now.addingTimeInterval(12),
            updatedAt: now.addingTimeInterval(13)
        )
        let resourceNode = CanvasNodeModel(
            id: "resource-node-source",
            canvasId: canvas.id,
            title: "Resource Card",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: resource.id,
            x: 20,
            y: 30,
            width: 180,
            height: 120,
            parentNodeId: frame.id,
            zIndex: 2,
            createdAt: now.addingTimeInterval(14),
            updatedAt: now.addingTimeInterval(15)
        )
        let edge = CanvasEdgeModel(
            id: "edge-source",
            canvasId: canvas.id,
            sourceNodeId: frame.id,
            targetNodeId: resourceNode.id,
            label: "depends on",
            controlPointX: 100,
            controlPointY: 120,
            createdAt: now.addingTimeInterval(16),
            updatedAt: now.addingTimeInterval(17)
        )
        let alias = FinderAliasRecordModel(
            id: "alias-source",
            sourceObjectType: "resourcePin",
            sourceObjectId: resource.id,
            aliasDisplayPath: "/tmp/round-trip.alias",
            status: .created,
            createdAt: now.addingTimeInterval(18)
        )
        let todoGroup = WorkspaceTodoGroupModel(
            id: "todo-group-source",
            workspaceId: workspace.id,
            title: "Round Trip Tasks",
            isPinned: true,
            sortIndex: 1,
            createdAt: now.addingTimeInterval(19),
            updatedAt: now.addingTimeInterval(20)
        )
        let todo = WorkspaceTodoModel(
            id: "todo-source",
            workspaceId: workspace.id,
            groupId: todoGroup.id,
            title: "Round Trip Task",
            details: "Task details",
            isCompleted: true,
            isPinned: true,
            sortIndex: 2,
            createdAt: now.addingTimeInterval(21),
            updatedAt: now.addingTimeInterval(22),
            completedAt: now.addingTimeInterval(23),
            dueAt: now.addingTimeInterval(24),
            linkedResourceId: resource.id
        )
        let service = ImportExportService()
        let exportedManifest = service.makeManifest(
            workspaces: [workspace],
            resources: [resource],
            snippets: [snippet],
            canvases: [canvas],
            nodes: [frame, resourceNode],
            edges: [edge],
            aliases: [alias],
            todoGroups: [todoGroup],
            todos: [todo]
        )

        let data = try JSONEncoder.minddesk.encode(exportedManifest)
        let decodedManifest = try service.decodeManifest(from: data)
        let summary = try ManifestImportService().importRecords(from: decodedManifest, into: destinationContext)

        XCTAssertEqual(summary.statusText, "1 workspace, 1 resource, 1 snippet, 1 canvas, 2 cards, 1 link, 1 alias, 1 task group, 1 task")
        let importedWorkspace = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<WorkspaceModel>()).first)
        let importedResource = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<ResourcePinModel>()).first)
        let importedSnippet = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<SnippetModel>()).first)
        let importedCanvas = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<CanvasModel>()).first)
        let importedNodes = try destinationContext.fetch(FetchDescriptor<CanvasNodeModel>())
        let importedFrame = try XCTUnwrap(importedNodes.first { $0.title == "Frame" })
        let importedResourceNode = try XCTUnwrap(importedNodes.first { $0.title == "Resource Card" })
        let importedEdge = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<CanvasEdgeModel>()).first)
        let importedAlias = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<FinderAliasRecordModel>()).first)
        let importedTodoGroup = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<WorkspaceTodoGroupModel>()).first)
        let importedTodo = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<WorkspaceTodoModel>()).first)

        XCTAssertNotEqual(importedWorkspace.id, workspace.id)
        XCTAssertNotEqual(importedResource.id, resource.id)
        XCTAssertNotEqual(importedSnippet.id, snippet.id)
        XCTAssertNotEqual(importedCanvas.id, canvas.id)
        XCTAssertEqual(importedWorkspace.title, workspace.title)
        XCTAssertEqual(importedResource.workspaceId, importedWorkspace.id)
        XCTAssertEqual(importedSnippet.workspaceId, importedWorkspace.id)
        XCTAssertEqual(importedSnippet.workingDirectoryRef, importedResource.id)
        XCTAssertEqual(importedCanvas.workspaceId, importedWorkspace.id)
        XCTAssertEqual(importedResourceNode.canvasId, importedCanvas.id)
        XCTAssertEqual(importedResourceNode.objectId, importedResource.id)
        XCTAssertEqual(importedResourceNode.parentNodeId, importedFrame.id)
        XCTAssertEqual(importedEdge.canvasId, importedCanvas.id)
        XCTAssertEqual(importedEdge.sourceNodeId, importedFrame.id)
        XCTAssertEqual(importedEdge.targetNodeId, importedResourceNode.id)
        XCTAssertEqual(importedAlias.sourceObjectId, importedResource.id)
        XCTAssertEqual(importedTodoGroup.workspaceId, importedWorkspace.id)
        XCTAssertEqual(importedTodo.workspaceId, importedWorkspace.id)
        XCTAssertEqual(importedTodo.groupId, importedTodoGroup.id)
        XCTAssertEqual(importedTodo.linkedResourceId, importedResource.id)
        XCTAssertEqual(importedTodo.details, todo.details)
        XCTAssertTrue(importedTodo.isCompleted)
    }

    func testManifestImportServiceRejectsInvalidManifestBeforeInsertingRecords() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 1),
            workspaces: [
                WorkspaceRecord(
                    id: "duplicate",
                    title: "One",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 1),
                    updatedAt: Date(timeIntervalSince1970: 1),
                    lastOpenedAt: nil
                ),
                WorkspaceRecord(
                    id: "duplicate",
                    title: "Two",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 1),
                    updatedAt: Date(timeIntervalSince1970: 1),
                    lastOpenedAt: nil
                )
            ],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        XCTAssertThrowsError(
            try ManifestImportService().importRecords(from: manifest, into: context)
        ) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected invalid manifest references error, got \(error)")
            }
            XCTAssertTrue(message.contains("Manifest import blocked"))
            XCTAssertTrue(message.contains("manifest.id.duplicate"))
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResourcePinModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasModel>()), 0)
    }

    func testManifestImportServiceBlocksCrossWorkspacePrivateCanvasReferencesBeforeInsertingRecords() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let manifest = makeCrossWorkspacePrivateCanvasReferenceManifest()

        XCTAssertThrowsError(
            try ManifestImportService().importRecords(from: manifest, into: context)
        ) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected invalid manifest references error, got \(error)")
            }
            XCTAssertTrue(message.contains("Manifest import blocked: 2 validation issues."))
            XCTAssertTrue(message.contains("manifest.reference.cross-workspace"))
            XCTAssertTrue(message.contains("/manifest/nodes/0/objectId"))
            XCTAssertTrue(message.contains("/manifest/nodes/1/objectId"))
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResourcePinModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SnippetModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasNodeModel>()), 0)
    }

    func testManifestImportServiceAllowsGlobalResourcesAndSnippetsOnWorkspaceCanvas() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let manifest = makeGlobalCanvasReferenceManifest()

        let summary = try ManifestImportService().importRecords(from: manifest, into: context)

        XCTAssertEqual(summary.workspaces, 1)
        XCTAssertEqual(summary.resources, 1)
        XCTAssertEqual(summary.snippets, 1)
        XCTAssertEqual(summary.canvases, 1)
        XCTAssertEqual(summary.nodes, 2)

        let importedResource = try XCTUnwrap(try context.fetch(FetchDescriptor<ResourcePinModel>()).first)
        let importedSnippet = try XCTUnwrap(try context.fetch(FetchDescriptor<SnippetModel>()).first)
        let importedNodes = try context.fetch(FetchDescriptor<CanvasNodeModel>())
        let resourceNode = try XCTUnwrap(importedNodes.first { $0.title == "Global Resource" })
        let snippetNode = try XCTUnwrap(importedNodes.first { $0.title == "Global Snippet" })

        XCTAssertNil(importedResource.workspaceId)
        XCTAssertEqual(importedResource.scope, .global)
        XCTAssertNil(importedSnippet.workspaceId)
        XCTAssertEqual(importedSnippet.scope, .global)
        XCTAssertEqual(resourceNode.objectId, importedResource.id)
        XCTAssertEqual(snippetNode.objectId, importedSnippet.id)
    }

    func testAgentReviewPackageCannotImportAsManifestOrCreateRecords() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let package = MindDeskInterchangePackage(
            manifest: makeCompleteManifest(),
            createdAt: Date(timeIntervalSince1970: 300)
        )
        let packageData = try JSONEncoder.minddesk.encode(package)

        XCTAssertThrowsError(
            try ImportExportService().decodeManifest(from: packageData)
        ) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected read-only MIP manifest import rejection, got \(error)")
            }
            XCTAssertEqual(
                message,
                "MindDesk interchange packages are read-only review files and cannot be imported as manifests."
            )
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResourcePinModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SnippetModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasNodeModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CanvasEdgeModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FinderAliasRecordModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceTodoGroupModel>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkspaceTodoModel>()), 0)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
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

    private func makeCompleteManifest() -> ExportManifest {
        ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 1),
            workspaces: [
                WorkspaceRecord(
                    id: "workspace-source",
                    title: "Imported Workspace",
                    details: "Workspace details",
                    createdAt: Date(timeIntervalSince1970: 10),
                    updatedAt: Date(timeIntervalSince1970: 20),
                    lastOpenedAt: Date(timeIntervalSince1970: 30),
                    isPinned: true,
                    sortIndex: 4
                )
            ],
            resources: [
                ResourceRecord(
                    id: "resource-source",
                    workspaceId: "workspace-source",
                    title: "Resource",
                    targetType: "folder",
                    displayPath: "/tmp/resource",
                    lastResolvedPath: "/tmp/resource",
                    note: "Resource note",
                    tags: ["alpha"],
                    scope: "workspace",
                    sortIndex: 2,
                    isPinned: true,
                    originalName: "resource",
                    customName: "Custom Resource",
                    searchText: "resource",
                    status: "available",
                    createdAt: Date(timeIntervalSince1970: 40),
                    updatedAt: Date(timeIntervalSince1970: 50),
                    lastOpenedAt: Date(timeIntervalSince1970: 60)
                )
            ],
            snippets: [
                SnippetRecord(
                    id: "snippet-source",
                    workspaceId: "workspace-source",
                    title: "Command",
                    kind: "command",
                    body: "pwd",
                    details: "Command details",
                    tags: ["shell"],
                    scope: "workspace",
                    workingDirectoryRef: "resource-source",
                    requiresConfirmation: false
                )
            ],
            canvases: [
                CanvasRecord(
                    id: "canvas-source",
                    workspaceId: "workspace-source",
                    title: "Canvas",
                    viewportX: 10,
                    viewportY: 20,
                    zoom: 1.25
                )
            ],
            nodes: [
                CanvasNodeRecord(
                    id: "frame-source",
                    canvasId: "canvas-source",
                    title: "Frame",
                    body: "",
                    nodeType: "groupFrame",
                    objectType: nil,
                    objectId: nil,
                    x: 0,
                    y: 0,
                    width: 300,
                    height: 240
                ),
                CanvasNodeRecord(
                    id: "resource-node-source",
                    canvasId: "canvas-source",
                    title: "Resource Card",
                    body: "",
                    nodeType: "resource",
                    objectType: "resourcePin",
                    objectId: "resource-source",
                    x: 40,
                    y: 40,
                    width: 180,
                    height: 120,
                    parentNodeId: "frame-source"
                )
            ],
            edges: [
                CanvasEdgeRecord(
                    id: "edge-source",
                    canvasId: "canvas-source",
                    sourceNodeId: "frame-source",
                    targetNodeId: "resource-node-source",
                    label: "Link"
                )
            ],
            aliases: [
                AliasRecord(
                    id: "alias-source",
                    sourceObjectType: "resourcePin",
                    sourceObjectId: "resource-source",
                    aliasDisplayPath: "/tmp/resource.alias",
                    status: "missing"
                )
            ],
            todoGroups: [
                TodoGroupRecord(
                    id: "todo-group-source",
                    workspaceId: "workspace-source",
                    title: "Group"
                )
            ],
            todos: [
                TodoRecord(
                    id: "todo-source",
                    workspaceId: "workspace-source",
                    groupId: "todo-group-source",
                    title: "Task",
                    details: "Imported details",
                    isCompleted: true,
                    completedAt: Date(timeIntervalSince1970: 171),
                    dueAt: Date(timeIntervalSince1970: 181),
                    linkedResourceId: "resource-source"
                )
            ]
        )
    }

    private func makeCrossWorkspacePrivateCanvasReferenceManifest() -> ExportManifest {
        ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 1),
            workspaces: [
                WorkspaceRecord(
                    id: "workspace-a",
                    title: "Workspace A",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 1),
                    updatedAt: Date(timeIntervalSince1970: 1),
                    lastOpenedAt: nil
                ),
                WorkspaceRecord(
                    id: "workspace-b",
                    title: "Workspace B",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 1),
                    updatedAt: Date(timeIntervalSince1970: 1),
                    lastOpenedAt: nil
                )
            ],
            resources: [
                ResourceRecord(
                    id: "private-resource-b",
                    workspaceId: "workspace-b",
                    title: "Private Resource B",
                    targetType: "folder",
                    displayPath: "/tmp/private-resource-b",
                    lastResolvedPath: "/tmp/private-resource-b",
                    note: "",
                    tags: [],
                    scope: "workspace",
                    status: "available"
                )
            ],
            snippets: [
                SnippetRecord(
                    id: "private-snippet-b",
                    workspaceId: "workspace-b",
                    title: "Private Snippet B",
                    kind: "prompt",
                    body: "Summarize",
                    details: "",
                    tags: [],
                    scope: "workspace",
                    workingDirectoryRef: nil,
                    requiresConfirmation: false
                )
            ],
            canvases: [
                CanvasRecord(id: "canvas-a", workspaceId: "workspace-a", title: "Canvas A")
            ],
            nodes: [
                CanvasNodeRecord(
                    id: "cross-resource-node",
                    canvasId: "canvas-a",
                    title: "Cross Resource",
                    body: "",
                    nodeType: "resource",
                    objectType: "resourcePin",
                    objectId: "private-resource-b",
                    x: 0,
                    y: 0,
                    width: 180,
                    height: 120
                ),
                CanvasNodeRecord(
                    id: "cross-snippet-node",
                    canvasId: "canvas-a",
                    title: "Cross Snippet",
                    body: "",
                    nodeType: "snippet",
                    objectType: "snippet",
                    objectId: "private-snippet-b",
                    x: 220,
                    y: 0,
                    width: 180,
                    height: 120
                )
            ],
            edges: [],
            aliases: []
        )
    }

    private func makeGlobalCanvasReferenceManifest() -> ExportManifest {
        ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 1),
            workspaces: [
                WorkspaceRecord(
                    id: "workspace-a",
                    title: "Workspace A",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 1),
                    updatedAt: Date(timeIntervalSince1970: 1),
                    lastOpenedAt: nil
                )
            ],
            resources: [
                ResourceRecord(
                    id: "global-resource",
                    workspaceId: nil,
                    title: "Global Resource",
                    targetType: "folder",
                    displayPath: "/tmp/global-resource",
                    lastResolvedPath: "/tmp/global-resource",
                    note: "",
                    tags: [],
                    scope: "global",
                    status: "available"
                )
            ],
            snippets: [
                SnippetRecord(
                    id: "global-snippet",
                    workspaceId: nil,
                    title: "Global Snippet",
                    kind: "prompt",
                    body: "Summarize",
                    details: "",
                    tags: [],
                    scope: "global",
                    workingDirectoryRef: nil,
                    requiresConfirmation: false
                )
            ],
            canvases: [
                CanvasRecord(id: "canvas-a", workspaceId: "workspace-a", title: "Canvas A")
            ],
            nodes: [
                CanvasNodeRecord(
                    id: "global-resource-node",
                    canvasId: "canvas-a",
                    title: "Global Resource",
                    body: "",
                    nodeType: "resource",
                    objectType: "resourcePin",
                    objectId: "global-resource",
                    x: 0,
                    y: 0,
                    width: 180,
                    height: 120
                ),
                CanvasNodeRecord(
                    id: "global-snippet-node",
                    canvasId: "canvas-a",
                    title: "Global Snippet",
                    body: "",
                    nodeType: "snippet",
                    objectType: "snippet",
                    objectId: "global-snippet",
                    x: 220,
                    y: 0,
                    width: 180,
                    height: 120
                )
            ],
            edges: [],
            aliases: []
        )
    }
}
