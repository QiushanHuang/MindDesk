import Foundation

public extension CanvasPerformancePolicy {
    static var maximumAnimatedVisibleEdgeCount: Int { 12 }
    static var maximumAnimatedVisibleCardCount: Int { 60 }
    static var maximumAnimatedRoutePointCount: Int { 96 }
    static var maximumDetailedVisibleCardCount: Int { 48 }
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
        guard !isInteracting,
              zoom.isFinite,
              baselineZoom.isFinite,
              baselineZoom > 0 else {
            return false
        }
        guard visibleCardCount <= CanvasPerformancePolicy.maximumDetailedVisibleCardCount else {
            return false
        }
        return zoom / baselineZoom >= CanvasPerformancePolicy.minimumDetailedCardZoomRatio
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
        edgeCount: Int,
        zoom: Double
    ) -> Bool {
        if isSelected || hasTransientControlPoint {
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
        isGeometryInteracting: Bool
    ) -> Bool {
        guard isGeometryInteracting else {
            return true
        }
        if selectedEdgeIDs.contains(edgeID) ||
            transientControlEdgeIDs.contains(edgeID) ||
            movedControlEdgeIDs.contains(edgeID) {
            return true
        }
        return movingNodeIDs.contains(sourceNodeID) || movingNodeIDs.contains(targetNodeID)
    }
}
