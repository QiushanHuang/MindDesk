import Foundation

public struct ExportManifest: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case workspaces
        case resources
        case snippets
        case canvases
        case nodes
        case edges
        case aliases
        case todoGroups
        case todos
    }

    public var schemaVersion: Int
    public var exportedAt: Date
    public var workspaces: [WorkspaceRecord]
    public var resources: [ResourceRecord]
    public var snippets: [SnippetRecord]
    public var canvases: [CanvasRecord]
    public var nodes: [CanvasNodeRecord]
    public var edges: [CanvasEdgeRecord]
    public var aliases: [AliasRecord]
    public var todoGroups: [TodoGroupRecord]
    public var todos: [TodoRecord]

    public init(
        schemaVersion: Int,
        exportedAt: Date,
        workspaces: [WorkspaceRecord],
        resources: [ResourceRecord],
        snippets: [SnippetRecord],
        canvases: [CanvasRecord],
        nodes: [CanvasNodeRecord],
        edges: [CanvasEdgeRecord],
        aliases: [AliasRecord],
        todoGroups: [TodoGroupRecord] = [],
        todos: [TodoRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.workspaces = workspaces
        self.resources = resources
        self.snippets = snippets
        self.canvases = canvases
        self.nodes = nodes
        self.edges = edges
        self.aliases = aliases
        self.todoGroups = todoGroups
        self.todos = todos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        workspaces = try container.decode([WorkspaceRecord].self, forKey: .workspaces)
        resources = try container.decode([ResourceRecord].self, forKey: .resources)
        snippets = try container.decode([SnippetRecord].self, forKey: .snippets)
        canvases = try container.decode([CanvasRecord].self, forKey: .canvases)
        nodes = try container.decode([CanvasNodeRecord].self, forKey: .nodes)
        edges = try container.decode([CanvasEdgeRecord].self, forKey: .edges)
        aliases = try container.decode([AliasRecord].self, forKey: .aliases)
        todoGroups = try container.decodeIfPresent([TodoGroupRecord].self, forKey: .todoGroups) ?? []
        todos = try container.decodeIfPresent([TodoRecord].self, forKey: .todos) ?? []
    }
}

public enum ExportManifestUsageDatePolicy {
    public static func removingUsageDates(from manifest: ExportManifest) -> ExportManifest {
        var copy = manifest
        for index in copy.workspaces.indices {
            copy.workspaces[index].lastOpenedAt = nil
        }
        for index in copy.resources.indices {
            copy.resources[index].lastOpenedAt = nil
        }
        for index in copy.snippets.indices {
            copy.snippets[index].lastCopiedAt = nil
            copy.snippets[index].lastUsedAt = nil
        }
        return copy
    }
}

public enum ExportManifestScopePolicy {
    public static func manifest(
        from manifest: ExportManifest,
        scope: ManifestExportScope
    ) -> ExportManifest {
        switch scope {
        case .completeWorkspaceMap:
            return manifest
        case .globalLibraryOnly:
            var copy = manifest
            copy.workspaces = []
            copy.resources = manifest.resources.filter { $0.scope == "global" }
            let retainedResourceIDs = Set(copy.resources.map(\.id))
            copy.snippets = manifest.snippets
                .filter { $0.scope == "global" }
                .map { snippet in
                    guard let workingDirectoryRef = snippet.workingDirectoryRef,
                          !retainedResourceIDs.contains(workingDirectoryRef) else {
                        return snippet
                    }
                    var copy = snippet
                    copy.workingDirectoryRef = nil
                    return copy
                }
            copy.canvases = []
            copy.nodes = []
            copy.edges = []
            copy.aliases = []
            copy.todoGroups = []
            copy.todos = []
            return copy
        }
    }
}

public enum ManifestImportLimits {
    public static let maximumManifestBytes = 64 * 1024 * 1024
    public static let maximumWorkspaces = 500
    public static let maximumResources = 5_000
    public static let maximumSnippets = 2_000
    public static let maximumCanvases = 1_000
    public static let maximumNodes = 10_000
    public static let maximumEdges = 20_000
    public static let maximumAliases = 5_000
    public static let maximumTodoGroups = 1_000
    public static let maximumTodos = 10_000
    public static let maximumIdentifierLength = 128
    public static let maximumPathLength = 4_096
    public static let maximumTextLength = 65_536
    public static let maximumCanvasCoordinate: Double = 1_000_000
    public static let minimumZoom: Double = 0.12
    public static let maximumZoom: Double = 2.4
    public static let minimumNodeSize: Double = 24
    public static let maximumNodeSize: Double = 5_000
    public static let maximumZIndex: Double = 1_000
}

public struct WorkspaceRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case details
        case createdAt
        case updatedAt
        case lastOpenedAt
        case isPinned
        case sortIndex
    }

    public var id: String
    public var title: String
    public var details: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    public var isPinned: Bool
    public var sortIndex: Int

    public init(
        id: String,
        title: String,
        details: String,
        createdAt: Date,
        updatedAt: Date,
        lastOpenedAt: Date?,
        isPinned: Bool = false,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.isPinned = isPinned
        self.sortIndex = sortIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
    }
}

public struct ResourceRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceId
        case title
        case targetType
        case displayPath
        case lastResolvedPath
        case note
        case tags
        case scope
        case sortIndex
        case isPinned
        case originalName
        case customName
        case searchText
        case status
        case createdAt
        case updatedAt
        case lastOpenedAt
    }

    public var id: String
    public var workspaceId: String?
    public var title: String
    public var targetType: String
    public var displayPath: String
    public var lastResolvedPath: String
    public var note: String
    public var tags: [String]
    public var scope: String
    public var sortIndex: Int
    public var isPinned: Bool
    public var originalName: String
    public var customName: String
    public var searchText: String
    public var status: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?

    public init(id: String, workspaceId: String?, title: String, targetType: String, displayPath: String, lastResolvedPath: String, note: String, tags: [String], scope: String, sortIndex: Int = 0, isPinned: Bool = false, originalName: String = "", customName: String = "", searchText: String = "", status: String, createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0), lastOpenedAt: Date? = nil) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.targetType = targetType
        self.displayPath = displayPath
        self.lastResolvedPath = lastResolvedPath
        self.note = note
        self.tags = tags
        self.scope = scope
        self.sortIndex = sortIndex
        self.isPinned = isPinned
        self.originalName = originalName
        self.customName = customName
        self.searchText = searchText
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        title = try container.decode(String.self, forKey: .title)
        targetType = try container.decode(String.self, forKey: .targetType)
        displayPath = try container.decode(String.self, forKey: .displayPath)
        lastResolvedPath = try container.decode(String.self, forKey: .lastResolvedPath)
        note = try container.decode(String.self, forKey: .note)
        tags = try container.decode([String].self, forKey: .tags)
        scope = try container.decode(String.self, forKey: .scope)
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? true
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName) ?? ""
        customName = try container.decodeIfPresent(String.self, forKey: .customName) ?? ""
        searchText = try container.decodeIfPresent(String.self, forKey: .searchText) ?? ""
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }
}

public struct SnippetRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceId
        case title
        case kind
        case body
        case details
        case tags
        case scope
        case workingDirectoryRef
        case requiresConfirmation
        case lastCopiedAt
        case lastUsedAt
        case createdAt
        case updatedAt
    }

    public var id: String
    public var workspaceId: String?
    public var title: String
    public var kind: String
    public var body: String
    public var details: String
    public var tags: [String]
    public var scope: String
    public var workingDirectoryRef: String?
    public var requiresConfirmation: Bool
    public var lastCopiedAt: Date?
    public var lastUsedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, workspaceId: String?, title: String, kind: String, body: String, details: String, tags: [String], scope: String, workingDirectoryRef: String?, requiresConfirmation: Bool, lastCopiedAt: Date? = nil, lastUsedAt: Date? = nil, createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.kind = kind
        self.body = body
        self.details = details
        self.tags = tags
        self.scope = scope
        self.workingDirectoryRef = workingDirectoryRef
        self.requiresConfirmation = requiresConfirmation
        self.lastCopiedAt = lastCopiedAt
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decode(String.self, forKey: .kind)
        body = try container.decode(String.self, forKey: .body)
        details = try container.decode(String.self, forKey: .details)
        tags = try container.decode([String].self, forKey: .tags)
        scope = try container.decode(String.self, forKey: .scope)
        workingDirectoryRef = try container.decodeIfPresent(String.self, forKey: .workingDirectoryRef)
        requiresConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? (kind == "command")
        lastCopiedAt = try container.decodeIfPresent(Date.self, forKey: .lastCopiedAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
    }
}

public struct CanvasRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceId
        case title
        case viewportX
        case viewportY
        case zoom
        case linkAnimationTheme
        case animationsEnabled
        case createdAt
        case updatedAt
    }

    public var id: String
    public var workspaceId: String
    public var title: String
    public var viewportX: Double
    public var viewportY: Double
    public var zoom: Double
    public var linkAnimationTheme: String
    public var animationsEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, workspaceId: String, title: String, viewportX: Double = 0, viewportY: Double = 0, zoom: Double = 1, linkAnimationTheme: String = "blue", animationsEnabled: Bool = true, createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.viewportX = viewportX
        self.viewportY = viewportY
        self.zoom = zoom
        self.linkAnimationTheme = linkAnimationTheme
        self.animationsEnabled = animationsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        title = try container.decode(String.self, forKey: .title)
        viewportX = try container.decodeIfPresent(Double.self, forKey: .viewportX) ?? 0
        viewportY = try container.decodeIfPresent(Double.self, forKey: .viewportY) ?? 0
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
        linkAnimationTheme = try container.decodeIfPresent(String.self, forKey: .linkAnimationTheme) ?? "blue"
        animationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .animationsEnabled) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
    }
}

public struct CanvasNodeRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case canvasId
        case title
        case body
        case nodeType
        case objectType
        case objectId
        case x
        case y
        case width
        case height
        case collapsed
        case parentNodeId
        case zIndex
        case locked
        case style
        case accentColor
        case createdAt
        case updatedAt
    }

    public var id: String
    public var canvasId: String
    public var title: String
    public var body: String
    public var nodeType: String
    public var objectType: String?
    public var objectId: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var collapsed: Bool
    public var parentNodeId: String?
    public var zIndex: Double
    public var locked: Bool
    public var style: String
    public var accentColor: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, canvasId: String, title: String, body: String, nodeType: String, objectType: String?, objectId: String?, x: Double, y: Double, width: Double, height: Double, collapsed: Bool = false, parentNodeId: String? = nil, zIndex: Double = 0, locked: Bool = false, style: String = "default", accentColor: String = "blue", createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.canvasId = canvasId
        self.title = title
        self.body = body
        self.nodeType = nodeType
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
        self.style = style
        self.accentColor = accentColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        canvasId = try container.decode(String.self, forKey: .canvasId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        nodeType = try container.decode(String.self, forKey: .nodeType)
        objectType = try container.decodeIfPresent(String.self, forKey: .objectType)
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        collapsed = try container.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        parentNodeId = try container.decodeIfPresent(String.self, forKey: .parentNodeId)
        zIndex = try container.decodeIfPresent(Double.self, forKey: .zIndex) ?? 0
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        style = try container.decodeIfPresent(String.self, forKey: .style) ?? "default"
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "blue"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
    }
}

public struct CanvasEdgeRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case canvasId
        case sourceNodeId
        case targetNodeId
        case label
        case style
        case sourceArrow
        case targetArrow
        case animated
        case animationTheme
        case controlPointX
        case controlPointY
        case createdAt
        case updatedAt
    }

    public var id: String
    public var canvasId: String
    public var sourceNodeId: String
    public var targetNodeId: String
    public var label: String
    public var style: String
    public var sourceArrow: String
    public var targetArrow: String
    public var animated: Bool
    public var animationTheme: String
    public var controlPointX: Double?
    public var controlPointY: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, canvasId: String, sourceNodeId: String, targetNodeId: String, label: String, style: String = "default", sourceArrow: String = "none", targetArrow: String = "arrow", animated: Bool = true, animationTheme: String = "blue", controlPointX: Double? = nil, controlPointY: Double? = nil, createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.canvasId = canvasId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.label = label
        self.style = style
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.animated = animated
        self.animationTheme = animationTheme
        self.controlPointX = controlPointX
        self.controlPointY = controlPointY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        canvasId = try container.decode(String.self, forKey: .canvasId)
        sourceNodeId = try container.decode(String.self, forKey: .sourceNodeId)
        targetNodeId = try container.decode(String.self, forKey: .targetNodeId)
        label = try container.decode(String.self, forKey: .label)
        style = try container.decodeIfPresent(String.self, forKey: .style) ?? "default"
        sourceArrow = try container.decodeIfPresent(String.self, forKey: .sourceArrow) ?? "none"
        targetArrow = try container.decodeIfPresent(String.self, forKey: .targetArrow) ?? "arrow"
        animated = try container.decodeIfPresent(Bool.self, forKey: .animated) ?? true
        animationTheme = try container.decodeIfPresent(String.self, forKey: .animationTheme) ?? "blue"
        controlPointX = try container.decodeIfPresent(Double.self, forKey: .controlPointX)
        controlPointY = try container.decodeIfPresent(Double.self, forKey: .controlPointY)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
    }
}

public struct AliasRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case sourceObjectType
        case sourceObjectId
        case aliasDisplayPath
        case status
        case createdAt
    }

    public var id: String
    public var sourceObjectType: String
    public var sourceObjectId: String
    public var aliasDisplayPath: String
    public var status: String
    public var createdAt: Date

    public init(id: String, sourceObjectType: String, sourceObjectId: String, aliasDisplayPath: String, status: String, createdAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.sourceObjectType = sourceObjectType
        self.sourceObjectId = sourceObjectId
        self.aliasDisplayPath = aliasDisplayPath
        self.status = status
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceObjectType = try container.decode(String.self, forKey: .sourceObjectType)
        sourceObjectId = try container.decode(String.self, forKey: .sourceObjectId)
        aliasDisplayPath = try container.decode(String.self, forKey: .aliasDisplayPath)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

public struct TodoGroupRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceId
        case title
        case isPinned
        case sortIndex
        case createdAt
        case updatedAt
    }

    public var id: String
    public var workspaceId: String
    public var title: String
    public var isPinned: Bool
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        workspaceId: String,
        title: String,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        title = try container.decode(String.self, forKey: .title)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
    }
}

public struct TodoRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case workspaceId
        case groupId
        case title
        case details
        case isCompleted
        case isPinned
        case sortIndex
        case createdAt
        case updatedAt
        case completedAt
        case dueAt
        case linkedResourceId
    }

    public var id: String
    public var workspaceId: String
    public var groupId: String?
    public var title: String
    public var details: String
    public var isCompleted: Bool
    public var isPinned: Bool
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var dueAt: Date?
    public var linkedResourceId: String?

    public init(
        id: String,
        workspaceId: String,
        groupId: String? = nil,
        title: String,
        details: String,
        isCompleted: Bool,
        isPinned: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date = Date(timeIntervalSince1970: 0),
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallbackDate = Date(timeIntervalSince1970: 0)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? fallbackDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? fallbackDate
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        linkedResourceId = try container.decodeIfPresent(String.self, forKey: .linkedResourceId)
    }
}

public enum ManifestImportValidation {
    public static func issues(in manifest: ExportManifest) -> [String] {
        let workspaceIds = Set(manifest.workspaces.map(\.id))
        let resourceIds = Set(manifest.resources.map(\.id))
        let snippetIds = Set(manifest.snippets.map(\.id))
        let canvasIds = Set(manifest.canvases.map(\.id))
        let nodeIds = Set(manifest.nodes.map(\.id))
        let todoGroupIds = Set(manifest.todoGroups.map(\.id))
        let todoGroupWorkspaceById = Dictionary(manifest.todoGroups.map { ($0.id, $0.workspaceId) }, uniquingKeysWith: { first, _ in first })
        let nodeCanvasById = Dictionary(manifest.nodes.map { ($0.id, $0.canvasId) }, uniquingKeysWith: { first, _ in first })
        let nodeTypeById = Dictionary(manifest.nodes.map { ($0.id, $0.nodeType) }, uniquingKeysWith: { first, _ in first })
        let resourceTypeById = Dictionary(manifest.resources.map { ($0.id, $0.targetType) }, uniquingKeysWith: { first, _ in first })
        let resourceScopeById = Dictionary(manifest.resources.map { ($0.id, $0.scope) }, uniquingKeysWith: { first, _ in first })
        let resourceWorkspaceById = Dictionary(manifest.resources.compactMap { resource -> (String, String)? in
            guard let workspaceId = resource.workspaceId else { return nil }
            return (resource.id, workspaceId)
        }, uniquingKeysWith: { first, _ in first })
        var issues: [String] = []

        appendCountIssues(manifest, issues: &issues)
        issues.append(contentsOf: emptyIDIssues(manifest.workspaces.map(\.id), label: "Workspace"))
        issues.append(contentsOf: emptyIDIssues(manifest.resources.map(\.id), label: "Resource"))
        issues.append(contentsOf: emptyIDIssues(manifest.snippets.map(\.id), label: "Snippet"))
        issues.append(contentsOf: emptyIDIssues(manifest.canvases.map(\.id), label: "Canvas"))
        issues.append(contentsOf: emptyIDIssues(manifest.nodes.map(\.id), label: "Node"))
        issues.append(contentsOf: emptyIDIssues(manifest.edges.map(\.id), label: "Edge"))
        issues.append(contentsOf: emptyIDIssues(manifest.aliases.map(\.id), label: "Alias"))
        issues.append(contentsOf: emptyIDIssues(manifest.todoGroups.map(\.id), label: "Todo group"))
        issues.append(contentsOf: emptyIDIssues(manifest.todos.map(\.id), label: "Todo"))
        issues.append(contentsOf: duplicateIssues(manifest.workspaces.map(\.id), label: "workspace"))
        issues.append(contentsOf: duplicateIssues(manifest.resources.map(\.id), label: "resource"))
        issues.append(contentsOf: duplicateIssues(manifest.snippets.map(\.id), label: "snippet"))
        issues.append(contentsOf: duplicateIssues(manifest.canvases.map(\.id), label: "canvas"))
        issues.append(contentsOf: duplicateIssues(manifest.nodes.map(\.id), label: "node"))
        issues.append(contentsOf: duplicateIssues(manifest.edges.map(\.id), label: "edge"))
        issues.append(contentsOf: duplicateIssues(manifest.aliases.map(\.id), label: "alias"))
        issues.append(contentsOf: duplicateIssues(manifest.todoGroups.map(\.id), label: "todo group"))
        issues.append(contentsOf: duplicateIssues(manifest.todos.map(\.id), label: "todo"))

        for workspace in manifest.workspaces {
            appendIdentifierIssue(workspace.id, ownerDescription: "Workspace \(workspace.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(workspace.title, ownerDescription: "Workspace \(workspace.id)", fieldDescription: "title", issues: &issues)
            appendTextIssue(workspace.details, ownerDescription: "Workspace \(workspace.id)", fieldDescription: "details", issues: &issues)
        }

        for resource in manifest.resources {
            appendIdentifierIssue(resource.id, ownerDescription: "Resource \(resource.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(resource.title, ownerDescription: "Resource \(resource.id)", fieldDescription: "title", issues: &issues)
            appendPathIssue(resource.displayPath, ownerDescription: "Resource \(resource.id)", fieldDescription: "display path", issues: &issues)
            appendPathIssue(resource.lastResolvedPath, ownerDescription: "Resource \(resource.id)", fieldDescription: "last resolved path", issues: &issues)
            appendTextIssue(resource.note, ownerDescription: "Resource \(resource.id)", fieldDescription: "note", issues: &issues)
            appendTextIssues(resource.tags, ownerDescription: "Resource \(resource.id)", fieldDescription: "tag", issues: &issues)
            appendAllowedIssue(resource.targetType, allowed: allowedResourceTargetTypes, ownerDescription: "Resource \(resource.id)", fieldDescription: "target type", issues: &issues)
            appendAllowedIssue(resource.scope, allowed: allowedScopes, ownerDescription: "Resource \(resource.id)", fieldDescription: "scope", issues: &issues)
            appendAllowedIssue(resource.status, allowed: allowedResourceStatuses, ownerDescription: "Resource \(resource.id)", fieldDescription: "status", issues: &issues)
            if requiresWorkspaceID(scope: resource.scope), resource.workspaceId == nil {
                issues.append("Resource \(resource.id) has workspace scope without a workspace id.")
            }
            if hasGlobalScope(scope: resource.scope), resource.workspaceId != nil {
                issues.append("Resource \(resource.id) has global scope with a workspace id.")
            }
            if let workspaceId = resource.workspaceId, !workspaceIds.contains(workspaceId) {
                issues.append("Resource \(resource.id) references missing workspace \(workspaceId).")
            }
        }

        for snippet in manifest.snippets {
            appendIdentifierIssue(snippet.id, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(snippet.title, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "title", issues: &issues)
            appendTextIssue(snippet.body, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "body", issues: &issues)
            appendTextIssue(snippet.details, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "details", issues: &issues)
            appendTextIssues(snippet.tags, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "tag", issues: &issues)
            appendAllowedIssue(snippet.kind, allowed: allowedSnippetKinds, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "kind", issues: &issues)
            appendAllowedIssue(snippet.scope, allowed: allowedScopes, ownerDescription: "Snippet \(snippet.id)", fieldDescription: "scope", issues: &issues)
            if requiresWorkspaceID(scope: snippet.scope), snippet.workspaceId == nil {
                issues.append("Snippet \(snippet.id) has workspace scope without a workspace id.")
            }
            if hasGlobalScope(scope: snippet.scope), snippet.workspaceId != nil {
                issues.append("Snippet \(snippet.id) has global scope with a workspace id.")
            }
            if let workspaceId = snippet.workspaceId, !workspaceIds.contains(workspaceId) {
                issues.append("Snippet \(snippet.id) references missing workspace \(workspaceId).")
            }
            if let resourceId = snippet.workingDirectoryRef, !resourceIds.contains(resourceId) {
                issues.append("Snippet \(snippet.id) references missing working directory resource \(resourceId).")
            } else if let resourceId = snippet.workingDirectoryRef,
                      resourceTypeById[resourceId] != "folder" {
                issues.append("Snippet \(snippet.id) working directory \(resourceId) is not a folder resource.")
            }
        }

        for canvas in manifest.canvases {
            appendIdentifierIssue(canvas.id, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(canvas.title, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "title", issues: &issues)
            appendCanvasCoordinateIssue(canvas.viewportX, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "viewportX", issues: &issues)
            appendCanvasCoordinateIssue(canvas.viewportY, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "viewportY", issues: &issues)
            appendRangeIssue(canvas.zoom, minimum: ManifestImportLimits.minimumZoom, maximum: ManifestImportLimits.maximumZoom, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "zoom", issues: &issues)
            appendAllowedIssue(canvas.linkAnimationTheme, allowed: allowedAnimationThemes, ownerDescription: "Canvas \(canvas.id)", fieldDescription: "link animation theme", issues: &issues)
            if !workspaceIds.contains(canvas.workspaceId) {
                issues.append("Canvas \(canvas.id) references missing workspace \(canvas.workspaceId).")
            }
        }

        for node in manifest.nodes {
            appendIdentifierIssue(node.id, ownerDescription: "Node \(node.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(node.title, ownerDescription: "Node \(node.id)", fieldDescription: "title", issues: &issues)
            appendTextIssue(node.body, ownerDescription: "Node \(node.id)", fieldDescription: "body", issues: &issues)
            appendAllowedIssue(node.nodeType, allowed: allowedNodeTypes, ownerDescription: "Node \(node.id)", fieldDescription: "node type", issues: &issues)
            appendCanvasCoordinateIssue(node.x, ownerDescription: "Node \(node.id)", fieldDescription: "x", issues: &issues)
            appendCanvasCoordinateIssue(node.y, ownerDescription: "Node \(node.id)", fieldDescription: "y", issues: &issues)
            appendRangeIssue(node.width, minimum: ManifestImportLimits.minimumNodeSize, maximum: ManifestImportLimits.maximumNodeSize, ownerDescription: "Node \(node.id)", fieldDescription: "width", issues: &issues)
            appendRangeIssue(node.height, minimum: ManifestImportLimits.minimumNodeSize, maximum: ManifestImportLimits.maximumNodeSize, ownerDescription: "Node \(node.id)", fieldDescription: "height", issues: &issues)
            appendRangeIssue(node.zIndex, minimum: -ManifestImportLimits.maximumZIndex, maximum: ManifestImportLimits.maximumZIndex, ownerDescription: "Node \(node.id)", fieldDescription: "zIndex", issues: &issues)
            appendAllowedIssue(node.style, allowed: allowedNodeStyles, ownerDescription: "Node \(node.id)", fieldDescription: "style", issues: &issues)
            if !node.accentColor.isEmpty,
               CanvasNodeColorStyle(rawValue: node.accentColor) == nil,
               !allowedLegacyAccentColors.contains(node.accentColor) {
                issues.append("Node \(node.id) has unsupported accent color \(node.accentColor).")
            }
            if !canvasIds.contains(node.canvasId) {
                issues.append("Node \(node.id) references missing canvas \(node.canvasId).")
            }
            if let parentNodeId = node.parentNodeId {
                if parentNodeId == node.id {
                    issues.append("Node \(node.id) cannot be its own parent.")
                } else if !nodeIds.contains(parentNodeId) {
                    issues.append("Node \(node.id) references missing parent node \(parentNodeId).")
                } else if let parentCanvasId = nodeCanvasById[parentNodeId], parentCanvasId != node.canvasId {
                    issues.append("Node \(node.id) references parent node \(parentNodeId) from another canvas.")
                } else if nodeTypeById[parentNodeId] != "groupFrame" {
                    issues.append("Node \(node.id) references parent node \(parentNodeId) that is not a frame.")
                }
            }
            if let objectType = node.objectType {
                appendAllowedIssue(objectType, allowed: allowedObjectTypes, ownerDescription: "Node \(node.id)", fieldDescription: "object type", issues: &issues)
                if objectType == "webURL" {
                    let trimmedObjectId = node.objectId?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let urlSource = trimmedObjectId?.isEmpty == false ? trimmedObjectId ?? "" : node.body
                    if WebCardURL.normalized(urlSource) == nil {
                        issues.append("Node \(node.id) references invalid web URL.")
                    }
                } else {
                    guard let objectId = normalizedReference(
                        node.objectId,
                        ownerDescription: "Node \(node.id)",
                        fieldDescription: "object id",
                        issues: &issues
                    ) else {
                        issues.append("Node \(node.id) has object type \(objectType) without an object id.")
                        continue
                    }
                    appendMissingObjectIssue(
                        objectType: objectType,
                        objectId: objectId,
                        ownerDescription: "Node \(node.id)",
                        resourceIds: resourceIds,
                        snippetIds: snippetIds,
                        workspaceIds: workspaceIds,
                        issues: &issues
                    )
                }
            }
        }

        for edge in manifest.edges {
            appendIdentifierIssue(edge.id, ownerDescription: "Edge \(edge.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(edge.label, ownerDescription: "Edge \(edge.id)", fieldDescription: "label", issues: &issues)
            appendTextIssue(edge.style, ownerDescription: "Edge \(edge.id)", fieldDescription: "style", issues: &issues)
            appendAllowedIssue(edge.sourceArrow, allowed: allowedArrowStyles, ownerDescription: "Edge \(edge.id)", fieldDescription: "source arrow", issues: &issues)
            appendAllowedIssue(edge.targetArrow, allowed: allowedArrowStyles, ownerDescription: "Edge \(edge.id)", fieldDescription: "target arrow", issues: &issues)
            appendAllowedIssue(edge.animationTheme, allowed: allowedAnimationThemes, ownerDescription: "Edge \(edge.id)", fieldDescription: "animation theme", issues: &issues)
            if let controlPointX = edge.controlPointX {
                appendCanvasCoordinateIssue(controlPointX, ownerDescription: "Edge \(edge.id)", fieldDescription: "controlPointX", issues: &issues)
            }
            if let controlPointY = edge.controlPointY {
                appendCanvasCoordinateIssue(controlPointY, ownerDescription: "Edge \(edge.id)", fieldDescription: "controlPointY", issues: &issues)
            }
            if !canvasIds.contains(edge.canvasId) {
                issues.append("Edge \(edge.id) references missing canvas \(edge.canvasId).")
            }
            if !nodeIds.contains(edge.sourceNodeId) {
                issues.append("Edge \(edge.id) references missing source node \(edge.sourceNodeId).")
            } else if let sourceCanvasId = nodeCanvasById[edge.sourceNodeId], sourceCanvasId != edge.canvasId {
                issues.append("Edge \(edge.id) references source node \(edge.sourceNodeId) from another canvas.")
            }
            if !nodeIds.contains(edge.targetNodeId) {
                issues.append("Edge \(edge.id) references missing target node \(edge.targetNodeId).")
            } else if let targetCanvasId = nodeCanvasById[edge.targetNodeId], targetCanvasId != edge.canvasId {
                issues.append("Edge \(edge.id) references target node \(edge.targetNodeId) from another canvas.")
            }
        }

        for group in manifest.todoGroups {
            appendIdentifierIssue(group.id, ownerDescription: "Todo group \(group.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(group.title, ownerDescription: "Todo group \(group.id)", fieldDescription: "title", issues: &issues)
            if !workspaceIds.contains(group.workspaceId) {
                issues.append("Todo group \(group.id) references missing workspace \(group.workspaceId).")
            }
        }

        for todo in manifest.todos {
            appendIdentifierIssue(todo.id, ownerDescription: "Todo \(todo.id)", fieldDescription: "id", issues: &issues)
            appendTextIssue(todo.title, ownerDescription: "Todo \(todo.id)", fieldDescription: "title", issues: &issues)
            appendTextIssue(todo.details, ownerDescription: "Todo \(todo.id)", fieldDescription: "details", issues: &issues)
            if !workspaceIds.contains(todo.workspaceId) {
                issues.append("Todo \(todo.id) references missing workspace \(todo.workspaceId).")
            }
            if let groupId = todo.groupId {
                if !todoGroupIds.contains(groupId) {
                    issues.append("Todo \(todo.id) references missing group \(groupId).")
                } else if todoGroupWorkspaceById[groupId] != todo.workspaceId {
                    issues.append("Todo \(todo.id) references group \(groupId) from another workspace.")
                }
            }
            if let resourceId = todo.linkedResourceId {
                if !resourceIds.contains(resourceId) {
                    issues.append("Todo \(todo.id) references missing linked resource \(resourceId).")
                } else if resourceScopeById[resourceId] == "workspace",
                          resourceWorkspaceById[resourceId] != todo.workspaceId {
                    issues.append("Todo \(todo.id) references linked resource \(resourceId) from another workspace.")
                }
            }
        }

        for alias in manifest.aliases {
            appendIdentifierIssue(alias.id, ownerDescription: "Alias \(alias.id)", fieldDescription: "id", issues: &issues)
            appendPathIssue(alias.aliasDisplayPath, ownerDescription: "Alias \(alias.id)", fieldDescription: "display path", issues: &issues)
            appendAllowedIssue(alias.status, allowed: allowedAliasStatuses, ownerDescription: "Alias \(alias.id)", fieldDescription: "status", issues: &issues)
            guard alias.sourceObjectType == "resourcePin" || alias.sourceObjectType == "snippet" else {
                issues.append("Alias \(alias.id) has unsupported source object type \(alias.sourceObjectType).")
                continue
            }
            guard let sourceObjectId = normalizedReference(
                alias.sourceObjectId,
                ownerDescription: "Alias \(alias.id)",
                fieldDescription: "source object id",
                issues: &issues
            ) else {
                issues.append("Alias \(alias.id) has empty source object id.")
                continue
            }
            if alias.status != "missing" {
                appendMissingObjectIssue(
                    objectType: alias.sourceObjectType,
                    objectId: sourceObjectId,
                    ownerDescription: "Alias \(alias.id)",
                    resourceIds: resourceIds,
                    snippetIds: snippetIds,
                    workspaceIds: workspaceIds,
                    issues: &issues
                )
            }
        }

        return issues
    }

    private static func emptyIDIssues(_ ids: [String], label: String) -> [String] {
        ids.compactMap { id in
            id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(label) has empty id." : nil
        }
    }

    private static func duplicateIssues(_ ids: [String], label: String) -> [String] {
        var seen: Set<String> = []
        var reported: Set<String> = []
        var duplicates: [String] = []
        for id in ids {
            if !seen.insert(id).inserted, reported.insert(id).inserted {
                duplicates.append(id)
            }
        }
        return duplicates.map { "Duplicate \(label) id \($0)." }
    }

    private static let allowedResourceTargetTypes: Set<String> = ["file", "folder"]
    private static let allowedResourceStatuses: Set<String> = ["available", "unavailable", "staleAuthorization", "missingVolume"]
    private static let allowedScopes: Set<String> = ["global", "workspace"]
    private static let allowedSnippetKinds: Set<String> = ["prompt", "command"]
    private static let allowedNodeTypes: Set<String> = ["resource", "snippet", "note", "groupFrame"]
    private static let allowedObjectTypes: Set<String> = ["resourcePin", "snippet", "workspace", "webURL"]
    private static let allowedNodeStyles: Set<String> = ["default"]
    private static let allowedArrowStyles: Set<String> = ["none", "arrow"]
    private static let allowedAnimationThemes: Set<String> = ["blue", "minimal", "off"]
    private static let allowedAliasStatuses: Set<String> = ["created", "missing", "failed", "staleAuthorization"]
    private static let allowedLegacyAccentColors: Set<String> = ["blue"]

    private static func appendCountIssues(_ manifest: ExportManifest, issues: inout [String]) {
        appendCountIssue(manifest.workspaces.count, maximum: ManifestImportLimits.maximumWorkspaces, label: "workspaces", issues: &issues)
        appendCountIssue(manifest.resources.count, maximum: ManifestImportLimits.maximumResources, label: "resources", issues: &issues)
        appendCountIssue(manifest.snippets.count, maximum: ManifestImportLimits.maximumSnippets, label: "snippets", issues: &issues)
        appendCountIssue(manifest.canvases.count, maximum: ManifestImportLimits.maximumCanvases, label: "canvases", issues: &issues)
        appendCountIssue(manifest.nodes.count, maximum: ManifestImportLimits.maximumNodes, label: "nodes", issues: &issues)
        appendCountIssue(manifest.edges.count, maximum: ManifestImportLimits.maximumEdges, label: "edges", issues: &issues)
        appendCountIssue(manifest.aliases.count, maximum: ManifestImportLimits.maximumAliases, label: "aliases", issues: &issues)
        appendCountIssue(manifest.todoGroups.count, maximum: ManifestImportLimits.maximumTodoGroups, label: "todo groups", issues: &issues)
        appendCountIssue(manifest.todos.count, maximum: ManifestImportLimits.maximumTodos, label: "todos", issues: &issues)
    }

    private static func appendCountIssue(_ count: Int, maximum: Int, label: String, issues: inout [String]) {
        if count > maximum {
            issues.append("Manifest has too many \(label).")
        }
    }

    private static func appendIdentifierIssue(
        _ value: String,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        if value.count > ManifestImportLimits.maximumIdentifierLength {
            issues.append("\(ownerDescription) \(fieldDescription) is too long.")
        }
    }

    private static func appendTextIssue(
        _ value: String,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        if value.count > ManifestImportLimits.maximumTextLength {
            issues.append("\(ownerDescription) \(fieldDescription) is too long.")
        }
    }

    private static func appendTextIssues(
        _ values: [String],
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        for value in values {
            appendTextIssue(value, ownerDescription: ownerDescription, fieldDescription: fieldDescription, issues: &issues)
        }
    }

    private static func appendPathIssue(
        _ value: String,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        if value.count > ManifestImportLimits.maximumPathLength {
            issues.append("\(ownerDescription) \(fieldDescription) is too long.")
        }
    }

    private static func appendAllowedIssue(
        _ value: String,
        allowed: Set<String>,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        if !allowed.contains(value) {
            issues.append("\(ownerDescription) has unsupported \(fieldDescription) \(value).")
        }
    }

    private static func appendCanvasCoordinateIssue(
        _ value: Double,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        appendRangeIssue(
            value,
            minimum: -ManifestImportLimits.maximumCanvasCoordinate,
            maximum: ManifestImportLimits.maximumCanvasCoordinate,
            ownerDescription: ownerDescription,
            fieldDescription: fieldDescription,
            issues: &issues
        )
    }

    private static func appendRangeIssue(
        _ value: Double,
        minimum: Double,
        maximum: Double,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) {
        guard value.isFinite, value >= minimum, value <= maximum else {
            issues.append("\(ownerDescription) has \(fieldDescription) outside the supported range.")
            return
        }
    }

    private static func requiresWorkspaceID(scope: String) -> Bool {
        scope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "workspace"
    }

    private static func hasGlobalScope(scope: String) -> Bool {
        scope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "global"
    }

    private static func normalizedReference(
        _ value: String?,
        ownerDescription: String,
        fieldDescription: String,
        issues: inout [String]
    ) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if normalized != value {
            issues.append("\(ownerDescription) has \(fieldDescription) with leading or trailing whitespace.")
            return nil
        }
        return normalized
    }

    private static func appendMissingObjectIssue(
        objectType: String,
        objectId: String,
        ownerDescription: String,
        resourceIds: Set<String>,
        snippetIds: Set<String>,
        workspaceIds: Set<String>,
        issues: inout [String]
    ) {
        switch objectType {
        case "workspace" where !workspaceIds.contains(objectId):
            issues.append("\(ownerDescription) references missing workspace object \(objectId).")
        case "resourcePin" where !resourceIds.contains(objectId):
            issues.append("\(ownerDescription) references missing resource object \(objectId).")
        case "snippet" where !snippetIds.contains(objectId):
            issues.append("\(ownerDescription) references missing snippet object \(objectId).")
        default:
            break
        }
    }
}

public extension JSONEncoder {
    static var minddesk: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var minddesk: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
