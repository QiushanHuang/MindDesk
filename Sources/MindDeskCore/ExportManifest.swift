import Foundation

public struct ExportManifest: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
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

    public static let currentFormat = "minddesk.export.manifest"
    public static let currentFormatVersion = 1
    public static let supportedFormatVersions: Set<Int> = [currentFormatVersion]

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
        let format: String?
        if container.contains(.format) {
            do {
                format = try container.decode(String.self, forKey: .format)
            } catch {
                throw ExportManifestWireFormatError.unsupportedFormat
            }
        } else {
            format = nil
        }
        let formatVersion: Int?
        if container.contains(.formatVersion) {
            do {
                formatVersion = try container.decode(Int.self, forKey: .formatVersion)
            } catch {
                throw ExportManifestWireFormatError.unsupportedFormatVersion
            }
        } else {
            formatVersion = nil
        }
        if let format {
            guard format == Self.currentFormat else {
                throw ExportManifestWireFormatError.unsupportedFormat
            }
            guard let formatVersion,
                  Self.supportedFormatVersions.contains(formatVersion) else {
                throw ExportManifestWireFormatError.unsupportedFormatVersion
            }
        } else if formatVersion != nil {
            throw ExportManifestWireFormatError.unsupportedFormatVersion
        }
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentFormat, forKey: .format)
        try container.encode(Self.currentFormatVersion, forKey: .formatVersion)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(workspaces, forKey: .workspaces)
        try container.encode(resources, forKey: .resources)
        try container.encode(snippets, forKey: .snippets)
        try container.encode(canvases, forKey: .canvases)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(todoGroups, forKey: .todoGroups)
        try container.encode(todos, forKey: .todos)
    }
}

public enum ExportManifestWireFormatError: Error, Equatable, Sendable {
    case unsupportedFormat
    case unsupportedFormatVersion
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

public struct WorkspaceRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct ResourceRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct SnippetRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct CanvasRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct CanvasNodeRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct CanvasEdgeRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct AliasRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct TodoGroupRecord: Codable, Equatable, Identifiable, Sendable {
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

public struct TodoRecord: Codable, Equatable, Identifiable, Sendable {
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

struct ManifestImportValidationDiagnostic: Equatable, Sendable {
    let code: String
    let ownerKind: String?
    let ownerID: String?
    let field: String?
    let path: String?
    let details: [String: String]
    let legacyMessage: String

    init(
        code: String,
        ownerKind: String? = nil,
        ownerID: String? = nil,
        field: String? = nil,
        path: String? = nil,
        details: [String: String] = [:],
        legacyMessage: String
    ) {
        self.code = code
        self.ownerKind = ownerKind
        self.ownerID = ownerID
        self.field = field
        self.path = path
        self.details = details
        self.legacyMessage = legacyMessage
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
        let canvasWorkspaceById = Dictionary(manifest.canvases.map { ($0.id, $0.workspaceId) }, uniquingKeysWith: { first, _ in first })
        let resourceTypeById = Dictionary(manifest.resources.map { ($0.id, $0.targetType) }, uniquingKeysWith: { first, _ in first })
        let resourceScopeById = Dictionary(manifest.resources.map { ($0.id, $0.scope) }, uniquingKeysWith: { first, _ in first })
        let resourceWorkspaceById = Dictionary(manifest.resources.compactMap { resource -> (String, String)? in
            guard let workspaceId = resource.workspaceId else { return nil }
            return (resource.id, workspaceId)
        }, uniquingKeysWith: { first, _ in first })
        let snippetScopeById = Dictionary(manifest.snippets.map { ($0.id, $0.scope) }, uniquingKeysWith: { first, _ in first })
        let snippetWorkspaceById = Dictionary(manifest.snippets.compactMap { snippet -> (String, String)? in
            guard let workspaceId = snippet.workspaceId else { return nil }
            return (snippet.id, workspaceId)
        }, uniquingKeysWith: { first, _ in first })
        var issues: [String] = []

        if manifest.schemaVersion != 1 && manifest.schemaVersion != 2 {
            issues.append("Unsupported manifest schema version \(manifest.schemaVersion).")
        }

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
            } else if let resourceId = snippet.workingDirectoryRef,
                      resourceScopeById[resourceId] == "workspace",
                      snippet.workspaceId == nil || resourceWorkspaceById[resourceId] != snippet.workspaceId {
                issues.append("Snippet \(snippet.id) references working directory resource \(resourceId) from another workspace.")
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
            if let objectType = node.objectType,
               !WorkbenchObjectReferencePolicy.isCompatible(nodeType: node.nodeType, objectType: objectType) {
                issues.append("Node \(node.id) with node type \(node.nodeType) cannot reference object type \(objectType).")
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
                    if objectType == "resourcePin",
                       resourceScopeById[objectId] == "workspace",
                       let canvasWorkspaceId = canvasWorkspaceById[node.canvasId],
                       resourceWorkspaceById[objectId] != canvasWorkspaceId {
                        issues.append("Node \(node.id) references resource \(objectId) from another workspace.")
                    } else if objectType == "snippet",
                              snippetScopeById[objectId] == "workspace",
                              let canvasWorkspaceId = canvasWorkspaceById[node.canvasId],
                              snippetWorkspaceById[objectId] != canvasWorkspaceId {
                        issues.append("Node \(node.id) references snippet \(objectId) from another workspace.")
                    }
                }
            }
        }
        issues.append(contentsOf: cyclicParentIssues(for: manifest.nodes, nodeCanvasById: nodeCanvasById))

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
            guard WorkbenchObjectReferencePolicy.importableAliasSourceTypes.contains(alias.sourceObjectType) else {
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

    static func diagnostics(in manifest: ExportManifest) -> [ManifestImportValidationDiagnostic] {
        var diagnostics: [ManifestImportValidationDiagnostic] = []
        let workspaceIds = Set(manifest.workspaces.map(\.id))
        let resourceIds = Set(manifest.resources.map(\.id))
        let snippetIds = Set(manifest.snippets.map(\.id))
        let canvasIds = Set(manifest.canvases.map(\.id))
        let nodeIds = Set(manifest.nodes.map(\.id))
        let todoGroupIds = Set(manifest.todoGroups.map(\.id))
        let todoGroupWorkspaceById = Dictionary(manifest.todoGroups.map { ($0.id, $0.workspaceId) }, uniquingKeysWith: { first, _ in first })
        let nodeCanvasById = Dictionary(manifest.nodes.map { ($0.id, $0.canvasId) }, uniquingKeysWith: { first, _ in first })
        let nodeTypeById = Dictionary(manifest.nodes.map { ($0.id, $0.nodeType) }, uniquingKeysWith: { first, _ in first })
        let nodeIndexById = Dictionary(manifest.nodes.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let canvasWorkspaceById = Dictionary(manifest.canvases.map { ($0.id, $0.workspaceId) }, uniquingKeysWith: { first, _ in first })
        let resourceTargetTypeById = Dictionary(manifest.resources.map { ($0.id, $0.targetType) }, uniquingKeysWith: { first, _ in first })
        let resourceIdsByScope = Dictionary(manifest.resources.map { ($0.id, $0.scope) }, uniquingKeysWith: { first, _ in first })
        let resourceWorkspaceById = Dictionary(manifest.resources.compactMap { resource -> (String, String)? in
            guard let workspaceId = resource.workspaceId else { return nil }
            return (resource.id, workspaceId)
        }, uniquingKeysWith: { first, _ in first })
        let snippetIdsByScope = Dictionary(manifest.snippets.map { ($0.id, $0.scope) }, uniquingKeysWith: { first, _ in first })
        let snippetWorkspaceById = Dictionary(manifest.snippets.compactMap { snippet -> (String, String)? in
            guard let workspaceId = snippet.workspaceId else { return nil }
            return (snippet.id, workspaceId)
        }, uniquingKeysWith: { first, _ in first })

        if manifest.schemaVersion != 1 && manifest.schemaVersion != 2 {
            diagnostics.append(ManifestImportValidationDiagnostic(
                code: "manifest.schema.unsupported-version",
                ownerKind: "manifest",
                field: "schemaVersion",
                path: "/manifest/schemaVersion",
                details: [
                    "actualVersion": String(manifest.schemaVersion),
                    "supportedVersions": "1,2"
                ],
                legacyMessage: "Unsupported manifest schema version \(manifest.schemaVersion)."
            ))
        }

        appendCountDiagnostics(manifest, diagnostics: &diagnostics)

        appendEmptyIDDiagnostics(manifest.workspaces.map(\.id), label: "Workspace", ownerKind: "workspace", collectionPath: "/manifest/workspaces", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.resources.map(\.id), label: "Resource", ownerKind: "resource", collectionPath: "/manifest/resources", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.snippets.map(\.id), label: "Snippet", ownerKind: "snippet", collectionPath: "/manifest/snippets", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.canvases.map(\.id), label: "Canvas", ownerKind: "canvas", collectionPath: "/manifest/canvases", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.nodes.map(\.id), label: "Node", ownerKind: "node", collectionPath: "/manifest/nodes", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.edges.map(\.id), label: "Edge", ownerKind: "edge", collectionPath: "/manifest/edges", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.aliases.map(\.id), label: "Alias", ownerKind: "alias", collectionPath: "/manifest/aliases", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.todoGroups.map(\.id), label: "Todo group", ownerKind: "todoGroup", collectionPath: "/manifest/todoGroups", diagnostics: &diagnostics)
        appendEmptyIDDiagnostics(manifest.todos.map(\.id), label: "Todo", ownerKind: "todo", collectionPath: "/manifest/todos", diagnostics: &diagnostics)

        appendDuplicateDiagnostics(manifest.workspaces.map(\.id), label: "workspace", ownerKind: "workspace", collectionPath: "/manifest/workspaces", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.resources.map(\.id), label: "resource", ownerKind: "resource", collectionPath: "/manifest/resources", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.snippets.map(\.id), label: "snippet", ownerKind: "snippet", collectionPath: "/manifest/snippets", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.canvases.map(\.id), label: "canvas", ownerKind: "canvas", collectionPath: "/manifest/canvases", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.nodes.map(\.id), label: "node", ownerKind: "node", collectionPath: "/manifest/nodes", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.edges.map(\.id), label: "edge", ownerKind: "edge", collectionPath: "/manifest/edges", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.aliases.map(\.id), label: "alias", ownerKind: "alias", collectionPath: "/manifest/aliases", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.todoGroups.map(\.id), label: "todo group", ownerKind: "todoGroup", collectionPath: "/manifest/todoGroups", diagnostics: &diagnostics)
        appendDuplicateDiagnostics(manifest.todos.map(\.id), label: "todo", ownerKind: "todo", collectionPath: "/manifest/todos", diagnostics: &diagnostics)

        for (index, workspace) in manifest.workspaces.enumerated() {
            appendIdentifierDiagnostic(workspace.id, ownerKind: "workspace", ownerID: workspace.id, field: "id", path: "/manifest/workspaces/\(index)/id", legacyMessage: "Workspace \(workspace.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(workspace.title, ownerKind: "workspace", ownerID: workspace.id, field: "title", path: "/manifest/workspaces/\(index)/title", legacyMessage: "Workspace \(workspace.id) title is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(workspace.details, ownerKind: "workspace", ownerID: workspace.id, field: "details", path: "/manifest/workspaces/\(index)/details", legacyMessage: "Workspace \(workspace.id) details is too long.", diagnostics: &diagnostics)
        }

        for (index, resource) in manifest.resources.enumerated() {
            appendIdentifierDiagnostic(resource.id, ownerKind: "resource", ownerID: resource.id, field: "id", path: "/manifest/resources/\(index)/id", legacyMessage: "Resource \(resource.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(resource.title, ownerKind: "resource", ownerID: resource.id, field: "title", path: "/manifest/resources/\(index)/title", legacyMessage: "Resource \(resource.id) title is too long.", diagnostics: &diagnostics)
            appendPathDiagnostic(resource.displayPath, ownerKind: "resource", ownerID: resource.id, field: "displayPath", path: "/manifest/resources/\(index)/displayPath", legacyMessage: "Resource \(resource.id) display path is too long.", diagnostics: &diagnostics)
            appendPathDiagnostic(resource.lastResolvedPath, ownerKind: "resource", ownerID: resource.id, field: "lastResolvedPath", path: "/manifest/resources/\(index)/lastResolvedPath", legacyMessage: "Resource \(resource.id) last resolved path is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(resource.note, ownerKind: "resource", ownerID: resource.id, field: "note", path: "/manifest/resources/\(index)/note", legacyMessage: "Resource \(resource.id) note is too long.", diagnostics: &diagnostics)
            appendTextDiagnostics(resource.tags, ownerKind: "resource", ownerID: resource.id, field: "tags", path: "/manifest/resources/\(index)/tags", legacyMessage: "Resource \(resource.id) tag is too long.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(
                resource.targetType,
                allowed: allowedResourceTargetTypes,
                ownerKind: "resource",
                ownerID: resource.id,
                field: "targetType",
                fieldDescription: "target type",
                path: "/manifest/resources/\(index)/targetType",
                legacyMessage: "Resource \(resource.id) has unsupported target type \(resource.targetType).",
                diagnostics: &diagnostics
            )
            appendUnsupportedValueDiagnostic(
                resource.scope,
                allowed: allowedScopes,
                ownerKind: "resource",
                ownerID: resource.id,
                field: "scope",
                fieldDescription: "scope",
                path: "/manifest/resources/\(index)/scope",
                legacyMessage: "Resource \(resource.id) has unsupported scope \(resource.scope).",
                diagnostics: &diagnostics
            )
            appendUnsupportedValueDiagnostic(
                resource.status,
                allowed: allowedResourceStatuses,
                ownerKind: "resource",
                ownerID: resource.id,
                field: "status",
                fieldDescription: "status",
                path: "/manifest/resources/\(index)/status",
                legacyMessage: "Resource \(resource.id) has unsupported status \(resource.status).",
                diagnostics: &diagnostics
            )
            if requiresWorkspaceID(scope: resource.scope), resource.workspaceId == nil {
                diagnostics.append(scopeDiagnostic(
                    code: "manifest.scope.workspace-id-required",
                    ownerKind: "resource",
                    ownerID: resource.id,
                    field: "workspaceId",
                    path: "/manifest/resources/\(index)/workspaceId",
                    legacyMessage: "Resource \(resource.id) has workspace scope without a workspace id."
                ))
            }
            if hasGlobalScope(scope: resource.scope), resource.workspaceId != nil {
                diagnostics.append(scopeDiagnostic(
                    code: "manifest.scope.workspace-id-forbidden",
                    ownerKind: "resource",
                    ownerID: resource.id,
                    field: "workspaceId",
                    path: "/manifest/resources/\(index)/workspaceId",
                    legacyMessage: "Resource \(resource.id) has global scope with a workspace id."
                ))
            }
            if let workspaceId = resource.workspaceId, !workspaceIds.contains(workspaceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "resource",
                    ownerID: resource.id,
                    field: "workspaceId",
                    path: "/manifest/resources/\(index)/workspaceId",
                    referencedOwnerKind: "workspace",
                    referencedOwnerID: workspaceId,
                    legacyMessage: "Resource \(resource.id) references missing workspace \(workspaceId)."
                ))
            }
        }

        for (index, snippet) in manifest.snippets.enumerated() {
            appendIdentifierDiagnostic(snippet.id, ownerKind: "snippet", ownerID: snippet.id, field: "id", path: "/manifest/snippets/\(index)/id", legacyMessage: "Snippet \(snippet.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(snippet.title, ownerKind: "snippet", ownerID: snippet.id, field: "title", path: "/manifest/snippets/\(index)/title", legacyMessage: "Snippet \(snippet.id) title is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(snippet.body, ownerKind: "snippet", ownerID: snippet.id, field: "body", path: "/manifest/snippets/\(index)/body", legacyMessage: "Snippet \(snippet.id) body is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(snippet.details, ownerKind: "snippet", ownerID: snippet.id, field: "details", path: "/manifest/snippets/\(index)/details", legacyMessage: "Snippet \(snippet.id) details is too long.", diagnostics: &diagnostics)
            appendTextDiagnostics(snippet.tags, ownerKind: "snippet", ownerID: snippet.id, field: "tags", path: "/manifest/snippets/\(index)/tags", legacyMessage: "Snippet \(snippet.id) tag is too long.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(
                snippet.kind,
                allowed: allowedSnippetKinds,
                ownerKind: "snippet",
                ownerID: snippet.id,
                field: "kind",
                fieldDescription: "kind",
                path: "/manifest/snippets/\(index)/kind",
                legacyMessage: "Snippet \(snippet.id) has unsupported kind \(snippet.kind).",
                diagnostics: &diagnostics
            )
            appendUnsupportedValueDiagnostic(
                snippet.scope,
                allowed: allowedScopes,
                ownerKind: "snippet",
                ownerID: snippet.id,
                field: "scope",
                fieldDescription: "scope",
                path: "/manifest/snippets/\(index)/scope",
                legacyMessage: "Snippet \(snippet.id) has unsupported scope \(snippet.scope).",
                diagnostics: &diagnostics
            )
            if requiresWorkspaceID(scope: snippet.scope), snippet.workspaceId == nil {
                diagnostics.append(scopeDiagnostic(
                    code: "manifest.scope.workspace-id-required",
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workspaceId",
                    path: "/manifest/snippets/\(index)/workspaceId",
                    legacyMessage: "Snippet \(snippet.id) has workspace scope without a workspace id."
                ))
            }
            if hasGlobalScope(scope: snippet.scope), snippet.workspaceId != nil {
                diagnostics.append(scopeDiagnostic(
                    code: "manifest.scope.workspace-id-forbidden",
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workspaceId",
                    path: "/manifest/snippets/\(index)/workspaceId",
                    legacyMessage: "Snippet \(snippet.id) has global scope with a workspace id."
                ))
            }
            if let workspaceId = snippet.workspaceId, !workspaceIds.contains(workspaceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workspaceId",
                    path: "/manifest/snippets/\(index)/workspaceId",
                    referencedOwnerKind: "workspace",
                    referencedOwnerID: workspaceId,
                    legacyMessage: "Snippet \(snippet.id) references missing workspace \(workspaceId)."
                ))
            }
            if let resourceId = snippet.workingDirectoryRef, !resourceIds.contains(resourceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workingDirectoryRef",
                    path: "/manifest/snippets/\(index)/workingDirectoryRef",
                    referencedOwnerKind: "resource",
                    referencedOwnerID: resourceId,
                    legacyMessage: "Snippet \(snippet.id) references missing working directory resource \(resourceId)."
                ))
            } else if let resourceId = snippet.workingDirectoryRef,
                      resourceTargetTypeById[resourceId] != "folder" {
                diagnostics.append(unsupportedReferenceTargetDiagnostic(
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workingDirectoryRef",
                    path: "/manifest/snippets/\(index)/workingDirectoryRef",
                    referencedOwnerKind: "resource",
                    referencedOwnerID: resourceId,
                    expectedTargetType: "folder",
                    actualTargetType: resourceTargetTypeById[resourceId],
                    legacyMessage: "Snippet \(snippet.id) working directory \(resourceId) is not a folder resource."
                ))
            } else if let resourceId = snippet.workingDirectoryRef,
                      resourceIdsByScope[resourceId] == "workspace",
                      snippet.workspaceId == nil || resourceWorkspaceById[resourceId] != snippet.workspaceId {
                diagnostics.append(crossWorkspaceDiagnostic(
                    ownerKind: "snippet",
                    ownerID: snippet.id,
                    field: "workingDirectoryRef",
                    path: "/manifest/snippets/\(index)/workingDirectoryRef",
                    referencedOwnerKind: "resource",
                    referencedOwnerID: resourceId,
                    ownerWorkspaceID: snippet.workspaceId,
                    referencedWorkspaceID: resourceWorkspaceById[resourceId],
                    legacyMessage: "Snippet \(snippet.id) references working directory resource \(resourceId) from another workspace."
                ))
            }
        }

        for (index, canvas) in manifest.canvases.enumerated() {
            appendIdentifierDiagnostic(canvas.id, ownerKind: "canvas", ownerID: canvas.id, field: "id", path: "/manifest/canvases/\(index)/id", legacyMessage: "Canvas \(canvas.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(canvas.title, ownerKind: "canvas", ownerID: canvas.id, field: "title", path: "/manifest/canvases/\(index)/title", legacyMessage: "Canvas \(canvas.id) title is too long.", diagnostics: &diagnostics)
            appendCanvasCoordinateDiagnostic(canvas.viewportX, ownerKind: "canvas", ownerID: canvas.id, field: "viewportX", path: "/manifest/canvases/\(index)/viewportX", legacyMessage: "Canvas \(canvas.id) has viewportX outside the supported range.", diagnostics: &diagnostics)
            appendCanvasCoordinateDiagnostic(canvas.viewportY, ownerKind: "canvas", ownerID: canvas.id, field: "viewportY", path: "/manifest/canvases/\(index)/viewportY", legacyMessage: "Canvas \(canvas.id) has viewportY outside the supported range.", diagnostics: &diagnostics)
            appendRangeDiagnostic(canvas.zoom, minimum: ManifestImportLimits.minimumZoom, maximum: ManifestImportLimits.maximumZoom, ownerKind: "canvas", ownerID: canvas.id, field: "zoom", path: "/manifest/canvases/\(index)/zoom", legacyMessage: "Canvas \(canvas.id) has zoom outside the supported range.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(canvas.linkAnimationTheme, allowed: allowedAnimationThemes, ownerKind: "canvas", ownerID: canvas.id, field: "linkAnimationTheme", fieldDescription: "link animation theme", path: "/manifest/canvases/\(index)/linkAnimationTheme", legacyMessage: "Canvas \(canvas.id) has unsupported link animation theme \(canvas.linkAnimationTheme).", diagnostics: &diagnostics)
            if !workspaceIds.contains(canvas.workspaceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "canvas",
                    ownerID: canvas.id,
                    field: "workspaceId",
                    path: "/manifest/canvases/\(index)/workspaceId",
                    referencedOwnerKind: "workspace",
                    referencedOwnerID: canvas.workspaceId,
                    legacyMessage: "Canvas \(canvas.id) references missing workspace \(canvas.workspaceId)."
                ))
            }
        }

        for (index, node) in manifest.nodes.enumerated() {
            appendIdentifierDiagnostic(node.id, ownerKind: "node", ownerID: node.id, field: "id", path: "/manifest/nodes/\(index)/id", legacyMessage: "Node \(node.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(node.title, ownerKind: "node", ownerID: node.id, field: "title", path: "/manifest/nodes/\(index)/title", legacyMessage: "Node \(node.id) title is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(node.body, ownerKind: "node", ownerID: node.id, field: "body", path: "/manifest/nodes/\(index)/body", legacyMessage: "Node \(node.id) body is too long.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(
                node.nodeType,
                allowed: allowedNodeTypes,
                ownerKind: "node",
                ownerID: node.id,
                field: "nodeType",
                fieldDescription: "node type",
                path: "/manifest/nodes/\(index)/nodeType",
                legacyMessage: "Node \(node.id) has unsupported node type \(node.nodeType).",
                diagnostics: &diagnostics
            )
            appendCanvasCoordinateDiagnostic(node.x, ownerKind: "node", ownerID: node.id, field: "x", path: "/manifest/nodes/\(index)/x", legacyMessage: "Node \(node.id) has x outside the supported range.", diagnostics: &diagnostics)
            appendCanvasCoordinateDiagnostic(node.y, ownerKind: "node", ownerID: node.id, field: "y", path: "/manifest/nodes/\(index)/y", legacyMessage: "Node \(node.id) has y outside the supported range.", diagnostics: &diagnostics)
            if let objectType = node.objectType {
                appendUnsupportedValueDiagnostic(
                    objectType,
                    allowed: allowedObjectTypes,
                    ownerKind: "node",
                    ownerID: node.id,
                    field: "objectType",
                    fieldDescription: "object type",
                    path: "/manifest/nodes/\(index)/objectType",
                    legacyMessage: "Node \(node.id) has unsupported object type \(objectType).",
                    diagnostics: &diagnostics
                )
            }
            appendRangeDiagnostic(
                node.width,
                minimum: ManifestImportLimits.minimumNodeSize,
                maximum: ManifestImportLimits.maximumNodeSize,
                ownerKind: "node",
                ownerID: node.id,
                field: "width",
                path: "/manifest/nodes/\(index)/width",
                legacyMessage: "Node \(node.id) has width outside the supported range.",
                diagnostics: &diagnostics
            )
            appendRangeDiagnostic(
                node.height,
                minimum: ManifestImportLimits.minimumNodeSize,
                maximum: ManifestImportLimits.maximumNodeSize,
                ownerKind: "node",
                ownerID: node.id,
                field: "height",
                path: "/manifest/nodes/\(index)/height",
                legacyMessage: "Node \(node.id) has height outside the supported range.",
                diagnostics: &diagnostics
            )
            appendRangeDiagnostic(
                node.zIndex,
                minimum: -ManifestImportLimits.maximumZIndex,
                maximum: ManifestImportLimits.maximumZIndex,
                ownerKind: "node",
                ownerID: node.id,
                field: "zIndex",
                path: "/manifest/nodes/\(index)/zIndex",
                legacyMessage: "Node \(node.id) has zIndex outside the supported range.",
                diagnostics: &diagnostics
            )
            appendUnsupportedValueDiagnostic(
                node.style,
                allowed: allowedNodeStyles,
                ownerKind: "node",
                ownerID: node.id,
                field: "style",
                fieldDescription: "style",
                path: "/manifest/nodes/\(index)/style",
                legacyMessage: "Node \(node.id) has unsupported style \(node.style).",
                diagnostics: &diagnostics
            )
            if !node.accentColor.isEmpty,
               CanvasNodeColorStyle(rawValue: node.accentColor) == nil,
               !allowedLegacyAccentColors.contains(node.accentColor) {
                diagnostics.append(ManifestImportValidationDiagnostic(
                    code: "manifest.field.unsupported-value",
                    ownerKind: "node",
                    ownerID: node.id,
                    field: "accentColor",
                    path: "/manifest/nodes/\(index)/accentColor",
                    details: [
                        "actual": node.accentColor,
                        "allowedValues": "hex-color,blue"
                    ],
                    legacyMessage: "Node \(node.id) has unsupported accent color \(node.accentColor)."
                ))
            }
            if !canvasIds.contains(node.canvasId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "node",
                    ownerID: node.id,
                    field: "canvasId",
                    path: "/manifest/nodes/\(index)/canvasId",
                    referencedOwnerKind: "canvas",
                    referencedOwnerID: node.canvasId,
                    legacyMessage: "Node \(node.id) references missing canvas \(node.canvasId)."
                ))
            }
            if let parentNodeId = node.parentNodeId {
                if parentNodeId == node.id {
                    diagnostics.append(ManifestImportValidationDiagnostic(
                        code: "manifest.node.parent.self-reference",
                        ownerKind: "node",
                        ownerID: node.id,
                        field: "parentNodeId",
                        path: "/manifest/nodes/\(index)/parentNodeId",
                        details: ["referencedOwnerID": parentNodeId],
                        legacyMessage: "Node \(node.id) cannot be its own parent."
                    ))
                } else if !nodeIds.contains(parentNodeId) {
                    diagnostics.append(missingReferenceDiagnostic(
                        ownerKind: "node",
                        ownerID: node.id,
                        field: "parentNodeId",
                        path: "/manifest/nodes/\(index)/parentNodeId",
                        referencedOwnerKind: "node",
                        referencedOwnerID: parentNodeId,
                        legacyMessage: "Node \(node.id) references missing parent node \(parentNodeId)."
                    ))
                } else if let parentCanvasId = nodeCanvasById[parentNodeId], parentCanvasId != node.canvasId {
                    diagnostics.append(crossCanvasDiagnostic(
                        ownerKind: "node",
                        ownerID: node.id,
                        field: "parentNodeId",
                        path: "/manifest/nodes/\(index)/parentNodeId",
                        referencedOwnerKind: "node",
                        referencedOwnerID: parentNodeId,
                        ownerCanvasID: node.canvasId,
                        referencedCanvasID: parentCanvasId,
                        legacyMessage: "Node \(node.id) references parent node \(parentNodeId) from another canvas."
                    ))
                } else if nodeTypeById[parentNodeId] != "groupFrame" {
                    diagnostics.append(unsupportedReferenceTargetDiagnostic(
                        ownerKind: "node",
                        ownerID: node.id,
                        field: "parentNodeId",
                        path: "/manifest/nodes/\(index)/parentNodeId",
                        referencedOwnerKind: "node",
                        referencedOwnerID: parentNodeId,
                        expectedTargetType: "groupFrame",
                        actualTargetType: nodeTypeById[parentNodeId],
                        legacyMessage: "Node \(node.id) references parent node \(parentNodeId) that is not a frame."
                    ))
                }
            }
            if let objectType = node.objectType {
                if !WorkbenchObjectReferencePolicy.isCompatible(nodeType: node.nodeType, objectType: objectType) {
                    diagnostics.append(incompatibleObjectReferenceDiagnostic(
                        ownerID: node.id,
                        nodeType: node.nodeType,
                        objectType: objectType,
                        path: "/manifest/nodes/\(index)/objectType",
                        legacyMessage: "Node \(node.id) with node type \(node.nodeType) cannot reference object type \(objectType)."
                    ))
                }
                if objectType == "webURL" {
                    let trimmedObjectId = node.objectId?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let sourceField = trimmedObjectId?.isEmpty == false ? "objectId" : "body"
                    let urlSource = sourceField == "objectId" ? trimmedObjectId ?? "" : node.body
                    if WebCardURL.normalized(urlSource) == nil {
                        diagnostics.append(invalidWebURLDiagnostic(
                            ownerID: node.id,
                            field: sourceField,
                            path: "/manifest/nodes/\(index)/\(sourceField)",
                            legacyMessage: "Node \(node.id) references invalid web URL."
                        ))
                    }
                } else {
                    let trimmedObjectId = node.objectId?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let rawObjectId = node.objectId,
                       let objectId = trimmedObjectId,
                       !objectId.isEmpty,
                       rawObjectId != objectId {
                        diagnostics.append(referenceIDWhitespaceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referenceDetails: ["objectType": objectType],
                            normalizedReferenceIDLength: objectId.count,
                            legacyMessage: "Node \(node.id) has object id with leading or trailing whitespace."
                        ))
                    }
                    guard let objectId = trimmedObjectId,
                          !objectId.isEmpty,
                          node.objectId == objectId else {
                        let reason: String
                        if node.objectId == nil {
                            reason = "missing"
                        } else if trimmedObjectId?.isEmpty == true {
                            reason = "empty"
                        } else {
                            reason = "invalidWhitespace"
                        }
                        diagnostics.append(referenceIDRequiredDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referenceDetails: ["objectType": objectType],
                            reason: reason,
                            legacyMessage: "Node \(node.id) has object type \(objectType) without an object id."
                        ))
                        continue
                    }
                    if objectType == "resourcePin", !resourceIds.contains(objectId) {
                        diagnostics.append(missingReferenceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referencedOwnerKind: "resource",
                            referencedOwnerID: objectId,
                            legacyMessage: "Node \(node.id) references missing resource object \(objectId)."
                        ))
                    } else if objectType == "snippet", !snippetIds.contains(objectId) {
                        diagnostics.append(missingReferenceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referencedOwnerKind: "snippet",
                            referencedOwnerID: objectId,
                            legacyMessage: "Node \(node.id) references missing snippet object \(objectId)."
                        ))
                    } else if objectType == "workspace", !workspaceIds.contains(objectId) {
                        diagnostics.append(missingReferenceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referencedOwnerKind: "workspace",
                            referencedOwnerID: objectId,
                            legacyMessage: "Node \(node.id) references missing workspace object \(objectId)."
                        ))
                    }
                    if objectType == "resourcePin",
                       resourceIdsByScope[objectId] == "workspace",
                       let canvasWorkspaceId = canvasWorkspaceById[node.canvasId],
                       resourceWorkspaceById[objectId] != canvasWorkspaceId {
                        diagnostics.append(crossWorkspaceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referencedOwnerKind: "resource",
                            referencedOwnerID: objectId,
                            ownerWorkspaceID: canvasWorkspaceId,
                            referencedWorkspaceID: resourceWorkspaceById[objectId],
                            legacyMessage: "Node \(node.id) references resource \(objectId) from another workspace."
                        ))
                    } else if objectType == "snippet",
                              snippetIdsByScope[objectId] == "workspace",
                              let canvasWorkspaceId = canvasWorkspaceById[node.canvasId],
                              snippetWorkspaceById[objectId] != canvasWorkspaceId {
                        diagnostics.append(crossWorkspaceDiagnostic(
                            ownerKind: "node",
                            ownerID: node.id,
                            field: "objectId",
                            path: "/manifest/nodes/\(index)/objectId",
                            referencedOwnerKind: "snippet",
                            referencedOwnerID: objectId,
                            ownerWorkspaceID: canvasWorkspaceId,
                            referencedWorkspaceID: snippetWorkspaceById[objectId],
                            legacyMessage: "Node \(node.id) references snippet \(objectId) from another workspace."
                        ))
                    }
                }
            }
        }

        diagnostics.append(contentsOf: cyclicParentDiagnostics(
            for: manifest.nodes,
            nodeCanvasById: nodeCanvasById,
            nodeIndexById: nodeIndexById
        ))

        for (index, edge) in manifest.edges.enumerated() {
            appendIdentifierDiagnostic(edge.id, ownerKind: "edge", ownerID: edge.id, field: "id", path: "/manifest/edges/\(index)/id", legacyMessage: "Edge \(edge.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(edge.label, ownerKind: "edge", ownerID: edge.id, field: "label", path: "/manifest/edges/\(index)/label", legacyMessage: "Edge \(edge.id) label is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(edge.style, ownerKind: "edge", ownerID: edge.id, field: "style", path: "/manifest/edges/\(index)/style", legacyMessage: "Edge \(edge.id) style is too long.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(edge.sourceArrow, allowed: allowedArrowStyles, ownerKind: "edge", ownerID: edge.id, field: "sourceArrow", fieldDescription: "source arrow", path: "/manifest/edges/\(index)/sourceArrow", legacyMessage: "Edge \(edge.id) has unsupported source arrow \(edge.sourceArrow).", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(edge.targetArrow, allowed: allowedArrowStyles, ownerKind: "edge", ownerID: edge.id, field: "targetArrow", fieldDescription: "target arrow", path: "/manifest/edges/\(index)/targetArrow", legacyMessage: "Edge \(edge.id) has unsupported target arrow \(edge.targetArrow).", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(edge.animationTheme, allowed: allowedAnimationThemes, ownerKind: "edge", ownerID: edge.id, field: "animationTheme", fieldDescription: "animation theme", path: "/manifest/edges/\(index)/animationTheme", legacyMessage: "Edge \(edge.id) has unsupported animation theme \(edge.animationTheme).", diagnostics: &diagnostics)
            if let controlPointX = edge.controlPointX {
                appendCanvasCoordinateDiagnostic(controlPointX, ownerKind: "edge", ownerID: edge.id, field: "controlPointX", path: "/manifest/edges/\(index)/controlPointX", legacyMessage: "Edge \(edge.id) has controlPointX outside the supported range.", diagnostics: &diagnostics)
            }
            if let controlPointY = edge.controlPointY {
                appendCanvasCoordinateDiagnostic(controlPointY, ownerKind: "edge", ownerID: edge.id, field: "controlPointY", path: "/manifest/edges/\(index)/controlPointY", legacyMessage: "Edge \(edge.id) has controlPointY outside the supported range.", diagnostics: &diagnostics)
            }
            if !canvasIds.contains(edge.canvasId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "edge",
                    ownerID: edge.id,
                    field: "canvasId",
                    path: "/manifest/edges/\(index)/canvasId",
                    referencedOwnerKind: "canvas",
                    referencedOwnerID: edge.canvasId,
                    legacyMessage: "Edge \(edge.id) references missing canvas \(edge.canvasId)."
                ))
            }
            if !nodeIds.contains(edge.sourceNodeId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "edge",
                    ownerID: edge.id,
                    field: "sourceNodeId",
                    path: "/manifest/edges/\(index)/sourceNodeId",
                    referencedOwnerKind: "node",
                    referencedOwnerID: edge.sourceNodeId,
                    legacyMessage: "Edge \(edge.id) references missing source node \(edge.sourceNodeId)."
                ))
            } else if let sourceCanvasId = nodeCanvasById[edge.sourceNodeId], sourceCanvasId != edge.canvasId {
                diagnostics.append(crossCanvasDiagnostic(
                    ownerKind: "edge",
                    ownerID: edge.id,
                    field: "sourceNodeId",
                    path: "/manifest/edges/\(index)/sourceNodeId",
                    referencedOwnerKind: "node",
                    referencedOwnerID: edge.sourceNodeId,
                    ownerCanvasID: edge.canvasId,
                    referencedCanvasID: sourceCanvasId,
                    legacyMessage: "Edge \(edge.id) references source node \(edge.sourceNodeId) from another canvas."
                ))
            }
            if !nodeIds.contains(edge.targetNodeId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "edge",
                    ownerID: edge.id,
                    field: "targetNodeId",
                    path: "/manifest/edges/\(index)/targetNodeId",
                    referencedOwnerKind: "node",
                    referencedOwnerID: edge.targetNodeId,
                    legacyMessage: "Edge \(edge.id) references missing target node \(edge.targetNodeId)."
                ))
            } else if let targetCanvasId = nodeCanvasById[edge.targetNodeId], targetCanvasId != edge.canvasId {
                diagnostics.append(crossCanvasDiagnostic(
                    ownerKind: "edge",
                    ownerID: edge.id,
                    field: "targetNodeId",
                    path: "/manifest/edges/\(index)/targetNodeId",
                    referencedOwnerKind: "node",
                    referencedOwnerID: edge.targetNodeId,
                    ownerCanvasID: edge.canvasId,
                    referencedCanvasID: targetCanvasId,
                    legacyMessage: "Edge \(edge.id) references target node \(edge.targetNodeId) from another canvas."
                ))
            }
        }

        for (index, group) in manifest.todoGroups.enumerated() {
            appendIdentifierDiagnostic(group.id, ownerKind: "todoGroup", ownerID: group.id, field: "id", path: "/manifest/todoGroups/\(index)/id", legacyMessage: "Todo group \(group.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(group.title, ownerKind: "todoGroup", ownerID: group.id, field: "title", path: "/manifest/todoGroups/\(index)/title", legacyMessage: "Todo group \(group.id) title is too long.", diagnostics: &diagnostics)
            if !workspaceIds.contains(group.workspaceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "todoGroup",
                    ownerID: group.id,
                    field: "workspaceId",
                    path: "/manifest/todoGroups/\(index)/workspaceId",
                    referencedOwnerKind: "workspace",
                    referencedOwnerID: group.workspaceId,
                    legacyMessage: "Todo group \(group.id) references missing workspace \(group.workspaceId)."
                ))
            }
        }

        for (index, todo) in manifest.todos.enumerated() {
            appendIdentifierDiagnostic(todo.id, ownerKind: "todo", ownerID: todo.id, field: "id", path: "/manifest/todos/\(index)/id", legacyMessage: "Todo \(todo.id) id is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(todo.title, ownerKind: "todo", ownerID: todo.id, field: "title", path: "/manifest/todos/\(index)/title", legacyMessage: "Todo \(todo.id) title is too long.", diagnostics: &diagnostics)
            appendTextDiagnostic(todo.details, ownerKind: "todo", ownerID: todo.id, field: "details", path: "/manifest/todos/\(index)/details", legacyMessage: "Todo \(todo.id) details is too long.", diagnostics: &diagnostics)
            if !workspaceIds.contains(todo.workspaceId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "todo",
                    ownerID: todo.id,
                    field: "workspaceId",
                    path: "/manifest/todos/\(index)/workspaceId",
                    referencedOwnerKind: "workspace",
                    referencedOwnerID: todo.workspaceId,
                    legacyMessage: "Todo \(todo.id) references missing workspace \(todo.workspaceId)."
                ))
            }
            if let groupId = todo.groupId {
                if !todoGroupIds.contains(groupId) {
                    diagnostics.append(missingReferenceDiagnostic(
                        ownerKind: "todo",
                        ownerID: todo.id,
                        field: "groupId",
                        path: "/manifest/todos/\(index)/groupId",
                        referencedOwnerKind: "todoGroup",
                        referencedOwnerID: groupId,
                        legacyMessage: "Todo \(todo.id) references missing group \(groupId)."
                    ))
                } else if todoGroupWorkspaceById[groupId] != todo.workspaceId {
                    diagnostics.append(crossWorkspaceDiagnostic(
                        ownerKind: "todo",
                        ownerID: todo.id,
                        field: "groupId",
                        path: "/manifest/todos/\(index)/groupId",
                        referencedOwnerKind: "todoGroup",
                        referencedOwnerID: groupId,
                        ownerWorkspaceID: todo.workspaceId,
                        referencedWorkspaceID: todoGroupWorkspaceById[groupId],
                        legacyMessage: "Todo \(todo.id) references group \(groupId) from another workspace."
                    ))
                }
            }
            if let resourceId = todo.linkedResourceId {
                if !resourceIds.contains(resourceId) {
                    diagnostics.append(missingReferenceDiagnostic(
                        ownerKind: "todo",
                        ownerID: todo.id,
                        field: "linkedResourceId",
                        path: "/manifest/todos/\(index)/linkedResourceId",
                        referencedOwnerKind: "resource",
                        referencedOwnerID: resourceId,
                        legacyMessage: "Todo \(todo.id) references missing linked resource \(resourceId)."
                    ))
                } else if resourceIdsByScope[resourceId] == "workspace",
                          resourceWorkspaceById[resourceId] != todo.workspaceId {
                    diagnostics.append(crossWorkspaceDiagnostic(
                        ownerKind: "todo",
                        ownerID: todo.id,
                        field: "linkedResourceId",
                        path: "/manifest/todos/\(index)/linkedResourceId",
                        referencedOwnerKind: "resource",
                        referencedOwnerID: resourceId,
                        ownerWorkspaceID: todo.workspaceId,
                        referencedWorkspaceID: resourceWorkspaceById[resourceId],
                        legacyMessage: "Todo \(todo.id) references linked resource \(resourceId) from another workspace."
                    ))
                }
            }
        }

        for (index, alias) in manifest.aliases.enumerated() {
            appendIdentifierDiagnostic(alias.id, ownerKind: "alias", ownerID: alias.id, field: "id", path: "/manifest/aliases/\(index)/id", legacyMessage: "Alias \(alias.id) id is too long.", diagnostics: &diagnostics)
            appendPathDiagnostic(alias.aliasDisplayPath, ownerKind: "alias", ownerID: alias.id, field: "aliasDisplayPath", path: "/manifest/aliases/\(index)/aliasDisplayPath", legacyMessage: "Alias \(alias.id) display path is too long.", diagnostics: &diagnostics)
            appendUnsupportedValueDiagnostic(alias.status, allowed: allowedAliasStatuses, ownerKind: "alias", ownerID: alias.id, field: "status", fieldDescription: "status", path: "/manifest/aliases/\(index)/status", legacyMessage: "Alias \(alias.id) has unsupported status \(alias.status).", diagnostics: &diagnostics)
            guard WorkbenchObjectReferencePolicy.importableAliasSourceTypes.contains(alias.sourceObjectType) else {
                diagnostics.append(unsupportedAliasSourceTypeDiagnostic(
                    ownerID: alias.id,
                    path: "/manifest/aliases/\(index)/sourceObjectType",
                    legacyMessage: "Alias \(alias.id) has unsupported source object type \(alias.sourceObjectType)."
                ))
                continue
            }
            let sourceObjectId = alias.sourceObjectId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sourceObjectId.isEmpty, alias.sourceObjectId != sourceObjectId {
                diagnostics.append(referenceIDWhitespaceDiagnostic(
                    ownerKind: "alias",
                    ownerID: alias.id,
                    field: "sourceObjectId",
                    path: "/manifest/aliases/\(index)/sourceObjectId",
                    referenceDetails: ["sourceObjectType": alias.sourceObjectType],
                    normalizedReferenceIDLength: sourceObjectId.count,
                    legacyMessage: "Alias \(alias.id) has source object id with leading or trailing whitespace."
                ))
            }
            guard !sourceObjectId.isEmpty, alias.sourceObjectId == sourceObjectId else {
                let reason = sourceObjectId.isEmpty ? "empty" : "invalidWhitespace"
                diagnostics.append(referenceIDRequiredDiagnostic(
                    ownerKind: "alias",
                    ownerID: alias.id,
                    field: "sourceObjectId",
                    path: "/manifest/aliases/\(index)/sourceObjectId",
                    referenceDetails: ["sourceObjectType": alias.sourceObjectType],
                    reason: reason,
                    legacyMessage: "Alias \(alias.id) has empty source object id."
                ))
                continue
            }
            guard alias.status != "missing" else { continue }
            if alias.sourceObjectType == "resourcePin", !resourceIds.contains(sourceObjectId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "alias",
                    ownerID: alias.id,
                    field: "sourceObjectId",
                    path: "/manifest/aliases/\(index)/sourceObjectId",
                    referencedOwnerKind: "resource",
                    referencedOwnerID: sourceObjectId,
                    legacyMessage: "Alias \(alias.id) references missing resource object \(sourceObjectId)."
                ))
            } else if alias.sourceObjectType == "snippet", !snippetIds.contains(sourceObjectId) {
                diagnostics.append(missingReferenceDiagnostic(
                    ownerKind: "alias",
                    ownerID: alias.id,
                    field: "sourceObjectId",
                    path: "/manifest/aliases/\(index)/sourceObjectId",
                    referencedOwnerKind: "snippet",
                    referencedOwnerID: sourceObjectId,
                    legacyMessage: "Alias \(alias.id) references missing snippet object \(sourceObjectId)."
                ))
            }
        }

        return diagnosticsOrderedByLegacyIssues(diagnostics, legacyIssues: issues(in: manifest))
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

    private static func diagnosticsOrderedByLegacyIssues(
        _ diagnostics: [ManifestImportValidationDiagnostic],
        legacyIssues: [String]
    ) -> [ManifestImportValidationDiagnostic] {
        var diagnosticsByMessage: [String: [ManifestImportValidationDiagnostic]] = [:]
        for diagnostic in diagnostics {
            diagnosticsByMessage[diagnostic.legacyMessage, default: []].append(diagnostic)
        }

        var ordered: [ManifestImportValidationDiagnostic] = []
        var consumedCounts: [String: Int] = [:]
        for (index, message) in legacyIssues.enumerated() {
            if var matchingDiagnostics = diagnosticsByMessage[message], !matchingDiagnostics.isEmpty {
                ordered.append(matchingDiagnostics.removeFirst())
                diagnosticsByMessage[message] = matchingDiagnostics
                consumedCounts[message, default: 0] += 1
            } else {
                ordered.append(ManifestImportValidationDiagnostic(
                    code: "manifest.import.issue",
                    ownerKind: "manifest",
                    field: "validationIssues",
                    path: "/manifest",
                    details: [
                        "fallbackSource": "legacyValidationIssues",
                        "legacyIssueIndex": String(index)
                    ],
                    legacyMessage: message
                ))
            }
        }

        var remainingCounts = diagnosticsByMessage.mapValues(\.count)
        var skippedConsumedCounts = consumedCounts
        for diagnostic in diagnostics {
            let message = diagnostic.legacyMessage
            if let consumedCount = skippedConsumedCounts[message], consumedCount > 0 {
                skippedConsumedCounts[message] = consumedCount - 1
            } else if let remainingCount = remainingCounts[message], remainingCount > 0 {
                ordered.append(diagnostic)
                remainingCounts[message] = remainingCount - 1
            }
        }
        return ordered
    }

    private static func appendCountDiagnostics(
        _ manifest: ExportManifest,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        appendCountDiagnostic(manifest.workspaces.count, maximum: ManifestImportLimits.maximumWorkspaces, field: "workspaces", path: "/manifest/workspaces", label: "workspaces", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.resources.count, maximum: ManifestImportLimits.maximumResources, field: "resources", path: "/manifest/resources", label: "resources", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.snippets.count, maximum: ManifestImportLimits.maximumSnippets, field: "snippets", path: "/manifest/snippets", label: "snippets", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.canvases.count, maximum: ManifestImportLimits.maximumCanvases, field: "canvases", path: "/manifest/canvases", label: "canvases", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.nodes.count, maximum: ManifestImportLimits.maximumNodes, field: "nodes", path: "/manifest/nodes", label: "nodes", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.edges.count, maximum: ManifestImportLimits.maximumEdges, field: "edges", path: "/manifest/edges", label: "edges", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.aliases.count, maximum: ManifestImportLimits.maximumAliases, field: "aliases", path: "/manifest/aliases", label: "aliases", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.todoGroups.count, maximum: ManifestImportLimits.maximumTodoGroups, field: "todoGroups", path: "/manifest/todoGroups", label: "todo groups", diagnostics: &diagnostics)
        appendCountDiagnostic(manifest.todos.count, maximum: ManifestImportLimits.maximumTodos, field: "todos", path: "/manifest/todos", label: "todos", diagnostics: &diagnostics)
    }

    private static func appendCountDiagnostic(
        _ count: Int,
        maximum: Int,
        field: String,
        path: String,
        label: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard count > maximum else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.collection.too-large",
            ownerKind: "manifest",
            field: field,
            path: path,
            details: [
                "count": String(count),
                "maximum": String(maximum)
            ],
            legacyMessage: "Manifest has too many \(label)."
        ))
    }

    private static func appendIdentifierDiagnostic(
        _ value: String,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard value.count > ManifestImportLimits.maximumIdentifierLength else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.id.too-long",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "actualLength": String(value.count),
                "maximum": String(ManifestImportLimits.maximumIdentifierLength)
            ],
            legacyMessage: legacyMessage
        ))
    }

    private static func appendTextDiagnostic(
        _ value: String,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard value.count > ManifestImportLimits.maximumTextLength else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.text.too-long",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "actualLength": String(value.count),
                "maximum": String(ManifestImportLimits.maximumTextLength)
            ],
            legacyMessage: legacyMessage
        ))
    }

    private static func appendTextDiagnostics(
        _ values: [String],
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        for (index, value) in values.enumerated() {
            appendTextDiagnostic(
                value,
                ownerKind: ownerKind,
                ownerID: ownerID,
                field: field,
                path: "\(path)/\(index)",
                legacyMessage: legacyMessage,
                diagnostics: &diagnostics
            )
        }
    }

    private static func appendPathDiagnostic(
        _ value: String,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard value.count > ManifestImportLimits.maximumPathLength else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.path.too-long",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "actualLength": String(value.count),
                "maximum": String(ManifestImportLimits.maximumPathLength)
            ],
            legacyMessage: legacyMessage
        ))
    }

    private static func appendDuplicateDiagnostics(
        _ ids: [String],
        label: String,
        ownerKind: String,
        collectionPath: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        var indexesByID: [String: [Int]] = [:]
        var order: [String] = []
        for (index, id) in ids.enumerated() {
            if indexesByID[id] == nil {
                order.append(id)
            }
            indexesByID[id, default: []].append(index)
        }
        for id in order {
            let indexes = indexesByID[id] ?? []
            guard indexes.count > 1 else { continue }
            diagnostics.append(ManifestImportValidationDiagnostic(
                code: "manifest.id.duplicate",
                ownerKind: ownerKind,
                ownerID: id,
                field: "id",
                path: "\(collectionPath)/\(indexes[1])/id",
                details: [
                    "duplicateID": id,
                    "count": String(indexes.count),
                    "firstIndex": String(indexes[0]),
                    "duplicateIndex": String(indexes[1]),
                    "indexes": indexes.map(String.init).joined(separator: ",")
                ],
                legacyMessage: "Duplicate \(label) id \(id)."
            ))
        }
    }

    private static func scopeDiagnostic(
        code: String,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        ManifestImportValidationDiagnostic(
            code: code,
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            legacyMessage: legacyMessage
        )
    }

    private static func missingReferenceDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referencedOwnerKind: String,
        referencedOwnerID: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        ManifestImportValidationDiagnostic(
            code: "manifest.reference.missing",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "referencedOwnerKind": referencedOwnerKind,
                "referencedOwnerID": referencedOwnerID
            ],
            legacyMessage: legacyMessage
        )
    }

    private static func crossWorkspaceDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referencedOwnerKind: String,
        referencedOwnerID: String,
        ownerWorkspaceID: String?,
        referencedWorkspaceID: String?,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        var details = [
            "referencedOwnerKind": referencedOwnerKind,
            "referencedOwnerID": referencedOwnerID
        ]
        if let ownerWorkspaceID {
            details["ownerWorkspaceID"] = ownerWorkspaceID
        }
        if let referencedWorkspaceID {
            details["referencedWorkspaceID"] = referencedWorkspaceID
        }
        return ManifestImportValidationDiagnostic(
            code: "manifest.reference.cross-workspace",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: details,
            legacyMessage: legacyMessage
        )
    }

    private static func crossCanvasDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referencedOwnerKind: String,
        referencedOwnerID: String,
        ownerCanvasID: String,
        referencedCanvasID: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        ManifestImportValidationDiagnostic(
            code: "manifest.reference.cross-canvas",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "referencedOwnerKind": referencedOwnerKind,
                "referencedOwnerID": referencedOwnerID,
                "ownerCanvasID": ownerCanvasID,
                "referencedCanvasID": referencedCanvasID
            ],
            legacyMessage: legacyMessage
        )
    }

    private static func appendEmptyIDDiagnostics(
        _ ids: [String],
        label: String,
        ownerKind: String,
        collectionPath: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        for (index, id) in ids.enumerated() where id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(ManifestImportValidationDiagnostic(
                code: "manifest.id.empty",
                ownerKind: ownerKind,
                field: "id",
                path: "\(collectionPath)/\(index)/id",
                legacyMessage: "\(label) has empty id."
            ))
        }
    }

    private static func appendUnsupportedValueDiagnostic(
        _ value: String,
        allowed: Set<String>,
        ownerKind: String,
        ownerID: String,
        field: String,
        fieldDescription: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard !allowed.contains(value) else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.field.unsupported-value",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "actual": value,
                "allowedValues": allowed.sorted().joined(separator: ",")
            ],
            legacyMessage: legacyMessage
        ))
    }

    private static func unsupportedReferenceTargetDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referencedOwnerKind: String,
        referencedOwnerID: String,
        expectedTargetType: String,
        actualTargetType: String?,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        var details = [
            "referencedOwnerKind": referencedOwnerKind,
            "referencedOwnerID": referencedOwnerID,
            "expectedTargetType": expectedTargetType
        ]
        if let actualTargetType {
            details["actualTargetType"] = actualTargetType
        }
        return ManifestImportValidationDiagnostic(
            code: "manifest.reference.unsupported-target",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: details,
            legacyMessage: legacyMessage
        )
    }

    private static func incompatibleObjectReferenceDiagnostic(
        ownerID: String,
        nodeType: String,
        objectType: String,
        path: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        var details = [
            "nodeType": nodeType,
            "objectTypeStatus": allowedObjectTypes.contains(objectType) ? "recognized" : "unsupported",
            "allowedObjectTypes": allowedObjectTypes.sorted().joined(separator: ",")
        ]
        details["objectType"] = allowedObjectTypes.contains(objectType) ? objectType : "unsupported"
        return ManifestImportValidationDiagnostic(
            code: "manifest.reference.incompatible",
            ownerKind: "node",
            ownerID: ownerID,
            field: "objectType",
            path: path,
            details: details,
            legacyMessage: legacyMessage
        )
    }

    private static func invalidWebURLDiagnostic(
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        ManifestImportValidationDiagnostic(
            code: "manifest.reference.invalid-url",
            ownerKind: "node",
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "objectType": "webURL",
                "sourceField": field,
                "allowedSchemes": "http,https"
            ],
            legacyMessage: legacyMessage
        )
    }

    private static func referenceIDRequiredDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referenceDetails: [String: String],
        reason: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        var details = referenceDetails
        details["reason"] = reason
        return ManifestImportValidationDiagnostic(
            code: "manifest.reference.id-required",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: details,
            legacyMessage: legacyMessage
        )
    }

    private static func referenceIDWhitespaceDiagnostic(
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        referenceDetails: [String: String],
        normalizedReferenceIDLength: Int,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        var details = referenceDetails
        details["normalizedReferenceIDLength"] = String(normalizedReferenceIDLength)
        return ManifestImportValidationDiagnostic(
            code: "manifest.reference.id-whitespace",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: details,
            legacyMessage: legacyMessage
        )
    }

    private static func unsupportedAliasSourceTypeDiagnostic(
        ownerID: String,
        path: String,
        legacyMessage: String
    ) -> ManifestImportValidationDiagnostic {
        ManifestImportValidationDiagnostic(
            code: "manifest.alias.source-type.unsupported",
            ownerKind: "alias",
            ownerID: ownerID,
            field: "sourceObjectType",
            path: path,
            details: [
                "allowedSourceObjectTypes": WorkbenchObjectReferencePolicy.importableAliasSourceTypes.sorted().joined(separator: ",")
            ],
            legacyMessage: legacyMessage
        )
    }

    private static func appendRangeDiagnostic(
        _ value: Double,
        minimum: Double,
        maximum: Double,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        guard !value.isFinite || value < minimum || value > maximum else { return }
        diagnostics.append(ManifestImportValidationDiagnostic(
            code: "manifest.range.out-of-bounds",
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            details: [
                "actualNumber": String(value),
                "minimum": String(minimum),
                "maximum": String(maximum)
            ],
            legacyMessage: legacyMessage
        ))
    }

    private static func appendCanvasCoordinateDiagnostic(
        _ value: Double,
        ownerKind: String,
        ownerID: String,
        field: String,
        path: String,
        legacyMessage: String,
        diagnostics: inout [ManifestImportValidationDiagnostic]
    ) {
        appendRangeDiagnostic(
            value,
            minimum: -ManifestImportLimits.maximumCanvasCoordinate,
            maximum: ManifestImportLimits.maximumCanvasCoordinate,
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            path: path,
            legacyMessage: legacyMessage,
            diagnostics: &diagnostics
        )
    }

    private static let allowedResourceTargetTypes: Set<String> = ["file", "folder"]
    private static let allowedResourceStatuses: Set<String> = ["available", "unavailable", "staleAuthorization", "missingVolume"]
    private static let allowedScopes: Set<String> = ["global", "workspace"]
    private static let allowedSnippetKinds: Set<String> = ["prompt", "command"]
    private static let allowedNodeTypes: Set<String> = ["resource", "snippet", "note", "groupFrame"]
    private static let allowedObjectTypes: Set<String> = WorkbenchObjectReferencePolicy.importableCanvasObjectTypes
    private static let allowedNodeStyles: Set<String> = ["default"]
    private static let allowedArrowStyles: Set<String> = ["none", "arrow"]
    private static let allowedAnimationThemes: Set<String> = ["blue", "minimal", "off"]
    private static let allowedAliasStatuses: Set<String> = ["created", "missing", "failed", "staleAuthorization"]
    private static let allowedLegacyAccentColors: Set<String> = ["blue"]

    private static func cyclicParentIssues(
        for nodes: [CanvasNodeRecord],
        nodeCanvasById: [String: String]
    ) -> [String] {
        let parentById = Dictionary(
            nodes.compactMap { node -> (String, String)? in
                guard let parentNodeId = node.parentNodeId else { return nil }
                return (node.id, parentNodeId)
            },
            uniquingKeysWith: { first, _ in first }
        )
        var reportedCycleKeys: Set<String> = []
        var issues: [String] = []

        for node in nodes {
            var path: [String] = []
            var visitedIndexByNodeId: [String: Int] = [:]
            var currentNodeId = node.id

            while let parentNodeId = parentById[currentNodeId],
                  nodeCanvasById[parentNodeId] == nodeCanvasById[currentNodeId] {
                visitedIndexByNodeId[currentNodeId] = path.count
                path.append(currentNodeId)

                if let cycleStartIndex = visitedIndexByNodeId[parentNodeId] {
                    let cycleNodeIds = Array(path[cycleStartIndex...])
                    let key = cycleNodeIds.sorted().joined(separator: "\u{1F}")
                    guard reportedCycleKeys.insert(key).inserted else { break }
                    let canvasId = nodeCanvasById[node.id] ?? node.canvasId
                    let reportedNodeId = cycleNodeIds.sorted().first ?? parentNodeId
                    issues.append("Canvas \(canvasId) has a cyclic frame parent relationship involving node \(reportedNodeId).")
                    break
                }

                currentNodeId = parentNodeId
            }
        }

        return issues
    }

    private static func cyclicParentDiagnostics(
        for nodes: [CanvasNodeRecord],
        nodeCanvasById: [String: String],
        nodeIndexById: [String: Int]
    ) -> [ManifestImportValidationDiagnostic] {
        let parentById = Dictionary(
            nodes.compactMap { node -> (String, String)? in
                guard let parentNodeId = node.parentNodeId else { return nil }
                return (node.id, parentNodeId)
            },
            uniquingKeysWith: { first, _ in first }
        )
        var reportedCycleKeys: Set<String> = []
        var diagnostics: [ManifestImportValidationDiagnostic] = []

        for node in nodes {
            var path: [String] = []
            var visitedIndexByNodeId: [String: Int] = [:]
            var currentNodeId = node.id

            while let parentNodeId = parentById[currentNodeId],
                  nodeCanvasById[parentNodeId] == nodeCanvasById[currentNodeId] {
                visitedIndexByNodeId[currentNodeId] = path.count
                path.append(currentNodeId)

                if let cycleStartIndex = visitedIndexByNodeId[parentNodeId] {
                    let cycleNodeIds = Array(path[cycleStartIndex...])
                    let sortedCycleNodeIds = cycleNodeIds.sorted()
                    let key = sortedCycleNodeIds.joined(separator: "\u{1F}")
                    guard reportedCycleKeys.insert(key).inserted else { break }
                    let canvasId = nodeCanvasById[node.id] ?? node.canvasId
                    let reportedNodeId = sortedCycleNodeIds.first ?? parentNodeId
                    let nodeIndex = nodeIndexById[reportedNodeId]
                    diagnostics.append(ManifestImportValidationDiagnostic(
                        code: "manifest.node.parent.cycle",
                        ownerKind: "node",
                        ownerID: reportedNodeId,
                        field: "parentNodeId",
                        path: nodeIndex.map { "/manifest/nodes/\($0)/parentNodeId" } ?? "/manifest/nodes",
                        details: [
                            "canvasID": canvasId,
                            "reportedNodeID": reportedNodeId,
                            "cycleNodeIDs": sortedCycleNodeIds.joined(separator: ",")
                        ],
                        legacyMessage: "Canvas \(canvasId) has a cyclic frame parent relationship involving node \(reportedNodeId)."
                    ))
                    break
                }

                currentNodeId = parentNodeId
            }
        }

        return diagnostics
    }

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
