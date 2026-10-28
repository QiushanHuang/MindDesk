import XCTest
import SwiftData
import MindDeskCore
@testable import MindDesk

@MainActor
final class WorkweftBridgeServiceTests: XCTestCase {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: WorkspaceModel.self, CanvasModel.self, CanvasNodeModel.self, CanvasEdgeModel.self, ResourcePinModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container); context.autosaveEnabled = false
        context.insert(WorkspaceModel(id: "workspace", title: "Fictional workspace"))
        try context.save(); return context
    }
    private func package() -> WorkweftBridgePackage {
        .init(pairId: "pair", projectId: "project", document: .init(nodes: [.init(id: "task:task-1", kind: "task", refID: "task-1"), .init(id: "note", kind: "note", x: 320, title: "Initial note")]), references: [.init(kind: "task", refID: "task-1", title: "Workweft task", status: "ready")])
    }
    private func preview(_ package: WorkweftBridgePackage, _ context: ModelContext) throws -> WorkweftBridgeImportPreview {
        try WorkweftBridgeService.preview(data: JSONEncoder().encode(package), workspaceID: "workspace", context: context)
    }
    func testReviewedImportAndExportRetainIDsAndReadOnlyReferences() throws {
        let context = try context()
        let bookmark = ResourcePinModel(id: "bookmark", title: "Local only", targetType: .file, displayPath: "/fictional", lastResolvedPath: "/fictional", securityScopedBookmarkData: Data([1, 2, 3]), scope: .global)
        context.insert(bookmark); try context.save()
        let proposal = try preview(package(), context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasModel>()).count, 0)
        let receipt = try WorkweftBridgeService.apply(preview: proposal, context: context)
        let exported = try JSONDecoder().decode(WorkweftBridgePackage.self, from: WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context))
        XCTAssertEqual(exported.workspaceId, "workspace")
        XCTAssertTrue(exported.document.semanticallyEquals(package().document))
        XCTAssertEqual(bookmark.securityScopedBookmarkData, Data([1, 2, 3]))
        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.objectId == "task-1" })
        XCTAssertEqual(task.title, "Workweft task")
        task.title = "must not become canonical"; task.body = "must not become canonical"; try context.save()
        XCTAssertThrowsError(try WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context))
    }
    func testStalePreviewUnknownBaseAndCrossWorkspaceAreRejected() throws {
        let context = try context(); let initial = package()
        let receipt = try WorkweftBridgeService.apply(preview: preview(initial, context), context: context)
        var incoming = initial; incoming.workspaceId = "workspace"; incoming.base = initial.document; incoming.document.nodes[1].body = "remote"
        let proposal = try preview(incoming, context)
        let node = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.title == "Initial note" })
        node.x = 900; try context.save()
        XCTAssertThrowsError(try WorkweftBridgeService.apply(preview: proposal, context: context))
        incoming.base?.nodes[1].title = "unrecognized base"
        XCTAssertThrowsError(try preview(incoming, context))
        incoming.base = initial.document; incoming.workspaceId = "other-workspace"
        XCTAssertThrowsError(try preview(incoming, context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasModel>()).first?.id, receipt.canvasID)
    }
    func testConflictRequiresChoiceAndUndoProtectsLaterEdits() throws {
        let context = try context(); let initial = package()
        let first = try WorkweftBridgeService.apply(preview: preview(initial, context), context: context)
        let note = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.title == "Initial note" })
        note.title = "local"; try context.save()
        var incoming = initial; incoming.workspaceId = "workspace"; incoming.base = initial.document; incoming.document.nodes[1].title = "remote"
        let proposal = try preview(incoming, context)
        let conflict = try XCTUnwrap(proposal.merge.conflicts.first)
        XCTAssertThrowsError(try WorkweftBridgeService.apply(preview: proposal, context: context))
        let receipt = try WorkweftBridgeService.apply(preview: proposal, choices: [conflict.id: .incoming], context: context)
        XCTAssertEqual(note.title, "remote")
        try WorkweftBridgeService.undo(receipt: receipt, context: context)
        XCTAssertEqual(note.title, "local")
        let later = try WorkweftBridgeService.apply(preview: preview(incoming, context), choices: [conflict.id: .incoming], context: context)
        note.body = "later edit"; try context.save()
        XCTAssertThrowsError(try WorkweftBridgeService.undo(receipt: later, context: context))
        XCTAssertEqual(note.body, "later edit")
        XCTAssertEqual(later.canvasID, first.canvasID)
    }
    func testAcknowledgedExportBaseAndNativeNewNoteHaveStableIdentity() throws {
        let context = try context(); let initial = package()
        let receipt = try WorkweftBridgeService.apply(preview: preview(initial, context), context: context)
        let added = CanvasNodeModel(id: "native-note", canvasId: receipt.canvasID, title: "Native note", nodeType: .note, x: 600, y: 0, width: 240, height: 160)
        context.insert(added); try context.save()
        let outgoing = try JSONDecoder().decode(WorkweftBridgePackage.self, from: WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context))
        XCTAssertTrue(outgoing.document.nodes.contains { $0.id == "minddesk:native-note" })
        var acknowledgement = outgoing; acknowledgement.base = outgoing.document; acknowledgement.document.nodes[0].y = 200
        let second = try WorkweftBridgeService.apply(preview: preview(acknowledgement, context), context: context)
        let repeated = try JSONDecoder().decode(WorkweftBridgePackage.self, from: WorkweftBridgeService.export(canvasID: second.canvasID, context: context))
        XCTAssertTrue(repeated.document.nodes.contains { $0.id == "minddesk:native-note" })
        XCTAssertEqual(try context.fetch(FetchDescriptor<CanvasModel>()).count, 1)
    }
    func testRemovedLinkedCardExportsHiddenAndInitialUndoRemovesOnlyNewCanvas() throws {
        let context = try context()
        let receipt = try WorkweftBridgeService.apply(preview: preview(package(), context), context: context)
        try WorkweftBridgeService.undo(receipt: receipt, context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CanvasModel>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkspaceModel>()).count, 1)
        let recreated = try WorkweftBridgeService.apply(preview: preview(package(), context), context: context)
        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.objectId == "task-1" })
        context.delete(task); try context.save()
        let exported = try JSONDecoder().decode(WorkweftBridgePackage.self, from: WorkweftBridgeService.export(canvasID: recreated.canvasID, context: context))
        XCTAssertEqual(exported.document.nodes.first { $0.id == "task:task-1" }?.hidden, true)
    }

    func testDedicatedBridgeDoesNotDisplaceOrdinaryPrimaryCanvas() throws {
        let context = try context()
        let normal = CanvasModel(id: "normal", workspaceId: "workspace")
        context.insert(normal); try context.save()
        _ = try WorkweftBridgeService.apply(preview: preview(package(), context), context: context)
        XCTAssertEqual(try WorkspaceCanvasLookup.resolve(for: "workspace", in: context), .unique(canvasID: "normal"))
    }

    func testMappedNodeMovedToAnotherCanvasIsNeverRebound() throws {
        let context = try context()
        let receipt = try WorkweftBridgeService.apply(preview: preview(package(), context), context: context)
        let other = CanvasModel(id: "other", workspaceId: "workspace")
        context.insert(other)
        let note = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.title == "Initial note" })
        note.canvasId = other.id; try context.save()
        XCTAssertThrowsError(try WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context))
        XCTAssertThrowsError(try preview(package(), context))
        XCTAssertEqual(note.canvasId, other.id)
    }

    func testUndoCannotReclaimAnIdentityNowOwnedByAnotherCanvas() throws {
        let context = try context(); let initial = package()
        _ = try WorkweftBridgeService.apply(preview: preview(initial, context), context: context)
        let noteID = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.title == "Initial note" }?.id)
        var incoming = initial; incoming.base = initial.document; incoming.document.nodes.removeAll { $0.kind == "note" }
        let receipt = try WorkweftBridgeService.apply(preview: preview(incoming, context), context: context)
        context.insert(CanvasModel(id: "other", workspaceId: "workspace"))
        let moved = CanvasNodeModel(id: noteID, canvasId: "other", title: "Other canvas data", nodeType: .note, x: 0, y: 0)
        context.insert(moved); try context.save()
        XCTAssertThrowsError(try WorkweftBridgeService.undo(receipt: receipt, context: context))
        XCTAssertEqual(moved.canvasId, "other")
        XCTAssertEqual(moved.title, "Other canvas data")
    }

    func testHiddenGroupPreservesUnhiddenDescendantMetadataWithoutShowingIt() throws {
        let context = try context()
        var input = package()
        input.document.nodes = [.init(id: "group", kind: "group", hidden: true, title: "Hidden group"), .init(id: "child", kind: "note", x: 100, parentID: "group", title: "Invisible child"), .init(id: "task:t", kind: "task", refID: "t", parentID: "group")]
        input.document.edges = [.init(id: "inside", source: "child", target: "task:t")]
        let receipt = try WorkweftBridgeService.apply(preview: preview(input, context), context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CanvasNodeModel>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CanvasEdgeModel>()).isEmpty)
        let result = try JSONDecoder().decode(WorkweftBridgePackage.self, from: WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context))
        XCTAssertTrue(result.document.semanticallyEquals(input.document))
    }

    func testOptInActualWorkweftPackageRoundTrip() throws {
        let env = ProcessInfo.processInfo.environment
        guard let input = env["WORKWEFT_BRIDGE_INPUT"], let output = env["WORKWEFT_BRIDGE_OUTPUT"] else { throw XCTSkip("Set explicit fixture input/output paths for cross-app proof.") }
        let data = try Data(contentsOf: URL(fileURLWithPath: input))
        let package = try JSONDecoder().decode(WorkweftBridgePackage.self, from: data)
        let context = try context()
        let receipt = try WorkweftBridgeService.apply(preview: WorkweftBridgeService.preview(data: data, workspaceID: "workspace", context: context), context: context)
        let note = try XCTUnwrap(try context.fetch(FetchDescriptor<CanvasNodeModel>()).first { $0.nodeType == .note && $0.objectType == nil })
        note.title = "Native roundtrip note"; note.x += 55; note.body = "Edited by the isolated native bridge fixture."
        try context.save()
        let exported = try WorkweftBridgeService.export(canvasID: receipt.canvasID, context: context)
        let returned = try JSONDecoder().decode(WorkweftBridgePackage.self, from: exported)
        XCTAssertEqual(Set(returned.document.nodes.map(\.id)), Set(package.document.nodes.map(\.id)))
        XCTAssertEqual(returned.document.nodes.filter { $0.kind == "group" }.count, package.document.nodes.filter { $0.kind == "group" }.count)
        guard !FileManager.default.fileExists(atPath: output) else { throw WorkweftBridgeError("Choose a fresh cross-app output path.") }
        try exported.write(to: URL(fileURLWithPath: output), options: .withoutOverwriting)
    }
}
