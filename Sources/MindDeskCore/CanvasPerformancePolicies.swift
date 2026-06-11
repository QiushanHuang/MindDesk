import Foundation

public extension CanvasPerformancePolicy {
    static var maximumAnimatedVisibleEdgeCount: Int { 12 }
    static var maximumAnimatedVisibleCardCount: Int { 60 }
    static var maximumAnimatedRoutePointCount: Int { 96 }
    static var maximumDetailedVisibleCardCount: Int { 48 }
    static var maximumDetailedInteractingVisibleCardCount: Int { 8 }
    static var maximumRichSpatialInteractionCardCount: Int { 48 }
    static var maximumContextEdgesDuringInteraction: Int { 48 }
    static var maximumPassiveResizeHandleNodeCount: Int { 12 }
    static var maximumPassiveEdgeControlHandleCount: Int { 24 }
    static var minimumPassiveEdgeControlZoom: Double { 0.30 }
    static var minimumDetailedCardZoomRatio: Double { 0.75 }
}

public extension CanvasEdgeAnimationPolicy {
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
        guard visibleEdgeCount <= CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount,
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
        guard zoom.isFinite,
              baselineZoom.isFinite,
              baselineZoom > 0 else {
            return false
        }
        let cardCount = max(0, visibleCardCount)
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
        return visibleNodeCount <= CanvasPerformancePolicy.maximumPassiveResizeHandleNodeCount
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
        return edgeCount <= CanvasPerformancePolicy.maximumPassiveEdgeControlHandleCount &&
            zoom.isFinite &&
            zoom >= CanvasPerformancePolicy.minimumPassiveEdgeControlZoom
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
        return max(0, visibleEdgeCount) <= CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
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
