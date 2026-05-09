import Foundation

public struct ExportManifest: Codable, Equatable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var workspaces: [WorkspaceRecord]
    public var resources: [ResourceRecord]
    public var snippets: [SnippetRecord]
    public var canvases: [CanvasRecord]
    public var nodes: [CanvasNodeRecord]
    public var edges: [CanvasEdgeRecord]
    public var aliases: [AliasRecord]

    public init(
        schemaVersion: Int,
        exportedAt: Date,
        workspaces: [WorkspaceRecord],
        resources: [ResourceRecord],
        snippets: [SnippetRecord],
        canvases: [CanvasRecord],
        nodes: [CanvasNodeRecord],
        edges: [CanvasEdgeRecord],
        aliases: [AliasRecord]
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
    }
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

public enum ManifestImportValidation {
    public static func issues(in manifest: ExportManifest) -> [String] {
        let workspaceIds = Set(manifest.workspaces.map(\.id))
        let resourceIds = Set(manifest.resources.map(\.id))
        let snippetIds = Set(manifest.snippets.map(\.id))
        let canvasIds = Set(manifest.canvases.map(\.id))
        let nodeIds = Set(manifest.nodes.map(\.id))
        var issues: [String] = []

        for resource in manifest.resources {
            if let workspaceId = resource.workspaceId, !workspaceIds.contains(workspaceId) {
                issues.append("Resource \(resource.id) references missing workspace \(workspaceId).")
            }
        }

        for snippet in manifest.snippets {
            if let workspaceId = snippet.workspaceId, !workspaceIds.contains(workspaceId) {
                issues.append("Snippet \(snippet.id) references missing workspace \(workspaceId).")
            }
            if let resourceId = snippet.workingDirectoryRef, !resourceIds.contains(resourceId) {
                issues.append("Snippet \(snippet.id) references missing working directory resource \(resourceId).")
            }
        }

        for canvas in manifest.canvases where !workspaceIds.contains(canvas.workspaceId) {
            issues.append("Canvas \(canvas.id) references missing workspace \(canvas.workspaceId).")
        }

        for node in manifest.nodes {
            if !canvasIds.contains(node.canvasId) {
                issues.append("Node \(node.id) references missing canvas \(node.canvasId).")
            }
            if let parentNodeId = node.parentNodeId, !nodeIds.contains(parentNodeId) {
                issues.append("Node \(node.id) references missing parent node \(parentNodeId).")
            }
            if let objectType = node.objectType, let objectId = node.objectId {
                switch objectType {
                case "workspace" where !workspaceIds.contains(objectId):
                    issues.append("Node \(node.id) references missing workspace object \(objectId).")
                case "resourcePin" where !resourceIds.contains(objectId):
                    issues.append("Node \(node.id) references missing resource object \(objectId).")
                case "snippet" where !snippetIds.contains(objectId):
                    issues.append("Node \(node.id) references missing snippet object \(objectId).")
                default:
                    break
                }
            }
        }

        for edge in manifest.edges {
            if !canvasIds.contains(edge.canvasId) {
                issues.append("Edge \(edge.id) references missing canvas \(edge.canvasId).")
            }
            if !nodeIds.contains(edge.sourceNodeId) {
                issues.append("Edge \(edge.id) references missing source node \(edge.sourceNodeId).")
            }
            if !nodeIds.contains(edge.targetNodeId) {
                issues.append("Edge \(edge.id) references missing target node \(edge.targetNodeId).")
            }
        }

        return issues
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
