import Foundation

public struct CanvasEdgeViewportRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var sourceNodeID: String
    public var targetNodeID: String
    public var controlPoint: CanvasEdgePoint?

    public init(
        id: String,
        sourceNodeID: String,
        targetNodeID: String,
        controlPoint: CanvasEdgePoint? = nil
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.controlPoint = controlPoint
    }
}

public struct CanvasEdgeViewportIndexDiagnostics: Equatable, Sendable {
    public var totalEdgeCount: Int
    public var indexedEdgeCount: Int
    public var duplicateEdgeCount: Int
    public var droppedDanglingEdgeCount: Int
    public var droppedInvalidGeometryEdgeCount: Int
    public var bucketSize: Double
    public var bucketSizeWasDefaulted: Bool
    public var bucketedEdgeCount: Int
    public var bucketFallbackEdgeCount: Int

    public init(
        totalEdgeCount: Int,
        indexedEdgeCount: Int,
        duplicateEdgeCount: Int,
        droppedDanglingEdgeCount: Int,
        droppedInvalidGeometryEdgeCount: Int = 0,
        bucketSize: Double,
        bucketSizeWasDefaulted: Bool = false,
        bucketedEdgeCount: Int = 0,
        bucketFallbackEdgeCount: Int = 0
    ) {
        self.totalEdgeCount = totalEdgeCount
        self.indexedEdgeCount = indexedEdgeCount
        self.duplicateEdgeCount = duplicateEdgeCount
        self.droppedDanglingEdgeCount = droppedDanglingEdgeCount
        self.droppedInvalidGeometryEdgeCount = droppedInvalidGeometryEdgeCount
        self.bucketSize = bucketSize
        self.bucketSizeWasDefaulted = bucketSizeWasDefaulted
        self.bucketedEdgeCount = bucketedEdgeCount
        self.bucketFallbackEdgeCount = bucketFallbackEdgeCount
    }
}

public struct CanvasEdgeViewportQueryDiagnostics: Equatable, Sendable, Encodable {
    public var queriedBucketCount: Int
    public var bucketCandidateEdgeCount: Int
    public var candidateExaminedCount: Int
    public var orderedScanCount: Int
    public var forcedRequestedCount: Int
    public var forcedValidCount: Int
    public var forcedInvalidCount: Int
    public var forcedRetentionCount: Int
    public var renderEdgeCount: Int
    public var fallbackExaminedEdgeCount: Int
    public var bucketEnumerationWasBounded: Bool

    public init(
        queriedBucketCount: Int,
        bucketCandidateEdgeCount: Int,
        candidateExaminedCount: Int,
        orderedScanCount: Int,
        forcedRequestedCount: Int,
        forcedValidCount: Int,
        forcedInvalidCount: Int,
        forcedRetentionCount: Int = 0,
        renderEdgeCount: Int,
        fallbackExaminedEdgeCount: Int = 0,
        bucketEnumerationWasBounded: Bool = false
    ) {
        self.queriedBucketCount = queriedBucketCount
        self.bucketCandidateEdgeCount = bucketCandidateEdgeCount
        self.candidateExaminedCount = candidateExaminedCount
        self.orderedScanCount = orderedScanCount
        self.forcedRequestedCount = forcedRequestedCount
        self.forcedValidCount = forcedValidCount
        self.forcedInvalidCount = forcedInvalidCount
        self.forcedRetentionCount = forcedRetentionCount
        self.renderEdgeCount = renderEdgeCount
        self.fallbackExaminedEdgeCount = fallbackExaminedEdgeCount
        self.bucketEnumerationWasBounded = bucketEnumerationWasBounded
    }

    private enum CodingKeys: String, CodingKey {
        case queriedBucketCount
        case bucketCandidateEdgeCount
        case candidateExaminedCount
        case orderedScanCount
        case forcedRequestedCount
        case forcedValidCount
        case forcedInvalidCount
        case forcedRetentionCount
        case renderEdgeCount
        case fallbackExaminedEdgeCount
        case bucketEnumerationWasBounded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(queriedBucketCount, forKey: .queriedBucketCount)
        try container.encode(bucketCandidateEdgeCount, forKey: .bucketCandidateEdgeCount)
        try container.encode(candidateExaminedCount, forKey: .candidateExaminedCount)
        try container.encode(orderedScanCount, forKey: .orderedScanCount)
        try container.encode(forcedRequestedCount, forKey: .forcedRequestedCount)
        try container.encode(forcedValidCount, forKey: .forcedValidCount)
        try container.encode(forcedInvalidCount, forKey: .forcedInvalidCount)
        try container.encode(forcedRetentionCount, forKey: .forcedRetentionCount)
        try container.encode(renderEdgeCount, forKey: .renderEdgeCount)
        try container.encode(fallbackExaminedEdgeCount, forKey: .fallbackExaminedEdgeCount)
        try container.encode(bucketEnumerationWasBounded, forKey: .bucketEnumerationWasBounded)
    }
}

public struct CanvasEdgeViewportQueryResult: Equatable, Sendable {
    public var edgeIDs: [String]
    public var candidateEdgeCount: Int
    public var examinedEdgeCount: Int
    public var orderedScanCount: Int
    public var diagnostics: CanvasEdgeViewportQueryDiagnostics

    public init(
        edgeIDs: [String],
        examinedEdgeCount: Int,
        orderedScanCount: Int? = nil,
        diagnostics: CanvasEdgeViewportQueryDiagnostics? = nil
    ) {
        let resolvedOrderedScanCount = orderedScanCount ?? 0
        self.edgeIDs = edgeIDs
        self.candidateEdgeCount = edgeIDs.count
        self.examinedEdgeCount = examinedEdgeCount
        self.orderedScanCount = resolvedOrderedScanCount
        self.diagnostics = diagnostics ?? CanvasEdgeViewportQueryDiagnostics(
            queriedBucketCount: 0,
            bucketCandidateEdgeCount: examinedEdgeCount,
            candidateExaminedCount: examinedEdgeCount,
            orderedScanCount: resolvedOrderedScanCount,
            forcedRequestedCount: 0,
            forcedValidCount: 0,
            forcedInvalidCount: 0,
            forcedRetentionCount: 0,
            renderEdgeCount: edgeIDs.count
        )
    }

    public static func == (lhs: CanvasEdgeViewportQueryResult, rhs: CanvasEdgeViewportQueryResult) -> Bool {
        lhs.edgeIDs == rhs.edgeIDs &&
            lhs.candidateEdgeCount == rhs.candidateEdgeCount &&
            lhs.examinedEdgeCount == rhs.examinedEdgeCount &&
            lhs.orderedScanCount == rhs.orderedScanCount
    }
}

public struct CanvasEdgeForceRetentionDiagnostics: Equatable, Sendable, Encodable {
    public var explicitActiveEdgeCount: Int
    public var incidentEdgeCount: Int
    public var droppedIncidentEdgeCount: Int
    public var maximumIncidentEdgeCount: Int
    public var incidentCandidateEdgeCount: Int
    public var edgeScanCount: Int
    public var adjacencyLookupNodeCount: Int
    public var usedIncidentAdjacency: Bool

    public init(
        explicitActiveEdgeCount: Int = 0,
        incidentEdgeCount: Int = 0,
        droppedIncidentEdgeCount: Int = 0,
        maximumIncidentEdgeCount: Int = 0,
        incidentCandidateEdgeCount: Int = 0,
        edgeScanCount: Int = 0,
        adjacencyLookupNodeCount: Int = 0,
        usedIncidentAdjacency: Bool = false
    ) {
        self.explicitActiveEdgeCount = explicitActiveEdgeCount
        self.incidentEdgeCount = incidentEdgeCount
        self.droppedIncidentEdgeCount = droppedIncidentEdgeCount
        self.maximumIncidentEdgeCount = maximumIncidentEdgeCount
        self.incidentCandidateEdgeCount = incidentCandidateEdgeCount
        self.edgeScanCount = edgeScanCount
        self.adjacencyLookupNodeCount = adjacencyLookupNodeCount
        self.usedIncidentAdjacency = usedIncidentAdjacency
    }

    public static var empty: CanvasEdgeForceRetentionDiagnostics {
        CanvasEdgeForceRetentionDiagnostics()
    }

    private enum CodingKeys: String, CodingKey {
        case explicitActiveEdgeCount
        case incidentEdgeCount
        case droppedIncidentEdgeCount
        case maximumIncidentEdgeCount
        case incidentCandidateEdgeCount
        case edgeScanCount
        case adjacencyLookupNodeCount
        case usedIncidentAdjacency
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(explicitActiveEdgeCount, forKey: .explicitActiveEdgeCount)
        try container.encode(incidentEdgeCount, forKey: .incidentEdgeCount)
        try container.encode(droppedIncidentEdgeCount, forKey: .droppedIncidentEdgeCount)
        try container.encode(maximumIncidentEdgeCount, forKey: .maximumIncidentEdgeCount)
        try container.encode(incidentCandidateEdgeCount, forKey: .incidentCandidateEdgeCount)
        try container.encode(edgeScanCount, forKey: .edgeScanCount)
        try container.encode(adjacencyLookupNodeCount, forKey: .adjacencyLookupNodeCount)
        try container.encode(usedIncidentAdjacency, forKey: .usedIncidentAdjacency)
    }
}

public struct CanvasEdgeVisibilityDiagnostics: Equatable, Sendable {
    public var index: CanvasEdgeViewportIndexDiagnostics
    public var visibleQuery: CanvasEdgeViewportQueryDiagnostics
    public var renderQuery: CanvasEdgeViewportQueryDiagnostics
    public var cache: CanvasEdgeViewportIndexCacheDiagnostics?
    public var forceRetention: CanvasEdgeForceRetentionDiagnostics
    public var forceRetainedEdgeCount: Int
    public var renderEdgeCount: Int

    public init(
        index: CanvasEdgeViewportIndexDiagnostics,
        visibleQuery: CanvasEdgeViewportQueryDiagnostics,
        renderQuery: CanvasEdgeViewportQueryDiagnostics,
        cache: CanvasEdgeViewportIndexCacheDiagnostics? = nil,
        forceRetention: CanvasEdgeForceRetentionDiagnostics = .empty,
        forceRetainedEdgeCount: Int,
        renderEdgeCount: Int
    ) {
        self.index = index
        self.visibleQuery = visibleQuery
        self.renderQuery = renderQuery
        self.cache = cache
        self.forceRetention = forceRetention
        self.forceRetainedEdgeCount = forceRetainedEdgeCount
        self.renderEdgeCount = renderEdgeCount
    }

    public static var empty: CanvasEdgeVisibilityDiagnostics {
        CanvasEdgeVisibilityDiagnostics(
            index: CanvasEdgeViewportIndexDiagnostics(
                totalEdgeCount: 0,
                indexedEdgeCount: 0,
                duplicateEdgeCount: 0,
                droppedDanglingEdgeCount: 0,
                bucketSize: 0
            ),
            visibleQuery: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 0,
                bucketCandidateEdgeCount: 0,
                candidateExaminedCount: 0,
                orderedScanCount: 0,
                forcedRequestedCount: 0,
                forcedValidCount: 0,
                forcedInvalidCount: 0,
                renderEdgeCount: 0
            ),
            renderQuery: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 0,
                bucketCandidateEdgeCount: 0,
                candidateExaminedCount: 0,
                orderedScanCount: 0,
                forcedRequestedCount: 0,
                forcedValidCount: 0,
                forcedInvalidCount: 0,
                renderEdgeCount: 0
            ),
            forceRetention: .empty,
            forceRetainedEdgeCount: 0,
            renderEdgeCount: 0
        )
    }
}

public struct CanvasEdgeVisibilityPlan: Equatable, Sendable {
    public var renderEdgeIDs: [String]
    public var forceRetainedEdgeIDs: Set<String>
    public var visibleCandidateCount: Int
    public var usesObstacleRouting: Bool
    public var animatesVisibleEdges: Bool
    public var diagnostics: CanvasEdgeVisibilityDiagnostics

    public init(
        renderEdgeIDs: [String],
        forceRetainedEdgeIDs: Set<String>,
        visibleCandidateCount: Int,
        usesObstacleRouting: Bool,
        animatesVisibleEdges: Bool,
        diagnostics: CanvasEdgeVisibilityDiagnostics = .empty
    ) {
        self.renderEdgeIDs = renderEdgeIDs
        self.forceRetainedEdgeIDs = forceRetainedEdgeIDs
        self.visibleCandidateCount = visibleCandidateCount
        self.usesObstacleRouting = usesObstacleRouting
        self.animatesVisibleEdges = animatesVisibleEdges
        self.diagnostics = diagnostics
    }

    public static func == (lhs: CanvasEdgeVisibilityPlan, rhs: CanvasEdgeVisibilityPlan) -> Bool {
        lhs.renderEdgeIDs == rhs.renderEdgeIDs &&
            lhs.forceRetainedEdgeIDs == rhs.forceRetainedEdgeIDs &&
            lhs.visibleCandidateCount == rhs.visibleCandidateCount &&
            lhs.usesObstacleRouting == rhs.usesObstacleRouting &&
            lhs.animatesVisibleEdges == rhs.animatesVisibleEdges
    }
}

public struct CanvasEdgeForceRetentionResult: Equatable, Sendable {
    public var edgeIDs: [String]
    public var explicitActiveEdgeCount: Int
    public var incidentEdgeCount: Int
    public var droppedIncidentEdgeCount: Int
    public var maximumIncidentEdgeCount: Int
    public var incidentCandidateEdgeCount: Int
    public var edgeScanCount: Int
    public var adjacencyLookupNodeCount: Int
    public var usedIncidentAdjacency: Bool

    public init(
        edgeIDs: [String],
        explicitActiveEdgeCount: Int,
        incidentEdgeCount: Int,
        droppedIncidentEdgeCount: Int,
        maximumIncidentEdgeCount: Int = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount,
        incidentCandidateEdgeCount: Int = 0,
        edgeScanCount: Int = 0,
        adjacencyLookupNodeCount: Int = 0,
        usedIncidentAdjacency: Bool = false
    ) {
        self.edgeIDs = edgeIDs
        self.explicitActiveEdgeCount = explicitActiveEdgeCount
        self.incidentEdgeCount = incidentEdgeCount
        self.droppedIncidentEdgeCount = droppedIncidentEdgeCount
        self.maximumIncidentEdgeCount = maximumIncidentEdgeCount
        self.incidentCandidateEdgeCount = incidentCandidateEdgeCount
        self.edgeScanCount = edgeScanCount
        self.adjacencyLookupNodeCount = adjacencyLookupNodeCount
        self.usedIncidentAdjacency = usedIncidentAdjacency
    }

    public var diagnostics: CanvasEdgeForceRetentionDiagnostics {
        CanvasEdgeForceRetentionDiagnostics(
            explicitActiveEdgeCount: explicitActiveEdgeCount,
            incidentEdgeCount: incidentEdgeCount,
            droppedIncidentEdgeCount: droppedIncidentEdgeCount,
            maximumIncidentEdgeCount: maximumIncidentEdgeCount,
            incidentCandidateEdgeCount: incidentCandidateEdgeCount,
            edgeScanCount: edgeScanCount,
            adjacencyLookupNodeCount: adjacencyLookupNodeCount,
            usedIncidentAdjacency: usedIncidentAdjacency
        )
    }
}

public enum CanvasEdgeForceRetentionPolicy {
    public static func forceRetainedEdgeIDs(
        in edges: [CanvasEdgeViewportRecord],
        selectedEdgeIDs: Set<String>,
        transientControlEdgeIDs: Set<String>,
        movedControlEdgeIDs: Set<String>,
        movingNodeIDs: Set<String>,
        maximumIncidentEdgeCount: Int = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
    ) -> CanvasEdgeForceRetentionResult {
        let explicitActiveIDs = selectedEdgeIDs
            .union(transientControlEdgeIDs)
            .union(movedControlEdgeIDs)
        let incidentLimit = max(0, maximumIncidentEdgeCount)
        var retainedIDs: [String] = []
        var retainedIDSet: Set<String> = []
        var explicitActiveEdgeCount = 0
        var incidentEdgeCount = 0
        var droppedIncidentEdgeCount = 0

        @discardableResult
        func appendRetained(_ id: String) -> Bool {
            guard retainedIDSet.insert(id).inserted else { return false }
            retainedIDs.append(id)
            return true
        }

        for edge in edges {
            if explicitActiveIDs.contains(edge.id) {
                if appendRetained(edge.id) {
                    explicitActiveEdgeCount += 1
                }
                continue
            }
            guard movingNodeIDs.contains(edge.sourceNodeID) || movingNodeIDs.contains(edge.targetNodeID) else {
                continue
            }
            guard incidentEdgeCount < incidentLimit else {
                droppedIncidentEdgeCount += 1
                continue
            }
            if appendRetained(edge.id) {
                incidentEdgeCount += 1
            }
        }

        return CanvasEdgeForceRetentionResult(
            edgeIDs: retainedIDs,
            explicitActiveEdgeCount: explicitActiveEdgeCount,
            incidentEdgeCount: incidentEdgeCount,
            droppedIncidentEdgeCount: droppedIncidentEdgeCount,
            maximumIncidentEdgeCount: incidentLimit,
            incidentCandidateEdgeCount: incidentEdgeCount + droppedIncidentEdgeCount,
            edgeScanCount: edges.count,
            adjacencyLookupNodeCount: 0,
            usedIncidentAdjacency: false
        )
    }
}

public enum CanvasEdgeViewportIndexCacheInvalidationReason: String, Equatable, Sendable {
    case initial
    case geometryChanged
    case bucketSizeChanged
}

public struct CanvasEdgeViewportIndexCacheDiagnostics: Equatable, Sendable {
    public var buildCount: Int
    public var reuseCount: Int
    public var lastInvalidationReason: CanvasEdgeViewportIndexCacheInvalidationReason

    public init(
        buildCount: Int = 0,
        reuseCount: Int = 0,
        lastInvalidationReason: CanvasEdgeViewportIndexCacheInvalidationReason = .initial
    ) {
        self.buildCount = buildCount
        self.reuseCount = reuseCount
        self.lastInvalidationReason = lastInvalidationReason
    }
}

public final class CanvasEdgeViewportIndexCache {
    public typealias LogEventHandler = (MindDeskHiddenMaintenanceLogEvent) -> Void

    private struct Signature: Equatable {
        var bucketSize: Double
        var nodes: [NodeSignature]
        var edges: [EdgeSignature]
    }

    private struct NodeSignature: Equatable {
        var id: String
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
    }

    private struct EdgeSignature: Equatable {
        var id: String
        var sourceNodeID: String
        var targetNodeID: String
        var controlPointX: Double?
        var controlPointY: Double?
    }

    private var signature: Signature?
    private var cachedIndex: CanvasEdgeViewportIndex?
    private let logEvent: LogEventHandler
    public private(set) var diagnostics: CanvasEdgeViewportIndexCacheDiagnostics

    public init(
        diagnostics: CanvasEdgeViewportIndexCacheDiagnostics = CanvasEdgeViewportIndexCacheDiagnostics(),
        logEvent: LogEventHandler? = nil
    ) {
        self.diagnostics = diagnostics
        self.logEvent = logEvent ?? MindDeskHiddenMaintenanceLogger.log
    }

    public func index(
        nodes: [CanvasFrameRect],
        edges: [CanvasEdgeViewportRecord],
        bucketSize: Double = 512
    ) -> CanvasEdgeViewportIndex {
        let nextSignature = Signature(
            bucketSize: Self.resolvedBucketSize(bucketSize),
            nodes: nodes.map {
                Self.nodeSignature(for: $0)
            },
            edges: edges.map {
                Self.edgeSignature(for: $0)
            }
        )

        if signature == nextSignature, let cachedIndex {
            diagnostics.reuseCount += 1
            logEvent(.canvasEdgeViewportIndexCacheReused(reuseCount: diagnostics.reuseCount))
            return cachedIndex
        }

        let invalidationReason = Self.invalidationReason(
            previous: signature,
            next: nextSignature
        )
        if signature != nil && cachedIndex != nil {
            logEvent(.canvasEdgeViewportIndexCacheCleanedUp(
                reason: invalidationReason,
                buildCount: diagnostics.buildCount,
                reuseCount: diagnostics.reuseCount
            ))
        }
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: edges,
            bucketSize: bucketSize
        )
        signature = nextSignature
        cachedIndex = index
        diagnostics.buildCount += 1
        diagnostics.lastInvalidationReason = invalidationReason
        logEvent(.canvasEdgeViewportIndexCacheCreated(
            reason: invalidationReason,
            buildCount: diagnostics.buildCount,
            totalEdgeCount: index.diagnostics.totalEdgeCount,
            indexedEdgeCount: index.diagnostics.indexedEdgeCount
        ))
        return index
    }

    private static func invalidationReason(
        previous: Signature?,
        next: Signature
    ) -> CanvasEdgeViewportIndexCacheInvalidationReason {
        guard let previous else { return .initial }
        if previous.bucketSize != next.bucketSize {
            return .bucketSizeChanged
        }
        return .geometryChanged
    }

    private static func nodeSignature(for node: CanvasFrameRect) -> NodeSignature {
        guard hasFiniteBounds(
            x: node.x,
            y: node.y,
            width: node.width,
            height: node.height
        ) else {
            return NodeSignature(id: node.id, x: nil, y: nil, width: nil, height: nil)
        }
        return NodeSignature(
            id: node.id,
            x: node.x,
            y: node.y,
            width: node.width,
            height: node.height
        )
    }

    private static func edgeSignature(for edge: CanvasEdgeViewportRecord) -> EdgeSignature {
        let controlPoint = normalizedControlPointSignature(edge.controlPoint)
        return EdgeSignature(
            id: edge.id,
            sourceNodeID: edge.sourceNodeID,
            targetNodeID: edge.targetNodeID,
            controlPointX: controlPoint?.x,
            controlPointY: controlPoint?.y
        )
    }

    private static func normalizedControlPointSignature(
        _ controlPoint: CanvasEdgePoint?
    ) -> (x: Double, y: Double)? {
        guard let controlPoint,
              controlPoint.x.isFinite,
              controlPoint.y.isFinite else {
            return nil
        }
        return (controlPoint.x, controlPoint.y)
    }

    private static func hasFiniteBounds(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> Bool {
        guard x.isFinite,
              y.isFinite,
              width.isFinite,
              height.isFinite else {
            return false
        }
        return (x + width).isFinite && (y + height).isFinite
    }

    private static func resolvedBucketSize(_ bucketSize: Double) -> Double {
        bucketSize.isFinite && bucketSize > 0 ? bucketSize : 512
    }
}

public enum CanvasEdgeVisibilityPlanner {
    public static func plan(
        nodes: [CanvasFrameRect],
        edges: [CanvasEdgeViewportRecord],
        viewport: CanvasFrameRect,
        overscan: Double,
        selectedEdgeIDs: Set<String>,
        transientControlEdgeIDs: Set<String>,
        movedControlEdgeIDs: Set<String>,
        movingNodeIDs: Set<String>,
        visibleObstacleCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool,
        isAnimationSuspendingInteraction: Bool? = nil,
        animationsEnabled: Bool = true,
        reduceMotion: Bool = false,
        animationTheme: String = "blue",
        bucketSize: Double = 512
    ) -> CanvasEdgeVisibilityPlan {
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: edges,
            bucketSize: bucketSize
        )
        return plan(
            edgeIndex: index,
            viewport: viewport,
            overscan: overscan,
            selectedEdgeIDs: selectedEdgeIDs,
            transientControlEdgeIDs: transientControlEdgeIDs,
            movedControlEdgeIDs: movedControlEdgeIDs,
            movingNodeIDs: movingNodeIDs,
            visibleObstacleCount: visibleObstacleCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isInteracting,
            isAnimationSuspendingInteraction: isAnimationSuspendingInteraction,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            animationTheme: animationTheme
        )
    }

    public static func plan(
        edgeIndex index: CanvasEdgeViewportIndex,
        cacheDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics? = nil,
        viewport: CanvasFrameRect,
        overscan: Double,
        selectedEdgeIDs: Set<String>,
        transientControlEdgeIDs: Set<String>,
        movedControlEdgeIDs: Set<String>,
        movingNodeIDs: Set<String>,
        visibleObstacleCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool,
        isAnimationSuspendingInteraction: Bool? = nil,
        animationsEnabled: Bool = true,
        reduceMotion: Bool = false,
        animationTheme: String = "blue"
    ) -> CanvasEdgeVisibilityPlan {
        let forceRetention = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: selectedEdgeIDs,
            transientControlEdgeIDs: transientControlEdgeIDs,
            movedControlEdgeIDs: movedControlEdgeIDs,
            movingNodeIDs: movingNodeIDs
        )
        return plan(
            edgeIndex: index,
            cacheDiagnostics: cacheDiagnostics,
            viewport: viewport,
            overscan: overscan,
            forceRetention: forceRetention,
            visibleObstacleCount: visibleObstacleCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isInteracting,
            isAnimationSuspendingInteraction: isAnimationSuspendingInteraction,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            animationTheme: animationTheme
        )
    }

    public static func plan(
        edgeIndex index: CanvasEdgeViewportIndex,
        cacheDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics? = nil,
        viewport: CanvasFrameRect,
        overscan: Double,
        forcedEdgeIDs: Set<String>,
        visibleObstacleCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool,
        isAnimationSuspendingInteraction: Bool? = nil,
        animationsEnabled: Bool = true,
        reduceMotion: Bool = false,
        animationTheme: String = "blue"
    ) -> CanvasEdgeVisibilityPlan {
        makePlan(
            edgeIndex: index,
            cacheDiagnostics: cacheDiagnostics,
            viewport: viewport,
            overscan: overscan,
            forcedEdgeIDs: forcedEdgeIDs,
            forceRetention: .empty,
            visibleObstacleCount: visibleObstacleCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isInteracting,
            isAnimationSuspendingInteraction: isAnimationSuspendingInteraction,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            animationTheme: animationTheme
        )
    }

    public static func plan(
        edgeIndex index: CanvasEdgeViewportIndex,
        cacheDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics? = nil,
        viewport: CanvasFrameRect,
        overscan: Double,
        forceRetention: CanvasEdgeForceRetentionResult,
        visibleObstacleCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool,
        isAnimationSuspendingInteraction: Bool? = nil,
        animationsEnabled: Bool = true,
        reduceMotion: Bool = false,
        animationTheme: String = "blue"
    ) -> CanvasEdgeVisibilityPlan {
        makePlan(
            edgeIndex: index,
            cacheDiagnostics: cacheDiagnostics,
            viewport: viewport,
            overscan: overscan,
            forcedEdgeIDs: Set(forceRetention.edgeIDs),
            forceRetention: forceRetention.diagnostics,
            visibleObstacleCount: visibleObstacleCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isInteracting,
            isAnimationSuspendingInteraction: isAnimationSuspendingInteraction,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            animationTheme: animationTheme
        )
    }

    private static func makePlan(
        edgeIndex index: CanvasEdgeViewportIndex,
        cacheDiagnostics: CanvasEdgeViewportIndexCacheDiagnostics?,
        viewport: CanvasFrameRect,
        overscan: Double,
        forcedEdgeIDs: Set<String>,
        forceRetention: CanvasEdgeForceRetentionDiagnostics,
        visibleObstacleCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool,
        isAnimationSuspendingInteraction: Bool?,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        animationTheme: String
    ) -> CanvasEdgeVisibilityPlan {
        let visibleQuery = index.query(
            visibleRect: viewport,
            overscan: overscan
        )
        let renderQuery = index.query(
            visibleRect: viewport,
            overscan: overscan,
            forcedEdgeIDs: forcedEdgeIDs
        )
        let forceRetainedEdgeIDs = Set(renderQuery.edgeIDs.filter { forcedEdgeIDs.contains($0) })
        let usesObstacleRouting = zoom.isFinite &&
            baselineZoom.isFinite &&
            zoom >= baselineZoom &&
            CanvasPerformancePolicy.usesObstacleRouting(
                edgeCount: renderQuery.candidateEdgeCount,
                obstacleCount: visibleObstacleCount,
                isInteracting: isInteracting
            )
        let animatesVisibleEdges = CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: animationTheme,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            visibleEdgeCount: renderQuery.candidateEdgeCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isAnimationSuspendingInteraction ?? isInteracting
        )
        return CanvasEdgeVisibilityPlan(
            renderEdgeIDs: renderQuery.edgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            visibleCandidateCount: visibleQuery.candidateEdgeCount,
            usesObstacleRouting: usesObstacleRouting,
            animatesVisibleEdges: animatesVisibleEdges,
            diagnostics: CanvasEdgeVisibilityDiagnostics(
                index: index.diagnostics,
                visibleQuery: visibleQuery.diagnostics,
                renderQuery: renderQuery.diagnostics,
                cache: cacheDiagnostics,
                forceRetention: forceRetention,
                forceRetainedEdgeCount: forceRetainedEdgeIDs.count,
                renderEdgeCount: renderQuery.edgeIDs.count
            )
        )
    }

}

public struct CanvasEdgeViewportIndex: Sendable {
    private struct Bucket: Hashable, Sendable {
        var x: Int
        var y: Int
    }

    private enum BucketSelection: Sendable {
        case enumerated([Bucket])
        case bounded
    }

    private struct Bounds: Equatable, Sendable {
        var minX: Double
        var minY: Double
        var maxX: Double
        var maxY: Double

        var isEmpty: Bool {
            minX > maxX || minY > maxY
        }

        func expanded(by amount: Double) -> Bounds {
            let safeAmount = amount.isFinite ? max(0, amount) : 0
            return Bounds(
                minX: minX - safeAmount,
                minY: minY - safeAmount,
                maxX: maxX + safeAmount,
                maxY: maxY + safeAmount
            )
        }

        func union(_ other: Bounds) -> Bounds {
            Bounds(
                minX: min(minX, other.minX),
                minY: min(minY, other.minY),
                maxX: max(maxX, other.maxX),
                maxY: max(maxY, other.maxY)
            )
        }

        func intersects(_ other: Bounds) -> Bool {
            !(maxX < other.minX ||
              other.maxX < minX ||
              maxY < other.minY ||
              other.maxY < minY)
        }
    }

    private struct IndexedEdge: Sendable {
        var record: CanvasEdgeViewportRecord
        var bounds: Bounds
        var order: Int
    }

    private struct NodePair: Hashable, Sendable {
        var first: String
        var second: String

        init(_ lhs: String, _ rhs: String) {
            if lhs <= rhs {
                first = lhs
                second = rhs
            } else {
                first = rhs
                second = lhs
            }
        }
    }

    private struct IncidentAdjacencyCursor: Sendable {
        var nodeID: String
        var position: Int
    }

    private static let maximumBucketEnumerationCount = 8_192

    private var indexedEdgesByID: [String: IndexedEdge]
    private var edgeIDsByBucket: [Bucket: [String]]
    private var edgeOrderByID: [String: Int]
    private var edgeIDsByNodeID: [String: [String]]
    private var nonSelfEdgeCountByNodePair: [NodePair: Int]
    private var fallbackEdgeIDs: Set<String>
    private var bucketSize: Double
    public var diagnostics: CanvasEdgeViewportIndexDiagnostics

    public init(
        nodes: [CanvasFrameRect],
        edges: [CanvasEdgeViewportRecord],
        bucketSize: Double = 512
    ) {
        let bucketSizeWasDefaulted = !(bucketSize.isFinite && bucketSize > 0)
        let resolvedBucketSize = bucketSizeWasDefaulted ? 512 : bucketSize

        let nodeBoundsByID = Dictionary(
            nodes.compactMap { node -> (String, Bounds)? in
                guard let bounds = Self.bounds(for: node) else { return nil }
                return (node.id, bounds)
            },
            uniquingKeysWith: { first, _ in first }
        )

        var indexedEdgesByID: [String: IndexedEdge] = [:]
        var edgeIDsByBucket: [Bucket: [String]] = [:]
        var edgeOrderByID: [String: Int] = [:]
        var edgeIDsByNodeID: [String: [String]] = [:]
        var nonSelfEdgeCountByNodePair: [NodePair: Int] = [:]
        var fallbackEdgeIDs: Set<String> = []
        var seenEdgeIDs: Set<String> = []
        var duplicateEdgeCount = 0
        var droppedDanglingEdgeCount = 0
        var droppedInvalidGeometryEdgeCount = 0
        var bucketedEdgeCount = 0
        var bucketFallbackEdgeCount = 0
        let nodeIDs = Set(nodes.map(\.id))

        for edge in edges {
            guard let sourceBounds = nodeBoundsByID[edge.sourceNodeID],
                  let targetBounds = nodeBoundsByID[edge.targetNodeID] else {
                if nodeIDs.contains(edge.sourceNodeID) && nodeIDs.contains(edge.targetNodeID) {
                    droppedInvalidGeometryEdgeCount += 1
                } else {
                    droppedDanglingEdgeCount += 1
                }
                continue
            }
            guard !seenEdgeIDs.contains(edge.id) else {
                duplicateEdgeCount += 1
                continue
            }
            seenEdgeIDs.insert(edge.id)
            var edgeBounds = sourceBounds.union(targetBounds)
            if let controlBounds = Self.bounds(for: edge.controlPoint) {
                edgeBounds = edgeBounds.union(controlBounds)
            }

            let indexedEdge = IndexedEdge(record: edge, bounds: edgeBounds, order: indexedEdgesByID.count)
            indexedEdgesByID[edge.id] = indexedEdge
            edgeOrderByID[edge.id] = indexedEdge.order
            edgeIDsByNodeID[edge.sourceNodeID, default: []].append(edge.id)
            if edge.targetNodeID != edge.sourceNodeID {
                edgeIDsByNodeID[edge.targetNodeID, default: []].append(edge.id)
                nonSelfEdgeCountByNodePair[
                    NodePair(edge.sourceNodeID, edge.targetNodeID),
                    default: 0
                ] += 1
            }
            switch Self.bucketSelection(overlapping: edgeBounds, bucketSize: resolvedBucketSize) {
            case let .enumerated(buckets):
                bucketedEdgeCount += 1
                for bucket in buckets {
                    edgeIDsByBucket[bucket, default: []].append(edge.id)
                }
            case .bounded:
                bucketFallbackEdgeCount += 1
                fallbackEdgeIDs.insert(edge.id)
            }
        }

        self.indexedEdgesByID = indexedEdgesByID
        self.edgeIDsByBucket = edgeIDsByBucket
        self.edgeOrderByID = edgeOrderByID
        self.edgeIDsByNodeID = edgeIDsByNodeID
        self.nonSelfEdgeCountByNodePair = nonSelfEdgeCountByNodePair
        self.fallbackEdgeIDs = fallbackEdgeIDs
        self.bucketSize = resolvedBucketSize
        self.diagnostics = CanvasEdgeViewportIndexDiagnostics(
            totalEdgeCount: edges.count,
            indexedEdgeCount: indexedEdgesByID.count,
            duplicateEdgeCount: duplicateEdgeCount,
            droppedDanglingEdgeCount: droppedDanglingEdgeCount,
            droppedInvalidGeometryEdgeCount: droppedInvalidGeometryEdgeCount,
            bucketSize: resolvedBucketSize,
            bucketSizeWasDefaulted: bucketSizeWasDefaulted,
            bucketedEdgeCount: bucketedEdgeCount,
            bucketFallbackEdgeCount: bucketFallbackEdgeCount
        )
    }

    public func forceRetainedEdgeIDs(
        selectedEdgeIDs: Set<String>,
        transientControlEdgeIDs: Set<String>,
        movedControlEdgeIDs: Set<String>,
        movingNodeIDs: Set<String>,
        maximumIncidentEdgeCount: Int = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
    ) -> CanvasEdgeForceRetentionResult {
        let explicitActiveIDs = selectedEdgeIDs
            .union(transientControlEdgeIDs)
            .union(movedControlEdgeIDs)
        let validExplicitIDs = Set(validEdgeIDs(explicitActiveIDs))
        let incidentLimit = max(0, maximumIncidentEdgeCount)
        let incidentCandidateEdgeCount = incidentCandidateEdgeCount(
            movingNodeIDs: movingNodeIDs,
            validExplicitIDs: validExplicitIDs
        )
        let incidentRetention = retainedIncidentEdgeIDs(
            movingNodeIDs: movingNodeIDs,
            validExplicitIDs: validExplicitIDs,
            maximumIncidentEdgeCount: incidentLimit
        )
        let retainedIncidentIDs = incidentRetention.edgeIDs
        let retainedIDs = orderedValidEdgeIDs(validExplicitIDs.union(retainedIncidentIDs))
        let incidentEdgeCount = retainedIncidentIDs.count

        return CanvasEdgeForceRetentionResult(
            edgeIDs: retainedIDs,
            explicitActiveEdgeCount: validExplicitIDs.count,
            incidentEdgeCount: incidentEdgeCount,
            droppedIncidentEdgeCount: incidentCandidateEdgeCount - incidentEdgeCount,
            maximumIncidentEdgeCount: incidentLimit,
            incidentCandidateEdgeCount: incidentCandidateEdgeCount,
            edgeScanCount: validExplicitIDs.count + incidentRetention.adjacencyVisitCount,
            adjacencyLookupNodeCount: movingNodeIDs.count,
            usedIncidentAdjacency: true
        )
    }

    private func incidentCandidateEdgeCount(
        movingNodeIDs: Set<String>,
        validExplicitIDs: Set<String>
    ) -> Int {
        let adjacencyEntryCount = movingNodeIDs.reduce(0) { count, nodeID in
            count + edgeIDsByNodeID[nodeID, default: []].count
        }
        let movingNodes = movingNodeIDs.sorted()
        var internalMovingEdgeDuplicateCount = 0
        for sourceIndex in movingNodes.indices {
            let nextIndex = movingNodes.index(after: sourceIndex)
            guard nextIndex < movingNodes.endIndex else { continue }
            for targetIndex in nextIndex..<movingNodes.endIndex {
                internalMovingEdgeDuplicateCount += nonSelfEdgeCountByNodePair[
                    NodePair(movingNodes[sourceIndex], movingNodes[targetIndex]),
                    default: 0
                ]
            }
        }
        let explicitIncidentEdgeCount = validExplicitIDs.reduce(0) { count, edgeID in
            guard let edge = indexedEdgesByID[edgeID]?.record else { return count }
            let isIncident = movingNodeIDs.contains(edge.sourceNodeID) ||
                movingNodeIDs.contains(edge.targetNodeID)
            return count + (isIncident ? 1 : 0)
        }

        return max(0, adjacencyEntryCount - internalMovingEdgeDuplicateCount - explicitIncidentEdgeCount)
    }

    private func retainedIncidentEdgeIDs(
        movingNodeIDs: Set<String>,
        validExplicitIDs: Set<String>,
        maximumIncidentEdgeCount: Int
    ) -> (edgeIDs: Set<String>, adjacencyVisitCount: Int) {
        guard maximumIncidentEdgeCount > 0,
              !movingNodeIDs.isEmpty else {
            return ([], 0)
        }

        let movingNodes = movingNodeIDs.sorted()
        var cursors = movingNodes.map { IncidentAdjacencyCursor(nodeID: $0, position: 0) }
        var seenIncidentIDs: Set<String> = []
        var retainedIncidentIDs: Set<String> = []
        var adjacencyVisitCount = 0

        while retainedIncidentIDs.count < maximumIncidentEdgeCount {
            var selectedCursorIndex: Int?
            var selectedEdgeID: String?
            var selectedEdgeOrder = Int.max

            for cursorIndex in cursors.indices {
                var cursor = cursors[cursorIndex]
                let edgeIDs = edgeIDsByNodeID[cursor.nodeID, default: []]
                while cursor.position < edgeIDs.count {
                    let candidateID = edgeIDs[cursor.position]
                    if seenIncidentIDs.contains(candidateID) {
                        cursor.position += 1
                        adjacencyVisitCount += 1
                        continue
                    }

                    let candidateOrder = edgeOrderByID[candidateID] ?? Int.max
                    if candidateOrder < selectedEdgeOrder ||
                        (candidateOrder == selectedEdgeOrder && candidateID < (selectedEdgeID ?? candidateID)) {
                        selectedCursorIndex = cursorIndex
                        selectedEdgeID = candidateID
                        selectedEdgeOrder = candidateOrder
                    }
                    break
                }
                cursors[cursorIndex] = cursor
            }

            guard let cursorIndex = selectedCursorIndex,
                  let edgeID = selectedEdgeID else {
                break
            }

            cursors[cursorIndex].position += 1
            adjacencyVisitCount += 1
            guard seenIncidentIDs.insert(edgeID).inserted else { continue }
            guard !validExplicitIDs.contains(edgeID) else { continue }
            retainedIncidentIDs.insert(edgeID)
        }

        return (retainedIncidentIDs, adjacencyVisitCount)
    }

    public func query(
        visibleRect: CanvasFrameRect,
        overscan: Double,
        forcedEdgeIDs: Set<String> = []
    ) -> CanvasEdgeViewportQueryResult {
        let forcedRequestedCount = forcedEdgeIDs.count
        let validForcedIDs = Set(validEdgeIDs(forcedEdgeIDs))
        guard let visibleBounds = Self.bounds(for: visibleRect)?.expanded(by: overscan) else {
            let forcedIDs = orderedValidEdgeIDs(validForcedIDs)
            let orderedScanCount = forcedIDs.count
            return CanvasEdgeViewportQueryResult(
                edgeIDs: forcedIDs,
                examinedEdgeCount: 0,
                orderedScanCount: orderedScanCount,
                diagnostics: CanvasEdgeViewportQueryDiagnostics(
                    queriedBucketCount: 0,
                    bucketCandidateEdgeCount: 0,
                    candidateExaminedCount: 0,
                    orderedScanCount: orderedScanCount,
                    forcedRequestedCount: forcedRequestedCount,
                    forcedValidCount: validForcedIDs.count,
                    forcedInvalidCount: forcedRequestedCount - validForcedIDs.count,
                    forcedRetentionCount: forcedIDs.count,
                    renderEdgeCount: forcedIDs.count
                )
            )
        }

        var candidateIDs: Set<String> = []
        var queriedBucketCount = 0
        var bucketCandidateEdgeCount = 0
        var fallbackExaminedIDs: Set<String> = []
        let bucketEnumerationWasBounded: Bool
        switch Self.bucketSelection(overlapping: visibleBounds, bucketSize: bucketSize) {
        case let .enumerated(queriedBuckets):
            bucketEnumerationWasBounded = false
            queriedBucketCount = queriedBuckets.count
            for bucket in queriedBuckets {
                for edgeID in edgeIDsByBucket[bucket, default: []] {
                    bucketCandidateEdgeCount += 1
                    candidateIDs.insert(edgeID)
                }
            }
            fallbackExaminedIDs.formUnion(fallbackEdgeIDs)
        case .bounded:
            bucketEnumerationWasBounded = true
            fallbackExaminedIDs.formUnion(indexedEdgesByID.keys)
        }

        candidateIDs.formUnion(fallbackExaminedIDs)
        candidateIDs.formUnion(validForcedIDs)
        let examinedEdgeCount = candidateIDs.count

        let orderedMatches = candidateIDs.compactMap { edgeID -> IndexedEdge? in
            guard let indexedEdge = indexedEdgesByID[edgeID] else { return nil }
            guard forcedEdgeIDs.contains(edgeID) || indexedEdge.bounds.intersects(visibleBounds) else {
                return nil
            }
            return indexedEdge
        }
            .sorted { lhs, rhs in
                if lhs.order != rhs.order {
                    return lhs.order < rhs.order
                }
                return lhs.record.id < rhs.record.id
            }
        let orderedScanCount = orderedMatches.count
        let edgeIDs = orderedMatches.map(\.record.id)

        return CanvasEdgeViewportQueryResult(
            edgeIDs: edgeIDs,
            examinedEdgeCount: examinedEdgeCount,
            orderedScanCount: orderedScanCount,
            diagnostics: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: queriedBucketCount,
                bucketCandidateEdgeCount: bucketCandidateEdgeCount,
                candidateExaminedCount: examinedEdgeCount,
                orderedScanCount: orderedScanCount,
                forcedRequestedCount: forcedRequestedCount,
                forcedValidCount: validForcedIDs.count,
                forcedInvalidCount: forcedRequestedCount - validForcedIDs.count,
                forcedRetentionCount: edgeIDs.filter { validForcedIDs.contains($0) }.count,
                renderEdgeCount: edgeIDs.count,
                fallbackExaminedEdgeCount: fallbackExaminedIDs.count,
                bucketEnumerationWasBounded: bucketEnumerationWasBounded
            )
        )
    }

    private func orderedValidEdgeIDs(_ ids: Set<String>) -> [String] {
        validEdgeIDs(ids)
            .sorted { lhs, rhs in
                let lhsOrder = edgeOrderByID[lhs] ?? Int.max
                let rhsOrder = edgeOrderByID[rhs] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs < rhs
            }
    }

    private func validEdgeIDs(_ ids: Set<String>) -> [String] {
        ids.filter { indexedEdgesByID[$0] != nil }
    }

    private static func bounds(for rect: CanvasFrameRect) -> Bounds? {
        guard rect.x.isFinite,
              rect.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite else {
            return nil
        }
        let right = rect.x + rect.width
        let bottom = rect.y + rect.height
        guard right.isFinite, bottom.isFinite else { return nil }
        return Bounds(
            minX: min(rect.x, right),
            minY: min(rect.y, bottom),
            maxX: max(rect.x, right),
            maxY: max(rect.y, bottom)
        )
    }

    private static func bounds(for point: CanvasEdgePoint?) -> Bounds? {
        guard let point,
              point.x.isFinite,
              point.y.isFinite else {
            return nil
        }
        return Bounds(minX: point.x, minY: point.y, maxX: point.x, maxY: point.y)
    }

    private static func bucketSelection(overlapping bounds: Bounds, bucketSize: Double) -> BucketSelection {
        guard !bounds.isEmpty,
              bucketSize.isFinite,
              bucketSize > 0 else {
            return .enumerated([])
        }
        guard let minBucketX = bucketCoordinate(for: bounds.minX, bucketSize: bucketSize),
              let maxBucketX = bucketCoordinate(for: bounds.maxX, bucketSize: bucketSize),
              let minBucketY = bucketCoordinate(for: bounds.minY, bucketSize: bucketSize),
              let maxBucketY = bucketCoordinate(for: bounds.maxY, bucketSize: bucketSize) else {
            return .bounded
        }
        guard minBucketX <= maxBucketX, minBucketY <= maxBucketY else {
            return .enumerated([])
        }
        let xCount = Double(maxBucketX) - Double(minBucketX) + 1
        let yCount = Double(maxBucketY) - Double(minBucketY) + 1
        guard xCount.isFinite,
              yCount.isFinite,
              xCount > 0,
              yCount > 0,
              xCount * yCount <= Double(maximumBucketEnumerationCount) else {
            return .bounded
        }

        var buckets: [Bucket] = []
        for x in minBucketX...maxBucketX {
            for y in minBucketY...maxBucketY {
                buckets.append(Bucket(x: x, y: y))
            }
        }
        return .enumerated(buckets)
    }

    private static func bucketCoordinate(for value: Double, bucketSize: Double) -> Int? {
        let bucket = floor(value / bucketSize)
        guard bucket.isFinite else { return nil }
        return Int(exactly: bucket)
    }
}
