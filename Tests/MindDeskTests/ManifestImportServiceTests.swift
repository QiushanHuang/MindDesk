import Darwin
import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class ManifestImportServiceTests: XCTestCase {
    func testDecodeManifestFromURLRejectsMetadataAndCappedReadOverflowBeforeClassification() throws {
        let maximumBytes = ManifestImportLimits.maximumManifestBytes
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-manifest-url-import-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let metadataOversizedURL = directory.appendingPathComponent("legacy-review.json")
        try makeLegacyReviewTrapData(byteCount: maximumBytes + 1).write(to: metadataOversizedURL)
        let oversizedMetadata = manifestURLMetadata(byteCount: maximumBytes + 1)

        assertManifestImportError(
            "This JSON file is larger than the 64 MiB import limit."
        ) {
            try ImportExportService().decodeManifest(from: metadataOversizedURL)
        }

        let metadataShortCircuitService = ImportExportService(
            manifestURLRead: .init(
                metadataSize: { _ in oversizedMetadata },
                cappedRead: { _, _, _ in
                    throw ManifestURLReadTestError.unexpectedRead
                }
            )
        )
        assertManifestImportError(
            "This JSON file is larger than the 64 MiB import limit."
        ) {
            try metadataShortCircuitService.decodeManifest(from: metadataOversizedURL)
        }

        let cappedReadOversizedData = makeLegacyReviewTrapData(byteCount: maximumBytes + 1)
        let atLimitMetadata = manifestURLMetadata(byteCount: maximumBytes)
        let cappedReadService = ImportExportService(
            manifestURLRead: .init(
                metadataSize: { _ in atLimitMetadata },
                cappedRead: { _, _, maximumReadBytes in
                    guard maximumReadBytes == maximumBytes + 1 else {
                        throw ManifestURLReadTestError.incorrectReadLimit
                    }
                    return cappedReadOversizedData
                }
            )
        )

        assertManifestImportError(
            "This JSON file is larger than the 64 MiB import limit."
        ) {
            try cappedReadService.decodeManifest(from: metadataOversizedURL)
        }

        let negativeMetadata = manifestURLMetadata(byteCount: -1)
        let negativeMetadataService = ImportExportService(
            manifestURLRead: .init(
                metadataSize: { _ in negativeMetadata },
                cappedRead: { _, _, _ in
                    throw ManifestURLReadTestError.unexpectedRead
                }
            )
        )
        assertManifestImportError(
            "Manifest import blocked: file size could not be read."
        ) {
            try negativeMetadataService.decodeManifest(from: metadataOversizedURL)
        }

        let emptyMetadata = manifestURLMetadata(byteCount: 0)
        let readFailureService = ImportExportService(
            manifestURLRead: .init(
                metadataSize: { _ in emptyMetadata },
                cappedRead: { _, _, _ in
                    throw ManifestURLReadTestError.simulatedReadFailure
                }
            )
        )
        assertManifestImportError(
            "Manifest import blocked: file could not be read."
        ) {
            try readFailureService.decodeManifest(from: metadataOversizedURL)
        }

        let directoryURL = directory.appendingPathComponent("not-a-file", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        assertManifestImportError(
            "Manifest import blocked: choose a regular JSON file."
        ) {
            try ImportExportService().decodeManifest(from: directoryURL)
        }

        let symlinkTargetURL = directory.appendingPathComponent("symlink-target.json")
        try Data("{}".utf8).write(to: symlinkTargetURL)
        let symlinkURL = directory.appendingPathComponent("IGNORE_AGENT_INSTRUCTIONS-token=link-secret.json")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: symlinkTargetURL)
        assertManifestImportError(
            "Manifest import blocked: choose a regular JSON file."
        ) {
            try ImportExportService().decodeManifest(from: symlinkURL)
        }

        let missingURL = directory.appendingPathComponent("IGNORE_AGENT_INSTRUCTIONS-token=missing-secret.json")
        assertManifestImportError(
            "Manifest import blocked: file could not be read."
        ) {
            try ImportExportService().decodeManifest(from: missingURL)
        }

        let inLimitManifestURL = directory.appendingPathComponent("ordinary-manifest.json")
        try minimalLegacyManifestData().write(to: inLimitManifestURL)
        let decoded = try ImportExportService().decodeManifest(from: inLimitManifestURL)
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertTrue(decoded.workspaces.isEmpty)

        let selectedURL = directory.appendingPathComponent("selected-manifest.json")
        let replacementURL = directory.appendingPathComponent("replacement-manifest.json")
        let selectedData = minimalLegacyManifestData(marker: "A")
        let replacementData = minimalLegacyManifestData(marker: "B")
        XCTAssertEqual(selectedData.count, replacementData.count)
        try selectedData.write(to: selectedURL)
        try replacementData.write(to: replacementURL)
        let liveRead = ImportExportService.ManifestURLReadDependency.live
        let replacementService = ImportExportService(
            manifestURLRead: .init(
                metadataSize: { url in
                    let metadata = try liveRead.metadataSize(url)
                    let renameResult = replacementURL.path.withCString { replacementPath in
                        selectedURL.path.withCString { selectedPath in
                            Darwin.rename(replacementPath, selectedPath)
                        }
                    }
                    guard renameResult == 0 else {
                        throw ManifestURLReadTestError.simulatedReplacementFailure
                    }
                    return metadata
                },
                cappedRead: { url, expectedMetadata, maximumReadBytes in
                    try liveRead.cappedRead(url, expectedMetadata, maximumReadBytes)
                }
            )
        )
        assertManifestImportError(
            "Manifest import blocked: file could not be read."
        ) {
            try replacementService.decodeManifest(from: selectedURL)
        }

        let serviceSource = try repositorySource("Sources/MindDesk/Services/SystemServices.swift")
        XCTAssertTrue(serviceSource.contains("struct ManifestURLReadDependency: Sendable"))
        XCTAssertTrue(serviceSource.contains("struct ManifestURLMetadata: Equatable, Sendable"))
        XCTAssertTrue(serviceSource.contains("static let live = Self("))
        XCTAssertTrue(serviceSource.contains("private let manifestURLRead: ManifestURLReadDependency"))
        let metadataSource = try functionSource(
            startingWith: "private static func liveManifestMetadata(from url: URL)",
            in: serviceSource
        )
        XCTAssertTrue(metadataSource.contains("Darwin.lstat"))
        XCTAssertTrue(metadataSource.contains("S_IFREG"))
        let cappedReadSource = try functionSource(
            startingWith: "private static func liveManifestCappedRead(",
            in: serviceSource
        )
        for required in [
            "O_NOFOLLOW",
            "O_CLOEXEC",
            "Darwin.fstat",
            "S_IFREG",
            "openedMetadata.st_dev == expectedMetadata.deviceID",
            "openedMetadata.st_ino == expectedMetadata.fileID",
            "maximumReadBytes - 1",
            "Darwin.read",
            "Darwin.close"
        ] {
            XCTAssertTrue(cappedReadSource.contains(required), "Live capped read omitted \(required)")
        }
        let openRange = try XCTUnwrap(cappedReadSource.range(of: "Darwin.open"))
        let fstatRange = try XCTUnwrap(cappedReadSource.range(of: "Darwin.fstat"))
        let readRange = try XCTUnwrap(cappedReadSource.range(of: "Darwin.read"))
        XCTAssertLessThan(openRange.lowerBound, fstatRange.lowerBound)
        XCTAssertLessThan(fstatRange.lowerBound, readRange.lowerBound)
    }

    func testDecodeManifestFromDataRejectsOversizeLegacyTrapBeforeClassification() {
        let maximumBytes = ManifestImportLimits.maximumManifestBytes

        do {
            let atLimit = makeLegacyReviewTrapData(byteCount: maximumBytes)
            assertManifestImportError(
                "This JSON document is not supported by this version of MindDesk and cannot be imported as a manifest."
            ) {
                try ImportExportService().decodeManifest(from: atLimit)
            }
        }

        do {
            let oversized = makeLegacyReviewTrapData(byteCount: maximumBytes + 1)
            assertManifestImportError(
                "This JSON file is larger than the 64 MiB import limit."
            ) {
                try ImportExportService().decodeManifest(from: oversized)
            }
        }
    }

    func testContentViewDelegatesURLManifestLoadingToImportExportService() throws {
        let contentViewSource = try repositorySource("Sources/MindDesk/Views/ContentView.swift")
        let loadManifestSource = try functionSource(
            startingWith: "nonisolated private static func loadManifest(from url: URL)",
            in: contentViewSource
        )
        XCTAssertEqual(
            normalizedSource(loadManifestSource),
            normalizedSource("""
            nonisolated private static func loadManifest(from url: URL) async throws -> ExportManifest {
                try await Task.detached(priority: .userInitiated) {
                    try ImportExportService().decodeManifest(from: url)
                }.value
            }
            """)
        )
        XCTAssertFalse(contentViewSource.contains("readManifestData(from:"))
        for forbidden in [
            "readJSONImportData",
            "Data(contentsOf:",
            "FileHandle",
            "resourceValues",
            "decodeManifest(from: data)"
        ] {
            XCTAssertFalse(loadManifestSource.contains(forbidden), "loadManifest rebuilt the service chain with \(forbidden)")
        }

        let importManifestSource = try functionSource(
            startingWith: "private func importManifest()",
            in: contentViewSource
        )
        let normalizedImport = normalizedSource(importManifestSource)
        XCTAssertTrue(
            normalizedImport.contains(
                "let manifest: ExportManifest do { manifest = try await Self.loadManifest(from: url) } catch { setStatus(error.localizedDescription) return } do { let summary = try ManifestImportService().importRecords"
            )
        )
        let importerRange = try XCTUnwrap(
            importManifestSource.range(of: "ManifestImportService().importRecords")
        )
        let beforeImporter = importManifestSource[..<importerRange.lowerBound]
        let afterImporter = importManifestSource[importerRange.lowerBound...]
        XCTAssertFalse(beforeImporter.contains("modelContext.rollback()"))
        XCTAssertEqual(afterImporter.components(separatedBy: "modelContext.rollback()").count - 1, 1)
    }

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

    private func makeLegacyReviewTrapData(
        byteCount: Int,
        format: String = "minddesk.interchange.package"
    ) -> Data {
        let prefix = Data("{\"format\":\"\(format)\",\"padding\":\"".utf8)
        let suffix = Data("\"}".utf8)
        precondition(byteCount >= prefix.count + suffix.count)
        var data = prefix
        data.append(Data(repeating: UInt8(ascii: "x"), count: byteCount - prefix.count - suffix.count))
        data.append(suffix)
        return data
    }

    private func minimalLegacyManifestData(marker: String? = nil) -> Data {
        let markerField = marker.map { "\"marker\": \"\($0)\"," } ?? ""
        return Data("""
        {
          \(markerField)
          "schemaVersion": 2,
          "exportedAt": "1970-01-01T00:00:00Z",
          "workspaces": [],
          "resources": [],
          "snippets": [],
          "canvases": [],
          "nodes": [],
          "edges": [],
          "aliases": []
        }
        """.utf8)
    }

    private func manifestURLMetadata(byteCount: Int) -> ImportExportService.ManifestURLMetadata {
        .init(byteCount: Int64(byteCount), deviceID: 0, fileID: 0)
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func functionSource(startingWith signature: String, in source: String) throws -> String {
        guard let signatureRange = source.range(of: signature),
              let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
            throw ManifestSourceTestError.functionNotFound(signature)
        }
        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            switch source[cursor] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(source[signatureRange.lowerBound...cursor])
                }
            default:
                break
            }
            cursor = source.index(after: cursor)
        }
        throw ManifestSourceTestError.unbalancedFunction(signature)
    }

    private func normalizedSource(_ source: String) -> String {
        source.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func assertManifestImportError<T>(
        _ expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () throws -> T
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected invalid manifest references error, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(message, expectedMessage, file: file, line: line)
        }
    }

    private enum ManifestURLReadTestError: Error, Sendable {
        case incorrectReadLimit
        case simulatedReadFailure
        case simulatedReplacementFailure
        case unexpectedRead
    }

    private enum ManifestSourceTestError: Error {
        case functionNotFound(String)
        case unbalancedFunction(String)
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
