import XCTest
import SwiftData
@testable import MindDesk

@MainActor
final class OrganizationApplyTests: XCTestCase {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkspaceModel.self, CanvasModel.self, CanvasNodeModel.self, WorkspaceTodoModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testSummaryAddsNoteWithoutChangingSourceAndUndoRemovesIt() throws {
        let context = try context()
        let canvas = CanvasModel(workspaceId: "w", title: "Canvas")
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Source", body: "Original", nodeType: .note, x: 20, y: 30)
        context.insert(canvas)
        context.insert(node)
        try context.save()
        let selection = OrganizationSelection(canvas: canvas, nodes: [node])
        let request = selection.request(intent: .summarize)
        let proposal = OrganizationProposal(summary: "A concise summary", groups: [], tasks: [])
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        try OrganizationApplyService.apply(proposal, request: request, selection: selection, canvas: canvas, context: context, undoManager: undo)
        undo.endUndoGrouping()
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasNodeModel>()).count, 2)
        XCTAssertEqual(node.body, "Original")
        undo.undo()
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasNodeModel>()).count, 1)
        XCTAssertEqual(node.body, "Original")
    }

    func testStaleOrLockedSelectionCannotApply() throws {
        let context = try context()
        let canvas = CanvasModel(workspaceId: "w", title: "Canvas")
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Before", nodeType: .note, x: 0, y: 0)
        context.insert(canvas)
        context.insert(node)
        try context.save()
        let selection = OrganizationSelection(canvas: canvas, nodes: [node])
        node.title = "After"
        try context.save()
        let request = selection.request(intent: .summarize)
        XCTAssertThrowsError(try OrganizationApplyService.apply(
            OrganizationProposal(summary: "Old", groups: [], tasks: []), request: request,
            selection: selection, canvas: canvas, context: context, undoManager: nil
        ))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasNodeModel>()).count, 1)
    }

    func testGroupingAndUndoRestorePositionsAndParentWithoutTouchingOtherCards() throws {
        let context = try context()
        let canvas = CanvasModel(workspaceId: "w")
        let first = CanvasNodeModel(id: "first", canvasId: canvas.id, title: "One", nodeType: .note, x: 10, y: 20)
        let other = CanvasNodeModel(id: "other", canvasId: canvas.id, title: "Other", nodeType: .note, x: 500, y: 600, locked: true)
        context.insert(canvas); context.insert(first); context.insert(other)
        try context.save()
        let selection = OrganizationSelection(canvas: canvas, nodes: [first, other])
        XCTAssertEqual(selection.cards.count, 1)
        let proposal = OrganizationProposal(summary: "", groups: [.init(name: "Ideas", cardIDs: ["first"])], tasks: [])
        let undo = UndoManager(); undo.groupsByEvent = false
        undo.beginUndoGrouping()
        try OrganizationApplyService.apply(proposal, request: selection.request(intent: .classify), selection: selection,
                                           canvas: canvas, context: context, undoManager: undo)
        undo.endUndoGrouping()
        XCTAssertNotNil(first.parentNodeId)
        XCTAssertEqual(other.x, 500)
        undo.undo()
        XCTAssertNil(first.parentNodeId)
        XCTAssertEqual(first.x, 10)
        XCTAssertEqual(first.y, 20)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasNodeModel>()).count, 2)
    }

    func testTaskCreationRetainsSourcesAndUndoRemovesOnlyCreatedTasks() throws {
        let context = try context()
        let canvas = CanvasModel(workspaceId: "w")
        let source = CanvasNodeModel(id: "source", canvasId: canvas.id, title: "Meeting", nodeType: .note, x: 0, y: 0)
        let existing = WorkspaceTodoModel(workspaceId: "w", title: "Keep me")
        context.insert(canvas); context.insert(source); context.insert(existing)
        try context.save()
        let selection = OrganizationSelection(canvas: canvas, nodes: [source])
        let undo = UndoManager(); undo.groupsByEvent = false
        undo.beginUndoGrouping()
        try OrganizationApplyService.apply(
            .init(summary: "", groups: [], tasks: [.init(title: "Follow up", details: "Call tomorrow", sourceCardIDs: [source.id])]),
            request: selection.request(intent: .extractTasks), selection: selection,
            canvas: canvas, context: context, undoManager: undo
        )
        undo.endUndoGrouping()
        let tasks = try context.fetch(FetchDescriptor<WorkspaceTodoModel>())
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.first { $0.title == "Follow up" }?.details.contains("Meeting") == true)
        undo.undo()
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkspaceTodoModel>()).map(\.title), ["Keep me"])
    }
}
