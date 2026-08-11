import CoreGraphics
import Foundation
import MindDeskCore

struct CanvasEdgeSegment: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
    let startDirection: CGPoint
    let endDirection: CGPoint
    let control: CGPoint?
    let routePoints: [CGPoint]
    let isControlPointLocked: Bool
    let sourceArrowRaw: String
    let targetArrowRaw: String
}

struct CanvasRenderSnapshot {
    let workflowNodes: [CanvasNodeModel]
    let nodeById: [String: CanvasNodeModel]
    let resourcesById: [String: ResourcePinModel]
    let snippetsById: [String: SnippetModel]
    let visibleEdges: [CanvasEdgeModel]
    let edgeById: [String: CanvasEdgeModel]
    let frameNodes: [CanvasNodeModel]
    let cardNodes: [CanvasNodeModel]

    init(nodes: [CanvasNodeModel], resources: [ResourcePinModel], snippets: [SnippetModel], edges: [CanvasEdgeModel]) {
        let uniqueNodes = Self.uniqueByID(nodes, id: \.id)
        let nodeLookup = Dictionary(uniqueNodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        workflowNodes = uniqueNodes
        nodeById = nodeLookup
        resourcesById = Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        snippetsById = Dictionary(snippets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let validEdges = Self.uniqueByID(
            edges.filter { nodeLookup[$0.sourceNodeId] != nil && nodeLookup[$0.targetNodeId] != nil },
            id: \.id
        )
        visibleEdges = validEdges
        edgeById = Dictionary(validEdges.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        frameNodes = uniqueNodes.filter { $0.nodeType == .groupFrame }.sorted { $0.updatedAt < $1.updatedAt }
        cardNodes = uniqueNodes.filter { $0.nodeType != .groupFrame }.sorted { $0.zIndex < $1.zIndex }
    }

    private static func uniqueByID<T>(_ values: [T], id: (T) -> String) -> [T] {
        var seen: Set<String> = []
        return values.filter { seen.insert(id($0)).inserted }
    }

    func resource(for node: CanvasNodeModel) -> ResourcePinModel? {
        guard node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    func snippet(for node: CanvasNodeModel) -> SnippetModel? {
        guard node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    func edgeSegments(
        targetClearance: Double,
        routingClearance: Double,
        usesObstacleRouting: Bool = true,
        routingObstacleNodes: [CanvasNodeModel]? = nil,
        rectFor: (CanvasNodeModel) -> CanvasFrameRect,
        controlPointFor: (CanvasEdgeModel) -> CGPoint?,
        candidateEdgeIDs: [String]? = nil,
        shouldVisitEdge: ((CanvasEdgeModel) -> Bool)? = nil,
        shouldIncludeEdge: ((CanvasEdgeModel, CanvasFrameRect, CanvasFrameRect, CGPoint?) -> Bool)? = nil
    ) -> [CanvasEdgeSegment] {
        var nodeRects: [String: CanvasFrameRect] = [:]
        func cachedRect(for node: CanvasNodeModel) -> CanvasFrameRect {
            if let rect = nodeRects[node.id] {
                return rect
            }
            let rect = rectFor(node)
            nodeRects[node.id] = rect
            return rect
        }

        let obstacleRects: [(id: String, rect: CanvasFrameRect)] = usesObstacleRouting
            ? (routingObstacleNodes ?? cardNodes).compactMap { node -> (id: String, rect: CanvasFrameRect)? in
                guard node.nodeType != .groupFrame else { return nil }
                return (id: node.id, rect: cachedRect(for: node))
            }
            : []
        let segmentEdges = candidateEdgeIDs.map { ids in
            ids.compactMap { edgeById[$0] }
        } ?? visibleEdges
        return segmentEdges.compactMap { edge -> CanvasEdgeSegment? in
            if let shouldVisitEdge, !shouldVisitEdge(edge) {
                return nil
            }
            guard let source = nodeById[edge.sourceNodeId],
                  let target = nodeById[edge.targetNodeId] else {
                return nil
            }
            let sourceRect = cachedRect(for: source)
            let targetRect = cachedRect(for: target)
            let control = controlPointFor(edge)
            if let shouldIncludeEdge, !shouldIncludeEdge(edge, sourceRect, targetRect, control) {
                return nil
            }
            let controlPoint = control.map { CanvasEdgePoint(x: $0.x, y: $0.y) }
            let anchors = CanvasEdgeAnchoring.anchors(
                source: sourceRect,
                target: targetRect,
                control: controlPoint,
                targetClearance: targetClearance
            )
            let routePoints: [CanvasEdgePoint]
            if usesObstacleRouting {
                let edgeObstacleRects = obstacleRects.compactMap { obstacle -> CanvasFrameRect? in
                    obstacle.id == source.id || obstacle.id == target.id ? nil : obstacle.rect
                }
                if let controlPoint {
                    routePoints = CanvasEdgeRoutePlanner.routePoints(
                        start: anchors.start,
                        end: anchors.end,
                        waypoints: [controlPoint],
                        startDirection: anchors.startDirection,
                        endDirection: anchors.endDirection,
                        obstacles: edgeObstacleRects,
                        clearance: routingClearance
                    )
                } else {
                    routePoints = CanvasEdgeRoutePlanner.routePoints(
                        start: anchors.start,
                        end: anchors.end,
                        startDirection: anchors.startDirection,
                        endDirection: anchors.endDirection,
                        obstacles: edgeObstacleRects,
                        clearance: routingClearance
                    )
                }
            } else {
                routePoints = []
            }
            return CanvasEdgeSegment(
                id: edge.id,
                start: CGPoint(x: anchors.start.x, y: anchors.start.y),
                end: CGPoint(x: anchors.end.x, y: anchors.end.y),
                startDirection: CGPoint(x: anchors.startDirection.x, y: anchors.startDirection.y),
                endDirection: CGPoint(x: anchors.endDirection.x, y: anchors.endDirection.y),
                control: control,
                routePoints: routePoints.map { CGPoint(x: $0.x, y: $0.y) },
                isControlPointLocked: CanvasEdgeStyleOptions.isControlPointLocked(edge.style),
                sourceArrowRaw: edge.sourceArrowRaw,
                targetArrowRaw: edge.targetArrowRaw
            )
        }
    }
}

struct CanvasWorldDerivedState {
    let generation: Int
    let snapshot: CanvasRenderSnapshot
    let edgeIndex: CanvasEdgeViewportIndex
    let edgeIndexDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics
}

@MainActor
final class CanvasWorldDerivedCache {
    private struct Token: Equatable {
        let nodes: [NodeToken]
        let resources: [ModelReferenceToken]
        let snippets: [ModelReferenceToken]
        let edges: [EdgeToken]
    }

    private struct NodeToken: Equatable {
        let identity: ObjectIdentifier
        let id: String
        let canvasID: String
        let nodeType: String
        let objectType: String?
        let objectID: String?
        let parentNodeID: String?
        let x: UInt64
        let y: UInt64
        let width: UInt64
        let height: UInt64
        let zIndex: UInt64
        let groupSortDate: UInt64?
    }

    private struct ModelReferenceToken: Equatable {
        let identity: ObjectIdentifier
        let id: String
    }

    private struct EdgeToken: Equatable {
        let identity: ObjectIdentifier
        let id: String
        let canvasID: String
        let sourceNodeID: String
        let targetNodeID: String
        let controlPointX: UInt64?
        let controlPointY: UInt64?
    }

    private let edgeIndexCache = CanvasEdgeViewportIndexCache(logsReuseEvents: false)
    private var token: Token?
    private var cachedState: CanvasWorldDerivedState?
    private var generation = 0

    func state(
        nodes: [CanvasNodeModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        edges: [CanvasEdgeModel]
    ) -> CanvasWorldDerivedState {
        let nextToken = Token(
            nodes: nodes.map(Self.nodeToken(for:)),
            resources: resources.map { ModelReferenceToken(identity: ObjectIdentifier($0), id: $0.id) },
            snippets: snippets.map { ModelReferenceToken(identity: ObjectIdentifier($0), id: $0.id) },
            edges: edges.map(Self.edgeToken(for:))
        )
        if token == nextToken, let cachedState {
            return cachedState
        }

        let snapshot = CanvasRenderSnapshot(
            nodes: nodes,
            resources: resources,
            snippets: snippets,
            edges: edges
        )
        let edgeIndex = edgeIndexCache.index(
            nodes: snapshot.workflowNodes.map(Self.edgeIndexRect(for:)),
            edges: snapshot.visibleEdges.map(Self.edgeIndexRecord(for:))
        )
        generation += 1
        let nextState = CanvasWorldDerivedState(
            generation: generation,
            snapshot: snapshot,
            edgeIndex: edgeIndex,
            edgeIndexDiagnostics: edgeIndexCache.diagnostics
        )
        token = nextToken
        cachedState = nextState
        return nextState
    }

    private static func nodeToken(for node: CanvasNodeModel) -> NodeToken {
        NodeToken(
            identity: ObjectIdentifier(node),
            id: node.id,
            canvasID: node.canvasId,
            nodeType: node.nodeTypeRaw,
            objectType: node.objectType,
            objectID: node.objectId,
            parentNodeID: node.parentNodeId,
            x: node.x.bitPattern,
            y: node.y.bitPattern,
            width: node.width.bitPattern,
            height: node.height.bitPattern,
            zIndex: node.zIndex.bitPattern,
            groupSortDate: node.nodeType == .groupFrame
                ? node.updatedAt.timeIntervalSinceReferenceDate.bitPattern
                : nil
        )
    }

    private static func edgeToken(for edge: CanvasEdgeModel) -> EdgeToken {
        EdgeToken(
            identity: ObjectIdentifier(edge),
            id: edge.id,
            canvasID: edge.canvasId,
            sourceNodeID: edge.sourceNodeId,
            targetNodeID: edge.targetNodeId,
            controlPointX: edge.controlPointX?.bitPattern,
            controlPointY: edge.controlPointY?.bitPattern
        )
    }

    private static func edgeIndexRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let size = committedSize(for: node)
        return CanvasFrameRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height
        )
    }

    private static func edgeIndexRecord(for edge: CanvasEdgeModel) -> CanvasEdgeViewportRecord {
        let controlPoint: CanvasEdgePoint? = if let x = edge.controlPointX, let y = edge.controlPointY {
            CanvasEdgePoint(x: x, y: y)
        } else {
            nil
        }
        return CanvasEdgeViewportRecord(
            id: edge.id,
            sourceNodeID: edge.sourceNodeId,
            targetNodeID: edge.targetNodeId,
            controlPoint: controlPoint
        )
    }

    private static func committedSize(for node: CanvasNodeModel) -> CanvasNodeSize {
        switch node.nodeType {
        case .groupFrame:
            CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.frameWidth,
                defaultHeight: CanvasNodeMetrics.frameHeight,
                minimumWidth: CanvasNodeMetrics.frameMinWidth,
                minimumHeight: CanvasNodeMetrics.frameMinHeight
            )
        case .note:
            CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.noteWidth,
                defaultHeight: CanvasNodeMetrics.noteHeight,
                minimumWidth: CanvasNodeMetrics.noteMinWidth,
                minimumHeight: CanvasNodeMetrics.noteMinHeight
            )
        case .resource, .snippet:
            CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.cardWidth,
                defaultHeight: CanvasNodeMetrics.cardHeight,
                minimumWidth: CanvasNodeMetrics.cardMinWidth,
                minimumHeight: CanvasNodeMetrics.cardMinHeight
            )
        }
    }
}
