import Foundation
import SwiftData

enum WorkbenchScope: String, Codable, CaseIterable, Identifiable {
    case global
    case workspace
    var id: String { rawValue }
}

enum ResourceTargetType: String, Codable, CaseIterable, Identifiable {
    case file
    case folder
    var id: String { rawValue }
}

enum ResourceStatus: String, Codable, CaseIterable, Identifiable {
    case available
    case unavailable
    case staleAuthorization
    case missingVolume
    var id: String { rawValue }
}

enum SnippetKind: String, Codable, CaseIterable, Identifiable {
    case prompt
    case command
    var id: String { rawValue }
}

enum CanvasNodeKind: String, Codable, CaseIterable, Identifiable {
    case resource
    case snippet
    case note
    case groupFrame
    var id: String { rawValue }
}

enum AliasStatus: String, Codable, CaseIterable, Identifiable {
    case created
    case missing
    case failed
    case staleAuthorization
    var id: String { rawValue }
}

@Model
final class WorkspaceModel {
    @Attribute(.unique) var id: String
    var title: String
    var details: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var isPinned: Bool = false
    var sortIndex: Int = 0
    var schemaVersion: Int

    init(
        id: String = UUID().uuidString,
        title: String,
        details: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.schemaVersion = schemaVersion
    }
}

@Model
final class ResourcePinModel {
    @Attribute(.unique) var id: String
    var workspaceId: String?
    var title: String
    var targetTypeRaw: String
    var displayPath: String
    var lastResolvedPath: String
    var securityScopedBookmarkData: Data?
    var note: String
    var tagsText: String
    var scopeRaw: String
    var sortIndex: Int
    var isPinned: Bool = true
    var originalName: String = ""
    var customName: String = ""
    var searchText: String = ""
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?

    init(
        id: String = UUID().uuidString,
        workspaceId: String? = nil,
        title: String,
        targetType: ResourceTargetType,
        displayPath: String,
        lastResolvedPath: String,
        securityScopedBookmarkData: Data? = nil,
        note: String = "",
        tags: [String] = [],
        scope: WorkbenchScope,
        sortIndex: Int = 0,
        isPinned: Bool = true,
        originalName: String = "",
        customName: String = "",
        searchText: String = "",
        status: ResourceStatus = .available,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.targetTypeRaw = targetType.rawValue
        self.displayPath = displayPath
        self.lastResolvedPath = lastResolvedPath
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.note = note
        self.tagsText = tags.joined(separator: ",")
        self.scopeRaw = scope.rawValue
        self.sortIndex = sortIndex
        self.isPinned = isPinned
        self.originalName = originalName.isEmpty ? URL(fileURLWithPath: lastResolvedPath).lastPathComponent : originalName
        self.customName = customName
        self.searchText = searchText
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        refreshSearchText()
    }

    var targetType: ResourceTargetType { ResourceTargetType(rawValue: targetTypeRaw) ?? .folder }
    var scope: WorkbenchScope { WorkbenchScope(rawValue: scopeRaw) ?? .global }
    var status: ResourceStatus {
        get { ResourceStatus(rawValue: statusRaw) ?? .unavailable }
        set { statusRaw = newValue.rawValue }
    }
    var tags: [String] {
        get { tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
        set { tagsText = newValue.joined(separator: ",") }
    }
    var displayName: String {
        let fallback = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = original.isEmpty ? fallback : original
        guard !custom.isEmpty, custom != base else { return base }
        return "\(base) · \(custom)"
    }
    var effectiveName: String {
        let custom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let original = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !original.isEmpty { return original }
        return title.isEmpty ? displayPath : title
    }
    func refreshSearchText() {
        searchText = [
            title,
            originalName,
            customName,
            displayPath,
            lastResolvedPath,
            note,
            tagsText
        ]
            .joined(separator: " ")
            .lowercased()
    }
}

@Model
final class SnippetModel {
    @Attribute(.unique) var id: String
    var workspaceId: String?
    var title: String
    var kindRaw: String
    var body: String
    var details: String
    var tagsText: String
    var scopeRaw: String
    var workingDirectoryRef: String?
    var requiresConfirmation: Bool
    var lastCopiedAt: Date?
    var lastUsedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        workspaceId: String? = nil,
        title: String,
        kind: SnippetKind,
        body: String,
        details: String = "",
        tags: [String] = [],
        scope: WorkbenchScope,
        workingDirectoryRef: String? = nil,
        requiresConfirmation: Bool = true,
        lastCopiedAt: Date? = nil,
        lastUsedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.kindRaw = kind.rawValue
        self.body = body
        self.details = details
        self.tagsText = tags.joined(separator: ",")
        self.scopeRaw = scope.rawValue
        self.workingDirectoryRef = workingDirectoryRef
        self.requiresConfirmation = requiresConfirmation
        self.lastCopiedAt = lastCopiedAt
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: SnippetKind { SnippetKind(rawValue: kindRaw) ?? .prompt }
    var scope: WorkbenchScope { WorkbenchScope(rawValue: scopeRaw) ?? .global }
    var tags: [String] {
        get { tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
        set { tagsText = newValue.joined(separator: ",") }
    }
}

@Model
final class WorkspaceTodoModel {
    @Attribute(.unique) var id: String
    var workspaceId: String
    var groupId: String?
    var title: String
    var details: String = ""
    var isCompleted: Bool
    var isPinned: Bool = false
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var dueAt: Date?
    var linkedResourceId: String?

    init(
        id: String = UUID().uuidString,
        workspaceId: String,
        groupId: String? = nil,
        title: String,
        details: String = "",
        isCompleted: Bool = false,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil,
        dueAt: Date? = nil,
        linkedResourceId: String? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.groupId = groupId
        self.title = title
        self.details = details
        self.isCompleted = isCompleted
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.dueAt = dueAt
        self.linkedResourceId = linkedResourceId
    }
}

@Model
final class WorkspaceTodoGroupModel {
    @Attribute(.unique) var id: String
    var workspaceId: String
    var title: String
    var isPinned: Bool = false
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        workspaceId: String,
        title: String,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CanvasModel {
    @Attribute(.unique) var id: String
    var workspaceId: String
    var title: String
    var viewportX: Double
    var viewportY: Double
    var zoom: Double
    var linkAnimationThemeRaw: String = "blue"
    var animationsEnabled: Bool = true
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, workspaceId: String, title: String = "Map", viewportX: Double = 0, viewportY: Double = 0, zoom: Double = 1, linkAnimationThemeRaw: String = "blue", animationsEnabled: Bool = true, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.viewportX = viewportX
        self.viewportY = viewportY
        self.zoom = zoom
        self.linkAnimationThemeRaw = linkAnimationThemeRaw
        self.animationsEnabled = animationsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CanvasNodeModel {
    @Attribute(.unique) var id: String
    var canvasId: String
    var title: String
    var body: String
    var nodeTypeRaw: String
    var objectType: String?
    var objectId: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var collapsed: Bool
    var parentNodeId: String?
    var zIndex: Double = 0
    var locked: Bool = false
    var styleRaw: String = "default"
    var accentColorRaw: String = "blue"
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, canvasId: String, title: String, body: String = "", nodeType: CanvasNodeKind, objectType: String? = nil, objectId: String? = nil, x: Double, y: Double, width: Double = 180, height: Double = 96, collapsed: Bool = false, parentNodeId: String? = nil, zIndex: Double = 0, locked: Bool = false, styleRaw: String = "default", accentColorRaw: String = "blue", createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.canvasId = canvasId
        self.title = title
        self.body = body
        self.nodeTypeRaw = nodeType.rawValue
        self.objectType = objectType
        self.objectId = objectId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.collapsed = collapsed
        self.parentNodeId = parentNodeId
        self.zIndex = zIndex
        self.locked = locked
        self.styleRaw = styleRaw
        self.accentColorRaw = accentColorRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var nodeType: CanvasNodeKind { CanvasNodeKind(rawValue: nodeTypeRaw) ?? .note }
}

@Model
final class CanvasEdgeModel {
    @Attribute(.unique) var id: String
    var canvasId: String
    var sourceNodeId: String
    var targetNodeId: String
    var label: String
    var style: String
    var sourceArrowRaw: String = "none"
    var targetArrowRaw: String = "arrow"
    var animated: Bool = true
    var animationThemeRaw: String = "blue"
    var controlPointX: Double?
    var controlPointY: Double?
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, canvasId: String, sourceNodeId: String, targetNodeId: String, label: String = "", style: String = "default", sourceArrowRaw: String = "none", targetArrowRaw: String = "arrow", animated: Bool = true, animationThemeRaw: String = "blue", controlPointX: Double? = nil, controlPointY: Double? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.canvasId = canvasId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.label = label
        self.style = style
        self.sourceArrowRaw = sourceArrowRaw
        self.targetArrowRaw = targetArrowRaw
        self.animated = animated
        self.animationThemeRaw = animationThemeRaw
        self.controlPointX = controlPointX
        self.controlPointY = controlPointY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class FinderAliasRecordModel {
    @Attribute(.unique) var id: String
    var sourceObjectType: String
    var sourceObjectId: String
    var aliasDisplayPath: String
    var aliasFileBookmarkData: Data?
    var aliasTargetBookmarkData: Data?
    var statusRaw: String
    var createdAt: Date

    init(id: String = UUID().uuidString, sourceObjectType: String, sourceObjectId: String, aliasDisplayPath: String, aliasFileBookmarkData: Data? = nil, aliasTargetBookmarkData: Data? = nil, status: AliasStatus = .created, createdAt: Date = .now) {
        self.id = id
        self.sourceObjectType = sourceObjectType
        self.sourceObjectId = sourceObjectId
        self.aliasDisplayPath = aliasDisplayPath
        self.aliasFileBookmarkData = aliasFileBookmarkData
        self.aliasTargetBookmarkData = aliasTargetBookmarkData
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
    }

    var status: AliasStatus {
        get { AliasStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }
}

enum SeedData {
    static func seedIfNeeded(
        context: ModelContext,
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel]
    ) {
        guard workspaces.isEmpty, snippets.isEmpty, resources.isEmpty, canvases.isEmpty, nodes.isEmpty else { return }

        let workspace = WorkspaceModel(title: "Qiushan Studio", details: "Personal desktop, files, commands, and prompt workbench.", sortIndex: 0)
        let canvas = CanvasModel(workspaceId: workspace.id, title: "Main Workflow")
        let prompt = SnippetModel(title: "Summarize Notes", kind: .prompt, body: "Summarize these notes into decisions, open questions, and next actions.", details: "General writing prompt", tags: ["writing"], scope: .global)
        let command = SnippetModel(title: "List Current Folder", kind: .command, body: "ls -la", details: "Safe directory listing", tags: ["shell"], scope: .global, requiresConfirmation: true)
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Start Here", body: "Drag files, folders, prompts, and commands onto this workspace map.", nodeType: .note, x: 120, y: 120)

        context.insert(workspace)
        context.insert(canvas)
        context.insert(prompt)
        context.insert(command)
        context.insert(node)
        try? context.save()
    }
}
