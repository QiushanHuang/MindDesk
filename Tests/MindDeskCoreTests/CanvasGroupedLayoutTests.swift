import XCTest
@testable import MindDeskCore

final class CanvasGroupedLayoutTests: XCTestCase {
    func testArrangePreservesNestedFrameOffsets() {
        let nodes = [
            CanvasLayoutNode(id: "outer", x: 500, y: 300, width: 600, height: 500),
            CanvasLayoutNode(id: "inner", x: 540, y: 350, width: 300, height: 250),
            CanvasLayoutNode(id: "card", x: 560, y: 400, width: 100, height: 80)
        ]
        let result = CanvasLayoutEngine.arrangeGroups(nodes, frameIDs: ["outer", "inner"], parents: [:], lockedIDs: [], edges: [])
        XCTAssertEqual(result[1].x - result[0].x, 40)
        XCTAssertEqual(result[2].y - result[0].y, 100)
        XCTAssertEqual(result[0].x, 0)
    }

    func testLockedChildKeepsEntireLinkedGroupFixed() {
        let nodes = [
            CanvasLayoutNode(id: "frame", x: 500, y: 300, width: 300, height: 250),
            CanvasLayoutNode(id: "card", x: 900, y: 400, width: 100, height: 80)
        ]
        XCTAssertEqual(CanvasLayoutEngine.arrangeGroups(nodes, frameIDs: ["frame"], parents: ["card": "frame"], lockedIDs: ["card"], edges: []), nodes)
    }
}
