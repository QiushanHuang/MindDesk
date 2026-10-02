import Foundation

/// Shared screen-space bounds for drawing and dragging the task-board divider.
public struct TodoBoardSplitLayout: Equatable, Sendable {
    public let availableWidth: Double
    public let minimumOpenWidth: Double
    public let maximumOpenWidth: Double

    public init(availableWidth: Double) {
        self.availableWidth = availableWidth.isFinite ? max(1, availableWidth) : 1
        let reservedDoneWidth = min(180, self.availableWidth * 0.35)
        maximumOpenWidth = min(self.availableWidth * TodoBoardColumnSplit.maximumRatio,
                               self.availableWidth - reservedDoneWidth)
        minimumOpenWidth = min(maximumOpenWidth,
                               max(self.availableWidth * TodoBoardColumnSplit.minimumRatio,
                                   min(380, self.availableWidth * 0.65)))
    }

    public func openWidth(ratio: Double) -> Double {
        clamp(availableWidth * TodoBoardColumnSplit.clampedRatio(ratio))
    }

    public func clamp(_ width: Double) -> Double {
        min(max(width, minimumOpenWidth), maximumOpenWidth)
    }
}

/// Tracks one divider gesture without storing presentation state in preferences.
public struct TodoBoardSplitDragState: Sendable {
    private var currentOpenWidth: Double?
    private var previousTranslation: Double = 0
    private var previousAvailableWidth: Double?

    public init() {}

    public mutating func update(translation: Double, displayedOpenWidth: Double, layout: TodoBoardSplitLayout) -> Double {
        // A window resize changes the coordinate space, so rebase without applying
        // translation already consumed by the preceding layout.
        if let previousAvailableWidth, previousAvailableWidth != layout.availableWidth {
            currentOpenWidth = layout.clamp(displayedOpenWidth)
            previousTranslation = translation
        }
        let width = layout.clamp((currentOpenWidth ?? displayedOpenWidth) + translation - previousTranslation)
        currentOpenWidth = width
        previousTranslation = translation
        previousAvailableWidth = layout.availableWidth
        return width / layout.availableWidth
    }
}
