public enum CanvasEdgeAnimationInteractionPolicy {
    public static func shouldDeferGlowAnimation(
        isNodeDragging: Bool,
        isViewportMoving _: Bool,
        isZooming _: Bool,
        isResizing: Bool,
        isEdgeControlDragging: Bool
    ) -> Bool {
        isNodeDragging || isResizing || isEdgeControlDragging
    }
}
