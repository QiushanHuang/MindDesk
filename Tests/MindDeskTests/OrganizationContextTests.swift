import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class OrganizationContextTests: XCTestCase {
    func testSourceRequestIncludesOnlySelectedTargetsWithExplicitReadOnlyNeighbors() {
        let canvas = CanvasModel(id: "c", workspaceId: "w")
        let selected = node("a", canvas)
        selected.parentNodeId = "group"
        let neighbor = node("b", canvas)
        neighbor.locked = true
        let frame = CanvasNodeModel(id: "group", canvasId: canvas.id, title: "Plan", nodeType: .groupFrame, x: 0, y: 0)
        let unrelated = node("private", canvas)
        let edge = CanvasEdgeModel(id: "ab", canvasId: canvas.id, sourceNodeId: "a", targetNodeId: "b", label: "depends on")
        let selection = OrganizationSelection(canvas: canvas, nodes: [selected], contextNodes: [selected, neighbor, frame, unrelated], edges: [edge])
        let request = selection.request(intent: .classify, scope: .neighbors, instructions: "Keep the group names concise.")
        XCTAssertEqual(request.cards.map(\.id), ["a"])
        XCTAssertEqual(Set(request.referenceCards.map(\.id)), ["b", "group"])
        XCTAssertEqual(request.links.map(\.id), ["ab"])
        XCTAssertEqual(request.instructions, "Keep the group names concise.")
        XCTAssertFalse(request.sourceID.isEmpty)
        XCTAssertTrue(request.referenceCards.first { $0.id == "b" }?.locked == true)
        XCTAssertFalse(request.referenceCards.contains { $0.id == "private" })
        XCTAssertThrowsError(try OrganizationProposal(summary: "", groups: [.init(name: "Move context", cardIDs: ["b"])], tasks: []).validate(for: request))
    }

    func testDefaultScopeDoesNotSendNeighborsAndFeedbackIsBoundToRequest() {
        let canvas = CanvasModel(id: "c", workspaceId: "w")
        let a = node("a", canvas), b = node("b", canvas)
        let edge = CanvasEdgeModel(id: "ab", canvasId: canvas.id, sourceNodeId: "a", targetNodeId: "b", label: "next")
        let selection = OrganizationSelection(canvas: canvas, nodes: [a], contextNodes: [a, b], edges: [edge])
        let previous = OrganizationProposal(summary: "Previous summary", groups: [], tasks: [])
        let request = selection.request(intent: .summarize, feedback: "Use Chinese", previous: previous)
        XCTAssertTrue(request.referenceCards.isEmpty)
        XCTAssertTrue(request.links.isEmpty)
        XCTAssertEqual(request.revisionFeedback, "Use Chinese")
        XCTAssertEqual(request.previousProposal, previous)
        XCTAssertEqual(request.sourceID, selection.request(intent: .summarize).sourceID)
    }

    func testWorkflowRoundTripAndInvalidStorageAreExplicit() throws {
        let workflows = [OrganizationWorkflow(id: "daily", title: "每日计划", intent: .extractTasks,
                                              scope: .neighbors, instructions: "保留未知事项，不要猜测截止日期。")]
        XCTAssertEqual(try OrganizationWorkflowLibrary.decode(OrganizationWorkflowLibrary.encode(workflows)), workflows)
        XCTAssertThrowsError(try OrganizationWorkflowLibrary.decode("{broken"))
        var oversized = workflows
        oversized[0].instructions = String(repeating: "中文", count: 1_000)
        XCTAssertThrowsError(try OrganizationWorkflowLibrary.encode(oversized))
        XCTAssertThrowsError(try OrganizationWorkflowLibrary.encode(workflows + workflows))
        var draft = workflows
        draft[0].instructions = "Edited draft"
        XCTAssertEqual(workflows[0].instructions, "保留未知事项，不要猜测截止日期。")
    }

    func testRequestRejectsLargeGuidanceAndOverlappingReferenceTargets() {
        var request = sampleRequest(.summarize)
        request.instructions = String(repeating: "中", count: 1_400)
        XCTAssertThrowsError(try request.validate())
        request.instructions = ""
        request.referenceCards = request.cards
        XCTAssertThrowsError(try request.validate())
    }

    func testDisplayedRelationshipRespectsBothEndpointArrows() {
        func link(_ source: String, _ target: String) -> OrganizationLink {
            .init(id: "e", sourceID: "a", targetID: "b", label: "", sourceArrow: source, targetArrow: target)
        }
        XCTAssertEqual(link("arrow", "none").directionSymbol, "←")
        XCTAssertEqual(link("none", "arrow").directionSymbol, "→")
        XCTAssertEqual(link("arrow", "arrow").directionSymbol, "↔")
        XCTAssertEqual(link("none", "none").directionSymbol, "—")
    }

    func testInspectedRevisionMatchesFeedbackAndEditedDraftBeforeAndDuringGeneration() {
        let current = sampleRequest(.summarize)
        var revision = current
        revision.revisionFeedback = "Keep my correction"
        revision.previousProposal = .init(summary: "User-edited summary", groups: [], tasks: [])
        let before = OrganizationRequestInspection.resolve(current: current, generated: current, inFlight: nil, revision: revision)
        XCTAssertEqual(before.request, revision)
        let during = OrganizationRequestInspection.resolve(current: current, generated: nil, inFlight: revision, revision: nil)
        XCTAssertEqual(during.request, revision)
        let after = OrganizationRequestInspection.resolve(current: current, generated: revision, inFlight: nil, revision: nil)
        XCTAssertEqual(after.request, revision)
    }

    private func node(_ id: String, _ canvas: CanvasModel) -> CanvasNodeModel {
        .init(id: id, canvasId: canvas.id, title: id, body: "Fictional note", nodeType: .note, x: 10, y: 20)
    }
}
