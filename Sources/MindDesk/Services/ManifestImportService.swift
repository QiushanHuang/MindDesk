import MindDeskCore
import SwiftData

struct ManifestImportSummary {
    var workspaces: Int
    var resources: Int
    var snippets: Int
    var canvases: Int
    var nodes: Int
    var edges: Int
    var aliases: Int
    var todoGroups: Int
    var todos: Int

    var statusText: String {
        let parts = [
            "\(workspaces) workspace\(workspaces == 1 ? "" : "s")",
            "\(resources) resource\(resources == 1 ? "" : "s")",
            "\(snippets) snippet\(snippets == 1 ? "" : "s")",
            "\(canvases) canvas\(canvases == 1 ? "" : "es")",
            "\(nodes) card\(nodes == 1 ? "" : "s")",
            "\(edges) link\(edges == 1 ? "" : "s")",
            "\(aliases) alias\(aliases == 1 ? "" : "es")",
            "\(todoGroups) task group\(todoGroups == 1 ? "" : "s")",
            "\(todos) task\(todos == 1 ? "" : "s")"
        ]
        return parts.joined(separator: ", ")
    }
}

@MainActor
struct ManifestImportService {
    func importRecords(
        from manifest: ExportManifest,
        into modelContext: ModelContext
    ) throws -> ManifestImportSummary {
        if let validationStatus = ImportExportService.manifestImportBlockedStatus(for: manifest) {
            throw WorkbenchError.invalidManifestReferences(validationStatus)
        }

        var workspaceMap: [String: String] = [:]
        var resourceMap: [String: String] = [:]
        var snippetMap: [String: String] = [:]
        var canvasMap: [String: String] = [:]
        var nodeMap: [String: String] = [:]
        var importedNodeParents: [(node: CanvasNodeModel, parentNodeId: String?)] = []
        var importedEdgeCount = 0
        var importedAliasCount = 0
        var importedTodoGroupCount = 0
        var importedTodoCount = 0

        for record in manifest.workspaces {
            let workspace = WorkspaceModel(title: record.title, details: record.details, createdAt: record.createdAt, updatedAt: record.updatedAt, lastOpenedAt: record.lastOpenedAt, isPinned: record.isPinned, sortIndex: record.sortIndex, schemaVersion: manifest.schemaVersion)
            workspaceMap[record.id] = workspace.id
            modelContext.insert(workspace)
        }

        for record in manifest.resources {
            let scope = WorkbenchScope(rawValue: record.scope) ?? .global
            let resource = ResourcePinModel(
                workspaceId: scope == .workspace ? record.workspaceId.flatMap { workspaceMap[$0] } : nil,
                title: record.title,
                targetType: ResourceTargetType(rawValue: record.targetType) ?? .folder,
                displayPath: record.displayPath,
                lastResolvedPath: record.lastResolvedPath,
                note: record.note,
                tags: record.tags,
                scope: scope,
                sortIndex: record.sortIndex,
                isPinned: record.isPinned,
                originalName: record.originalName,
                customName: record.customName,
                searchText: record.searchText,
                status: .unavailable
            )
            resource.createdAt = record.createdAt
            resource.updatedAt = record.updatedAt
            resource.lastOpenedAt = record.lastOpenedAt
            resourceMap[record.id] = resource.id
            modelContext.insert(resource)
        }

        for record in manifest.snippets {
            let scope = WorkbenchScope(rawValue: record.scope) ?? .global
            let snippet = SnippetModel(
                workspaceId: scope == .workspace ? record.workspaceId.flatMap { workspaceMap[$0] } : nil,
                title: record.title,
                kind: SnippetKind(rawValue: record.kind) ?? .prompt,
                body: record.body,
                details: record.details,
                tags: record.tags,
                scope: scope,
                workingDirectoryRef: record.workingDirectoryRef.flatMap { resourceMap[$0] },
                requiresConfirmation: SnippetImportTrustPolicy.requiresConfirmation(
                    kind: record.kind,
                    exportedRequiresConfirmation: record.requiresConfirmation
                ),
                lastCopiedAt: record.lastCopiedAt,
                lastUsedAt: record.lastUsedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            snippetMap[record.id] = snippet.id
            modelContext.insert(snippet)
        }

        for record in manifest.canvases {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let canvas = CanvasModel(workspaceId: workspaceId, title: record.title, viewportX: record.viewportX, viewportY: record.viewportY, zoom: record.zoom, linkAnimationThemeRaw: record.linkAnimationTheme, animationsEnabled: record.animationsEnabled, createdAt: record.createdAt, updatedAt: record.updatedAt)
            canvasMap[record.id] = canvas.id
            modelContext.insert(canvas)
        }

        for record in manifest.nodes {
            guard let canvasId = canvasMap[record.canvasId] else { continue }
            let mappedObjectId = CanvasNodeObjectReferenceMapper.mappedObjectId(
                objectType: record.objectType,
                objectId: record.objectId,
                body: record.body,
                resourceMap: resourceMap,
                snippetMap: snippetMap,
                workspaceMap: workspaceMap
            )
            let node = CanvasNodeModel(
                canvasId: canvasId,
                title: record.title,
                body: record.body,
                nodeType: CanvasNodeKind(rawValue: record.nodeType) ?? .note,
                objectType: record.objectType,
                objectId: mappedObjectId,
                x: record.x,
                y: record.y,
                width: record.width,
                height: record.height,
                collapsed: record.collapsed,
                parentNodeId: nil,
                zIndex: record.zIndex,
                locked: record.locked,
                styleRaw: record.style,
                accentColorRaw: record.accentColor,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            nodeMap[record.id] = node.id
            importedNodeParents.append((node: node, parentNodeId: record.parentNodeId))
            modelContext.insert(node)
        }

        for importedNodeParent in importedNodeParents {
            importedNodeParent.node.parentNodeId = CanvasManifestParentMapper.mappedParentNodeId(
                importedNodeParent.parentNodeId,
                nodeMap: nodeMap
            )
        }

        for record in manifest.edges {
            guard let canvasId = canvasMap[record.canvasId],
                  let sourceId = nodeMap[record.sourceNodeId],
                  let targetId = nodeMap[record.targetNodeId] else { continue }
            modelContext.insert(CanvasEdgeModel(canvasId: canvasId, sourceNodeId: sourceId, targetNodeId: targetId, label: record.label, style: record.style, sourceArrowRaw: record.sourceArrow, targetArrowRaw: record.targetArrow, animated: record.animated, animationThemeRaw: record.animationTheme, controlPointX: record.controlPointX, controlPointY: record.controlPointY, createdAt: record.createdAt, updatedAt: record.updatedAt))
            importedEdgeCount += 1
        }

        for record in manifest.aliases {
            let mappedSourceId = AliasImportSourceMapper.mappedSourceObjectId(
                sourceObjectType: record.sourceObjectType,
                sourceObjectId: record.sourceObjectId,
                resourceMap: resourceMap,
                snippetMap: snippetMap
            )
            modelContext.insert(FinderAliasRecordModel(sourceObjectType: record.sourceObjectType, sourceObjectId: mappedSourceId, aliasDisplayPath: record.aliasDisplayPath, status: AliasStatus(rawValue: record.status) ?? .missing, createdAt: record.createdAt))
            importedAliasCount += 1
        }

        var todoGroupMap: [String: String] = [:]
        for record in manifest.todoGroups {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let group = WorkspaceTodoGroupModel(
                workspaceId: workspaceId,
                title: record.title,
                isPinned: record.isPinned,
                sortIndex: record.sortIndex,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            todoGroupMap[record.id] = group.id
            modelContext.insert(group)
            importedTodoGroupCount += 1
        }

        for record in manifest.todos {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let todo = WorkspaceTodoModel(
                workspaceId: workspaceId,
                groupId: record.groupId.flatMap { todoGroupMap[$0] },
                title: record.title,
                details: record.details,
                isCompleted: record.isCompleted,
                isPinned: record.isPinned,
                sortIndex: record.sortIndex,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                completedAt: record.completedAt,
                dueAt: record.dueAt,
                linkedResourceId: record.linkedResourceId.flatMap { resourceMap[$0] }
            )
            modelContext.insert(todo)
            importedTodoCount += 1
        }

        try modelContext.save()
        return ManifestImportSummary(
            workspaces: workspaceMap.count,
            resources: resourceMap.count,
            snippets: snippetMap.count,
            canvases: canvasMap.count,
            nodes: nodeMap.count,
            edges: importedEdgeCount,
            aliases: importedAliasCount,
            todoGroups: importedTodoGroupCount,
            todos: importedTodoCount
        )
    }
}
