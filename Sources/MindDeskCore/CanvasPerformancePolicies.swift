import Foundation

public extension CanvasPerformancePolicy {
    static var maximumAnimatedVisibleEdgeCount: Int { 12 }
    static var maximumBalancedAnimatedVisibleEdgeCount: Int { 8 }
    static var maximumSmoothAnimatedVisibleEdgeCount: Int { 4 }
    static var maximumAnimatedFlowStrokePaintsPerSecond: Int { 240 }
    static var maximumAnimatedVisibleCardCount: Int { 60 }
    static var maximumBalancedAnimatedVisibleCardCount: Int { 40 }
    static var maximumSmoothAnimatedVisibleCardCount: Int { 20 }
    static var maximumAnimatedRoutePointCount: Int { 96 }
    static var maximumBalancedAnimatedRoutePointCount: Int { 64 }
    static var maximumSmoothAnimatedRoutePointCount: Int { 24 }
    static var maximumDetailedVisibleCardCount: Int { 48 }
    static var maximumDetailedInteractingVisibleCardCount: Int { 8 }
    static var maximumRichSpatialInteractionCardCount: Int { 48 }
    static var maximumContextEdgesDuringInteraction: Int { 48 }
    static var maximumMovingNodeIncidentForceRetainedEdgeCount: Int { maximumContextEdgesDuringInteraction }
    static var maximumPassiveResizeHandleNodeCount: Int { 12 }
    static var maximumPassiveEdgeControlHandleCount: Int { 24 }
    static var minimumPassiveEdgeControlZoom: Double { 0.30 }
    static var minimumDetailedCardZoomRatio: Double { 0.75 }
}

public enum CanvasEdgeAnimationTimelineReason: String, Equatable, Sendable {
    case withinBudget
    case animationsDisabled
    case reduceMotionEnabled
    case themeOff
    case noVisibleEdges
    case invalidLoad
    case tooManyVisibleEdges
    case tooManyVisibleCards
    case tooManyRoutedPoints
    case invalidZoom
    case zoomBelowBaseline
    case interacting
    case flowStrokeWorkOverBudget
}

public struct CanvasEdgeAnimationTimelinePlan: Equatable, Sendable {
    public var minimumInterval: Double?
    public var effectiveFrameRate: CanvasAnimationFrameRate?
    public var estimatedFlowStrokePaintsPerSecond: Int
    public var reason: CanvasEdgeAnimationTimelineReason

    public var shouldAnimate: Bool {
        minimumInterval != nil
    }

    public init(
        minimumInterval: Double?,
        effectiveFrameRate: CanvasAnimationFrameRate?,
        estimatedFlowStrokePaintsPerSecond: Int,
        reason: CanvasEdgeAnimationTimelineReason
    ) {
        self.minimumInterval = minimumInterval
        self.effectiveFrameRate = effectiveFrameRate
        self.estimatedFlowStrokePaintsPerSecond = estimatedFlowStrokePaintsPerSecond
        self.reason = reason
    }
}

public extension CanvasEdgeAnimationPolicy {
    static func timelineMinimumInterval(frameRate: CanvasAnimationFrameRate) -> Double {
        switch frameRate {
        case .reduced:
            1.0 / 15.0
        case .balanced:
            1.0 / 30.0
        case .smooth:
            1.0 / 60.0
        }
    }

    static func effectiveTimelineMinimumInterval(
        preferredFrameRate: CanvasAnimationFrameRate,
        visibleEdgeCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        isInteracting: Bool
    ) -> Double {
        let preferredInterval = timelineMinimumInterval(frameRate: preferredFrameRate)
        let loadInterval = timelineMinimumInterval(
            frameRate: effectiveFrameRate(
                visibleEdgeCount: visibleEdgeCount,
                visibleCardCount: visibleCardCount,
                routedPointCount: routedPointCount,
                isInteracting: isInteracting
            )
        )
        return max(preferredInterval, loadInterval)
    }

    static func effectiveTimelineMinimumInterval(
        preferredFrameRate: CanvasAnimationFrameRate,
        theme: String,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        visibleEdgeCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool
    ) -> Double? {
        effectiveTimelinePlan(
            preferredFrameRate: preferredFrameRate,
            theme: theme,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            visibleEdgeCount: visibleEdgeCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            zoom: zoom,
            baselineZoom: baselineZoom,
            isInteracting: isInteracting
        ).minimumInterval
    }

    static func effectiveTimelinePlan(
        preferredFrameRate: CanvasAnimationFrameRate,
        theme: String,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        visibleEdgeCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool
    ) -> CanvasEdgeAnimationTimelinePlan {
        func stopped(_ reason: CanvasEdgeAnimationTimelineReason) -> CanvasEdgeAnimationTimelinePlan {
            CanvasEdgeAnimationTimelinePlan(
                minimumInterval: nil,
                effectiveFrameRate: nil,
                estimatedFlowStrokePaintsPerSecond: 0,
                reason: reason
            )
        }

        guard visibleEdgeCount >= 0,
              visibleCardCount >= 0,
              routedPointCount >= 0 else {
            return stopped(.invalidLoad)
        }
        guard visibleEdgeCount > 0 else {
            return stopped(.noVisibleEdges)
        }
        guard visibleEdgeCount <= CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount else {
            return stopped(.tooManyVisibleEdges)
        }
        guard visibleCardCount <= CanvasPerformancePolicy.maximumAnimatedVisibleCardCount else {
            return stopped(.tooManyVisibleCards)
        }
        guard routedPointCount <= CanvasPerformancePolicy.maximumAnimatedRoutePointCount else {
            return stopped(.tooManyRoutedPoints)
        }
        guard animationsEnabled else {
            return stopped(.animationsDisabled)
        }
        guard !reduceMotion else {
            return stopped(.reduceMotionEnabled)
        }
        guard theme != "off" else {
            return stopped(.themeOff)
        }
        guard !isInteracting else {
            return stopped(.interacting)
        }
        guard zoom.isFinite,
              baselineZoom.isFinite,
              baselineZoom > 0 else {
            return stopped(.invalidZoom)
        }
        guard zoom >= baselineZoom else {
            return stopped(.zoomBelowBaseline)
        }

        let loadFrameRate = effectiveFrameRate(
            visibleEdgeCount: visibleEdgeCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            isInteracting: false
        )
        let minimumInterval = effectiveTimelineMinimumInterval(
            preferredFrameRate: preferredFrameRate,
            visibleEdgeCount: visibleEdgeCount,
            visibleCardCount: visibleCardCount,
            routedPointCount: routedPointCount,
            isInteracting: false
        )
        let resolvedFrameRate = frameRate(forMinimumInterval: minimumInterval)
        let estimatedPaintsPerSecond = estimatedFlowStrokePaintsPerSecond(
            visibleEdgeCount: visibleEdgeCount,
            frameRate: resolvedFrameRate
        )
        guard estimatedPaintsPerSecond <= CanvasPerformancePolicy.maximumAnimatedFlowStrokePaintsPerSecond else {
            return stopped(.flowStrokeWorkOverBudget)
        }

        return CanvasEdgeAnimationTimelinePlan(
            minimumInterval: minimumInterval,
            effectiveFrameRate: resolvedFrameRate ?? loadFrameRate,
            estimatedFlowStrokePaintsPerSecond: estimatedPaintsPerSecond,
            reason: .withinBudget
        )
    }

    static func shouldAnimateVisibleEdges(
        theme: String,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        visibleEdgeCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        zoom: Double,
        baselineZoom: Double,
        isInteracting: Bool
    ) -> Bool {
        guard visibleEdgeCount >= 0,
              visibleCardCount >= 0,
              routedPointCount >= 0,
              visibleEdgeCount <= CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount,
              visibleCardCount <= CanvasPerformancePolicy.maximumAnimatedVisibleCardCount,
              routedPointCount <= CanvasPerformancePolicy.maximumAnimatedRoutePointCount else {
            return false
        }
        guard zoom.isFinite,
              baselineZoom.isFinite,
              baselineZoom > 0,
              zoom >= baselineZoom else {
            return false
        }
        return shouldAnimateEdge(
            theme: theme,
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion,
            edgeCount: visibleEdgeCount,
            isInteracting: isInteracting
        )
    }

    static func effectiveFrameRate(
        visibleEdgeCount: Int,
        visibleCardCount: Int,
        routedPointCount: Int,
        isInteracting: Bool
    ) -> CanvasAnimationFrameRate {
        if isInteracting {
            return .reduced
        }

        let edgeCount = max(0, visibleEdgeCount)
        let cardCount = max(0, visibleCardCount)
        let routePointCount = max(0, routedPointCount)
        if edgeCount > CanvasPerformancePolicy.maximumBalancedAnimatedVisibleEdgeCount ||
            cardCount > CanvasPerformancePolicy.maximumBalancedAnimatedVisibleCardCount ||
            routePointCount > CanvasPerformancePolicy.maximumBalancedAnimatedRoutePointCount {
            return .reduced
        }
        if edgeCount > CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount ||
            cardCount > CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount ||
            routePointCount > CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount {
            return .balanced
        }
        return .smooth
    }

    private static func frameRate(forMinimumInterval interval: Double) -> CanvasAnimationFrameRate? {
        if abs(interval - timelineMinimumInterval(frameRate: .reduced)) < 0.0001 {
            return .reduced
        }
        if abs(interval - timelineMinimumInterval(frameRate: .balanced)) < 0.0001 {
            return .balanced
        }
        if abs(interval - timelineMinimumInterval(frameRate: .smooth)) < 0.0001 {
            return .smooth
        }
        return nil
    }

    private static func estimatedFlowStrokePaintsPerSecond(
        visibleEdgeCount: Int,
        frameRate: CanvasAnimationFrameRate?
    ) -> Int {
        guard visibleEdgeCount > 0,
              let frameRate else {
            return 0
        }
        let framesPerSecond: Int
        switch frameRate {
        case .reduced:
            framesPerSecond = 15
        case .balanced:
            framesPerSecond = 30
        case .smooth:
            framesPerSecond = 60
        }
        guard visibleEdgeCount <= Int.max / framesPerSecond else {
            return Int.max
        }
        return visibleEdgeCount * framesPerSecond
    }
}

public enum CanvasZoomCommitPolicy {
    public static func commitDelayNanos(cadence: CanvasZoomCommitCadence) -> UInt64 {
        switch cadence {
        case .responsive:
            120_000_000
        case .balanced:
            250_000_000
        case .relaxed:
            450_000_000
        }
    }
}

public enum CanvasCardRenderDetailPolicy {
    public static func shouldRenderDetails(
        zoom: Double,
        baselineZoom: Double,
        visibleCardCount: Int,
        isInteracting: Bool,
        isSelected: Bool,
        isEditing: Bool
    ) -> Bool {
        if isSelected || isEditing {
            return true
        }
        guard visibleCardCount >= 0,
              zoom.isFinite,
              baselineZoom.isFinite,
              baselineZoom > 0 else {
            return false
        }
        let cardCount = visibleCardCount
        let detailLimit = isInteracting
            ? CanvasPerformancePolicy.maximumDetailedInteractingVisibleCardCount
            : CanvasPerformancePolicy.maximumDetailedVisibleCardCount
        guard cardCount <= detailLimit else {
            return false
        }
        if isInteracting, !isSelected {
            return false
        }
        return zoom / baselineZoom >= CanvasPerformancePolicy.minimumDetailedCardZoomRatio
    }
}

public enum CanvasCardDetailInteractionPolicy {
    public static func shouldReducePeerDetails(
        isNodeDragging: Bool,
        isViewportMoving: Bool,
        isZooming: Bool,
        isResizing: Bool,
        isEdgeControlDragging: Bool,
        visibleCardCount: Int = 0
    ) -> Bool {
        if isZooming || isResizing || isEdgeControlDragging {
            return true
        }
        if isNodeDragging || isViewportMoving {
            return max(0, visibleCardCount) > CanvasPerformancePolicy.maximumRichSpatialInteractionCardCount
        }
        return false
    }
}

public struct CanvasInteractionPerformanceBudgetAssessment: Equatable, Sendable {
    public var issueCodes: [String]

    public var isAccepted: Bool {
        issueCodes.isEmpty
    }

    public init(issueCodes: [String]) {
        self.issueCodes = issueCodes
    }
}

public enum CanvasInteractionPerformanceBudget {
    public static let maximumSmoothNodeCount = 100

    public static func maximumInteractiveQueryWorkCount(nodeCount: Int) -> Int {
        guard nodeCount > 0 else { return 0 }
        return cappedSum([
            nodeCount,
            CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
        ])
    }

    public static func maximumForceRetentionScanCount(
        explicitActiveEdgeCount: Int,
        movingNodeCount: Int
    ) -> Int {
        cappedSum([
            explicitActiveEdgeCount,
            CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount,
            movingNodeCount
        ])
    }

    public static func assessment(
        nodeCount: Int,
        movingNodeCount: Int,
        plan: CanvasEdgeVisibilityPlan
    ) -> CanvasInteractionPerformanceBudgetAssessment {
        var issueCodes: [String] = []
        if nodeCount < 0 || nodeCount > maximumSmoothNodeCount {
            issueCodes.append("node-count-outside-100-budget")
        }
        if plan.usesObstacleRouting {
            issueCodes.append("interaction-routing-enabled")
        }
        if plan.animatesVisibleEdges {
            issueCodes.append("interaction-edge-animation-enabled")
        }
        if let cache = plan.diagnostics.cache,
           cache.buildCount > 1 || cache.reuseCount < 1 {
            issueCodes.append("cache-not-reused")
        }

        let maximumQueryWorkCount = maximumInteractiveQueryWorkCount(nodeCount: nodeCount)
        if plan.diagnostics.renderQuery.candidateExaminedCount > maximumQueryWorkCount {
            issueCodes.append("query-candidate-work-over-budget")
        }
        if plan.diagnostics.renderQuery.orderedScanCount > maximumQueryWorkCount {
            issueCodes.append("query-ordering-work-over-budget")
        }

        let forceRetention = plan.diagnostics.forceRetention
        if movingNodeCount > 0 {
            if forceRetention.incidentCandidateEdgeCount > 0,
               !forceRetention.usedIncidentAdjacency {
                issueCodes.append("force-retention-without-incident-adjacency")
            }
            let maximumForceRetentionScanCount = maximumForceRetentionScanCount(
                explicitActiveEdgeCount: forceRetention.explicitActiveEdgeCount,
                movingNodeCount: movingNodeCount
            )
            if forceRetention.edgeScanCount > maximumForceRetentionScanCount {
                issueCodes.append("force-retention-scan-over-budget")
            }
        }

        return CanvasInteractionPerformanceBudgetAssessment(issueCodes: issueCodes)
    }

    private static func cappedSum(_ values: [Int]) -> Int {
        values.reduce(0) { total, rawValue in
            let value = max(0, rawValue)
            guard total <= Int.max - value else { return Int.max }
            return total + value
        }
    }
}

public enum CanvasScrollWheelEventPolicy {
    public static let minimumVerticalDelta = 0.01

    public static func shouldZoom(deltaX: Double, deltaY: Double) -> Bool {
        guard deltaX.isFinite, deltaY.isFinite else { return false }
        let absX = abs(deltaX)
        let absY = abs(deltaY)
        guard absY > minimumVerticalDelta else { return false }
        return absY >= absX
    }
}

public enum CanvasResizeHandleVisibilityPolicy {
    public static func shouldShow(
        isSelected: Bool,
        isDragging: Bool,
        isResizing: Bool,
        isInteracting: Bool,
        visibleNodeCount: Int
    ) -> Bool {
        if isSelected || isDragging || isResizing {
            return true
        }
        guard !isInteracting else {
            return false
        }
        return visibleNodeCount >= 0 &&
            visibleNodeCount <= CanvasPerformancePolicy.maximumPassiveResizeHandleNodeCount
    }
}

public enum CanvasEdgeControlHandlePolicy {
    public static func shouldShow(
        isSelected: Bool,
        hasTransientControlPoint: Bool,
        hasStoredControlPoint: Bool,
        isLocked: Bool,
        isInteracting: Bool,
        isDragging: Bool = false,
        edgeCount: Int,
        zoom: Double
    ) -> Bool {
        if isSelected || hasTransientControlPoint || isDragging {
            return true
        }
        guard !isInteracting else {
            return false
        }
        if hasStoredControlPoint || isLocked {
            return true
        }
        return edgeCount >= 0 &&
            edgeCount <= CanvasPerformancePolicy.maximumPassiveEdgeControlHandleCount &&
            zoom.isFinite &&
            zoom >= CanvasPerformancePolicy.minimumPassiveEdgeControlZoom
    }
}

public enum CanvasEdgeControlPointDragPolicy {
    public static let minimumDragDistance = 4.0

    public static func hasMovedBeyondClickThreshold(
        translation: CanvasEdgePoint,
        minimumDistance: Double = minimumDragDistance
    ) -> Bool {
        let threshold = minimumDistance.isFinite ? max(0, minimumDistance) : minimumDragDistance
        return hypot(translation.x, translation.y) >= threshold
    }

    public static func movedScreenPoint(
        startScreenPoint: CanvasEdgePoint,
        translation: CanvasEdgePoint,
        minimumDistance: Double = minimumDragDistance
    ) -> CanvasEdgePoint? {
        guard hasMovedBeyondClickThreshold(
            translation: translation,
            minimumDistance: minimumDistance
        ) else {
            return nil
        }
        return CanvasEdgePoint(
            x: startScreenPoint.x + translation.x,
            y: startScreenPoint.y + translation.y
        )
    }

    public static func persistentControlPoint(
        startScreenPoint: CanvasEdgePoint,
        translation: CanvasEdgePoint,
        zoom: Double,
        viewportX: Double,
        viewportY: Double,
        minimumDistance: Double = minimumDragDistance
    ) -> CanvasEdgePoint? {
        guard let screenPoint = movedScreenPoint(
            startScreenPoint: startScreenPoint,
            translation: translation,
            minimumDistance: minimumDistance
        ) else {
            return nil
        }
        return CanvasViewportProjection.canvasPoint(
            screenX: screenPoint.x,
            screenY: screenPoint.y,
            zoom: zoom,
            viewportX: viewportX,
            viewportY: viewportY
        )
    }
}

public struct CanvasNodeStateReconciliationPlan: Equatable, Sendable {
    public var selectedNodeIDs: Set<String>
    public var editingNodeIDs: Set<String>
    public var connectionSourceNodeId: String?
    public var primaryDraggedNodeId: String?
    public var suppressedTapNodeId: String?
    public var resizingNodeId: String?
    public var nodeDragStartIDs: Set<String>
    public var nodeDragSnapshotIDs: Set<String>
    public var transientNodeOffsetIDs: Set<String>
    public var resizeStartSizeIDs: Set<String>
    public var transientNodeSizeIDs: Set<String>

    public init(
        selectedNodeIDs: Set<String>,
        editingNodeIDs: Set<String>,
        connectionSourceNodeId: String?,
        primaryDraggedNodeId: String?,
        suppressedTapNodeId: String?,
        resizingNodeId: String?,
        nodeDragStartIDs: Set<String>,
        nodeDragSnapshotIDs: Set<String>,
        transientNodeOffsetIDs: Set<String>,
        resizeStartSizeIDs: Set<String>,
        transientNodeSizeIDs: Set<String>
    ) {
        self.selectedNodeIDs = selectedNodeIDs
        self.editingNodeIDs = editingNodeIDs
        self.connectionSourceNodeId = connectionSourceNodeId
        self.primaryDraggedNodeId = primaryDraggedNodeId
        self.suppressedTapNodeId = suppressedTapNodeId
        self.resizingNodeId = resizingNodeId
        self.nodeDragStartIDs = nodeDragStartIDs
        self.nodeDragSnapshotIDs = nodeDragSnapshotIDs
        self.transientNodeOffsetIDs = transientNodeOffsetIDs
        self.resizeStartSizeIDs = resizeStartSizeIDs
        self.transientNodeSizeIDs = transientNodeSizeIDs
    }
}

public enum CanvasNodeStateReconciliation {
    public static func validIDs(_ ids: Set<String>, existingNodeIDs: Set<String>) -> Set<String> {
        ids.intersection(existingNodeIDs)
    }

    public static func validOptionalID(_ id: String?, existingNodeIDs: Set<String>) -> String? {
        guard let id, existingNodeIDs.contains(id) else { return nil }
        return id
    }

    public static func filteredKeys<Value>(_ values: [String: Value], existingNodeIDs: Set<String>) -> [String: Value] {
        values.filter { existingNodeIDs.contains($0.key) }
    }

    public static func plan(
        selectedNodeIDs: Set<String>,
        editingNodeIDs: Set<String>,
        connectionSourceNodeId: String?,
        primaryDraggedNodeId: String?,
        suppressedTapNodeId: String?,
        resizingNodeId: String?,
        nodeDragStartIDs: Set<String>,
        nodeDragSnapshotIDs: Set<String>,
        transientNodeOffsetIDs: Set<String>,
        resizeStartSizeIDs: Set<String>,
        transientNodeSizeIDs: Set<String>,
        existingNodeIDs: Set<String>
    ) -> CanvasNodeStateReconciliationPlan {
        CanvasNodeStateReconciliationPlan(
            selectedNodeIDs: validIDs(selectedNodeIDs, existingNodeIDs: existingNodeIDs),
            editingNodeIDs: validIDs(editingNodeIDs, existingNodeIDs: existingNodeIDs),
            connectionSourceNodeId: validOptionalID(connectionSourceNodeId, existingNodeIDs: existingNodeIDs),
            primaryDraggedNodeId: validOptionalID(primaryDraggedNodeId, existingNodeIDs: existingNodeIDs),
            suppressedTapNodeId: validOptionalID(suppressedTapNodeId, existingNodeIDs: existingNodeIDs),
            resizingNodeId: validOptionalID(resizingNodeId, existingNodeIDs: existingNodeIDs),
            nodeDragStartIDs: validIDs(nodeDragStartIDs, existingNodeIDs: existingNodeIDs),
            nodeDragSnapshotIDs: validIDs(nodeDragSnapshotIDs, existingNodeIDs: existingNodeIDs),
            transientNodeOffsetIDs: validIDs(transientNodeOffsetIDs, existingNodeIDs: existingNodeIDs),
            resizeStartSizeIDs: validIDs(resizeStartSizeIDs, existingNodeIDs: existingNodeIDs),
            transientNodeSizeIDs: validIDs(transientNodeSizeIDs, existingNodeIDs: existingNodeIDs)
        )
    }
}

public enum CanvasViewportVisibilityPolicy {
    public static func nodeOverscanPixels(zoom: Double, baselineZoom: Double) -> Double {
        guard zoom.isFinite, baselineZoom.isFinite, baselineZoom > 0 else {
            return 320
        }
        return min(640, max(220, 320 * sqrt(max(0, zoom) / baselineZoom)))
    }
}

public enum CanvasActiveEdgeRenderPolicy {
    public static func shouldRenderEdge(
        edgeID: String,
        sourceNodeID: String,
        targetNodeID: String,
        movingNodeIDs: Set<String>,
        selectedEdgeIDs: Set<String>,
        transientControlEdgeIDs: Set<String>,
        movedControlEdgeIDs: Set<String>,
        isGeometryInteracting: Bool,
        visibleEdgeCount: Int = Int.max
    ) -> Bool {
        guard isGeometryInteracting else {
            return true
        }
        if selectedEdgeIDs.contains(edgeID) ||
            transientControlEdgeIDs.contains(edgeID) ||
            movedControlEdgeIDs.contains(edgeID) {
            return true
        }
        if movingNodeIDs.contains(sourceNodeID) || movingNodeIDs.contains(targetNodeID) {
            return true
        }
        return visibleEdgeCount >= 0 &&
            visibleEdgeCount <= CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
    }
}

public enum CanvasFinalEdgeRenderPolicy {
    public static func shouldIncludeCandidateEdge(
        edgeID: String,
        selectedEdgeIDs: Set<String>,
        forceRetainedEdgeIDs: Set<String>,
        isPotentiallyVisible: Bool
    ) -> Bool {
        selectedEdgeIDs.contains(edgeID) ||
            forceRetainedEdgeIDs.contains(edgeID) ||
            isPotentiallyVisible
    }

    public static func shouldKeepSegment(
        edgeID: String,
        selectedEdgeIDs: Set<String>,
        forceRetainedEdgeIDs: Set<String>,
        isSegmentVisible: Bool
    ) -> Bool {
        selectedEdgeIDs.contains(edgeID) ||
            forceRetainedEdgeIDs.contains(edgeID) ||
            isSegmentVisible
    }
}

public enum CanvasNodeVisualZIndexPolicy {
    public static func zIndex(
        storedZIndex: Double,
        isFrame: Bool,
        isSelected: Bool,
        isDragging: Bool,
        isResizing: Bool,
        isConnectionSource: Bool,
        isEditing: Bool
    ) -> Double {
        let base = isFrame ? 0.25 : 2.0
        let storedOffset = min(max(storedZIndex.isFinite ? storedZIndex : 0, -1_000), 1_000) / 1_000
        let selectionBoost = isSelected || isConnectionSource ? 0.25 : 0
        let editingBoost = isEditing ? 0.5 : 0
        let motionBoost = isDragging || isResizing ? (isFrame ? 1.25 : 2.0) : 0
        return base + storedOffset + selectionBoost + editingBoost + motionBoost
    }
}

public enum CanvasEdgeLayerZIndexPolicy {
    public static let strokeLayer = 1.9
    public static let arrowHeadLayer = 2.75
}

public enum CanvasEdgeFlowLineCap: String, Equatable, Sendable {
    case butt
    case round
}

public enum CanvasEdgeFlowStrokePolicy {
    public static let lineCap = CanvasEdgeFlowLineCap.butt

    public static func strokeWidth(baseStrokeWidth: Double) -> Double {
        guard baseStrokeWidth.isFinite else { return 0 }
        return max(0, baseStrokeWidth)
    }
}

public enum CanvasEdgeVisualMetrics {
    public static func strokeWidth(
        zoom: Double,
        baseWidth: Double,
        minimumWidth: Double,
        maximumWidth: Double = .greatestFiniteMagnitude
    ) -> Double {
        let safeBase = baseWidth.isFinite ? max(0, baseWidth) : 0
        let safeMinimum = minimumWidth.isFinite ? max(0, minimumWidth) : 0
        let safeMaximum = maximumWidth.isFinite ? max(safeMinimum, maximumWidth) : .greatestFiniteMagnitude
        return min(safeMaximum, max(safeMinimum, safeBase * CanvasZoomScale.safeZoom(zoom)))
    }

    public static func arrowLength(
        zoom: Double,
        baseLength: Double,
        minimumLength: Double,
        maximumLength: Double = .greatestFiniteMagnitude
    ) -> Double {
        let safeBase = baseLength.isFinite ? max(0, baseLength) : 0
        let safeMinimum = minimumLength.isFinite ? max(0, minimumLength) : 0
        let safeMaximum = maximumLength.isFinite ? max(safeMinimum, maximumLength) : .greatestFiniteMagnitude
        return min(safeMaximum, max(safeMinimum, safeBase * CanvasZoomScale.safeZoom(zoom)))
    }
}
