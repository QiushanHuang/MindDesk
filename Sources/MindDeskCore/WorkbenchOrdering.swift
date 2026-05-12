import Foundation

public struct WorkspaceSidebarOrderRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var isPinned: Bool
    public var sortIndex: Int
    public var updatedAt: Date

    public init(id: String, isPinned: Bool, sortIndex: Int, updatedAt: Date) {
        self.id = id
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.updatedAt = updatedAt
    }
}

public enum SidebarMoveDirection: Sendable {
    case up
    case down
}

public enum WorkspaceSidebarOrdering {
    public static func ordered(_ records: [WorkspaceSidebarOrderRecord]) -> [WorkspaceSidebarOrderRecord] {
        records.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }

    public static func movedIDs(
        _ ids: [String],
        moving id: String,
        direction: SidebarMoveDirection
    ) -> [String] {
        guard let index = ids.firstIndex(of: id) else { return ids }
        var moved = ids
        switch direction {
        case .up:
            guard index > moved.startIndex else { return ids }
            moved.swapAt(index, moved.index(before: index))
        case .down:
            let nextIndex = moved.index(after: index)
            guard nextIndex < moved.endIndex else { return ids }
            moved.swapAt(index, nextIndex)
        }
        return moved
    }

    public static func movedIDs(
        _ ids: [String],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [String] {
        guard !source.isEmpty else { return ids }

        let moving = source.sorted().compactMap { index in
            ids.indices.contains(index) ? ids[index] : nil
        }
        guard !moving.isEmpty else { return ids }

        var remaining = ids
        for index in source.sorted(by: >) where remaining.indices.contains(index) {
            remaining.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertionIndex)
        return remaining
    }

    public static func keepsPinnedPrefix(_ ids: [String], pinnedIDs: Set<String>) -> Bool {
        var hasSeenUnpinned = false
        for id in ids {
            if pinnedIDs.contains(id) {
                guard !hasSeenUnpinned else { return false }
            } else {
                hasSeenUnpinned = true
            }
        }
        return true
    }
}

public struct WorkspaceDeletionCanvasRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workspaceId: String

    public init(id: String, workspaceId: String) {
        self.id = id
        self.workspaceId = workspaceId
    }
}

public struct WorkspaceDeletionNodeRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var canvasId: String
    public var objectType: String?
    public var objectId: String?

    public init(id: String, canvasId: String, objectType: String?, objectId: String?) {
        self.id = id
        self.canvasId = canvasId
        self.objectType = objectType
        self.objectId = objectId
    }
}

public struct WorkspaceDeletionEdgeRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var canvasId: String
    public var sourceNodeId: String
    public var targetNodeId: String

    public init(id: String, canvasId: String, sourceNodeId: String, targetNodeId: String) {
        self.id = id
        self.canvasId = canvasId
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }
}

public struct WorkspaceDeletionSnippetRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var workingDirectoryRef: String?

    public init(id: String, workingDirectoryRef: String?) {
        self.id = id
        self.workingDirectoryRef = workingDirectoryRef
    }
}

public struct WorkspaceDeletionPlan: Equatable, Sendable {
    public var nodeIds: [String]
    public var edgeIds: [String]
    public var snippetIdsClearingWorkingDirectory: [String]

    public init(
        nodeIds: [String],
        edgeIds: [String],
        snippetIdsClearingWorkingDirectory: [String]
    ) {
        self.nodeIds = nodeIds
        self.edgeIds = edgeIds
        self.snippetIdsClearingWorkingDirectory = snippetIdsClearingWorkingDirectory
    }
}

public enum WorkspaceDeletionPolicy {
    public static func plan(
        workspaceId: String,
        canvases: [WorkspaceDeletionCanvasRecord],
        nodes: [WorkspaceDeletionNodeRecord],
        edges: [WorkspaceDeletionEdgeRecord],
        snippets: [WorkspaceDeletionSnippetRecord],
        resourceIds: Set<String>,
        snippetIds: Set<String>
    ) -> WorkspaceDeletionPlan {
        let workspaceCanvasIds = Set(canvases.filter { $0.workspaceId == workspaceId }.map(\.id))
        let nodeIds = Set(nodes.compactMap { node -> String? in
            if workspaceCanvasIds.contains(node.canvasId) {
                return node.id
            }
            if node.objectType == "workspace", node.objectId == workspaceId {
                return node.id
            }
            if node.objectType == "resourcePin",
               let objectId = node.objectId,
               resourceIds.contains(objectId) {
                return node.id
            }
            if node.objectType == "snippet",
               let objectId = node.objectId,
               snippetIds.contains(objectId) {
                return node.id
            }
            return nil
        })
        let edgeIds = Set(edges.compactMap { edge -> String? in
            workspaceCanvasIds.contains(edge.canvasId) ||
                nodeIds.contains(edge.sourceNodeId) ||
                nodeIds.contains(edge.targetNodeId)
                ? edge.id
                : nil
        })
        let snippetIdsClearingWorkingDirectory = Set(snippets.compactMap { snippet -> String? in
            guard let ref = snippet.workingDirectoryRef, resourceIds.contains(ref) else { return nil }
            return snippet.id
        })

        return WorkspaceDeletionPlan(
            nodeIds: nodeIds.sorted(),
            edgeIds: edgeIds.sorted(),
            snippetIdsClearingWorkingDirectory: snippetIdsClearingWorkingDirectory.sorted()
        )
    }
}

public enum WorkbenchSidebarMetrics {
    public static let minimumWidth: Double = 208
    public static let idealWidth: Double = 224
    public static let maximumWidth: Double = 300
}

public enum CanvasSideRailLayout {
    public static let leftRailWidth: Double = 196
    public static let rightRailMinimumWidth: Double = 180
    public static let rightRailIdealWidth: Double = 244

    public static func rightRailWidth(availableWidth: Double) -> Double {
        min(rightRailIdealWidth, max(rightRailMinimumWidth, floor(availableWidth * 0.22)))
    }
}

public struct ResourceLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var targetType: String
    public var title: String
    public var originalName: String
    public var customName: String
    public var displayPath: String
    public var lastResolvedPath: String
    public var isPinned: Bool
    public var updatedAt: Date
    public var sortIndex: Int
    public var scope: String
    public var workspaceId: String?

    public init(
        id: String,
        targetType: String,
        title: String,
        originalName: String,
        customName: String,
        displayPath: String,
        lastResolvedPath: String = "",
        isPinned: Bool,
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        sortIndex: Int = 0,
        scope: String = "global",
        workspaceId: String? = nil
    ) {
        self.id = id
        self.targetType = targetType
        self.title = title
        self.originalName = originalName
        self.customName = customName
        self.displayPath = displayPath
        self.lastResolvedPath = lastResolvedPath.isEmpty ? displayPath : lastResolvedPath
        self.isPinned = isPinned
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
        self.scope = scope
        self.workspaceId = workspaceId
    }

    public var displayName: String {
        let trimmedOriginal = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCustom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedOriginal.isEmpty ? fallback : trimmedOriginal

        guard !trimmedCustom.isEmpty, trimmedCustom != base else {
            return base
        }
        return "\(base) · \(trimmedCustom)"
    }
}

public enum ResourceLibraryFiltering {
    public static func folders(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.targetType == "folder" })
    }

    public static func files(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.targetType == "file" })
    }

    public static func pinnedFolders(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.isPinned && $0.targetType == "folder" })
    }

    public static func pinnedFiles(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.isPinned && $0.targetType == "file" })
    }

    public static func ordered(_ records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        records.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            let nameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}

public enum ResourceFinderAction: Equatable, Sendable {
    case open
    case reveal
}

public enum ResourceFinderRouting {
    public static func doubleClickAction(forTargetType targetType: String) -> ResourceFinderAction {
        targetType == "file" ? .reveal : .open
    }
}

public struct SnippetLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var scope: String
    public var workspaceId: String?
    public var title: String
    public var updatedAt: Date

    public init(id: String, scope: String, workspaceId: String?, title: String, updatedAt: Date) {
        self.id = id
        self.scope = scope
        self.workspaceId = workspaceId
        self.title = title
        self.updatedAt = updatedAt
    }
}

public enum SnippetLibraryFiltering {
    public static func visible(
        _ records: [SnippetLibraryRecord],
        scope: String?,
        workspaceId: String?
    ) -> [SnippetLibraryRecord] {
        let filtered = records.filter { record in
            guard let scope else { return true }
            if scope == "global" {
                return record.scope == "global"
            }
            return record.scope == "global" || record.workspaceId == workspaceId
        }
        return ordered(filtered)
    }

    public static func ordered(_ records: [SnippetLibraryRecord]) -> [SnippetLibraryRecord] {
        records.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            let nameComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}

public enum CommandRunConfirmationPolicy {
    public static func shouldConfirm(kind: String, requiresConfirmation _: Bool) -> Bool {
        kind == "command"
    }
}

public enum SnippetImportTrustPolicy {
    public static func requiresConfirmation(kind: String, exportedRequiresConfirmation: Bool) -> Bool {
        kind == "command" ? true : exportedRequiresConfirmation
    }
}

public enum ResourceAuthorizationPolicy {
    public static func canAccessFileSystem(status: String, hasBookmarkData: Bool) -> Bool {
        hasBookmarkData && status == "available"
    }

    public static func acceptsReauthorization(existingTargetType: String, selectedTargetType: String) -> Bool {
        existingTargetType == selectedTargetType
    }
}

public enum SnippetWorkingDirectoryOptions {
    public static func folders(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ResourceLibraryFiltering.folders(in: records)
    }

    public static func validSelection(_ id: String?, in records: [ResourceLibraryRecord]) -> String? {
        guard let id else { return nil }
        return folders(in: records).contains { $0.id == id } ? id : nil
    }
}

public struct FolderPreviewItemRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isDirectory: Bool

    public init(id: String, name: String, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
    }
}

public enum FolderPreviewOrdering {
    public static func ordered(_ records: [FolderPreviewItemRecord]) -> [FolderPreviewItemRecord] {
        records.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}

public enum CanvasEdgeAnimationPolicy {
    public static func shouldAnimateEdge(
        theme: String,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        edgeCount: Int,
        isInteracting: Bool = false
    ) -> Bool {
        animationsEnabled &&
        !reduceMotion &&
        !isInteracting &&
        theme != "off" &&
        edgeCount > 0 &&
        edgeCount <= CanvasPerformancePolicy.maximumAnimatedEdgeCount
    }
}

public enum CanvasPerformancePolicy {
    public static let maximumAnimatedEdgeCount = 16
    public static let maximumRoutedEdgeCount = 24
    public static let maximumRoutingObstacleCount = 40
    public static let maximumRoutingWorkload = 900

    public static func usesObstacleRouting(edgeCount: Int, obstacleCount: Int, isInteracting: Bool) -> Bool {
        guard !isInteracting, edgeCount > 0, obstacleCount >= 0 else { return false }
        guard edgeCount <= maximumRoutedEdgeCount, obstacleCount <= maximumRoutingObstacleCount else { return false }
        guard obstacleCount > 0 else { return false }
        return edgeCount <= maximumRoutingWorkload / obstacleCount
    }
}

public struct CanvasNodeSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum CanvasNodeSizePolicy {
    public static func size(
        kind _: String,
        storedWidth: Double,
        storedHeight: Double,
        defaultWidth: Double,
        defaultHeight: Double,
        minimumWidth: Double,
        minimumHeight: Double
    ) -> CanvasNodeSize {
        let widthBase = storedWidth > 0 ? storedWidth : defaultWidth
        let heightBase = storedHeight > 0 ? storedHeight : defaultHeight
        return CanvasNodeSize(
            width: max(widthBase, minimumWidth),
            height: max(heightBase, minimumHeight)
        )
    }
}

public enum CanvasCardTitleLayoutPolicy {
    public static func maxTitleHeight(kind: String, cardHeight: Double) -> Double {
        let safeHeight = max(cardHeight, 0)
        if kind == "note" {
            return min(36, max(18, safeHeight * 0.10))
        }
        return min(70, max(30, safeHeight * 0.20))
    }

    public static func minTitleHeight(kind: String) -> Double {
        kind == "note" ? 18 : 24
    }
}

public enum CanvasChromeTextRole: Sendable {
    case cardHeader
    case cardDetailLabel
    case cardDetailBody
    case frameNote
}

public enum CanvasChromeRenderingPolicy {
    public static func requiresNativeDrawing(_ role: CanvasChromeTextRole) -> Bool {
        switch role {
        case .cardHeader, .cardDetailLabel, .cardDetailBody, .frameNote:
            return true
        }
    }
}

public struct CanvasEdgeIdentity: Equatable, Sendable {
    public var sourceNodeId: String
    public var targetNodeId: String

    public init(sourceNodeId: String, targetNodeId: String) {
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }

    public static func exists(
        sourceNodeId: String,
        targetNodeId: String,
        in edges: [CanvasEdgeIdentity]
    ) -> Bool {
        edges.contains { $0.sourceNodeId == sourceNodeId && $0.targetNodeId == targetNodeId }
    }
}

public struct CanvasEdgeEndpointRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var sourceNodeId: String
    public var targetNodeId: String

    public init(id: String, sourceNodeId: String, targetNodeId: String) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }
}

public struct CanvasEdgeDirectionRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var sourceNodeId: String
    public var targetNodeId: String
    public var sourceArrow: String
    public var targetArrow: String

    public init(
        id: String,
        sourceNodeId: String,
        targetNodeId: String,
        sourceArrow: String,
        targetArrow: String
    ) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
    }
}

public enum CanvasEdgeDirectionPolicy {
    public static func canReverse(
        _ record: CanvasEdgeDirectionRecord,
        existingEdges: [CanvasEdgeEndpointRecord]
    ) -> Bool {
        !existingEdges.contains { edge in
            edge.id != record.id &&
            edge.sourceNodeId == record.targetNodeId &&
            edge.targetNodeId == record.sourceNodeId
        }
    }

    public static func reversed(_ record: CanvasEdgeDirectionRecord) -> CanvasEdgeDirectionRecord {
        CanvasEdgeDirectionRecord(
            id: record.id,
            sourceNodeId: record.targetNodeId,
            targetNodeId: record.sourceNodeId,
            sourceArrow: "none",
            targetArrow: record.targetArrow == "none" ? "arrow" : record.targetArrow
        )
    }
}

public enum CanvasEdgeDeletionPolicy {
    public static func edgeIDsToDelete(
        selectedEdgeIDs: Set<String>,
        selectedNodeIDs: Set<String>,
        edges: [CanvasEdgeEndpointRecord]
    ) -> [String] {
        if !selectedEdgeIDs.isEmpty {
            return edges.filter { selectedEdgeIDs.contains($0.id) }.map(\.id)
        }

        guard selectedNodeIDs.count == 2 else { return [] }
        let selected = Array(selectedNodeIDs)
        let matches = edges.filter { edge in
            selectedNodeIDs.contains(edge.sourceNodeId) &&
            selectedNodeIDs.contains(edge.targetNodeId) &&
            edge.sourceNodeId != edge.targetNodeId
        }
        guard matches.count == 1,
              let edge = matches.first,
              selected.contains(edge.sourceNodeId),
              selected.contains(edge.targetNodeId) else {
            return []
        }
        return [edge.id]
    }
}

public enum CanvasNodeDeletionPolicy {
    public static func incidentEdgeIDs(
        selectedNodeIDs: Set<String>,
        edges: [CanvasEdgeEndpointRecord]
    ) -> [String] {
        guard !selectedNodeIDs.isEmpty else { return [] }
        return edges
            .filter { selectedNodeIDs.contains($0.sourceNodeId) || selectedNodeIDs.contains($0.targetNodeId) }
            .map(\.id)
    }
}

public enum CanvasNodeObjectReferenceMapper {
    public static func mappedObjectId(
        objectType: String?,
        objectId: String?,
        body: String = "",
        resourceMap: [String: String],
        snippetMap: [String: String],
        workspaceMap: [String: String]
    ) -> String? {
        switch objectType {
        case "resourcePin":
            objectId.flatMap { resourceMap[$0] }
        case "snippet":
            objectId.flatMap { snippetMap[$0] }
        case "workspace":
            objectId.flatMap { workspaceMap[$0] }
        case "webURL":
            objectId.flatMap(WebCardURL.normalized(_:))?.absoluteString ??
                WebCardURL.normalized(body)?.absoluteString
        case nil:
            nil
        default:
            objectId
        }
    }
}

public enum CanvasManifestParentMapper {
    public static func mappedParentNodeId(
        _ parentNodeId: String?,
        nodeMap: [String: String]
    ) -> String? {
        parentNodeId.flatMap { nodeMap[$0] }
    }
}

public struct CanvasEdgeHitRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var points: [CanvasEdgePoint]

    public init(id: String, points: [CanvasEdgePoint]) {
        self.id = id
        self.points = points
    }
}

public enum CanvasEdgeHitTesting {
    public static func nearestEdgeID(
        at point: CanvasEdgePoint,
        edges: [CanvasEdgeHitRecord],
        threshold: Double
    ) -> String? {
        var best: (id: String, distance: Double)?
        for edge in edges {
            let distance = distanceToPolyline(point, points: edge.points)
            guard distance <= threshold else { continue }
            if best == nil || distance < best!.distance {
                best = (edge.id, distance)
            }
        }
        return best?.id
    }

    private static func distanceToPolyline(_ point: CanvasEdgePoint, points: [CanvasEdgePoint]) -> Double {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        return points.indices.dropLast().map { index in
            distanceFromPoint(point, toSegmentStart: points[index], end: points[index + 1])
        }.min() ?? .greatestFiniteMagnitude
    }

    private static func distanceFromPoint(
        _ point: CanvasEdgePoint,
        toSegmentStart start: CanvasEdgePoint,
        end: CanvasEdgePoint
    ) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0.0001 else {
            return distance(point, start)
        }
        let rawT = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let t = min(max(rawT, 0), 1)
        let projected = CanvasEdgePoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(point, projected)
    }

    private static func distance(_ lhs: CanvasEdgePoint, _ rhs: CanvasEdgePoint) -> Double {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt(dx * dx + dy * dy)
    }
}

public struct CanvasFrameRect: Equatable, Identifiable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CanvasEdgePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasEdgeAnchorPair: Equatable, Sendable {
    public var start: CanvasEdgePoint
    public var end: CanvasEdgePoint
    public var startDirection: CanvasEdgePoint
    public var endDirection: CanvasEdgePoint

    public init(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint = CanvasEdgePoint(x: 1, y: 0),
        endDirection: CanvasEdgePoint = CanvasEdgePoint(x: 1, y: 0)
    ) {
        self.start = start
        self.end = end
        self.startDirection = startDirection
        self.endDirection = endDirection
    }
}

public struct CanvasEdgeCubicControls: Equatable, Sendable {
    public var control1: CanvasEdgePoint
    public var control2: CanvasEdgePoint

    public init(control1: CanvasEdgePoint, control2: CanvasEdgePoint) {
        self.control1 = control1
        self.control2 = control2
    }
}

public struct CanvasEdgeControlSegments: Equatable, Sendable {
    public var first: CanvasEdgeCubicControls
    public var second: CanvasEdgeCubicControls

    public init(first: CanvasEdgeCubicControls, second: CanvasEdgeCubicControls) {
        self.first = first
        self.second = second
    }
}

public enum CanvasEdgeAnchoring {
    private struct ResolvedAnchor {
        var point: CanvasEdgePoint
        var outwardDirection: CanvasEdgePoint
    }

    public static func anchors(
        source: CanvasFrameRect,
        target: CanvasFrameRect,
        control: CanvasEdgePoint? = nil,
        targetClearance: Double = 0
    ) -> CanvasEdgeAnchorPair {
        let sourceToward = control ?? center(of: target)
        let targetToward = control ?? center(of: source)
        let sourceAnchor = anchor(on: source, toward: sourceToward)
        let targetAnchor = anchor(on: target, toward: targetToward, clearance: targetClearance)

        return CanvasEdgeAnchorPair(
            start: sourceAnchor.point,
            end: targetAnchor.point,
            startDirection: sourceAnchor.outwardDirection,
            endDirection: CanvasEdgePoint(x: -targetAnchor.outwardDirection.x, y: -targetAnchor.outwardDirection.y)
        )
    }

    private static func center(of rect: CanvasFrameRect) -> CanvasEdgePoint {
        CanvasEdgePoint(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
    }

    private static func anchor(
        on rect: CanvasFrameRect,
        toward point: CanvasEdgePoint,
        clearance: Double = 0
    ) -> ResolvedAnchor {
        let center = center(of: rect)
        let dx = point.x - center.x
        let dy = point.y - center.y

        if abs(dx) >= abs(dy) {
            return dx >= 0
                ? ResolvedAnchor(
                    point: CanvasEdgePoint(x: rect.x + rect.width + clearance, y: center.y),
                    outwardDirection: CanvasEdgePoint(x: 1, y: 0)
                )
                : ResolvedAnchor(
                    point: CanvasEdgePoint(x: rect.x - clearance, y: center.y),
                    outwardDirection: CanvasEdgePoint(x: -1, y: 0)
                )
        }

        return dy >= 0
            ? ResolvedAnchor(
                point: CanvasEdgePoint(x: center.x, y: rect.y + rect.height + clearance),
                outwardDirection: CanvasEdgePoint(x: 0, y: 1)
            )
            : ResolvedAnchor(
                point: CanvasEdgePoint(x: center.x, y: rect.y - clearance),
                outwardDirection: CanvasEdgePoint(x: 0, y: -1)
            )
    }
}

public enum CanvasEdgeCurveGeometry {
    public static func automaticControls(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint
    ) -> CanvasEdgeCubicControls {
        let distance = distance(start, end)
        let handle = handleLength(for: distance)
        let startVector = normalized(startDirection, fallback: vector(from: start, to: end))
        let endVector = normalized(endDirection, fallback: vector(from: start, to: end))

        return CanvasEdgeCubicControls(
            control1: CanvasEdgePoint(
                x: start.x + startVector.x * handle,
                y: start.y + startVector.y * handle
            ),
            control2: CanvasEdgePoint(
                x: end.x - endVector.x * handle,
                y: end.y - endVector.y * handle
            )
        )
    }

    public static func controlsThroughPoint(
        start: CanvasEdgePoint,
        control: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint
    ) -> CanvasEdgeControlSegments {
        let incoming = normalized(vector(from: start, to: control), fallback: vector(from: start, to: end))
        let outgoing = normalized(vector(from: control, to: end), fallback: vector(from: start, to: end))
        let tangent = normalized(
            CanvasEdgePoint(x: incoming.x + outgoing.x, y: incoming.y + outgoing.y),
            fallback: vector(from: start, to: end)
        )
        let firstDistance = distance(start, control)
        let secondDistance = distance(control, end)
        let firstStartHandle = handleLength(for: firstDistance)
        let firstEndHandle = handleLength(for: firstDistance)
        let secondStartHandle = handleLength(for: secondDistance)
        let secondEndHandle = handleLength(for: secondDistance)
        let startVector = normalized(startDirection, fallback: vector(from: start, to: control))
        let endVector = normalized(endDirection, fallback: vector(from: control, to: end))

        return CanvasEdgeControlSegments(
            first: CanvasEdgeCubicControls(
                control1: CanvasEdgePoint(
                    x: start.x + startVector.x * firstStartHandle,
                    y: start.y + startVector.y * firstStartHandle
                ),
                control2: CanvasEdgePoint(
                    x: control.x - tangent.x * firstEndHandle,
                    y: control.y - tangent.y * firstEndHandle
                )
            ),
            second: CanvasEdgeCubicControls(
                control1: CanvasEdgePoint(
                    x: control.x + tangent.x * secondStartHandle,
                    y: control.y + tangent.y * secondStartHandle
                ),
                control2: CanvasEdgePoint(
                    x: end.x - endVector.x * secondEndHandle,
                    y: end.y - endVector.y * secondEndHandle
                )
            )
        )
    }

    public static func terminalAngleRadians(endDirection: CanvasEdgePoint) -> Double {
        let direction = normalized(endDirection, fallback: CanvasEdgePoint(x: 1, y: 0))
        return atan2(direction.y, direction.x)
    }

    private static func handleLength(for distance: Double) -> Double {
        guard distance > 0 else { return 0 }
        let maximum = min(140, distance * 0.5)
        let minimum = min(28, maximum)
        return min(max(distance * 0.42, minimum), maximum)
    }

    private static func distance(_ lhs: CanvasEdgePoint, _ rhs: CanvasEdgePoint) -> Double {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func vector(from start: CanvasEdgePoint, to end: CanvasEdgePoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: end.x - start.x, y: end.y - start.y)
    }

    private static func normalized(_ vector: CanvasEdgePoint, fallback: CanvasEdgePoint) -> CanvasEdgePoint {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y)
        if length > 0.0001 {
            return CanvasEdgePoint(x: vector.x / length, y: vector.y / length)
        }

        let fallbackLength = sqrt(fallback.x * fallback.x + fallback.y * fallback.y)
        if fallbackLength > 0.0001 {
            return CanvasEdgePoint(x: fallback.x / fallbackLength, y: fallback.y / fallbackLength)
        }

        return CanvasEdgePoint(x: 1, y: 0)
    }
}

public enum CanvasEdgeRoutePlanner {
    public static func routePoints(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        waypoints: [CanvasEdgePoint],
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint,
        obstacles: [CanvasFrameRect],
        clearance: Double = 24
    ) -> [CanvasEdgePoint] {
        guard !waypoints.isEmpty else {
            return routePoints(
                start: start,
                end: end,
                startDirection: startDirection,
                endDirection: endDirection,
                obstacles: obstacles,
                clearance: clearance
            )
        }

        let requiredPoints = [start] + waypoints + [end]
        guard polylineIntersectsObstacles(requiredPoints, obstacles: obstacles, clearance: clearance) else {
            return []
        }

        var route: [CanvasEdgePoint] = []
        for index in requiredPoints.indices.dropLast() {
            let segmentStart = requiredPoints[index]
            let segmentEnd = requiredPoints[index + 1]
            let segmentStartDirection = index == requiredPoints.startIndex
                ? startDirection
                : vector(from: segmentStart, to: segmentEnd)
            let segmentEndDirection = index == requiredPoints.index(before: requiredPoints.endIndex) - 1
                ? endDirection
                : vector(from: segmentStart, to: segmentEnd)
            route.append(contentsOf: routePoints(
                start: segmentStart,
                end: segmentEnd,
                startDirection: segmentStartDirection,
                endDirection: segmentEndDirection,
                obstacles: obstacles,
                clearance: clearance
            ))
            if index + 1 < requiredPoints.index(before: requiredPoints.endIndex) {
                route.append(segmentEnd)
            }
        }

        return route
    }

    public static func routePoints(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint,
        obstacles: [CanvasFrameRect],
        clearance: Double = 24
    ) -> [CanvasEdgePoint] {
        guard polylineIntersectsObstacles([start, end], obstacles: obstacles, clearance: clearance) else {
            return []
        }

        let expandedObstacles = obstacles.map { expanded($0, by: clearance) }
        let blockingObstacles = expandedObstacles.filter { segmentIntersectsRect(start, end, $0) }
        let routeObstacles = blockingObstacles.isEmpty ? expandedObstacles : blockingObstacles
        let lead = max(28, clearance * 1.25)
        let sourceLead = safeLead(
            from: start,
            direction: startDirection,
            distance: lead,
            avoiding: expandedObstacles
        )
        let targetLead = safeLead(
            from: end,
            direction: CanvasEdgePoint(x: -endDirection.x, y: -endDirection.y),
            distance: lead,
            avoiding: expandedObstacles
        )
        var candidates: [[CanvasEdgePoint]] = []

        for obstacle in routeObstacles {
            let topLane = obstacle.y - clearance
            let bottomLane = obstacle.y + obstacle.height + clearance
            let leftLane = obstacle.x - clearance
            let rightLane = obstacle.x + obstacle.width + clearance

            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: sourceLead.x, y: topLane), CanvasEdgePoint(x: targetLead.x, y: topLane), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: sourceLead.x, y: bottomLane), CanvasEdgePoint(x: targetLead.x, y: bottomLane), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: leftLane, y: sourceLead.y), CanvasEdgePoint(x: leftLane, y: targetLead.y), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: rightLane, y: sourceLead.y), CanvasEdgePoint(x: rightLane, y: targetLead.y), targetLead]))
        }

        let clearCandidates = candidates.filter { candidate in
            !polylineIntersectsObstacles([start] + candidate + [end], obstacles: obstacles, clearance: clearance)
        }
        let candidatesToScore = clearCandidates.isEmpty ? candidates : clearCandidates

        return candidatesToScore
            .min { score([start] + $0 + [end]) < score([start] + $1 + [end]) } ?? []
    }

    public static func polylineIntersectsObstacles(
        _ points: [CanvasEdgePoint],
        obstacles: [CanvasFrameRect],
        clearance: Double = 0
    ) -> Bool {
        guard points.count >= 2, !obstacles.isEmpty else { return false }
        let expandedObstacles = obstacles.map { expanded($0, by: clearance) }
        for index in points.indices.dropLast() {
            let start = points[index]
            let end = points[index + 1]
            if expandedObstacles.contains(where: { segmentIntersectsRect(start, end, $0) }) {
                return true
            }
        }
        return false
    }

    private static func offset(_ point: CanvasEdgePoint, direction: CanvasEdgePoint, distance: Double) -> CanvasEdgePoint {
        let vector = normalized(direction, fallback: CanvasEdgePoint(x: 1, y: 0))
        return CanvasEdgePoint(x: point.x + vector.x * distance, y: point.y + vector.y * distance)
    }

    private static func safeLead(
        from point: CanvasEdgePoint,
        direction: CanvasEdgePoint,
        distance: Double,
        avoiding obstacles: [CanvasFrameRect]
    ) -> CanvasEdgePoint {
        let lead = offset(point, direction: direction, distance: distance)
        return obstacles.contains(where: { contains(lead, in: $0) }) ? point : lead
    }

    private static func expanded(_ rect: CanvasFrameRect, by clearance: Double) -> CanvasFrameRect {
        CanvasFrameRect(
            id: rect.id,
            x: rect.x - clearance,
            y: rect.y - clearance,
            width: rect.width + clearance * 2,
            height: rect.height + clearance * 2
        )
    }

    private static func segmentIntersectsRect(_ start: CanvasEdgePoint, _ end: CanvasEdgePoint, _ rect: CanvasFrameRect) -> Bool {
        if contains(start, in: rect) || contains(end, in: rect) {
            return true
        }

        let topLeft = CanvasEdgePoint(x: rect.x, y: rect.y)
        let topRight = CanvasEdgePoint(x: rect.x + rect.width, y: rect.y)
        let bottomLeft = CanvasEdgePoint(x: rect.x, y: rect.y + rect.height)
        let bottomRight = CanvasEdgePoint(x: rect.x + rect.width, y: rect.y + rect.height)

        return segmentsIntersect(start, end, topLeft, topRight) ||
            segmentsIntersect(start, end, topRight, bottomRight) ||
            segmentsIntersect(start, end, bottomRight, bottomLeft) ||
            segmentsIntersect(start, end, bottomLeft, topLeft)
    }

    private static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect) -> Bool {
        point.x >= rect.x &&
            point.x <= rect.x + rect.width &&
            point.y >= rect.y &&
            point.y <= rect.y + rect.height
    }

    private static func segmentsIntersect(
        _ a: CanvasEdgePoint,
        _ b: CanvasEdgePoint,
        _ c: CanvasEdgePoint,
        _ d: CanvasEdgePoint
    ) -> Bool {
        let d1 = direction(c, d, a)
        let d2 = direction(c, d, b)
        let d3 = direction(a, b, c)
        let d4 = direction(a, b, d)

        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
            ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }

        return approximatelyZero(d1) && onSegment(c, d, a) ||
            approximatelyZero(d2) && onSegment(c, d, b) ||
            approximatelyZero(d3) && onSegment(a, b, c) ||
            approximatelyZero(d4) && onSegment(a, b, d)
    }

    private static func direction(_ a: CanvasEdgePoint, _ b: CanvasEdgePoint, _ c: CanvasEdgePoint) -> Double {
        (c.x - a.x) * (b.y - a.y) - (b.x - a.x) * (c.y - a.y)
    }

    private static func onSegment(_ a: CanvasEdgePoint, _ b: CanvasEdgePoint, _ c: CanvasEdgePoint) -> Bool {
        c.x >= min(a.x, b.x) - 0.0001 &&
            c.x <= max(a.x, b.x) + 0.0001 &&
            c.y >= min(a.y, b.y) - 0.0001 &&
            c.y <= max(a.y, b.y) + 0.0001
    }

    private static func approximatelyZero(_ value: Double) -> Bool {
        abs(value) < 0.0001
    }

    private static func simplified(_ points: [CanvasEdgePoint]) -> [CanvasEdgePoint] {
        var output: [CanvasEdgePoint] = []
        for point in points {
            if let last = output.last,
               distance(last, point) < 1 {
                continue
            }
            output.append(point)
        }
        return removeCollinear(output)
    }

    private static func removeCollinear(_ points: [CanvasEdgePoint]) -> [CanvasEdgePoint] {
        guard points.count >= 3 else { return points }
        var output: [CanvasEdgePoint] = []
        for point in points {
            output.append(point)
            while output.count >= 3 {
                let count = output.count
                let a = output[count - 3]
                let b = output[count - 2]
                let c = output[count - 1]
                let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
                if abs(cross) < 0.0001 {
                    output.remove(at: count - 2)
                } else {
                    break
                }
            }
        }
        return output
    }

    private static func score(_ points: [CanvasEdgePoint]) -> Double {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        var total = 0.0
        for index in points.indices.dropLast() {
            total += distance(points[index], points[index + 1])
        }
        return total + Double(max(0, points.count - 2)) * 18
    }

    private static func vector(from start: CanvasEdgePoint, to end: CanvasEdgePoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: end.x - start.x, y: end.y - start.y)
    }

    private static func distance(_ lhs: CanvasEdgePoint, _ rhs: CanvasEdgePoint) -> Double {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func normalized(_ vector: CanvasEdgePoint, fallback: CanvasEdgePoint) -> CanvasEdgePoint {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y)
        if length > 0.0001 {
            return CanvasEdgePoint(x: vector.x / length, y: vector.y / length)
        }

        let fallbackLength = sqrt(fallback.x * fallback.x + fallback.y * fallback.y)
        if fallbackLength > 0.0001 {
            return CanvasEdgePoint(x: fallback.x / fallbackLength, y: fallback.y / fallbackLength)
        }

        return CanvasEdgePoint(x: 1, y: 0)
    }
}

public enum CanvasEdgeRouteDefaults {
    public static let targetClearance = 0.0
    public static let routingClearance = 2.0
}

public enum CanvasViewportProjection {
    public static func screenPoint(
        x: Double,
        y: Double,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        let safeZoom = CanvasZoomScale.safeZoom(zoom)
        return CanvasEdgePoint(
            x: x * safeZoom + viewportX,
            y: y * safeZoom + viewportY
        )
    }

    public static func screenPoint(
        id: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        let safeZoom = CanvasZoomScale.safeZoom(zoom)
        return CanvasEdgePoint(
            x: (x + offsetX + width / 2) * safeZoom + viewportX,
            y: (y + offsetY + height / 2) * safeZoom + viewportY
        )
    }

    public static func screenRect(
        id: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasFrameRect {
        let safeZoom = CanvasZoomScale.safeZoom(zoom)
        return CanvasFrameRect(
            id: id,
            x: (x + offsetX) * safeZoom + viewportX,
            y: (y + offsetY) * safeZoom + viewportY,
            width: width * safeZoom,
            height: height * safeZoom
        )
    }

    public static func canvasPoint(
        screenX: Double,
        screenY: Double,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        let safeZoom = CanvasZoomScale.safeZoom(zoom, minimum: 0.01)
        return CanvasEdgePoint(
            x: (screenX - viewportX) / safeZoom,
            y: (screenY - viewportY) / safeZoom
        )
    }
}

public enum CanvasEdgeControlHandleMetrics {
    public static func diameter(zoom: Double, baseDiameter: Double, minimumDiameter: Double = 8) -> Double {
        let safeBase = baseDiameter.isFinite ? max(0, baseDiameter) : 0
        let safeMinimum = minimumDiameter.isFinite ? max(0, minimumDiameter) : 0
        return max(safeMinimum, safeBase * CanvasZoomScale.safeZoom(zoom, minimum: 0.01))
    }
}

public enum CanvasResizeHandleGeometry {
    public static let baseVisualSize = 22.0
    public static let basePadding = 6.0

    public static var baseInset: Double {
        basePadding + baseVisualSize / 2
    }

    public static var baseHitSize: Double {
        baseVisualSize + basePadding * 2
    }

    public static func center(in rect: CanvasFrameRect, zoom: Double) -> CanvasEdgePoint {
        let scale = max(zoom, 0.01)
        let inset = baseInset * scale
        return CanvasEdgePoint(
            x: rect.x + rect.width - inset,
            y: rect.y + rect.height - inset
        )
    }

    public static func hitRect(center: CanvasEdgePoint, zoom: Double) -> CanvasFrameRect {
        let size = baseHitSize * max(zoom, 0.01)
        return CanvasFrameRect(
            id: "resize-handle",
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
    }

    public static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect) -> Bool {
        point.x >= rect.x &&
            point.x <= rect.x + rect.width &&
            point.y >= rect.y &&
            point.y <= rect.y + rect.height
    }
}

public enum CanvasInteractionMetrics {
    public static let nodeHitSlop = 8.0
}

public enum CanvasIconButtonMetrics {
    public static let circleDiameter = 22.0
    public static let symbolDiameter = 13.0

    public static var symbolOrigin: Double {
        (circleDiameter - symbolDiameter) / 2
    }
}

public enum CanvasEdgeStyleOptions {
    private static let controlPointLockedToken = "controlPointLocked"
    private static let separator = ";"

    public static func isControlPointLocked(_ style: String) -> Bool {
        tokens(in: style).contains(controlPointLockedToken)
    }

    public static func style(_ style: String, controlPointLocked: Bool) -> String {
        var values = tokens(in: style)
        if controlPointLocked {
            values.insert(controlPointLockedToken)
        } else {
            values.remove(controlPointLockedToken)
        }
        if values.isEmpty {
            return "default"
        }
        return values.sorted().joined(separator: separator)
    }

    private static func tokens(in style: String) -> Set<String> {
        let parts = style
            .split(separator: Character(separator))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "default" }
        return Set(parts)
    }
}

public enum CanvasEdgeFlowPhase {
    public static func dashPhase(elapsed: Double, duration: Double, cycleLength: Double) -> Double {
        guard duration > 0, cycleLength > 0 else { return 0 }
        let progress = elapsed.truncatingRemainder(dividingBy: duration) / duration
        return -cycleLength * progress
    }
}

public struct CanvasFramePosition: Equatable, Identifiable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double

    public init(id: String, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

public enum CanvasHitTarget: Equatable, Sendable {
    case node(String)
    case background
}

public enum CanvasHitTesting {
    public static func target(
        at point: CanvasEdgePoint,
        nodes: [CanvasFrameRect],
        hitSlop: Double = 0
    ) -> CanvasHitTarget {
        for node in nodes.reversed() where contains(point, in: node, hitSlop: hitSlop) {
            return .node(node.id)
        }
        return .background
    }

    public static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect, hitSlop: Double = 0) -> Bool {
        point.x >= rect.x - hitSlop &&
            point.y >= rect.y - hitSlop &&
            point.x <= rect.x + rect.width + hitSlop &&
            point.y <= rect.y + rect.height + hitSlop
    }
}

public enum CanvasFrameGeometry {
    public static func childNodeIDs(
        inside frame: CanvasFrameRect,
        candidates: [CanvasFrameRect]
    ) -> [String] {
        candidates
            .filter { candidate in
                candidate.id != frame.id &&
                candidate.x >= frame.x &&
                candidate.y >= frame.y &&
                candidate.x + candidate.width <= frame.x + frame.width &&
                candidate.y + candidate.height <= frame.y + frame.height
            }
            .map(\.id)
    }

    public static func movedPositions(
        _ positions: [CanvasFramePosition],
        movingFrameId: String,
        childNodeIDs: [String],
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFramePosition] {
        let movedIDs = Set(childNodeIDs).union([movingFrameId])
        return positions.map { position in
            guard movedIDs.contains(position.id) else { return position }
            return CanvasFramePosition(id: position.id, x: position.x + deltaX, y: position.y + deltaY)
        }
    }

    public static func movedControlPoints(
        _ points: [CanvasFramePosition],
        inside frame: CanvasFrameRect,
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFramePosition] {
        points.map { point in
            guard contains(point, in: frame) else {
                return point
            }
            return CanvasFramePosition(id: point.id, x: point.x + deltaX, y: point.y + deltaY)
        }
    }

    public static func contains(_ point: CanvasFramePosition, in frame: CanvasFrameRect) -> Bool {
        point.x >= frame.x &&
            point.y >= frame.y &&
            point.x <= frame.x + frame.width &&
            point.y <= frame.y + frame.height
    }

    public static func movedRects(
        _ rects: [CanvasFrameRect],
        movedIDs: Set<String>,
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFrameRect] {
        rects.map { rect in
            guard movedIDs.contains(rect.id) else { return rect }
            return CanvasFrameRect(
                id: rect.id,
                x: rect.x + deltaX,
                y: rect.y + deltaY,
                width: rect.width,
                height: rect.height
            )
        }
    }

    public static func resizedFrame(
        _ frame: CanvasFrameRect,
        deltaWidth: Double,
        deltaHeight: Double,
        minimumWidth: Double,
        minimumHeight: Double
    ) -> CanvasFrameRect {
        CanvasFrameRect(
            id: frame.id,
            x: frame.x,
            y: frame.y,
            width: max(minimumWidth, frame.width + deltaWidth),
            height: max(minimumHeight, frame.height + deltaHeight)
        )
    }

    public static func containingFrameId(for candidate: CanvasFrameRect, frames: [CanvasFrameRect]) -> String? {
        frames
            .filter { frame in
                candidate.id != frame.id &&
                candidate.x >= frame.x &&
                candidate.y >= frame.y &&
                candidate.x + candidate.width <= frame.x + frame.width &&
                candidate.y + candidate.height <= frame.y + frame.height
            }
            .sorted {
                let lhsArea = $0.width * $0.height
                let rhsArea = $1.width * $1.height
                if lhsArea != rhsArea {
                    return lhsArea < rhsArea
                }
                return $0.id < $1.id
            }
            .first?
            .id
    }
}

public enum CanvasDropPlacement {
    public static func cardOrigin(
        dropX: Double,
        dropY: Double,
        viewportX: Double,
        viewportY: Double,
        zoom: Double,
        cardWidth: Double,
        cardHeight: Double
    ) -> (x: Double, y: Double) {
        let safeZoom = CanvasZoomScale.safeZoom(zoom, minimum: 0.01)
        return (
            x: (dropX - viewportX) / safeZoom - cardWidth / 2,
            y: (dropY - viewportY) / safeZoom - cardHeight / 2
        )
    }
}

public struct CanvasConnectionCompletion: Equatable, Sendable {
    public var nextSourceNodeId: String?
    public var returnsToSelectMode: Bool

    public init(nextSourceNodeId: String?, returnsToSelectMode: Bool) {
        self.nextSourceNodeId = nextSourceNodeId
        self.returnsToSelectMode = returnsToSelectMode
    }
}

public struct CanvasConnectSourceCommand: Equatable, Sendable {
    public var nextSourceNodeId: String?
    public var selectedNodeIDs: Set<String>
    public var entersConnectMode: Bool

    public init(nextSourceNodeId: String?, selectedNodeIDs: Set<String>, entersConnectMode: Bool) {
        self.nextSourceNodeId = nextSourceNodeId
        self.selectedNodeIDs = selectedNodeIDs
        self.entersConnectMode = entersConnectMode
    }
}

public enum CanvasConnectSourcePolicy {
    public static func start(from nodeId: String) -> CanvasConnectSourceCommand {
        CanvasConnectSourceCommand(
            nextSourceNodeId: nodeId,
            selectedNodeIDs: [nodeId],
            entersConnectMode: true
        )
    }
}

public enum CanvasConnectionPolicy {
    public static func completion(targetNodeId: String, singleShot: Bool) -> CanvasConnectionCompletion {
        CanvasConnectionCompletion(
            nextSourceNodeId: singleShot ? nil : targetNodeId,
            returnsToSelectMode: singleShot
        )
    }
}

public enum TodoBoardColumnSplit {
    public static let minimumRatio = 0.3
    public static let maximumRatio = 0.7
    public static let defaultRatio = 0.5

    public static func clampedRatio(_ ratio: Double) -> Double {
        min(max(ratio, minimumRatio), maximumRatio)
    }
}

public struct TodoBoardOrderRecord: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let isPinned: Bool
    public let sortIndex: Int

    public init(id: String, title: String, isPinned: Bool, sortIndex: Int) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.sortIndex = sortIndex
    }
}

public enum TodoBoardOrdering {
    public static func ordered(_ records: [TodoBoardOrderRecord]) -> [TodoBoardOrderRecord] {
        records.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            let titleComparison = $0.title.localizedStandardCompare($1.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    public static func movedIDs(_ ids: [String], moving movingID: String, to targetID: String) -> [String] {
        guard movingID != targetID,
              let sourceIndex = ids.firstIndex(of: movingID),
              let targetIndex = ids.firstIndex(of: targetID) else {
            return ids
        }

        var result = ids
        let moved = result.remove(at: sourceIndex)
        let adjustedTargetIndex = result.firstIndex(of: targetID) ?? targetIndex
        let insertionIndex = sourceIndex < targetIndex ? adjustedTargetIndex + 1 : adjustedTargetIndex
        result.insert(moved, at: min(insertionIndex, result.count))
        return result
    }
}

public struct TodoGroupDeletionPlan: Equatable, Sendable {
    public var todoTargetGroupId: String?
    public var nextSelectedGroupId: String?
    public var deletesGroup: Bool

    public init(todoTargetGroupId: String?, nextSelectedGroupId: String?, deletesGroup: Bool) {
        self.todoTargetGroupId = todoTargetGroupId
        self.nextSelectedGroupId = nextSelectedGroupId
        self.deletesGroup = deletesGroup
    }
}

public enum TodoGroupDeletionPolicy {
    public static func plan(
        deletingGroupId: String,
        defaultGroupId: String,
        orderedGroupIds: [String]
    ) -> TodoGroupDeletionPlan {
        if deletingGroupId == defaultGroupId {
            return TodoGroupDeletionPlan(
                todoTargetGroupId: nil,
                nextSelectedGroupId: deletingGroupId,
                deletesGroup: false
            )
        }

        return TodoGroupDeletionPlan(
            todoTargetGroupId: defaultGroupId,
            nextSelectedGroupId: defaultGroupId,
            deletesGroup: true
        )
    }
}

public enum TodoBoardTaskSummary {
    public static func inlineDetail(_ details: String) -> String? {
        let cleaned = details
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned.isEmpty ? nil : cleaned
    }
}

public enum WebCardURL {
    public static func normalized(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let candidate: String
        if trimmed.contains("://") {
            candidate = trimmed
        } else {
            guard !hasNonPortColon(trimmed) else { return nil }
            candidate = "https://\(trimmed)"
        }
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              let url = components.url else {
            return nil
        }
        return url
    }

    private static func hasNonPortColon(_ value: String) -> Bool {
        guard let colonIndex = value.firstIndex(of: ":") else { return false }
        let delimiterIndex = value[colonIndex...].firstIndex { character in
            character == "/" || character == "?" || character == "#"
        } ?? value.endIndex
        let portSlice = value[value.index(after: colonIndex)..<delimiterIndex]
        return portSlice.isEmpty || portSlice.contains { !$0.isNumber }
    }
}

public enum QuickOpenRecordKind: String, Sendable {
    case workspace
    case resource
    case webCard
    case snippet
}

public struct QuickOpenRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: QuickOpenRecordKind
    public var title: String
    public var subtitle: String

    public init(id: String, kind: QuickOpenRecordKind, title: String, subtitle: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }
}

public enum QuickOpenIndex {
    private struct SearchRecord {
        let offset: Int
        let record: QuickOpenRecord
        let title: String
        let subtitle: String
        let kind: String
    }

    public static func results(
        for query: String,
        in records: [QuickOpenRecord],
        limit: Int = 12
    ) -> [QuickOpenRecord] {
        let safeLimit = max(limit, 0)
        guard safeLimit > 0 else { return [] }
        let tokens = query
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            return Array(records.prefix(safeLimit))
        }
        var best: [(offset: Int, score: Int, record: QuickOpenRecord)] = []
        for (offset, record) in records.enumerated() {
            let searchRecord = SearchRecord(
                offset: offset,
                record: record,
                title: record.title.lowercased(),
                subtitle: record.subtitle.lowercased(),
                kind: record.kind.rawValue.lowercased()
            )
            var totalScore = 0
            for token in tokens {
                guard let tokenScore = score(searchRecord, token: token) else {
                    totalScore = Int.max
                    break
                }
                totalScore += tokenScore
            }
            guard totalScore != Int.max else { continue }
            let candidate = (searchRecord.offset, totalScore, searchRecord.record)
            guard best.count < safeLimit || isBetter(candidate, than: best[best.count - 1]) else {
                continue
            }
            let insertionIndex = best.firstIndex { isBetter(candidate, than: $0) } ?? best.count
            best.insert(candidate, at: insertionIndex)
            if best.count > safeLimit {
                best.removeLast()
            }
        }
        return best.map(\.record)
    }

    private static func score(_ searchRecord: SearchRecord, token: String) -> Int? {
        if searchRecord.title == token { return 0 }
        if searchRecord.title.hasPrefix(token) { return 1 }
        if searchRecord.title.contains(token) { return 2 }
        if searchRecord.subtitle.hasPrefix(token) { return 3 }
        if searchRecord.subtitle.contains(token) { return 4 }
        if searchRecord.kind.contains(token) { return 5 }
        return nil
    }

    private static func isBetter(
        _ lhs: (offset: Int, score: Int, record: QuickOpenRecord),
        than rhs: (offset: Int, score: Int, record: QuickOpenRecord)
    ) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        return lhs.offset < rhs.offset
    }
}

public enum QuickOpenSelectionPolicy {
    public static func normalizedIndex(_ index: Int, resultCount: Int) -> Int {
        guard resultCount > 0 else { return 0 }
        return min(max(index, 0), resultCount - 1)
    }

    public static func movedIndex(current: Int, delta: Int, resultCount: Int) -> Int {
        guard resultCount > 0 else { return 0 }
        let next = (normalizedIndex(current, resultCount: resultCount) + delta) % resultCount
        return next >= 0 ? next : next + resultCount
    }
}

public enum CanvasScrollZoomDirection: String, CaseIterable, Identifiable, Sendable {
    case scrollDownZoomsOut
    case scrollDownZoomsIn

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scrollDownZoomsOut:
            "Scroll down zooms out"
        case .scrollDownZoomsIn:
            "Scroll down zooms in"
        }
    }

    public static func resolved(_ rawValue: String) -> CanvasScrollZoomDirection {
        CanvasScrollZoomDirection(rawValue: rawValue) ?? .scrollDownZoomsOut
    }
}

public enum CanvasZoomScale {
    private static let fallbackZoom = 0.35

    public static func safeZoom(_ zoom: Double, minimum: Double = 0.01, fallback: Double = 1.0) -> Double {
        guard zoom.isFinite else { return max(fallback, minimum) }
        return max(zoom, minimum)
    }

    public static func clamped(_ zoom: Double, minimum: Double, maximum: Double) -> Double {
        let lower = minimum.isFinite ? minimum : fallbackZoom
        let upper = maximum.isFinite ? maximum : lower
        let safeMinimum = min(lower, upper)
        let safeMaximum = max(lower, upper)
        guard zoom.isFinite else {
            return min(max(fallbackZoom, safeMinimum), safeMaximum)
        }
        return min(max(zoom, safeMinimum), safeMaximum)
    }

    public static func displayPercent(forZoom zoom: Double, baseline: Double) -> Int {
        guard zoom.isFinite, baseline.isFinite, baseline > 0 else { return 100 }
        return Int((zoom / baseline * 100).rounded())
    }

    public static func zoom(
        forDisplayScale displayScale: Double,
        baseline: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        guard displayScale.isFinite, baseline.isFinite else {
            return clamped(fallbackZoom, minimum: minimum, maximum: maximum)
        }
        return clamped(displayScale * baseline, minimum: minimum, maximum: maximum)
    }

    public static func zoom(
        forScrollDeltaY deltaY: Double,
        current: Double,
        minimum: Double,
        maximum: Double,
        direction: CanvasScrollZoomDirection = .scrollDownZoomsOut
    ) -> Double {
        guard current.isFinite else {
            return clamped(fallbackZoom, minimum: minimum, maximum: maximum)
        }
        guard deltaY.isFinite else {
            return clamped(current, minimum: minimum, maximum: maximum)
        }
        let signedDelta = direction == .scrollDownZoomsOut ? -deltaY : deltaY
        let multiplier = pow(1.0025, signedDelta)
        return clamped(current * multiplier, minimum: minimum, maximum: maximum)
    }

    public static func viewport(
        keepingScreenX screenX: Double,
        screenY: Double,
        canvasX: Double,
        canvasY: Double,
        zoom: Double
    ) -> (x: Double, y: Double) {
        let resolvedZoom = safeZoom(zoom)
        return (
            x: screenX - canvasX * resolvedZoom,
            y: screenY - canvasY * resolvedZoom
        )
    }
}

public struct CanvasViewportFitResult: Equatable, Sendable {
    public var zoom: Double
    public var viewportX: Double
    public var viewportY: Double

    public init(zoom: Double, viewportX: Double, viewportY: Double) {
        self.zoom = zoom
        self.viewportX = viewportX
        self.viewportY = viewportY
    }
}

public enum CanvasViewportFitPolicy {
    public static func fit(
        bounds: CanvasFrameRect,
        viewportWidth: Double,
        viewportHeight: Double,
        padding: Double,
        minimumZoom: Double,
        maximumZoom: Double
    ) -> CanvasViewportFitResult? {
        guard bounds.x.isFinite,
              bounds.y.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite,
              viewportWidth.isFinite,
              viewportHeight.isFinite,
              padding.isFinite,
              bounds.width > 0,
              bounds.height > 0,
              viewportWidth > 0,
              viewportHeight > 0 else {
            return nil
        }

        let safePadding = max(0, padding)
        let availableWidth = max(1, viewportWidth - safePadding * 2)
        let availableHeight = max(1, viewportHeight - safePadding * 2)
        let zoom = CanvasZoomScale.clamped(
            min(availableWidth / bounds.width, availableHeight / bounds.height),
            minimum: minimumZoom,
            maximum: maximumZoom
        )
        let centerX = bounds.x + bounds.width / 2
        let centerY = bounds.y + bounds.height / 2
        return CanvasViewportFitResult(
            zoom: zoom,
            viewportX: viewportWidth / 2 - centerX * zoom,
            viewportY: viewportHeight / 2 - centerY * zoom
        )
    }
}

public enum CanvasZoomBaseline {
    public static let standardBaseline = 0.35
    public static let minimumZoom = 0.12
    public static let maximumZoom = 2.4
    public static let defaultPercent = 100.0

    public static func actualZoom(
        percent: Double,
        standardBaseline: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        let baseline = standardBaseline.isFinite ? standardBaseline : CanvasZoomBaseline.standardBaseline
        guard percent.isFinite else {
            return CanvasZoomScale.clamped(baseline, minimum: minimum, maximum: maximum)
        }
        let safePercent = min(max(percent, 25), 500)
        return CanvasZoomScale.clamped(
            baseline * safePercent / 100,
            minimum: minimum,
            maximum: maximum
        )
    }
}
