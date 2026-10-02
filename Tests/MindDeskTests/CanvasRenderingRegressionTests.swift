import AppKit
import SwiftUI
import XCTest
import MindDeskCore
@testable import MindDesk

@MainActor
final class CanvasRenderingRegressionTests: XCTestCase {
    func testFlowAnimationDoesNotStopWhenCrossingBaselineZoom() {
        for zoom in [0.12, 0.175, 0.349, 0.35, 0.7, 2.4] {
            let plan = CanvasEdgeAnimationPolicy.effectiveTimelinePlan(
                preferredFrameRate: .smooth, theme: "blue", animationsEnabled: true,
                reduceMotion: false, visibleEdgeCount: 2, visibleCardCount: 4,
                routedPointCount: 0, zoom: zoom, baselineZoom: 0.35, isInteracting: false
            )
            XCTAssertTrue(plan.shouldAnimate, "zoom=\(zoom)")
            XCTAssertEqual(plan.minimumInterval ?? 0, 1.0 / 60.0, accuracy: 0.0001)
        }
    }

    func testGeometryCacheReusesRoutesAndInvalidatesEditedGeometry() throws {
        let source = CanvasNodeModel(id: "source", canvasId: "c", title: "A", nodeType: .note, x: 0, y: 0, width: 240, height: 180)
        let target = CanvasNodeModel(id: "target", canvasId: "c", title: "B", nodeType: .note, x: 800, y: 0, width: 240, height: 180)
        let obstacle = CanvasNodeModel(id: "obstacle", canvasId: "c", title: "C", nodeType: .note, x: 380, y: 0, width: 240, height: 180)
        let edge = CanvasEdgeModel(id: "edge", canvasId: "c", sourceNodeId: source.id, targetNodeId: target.id)
        let snapshot = CanvasRenderSnapshot(nodes: [source, target, obstacle], resources: [], snippets: [], edges: [edge])
        let cache = CanvasEdgeGeometryCache()
        func segments() -> [CanvasEdgeSegment] {
            snapshot.edgeSegments(targetClearance: 4, routingClearance: 2, geometryCache: cache,
                rectFor: { CanvasFrameRect(id: $0.id, x: $0.x, y: $0.y, width: $0.width, height: $0.height) },
                controlPointFor: { edge in
                    guard let x = edge.controlPointX, let y = edge.controlPointY else { return nil }
                    return CGPoint(x: x, y: y)
                })
        }
        let initial = try XCTUnwrap(segments().first)
        XCTAssertFalse(initial.routePoints.isEmpty, "The link must avoid the intervening card")
        for _ in 0..<120 { _ = segments() }
        XCTAssertEqual(cache.buildCount, 1, "Camera/animation frames reuse model geometry")
        obstacle.y = 400
        let unobstructed = try XCTUnwrap(segments().first)
        XCTAssertEqual(cache.buildCount, 2)
        XCTAssertNotEqual(initial.routePoints, unobstructed.routePoints)
        edge.controlPointX = 500; edge.controlPointY = -200
        XCTAssertEqual(segments().first?.control, CGPoint(x: 500, y: -200))
        XCTAssertEqual(cache.buildCount, 3)
        target.x = 900
        XCTAssertNotEqual(segments().first?.end, unobstructed.end)
        XCTAssertEqual(cache.buildCount, 4)
        edge.targetArrowRaw = "none"
        XCTAssertEqual(segments().first?.targetArrowRaw, "none")
        XCTAssertEqual(cache.buildCount, 5)
    }

    func testFrameBorderKeepsStoredBoundsWhenDetailsChange() async throws {
        let node = CanvasNodeModel(canvasId: "preview", title: "A long organization frame title", nodeType: .groupFrame, x: 0, y: 0, width: 240, height: 160)
        for (details, zoom) in [true, false].flatMap({ details in
            [0.175, 0.35, 0.7, 1.4].map { (details, $0) }
        }) {
            let card = CanvasFrameCard(node: node, isSelected: true, isConnectionSource: false,
                rendersDetails: details, onEditingChange: { _ in }, onInfo: { _ in },
                onCopy: {}, onStartLink: {}, onConnect: {}, onDelete: {},
                onTitleChange: { _ in }, onNoteChange: { _ in })
            let host = NSHostingView(rootView: card.frame(width: 240, height: 160)
                .scaleEffect(zoom)
                .frame(width: 440, height: 360).background(.white)
                .environment(\.colorScheme, .light).tint(.blue))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 360), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            var blueX: [Int] = []
            var blueY: [Int] = []
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    if c.blueComponent - c.redComponent > 0.10 && c.blueComponent - c.greenComponent > 0.04 {
                        blueX.append(x); blueY.append(y)
                    }
                }
            }
            let scale = Double(bitmap.pixelsWide) / 440
            let width = Double(try XCTUnwrap(blueX.max()) - XCTUnwrap(blueX.min())) / scale
            let height = Double(try XCTUnwrap(blueY.max()) - XCTUnwrap(blueY.min())) / scale
            XCTAssertEqual(width, 240 * zoom, accuracy: 4, "details=\(details), zoom=\(zoom)")
            XCTAssertEqual(height, 160 * zoom, accuracy: 4, "details=\(details), zoom=\(zoom)")
            window.close()
        }
    }
}
