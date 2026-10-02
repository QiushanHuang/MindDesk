import XCTest
@testable import MindDeskCore

final class TodoBoardSplitLayoutTests: XCTestCase {
    func testReversingFromUpperBoundaryRespondsToFirstPointerMovement() {
        let layout = TodoBoardSplitLayout(availableWidth: 1_000)
        var drag = TodoBoardSplitDragState()
        let upper = drag.update(translation: 900, displayedOpenWidth: 500, layout: layout)
        XCTAssertEqual(upper, 0.7, accuracy: 0.0001)
        let reversed = drag.update(translation: 895, displayedOpenWidth: upper * 1_000, layout: layout)
        XCTAssertEqual(reversed, 0.695, accuracy: 0.0001, "Dragging left by 5 pt should immediately move the divider left by 5 pt")
    }

    func testReversingFromLowerBoundaryRespondsToFirstPointerMovement() {
        let layout = TodoBoardSplitLayout(availableWidth: 1_000)
        var drag = TodoBoardSplitDragState()
        let lower = drag.update(translation: -900, displayedOpenWidth: 500, layout: layout)
        XCTAssertEqual(lower, 0.38, accuracy: 0.0001)
        let reversed = drag.update(translation: -895, displayedOpenWidth: lower * 1_000, layout: layout)
        XCTAssertEqual(reversed, 0.385, accuracy: 0.0001)
    }

    func testCompactWidthStillAllocatesSpaceToBothTaskColumns() {
        let layout = TodoBoardSplitLayout(availableWidth: 400)
        XCTAssertEqual(layout.openWidth(ratio: 0.5), 260, accuracy: 0.0001)
        XCTAssertEqual(400 - layout.openWidth(ratio: 0.5), 140, accuracy: 0.0001)
    }

    func testWindowResizeRebasesGestureWithoutJumping() {
        var drag = TodoBoardSplitDragState()
        let wide = TodoBoardSplitLayout(availableWidth: 1_000)
        _ = drag.update(translation: 100, displayedOpenWidth: 500, layout: wide)
        let resized = TodoBoardSplitLayout(availableWidth: 800)
        XCTAssertEqual(drag.update(translation: 100, displayedOpenWidth: 480, layout: resized), 0.6, accuracy: 0.0001)
        XCTAssertEqual(drag.update(translation: 104, displayedOpenWidth: 480, layout: resized), 0.605, accuracy: 0.0001)
    }

    func testNormalDragAndStoredRatioKeepTheirExpectedPosition() {
        let layout = TodoBoardSplitLayout(availableWidth: 1_000)
        XCTAssertEqual(layout.openWidth(ratio: 0.6), 600, accuracy: 0.0001)
        var drag = TodoBoardSplitDragState()
        XCTAssertEqual(drag.update(translation: 20, displayedOpenWidth: 600, layout: layout), 0.62, accuracy: 0.0001)
        XCTAssertEqual(drag.update(translation: 30, displayedOpenWidth: 620, layout: layout), 0.63, accuracy: 0.0001)
    }

    func testBothColumnsStayInsideAvailableSpaceAcrossWindowSizes() {
        for width in [1.0, 120, 250, 400, 650, 1_000, 2_400] {
            let layout = TodoBoardSplitLayout(availableWidth: width)
            for ratio in [-1.0, 0, 0.3, 0.5, 0.7, 1, 2] {
                let open = layout.openWidth(ratio: ratio)
                XCTAssertGreaterThan(open, 0)
                XCTAssertLessThan(open, width)
                XCTAssertGreaterThanOrEqual(open / width, TodoBoardColumnSplit.minimumRatio - 0.0001)
                XCTAssertLessThanOrEqual(open / width, TodoBoardColumnSplit.maximumRatio + 0.0001)
            }
        }
    }
}
