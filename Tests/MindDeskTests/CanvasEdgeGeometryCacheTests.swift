import CoreGraphics
import XCTest
import MindDeskCore
@testable import MindDesk

final class CanvasEdgeGeometryCacheTests: XCTestCase {
    func testAdmittingNewGeometryEvictsOnlyTheLeastRecentlyUsedEntry() {
        let cache = CanvasEdgeGeometryCache()
        for index in 0..<512 {
            _ = segment(index, in: cache)
        }
        XCTAssertEqual(cache.buildCount, 512)

        // A camera revisit keeps this old but recently used edge in the working set.
        _ = segment(0, in: cache)
        _ = segment(512, in: cache)
        XCTAssertEqual(cache.buildCount, 513)

        _ = segment(0, in: cache)
        for index in 2...512 {
            _ = segment(index, in: cache)
        }
        XCTAssertEqual(cache.buildCount, 513, "Admitting one edge must preserve all other retained geometry")

        _ = segment(1, in: cache)
        XCTAssertEqual(cache.buildCount, 514, "The least recently used entry must be evicted to preserve the bound")
    }

    func testEditingCachedGeometryAtCapacityDoesNotEvictOtherEntries() {
        let cache = CanvasEdgeGeometryCache()
        for index in 0..<512 {
            _ = segment(index, in: cache)
        }
        let newControl = CGPoint(x: 50, y: -30)
        let edited = segment(0, control: newControl, in: cache)
        XCTAssertEqual(edited.control, newControl)
        XCTAssertEqual(cache.buildCount, 513)

        _ = segment(0, control: newControl, in: cache)
        for index in 1..<512 {
            _ = segment(index, in: cache)
        }
        XCTAssertEqual(cache.buildCount, 513, "Updating an existing entry must retain the other 511 entries")
    }

    private func segment(
        _ index: Int,
        control: CGPoint? = nil,
        in cache: CanvasEdgeGeometryCache
    ) -> CanvasEdgeSegment {
        let id = "edge-\(index)"
        let key = CanvasEdgeGeometryCache.Key(
            source: CanvasFrameRect(id: "source", x: 0, y: 0, width: 20, height: 20),
            target: CanvasFrameRect(id: "target", x: 100, y: 0, width: 20, height: 20),
            control: control,
            obstacles: [],
            targetClearance: 4,
            routingClearance: 2,
            usesObstacleRouting: false,
            style: "",
            sourceArrow: "none",
            targetArrow: "arrow"
        )
        return cache.segment(id: id, key: key) {
            CanvasEdgeSegment(
                id: id,
                start: CGPoint(x: 20, y: 10),
                end: CGPoint(x: 96, y: 10),
                startDirection: CGPoint(x: 1, y: 0),
                endDirection: CGPoint(x: -1, y: 0),
                control: control,
                routePoints: [],
                isControlPointLocked: false,
                sourceArrowRaw: "none",
                targetArrowRaw: "arrow"
            )
        }
    }
}
