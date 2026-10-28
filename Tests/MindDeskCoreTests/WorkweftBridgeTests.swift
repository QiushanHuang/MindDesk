import XCTest
@testable import MindDeskCore

final class WorkweftBridgeTests: XCTestCase {
    func testWireRoundTripUsesSharedKeysAndExplicitNulls() throws {
        let node = WorkweftCanvasNode(id: "n", kind: "note", title: "Note")
        let package = WorkweftBridgePackage(pairId: "pair", projectId: "project", document: .init(nodes: [node]))
        let data = try JSONEncoder().encode(package)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["format"] as? String, "workweft.minddesk.bridge")
        XCTAssertTrue(object["base"] is NSNull)
        XCTAssertTrue(object["workspaceId"] is NSNull)
        let document = try XCTUnwrap(object["document"] as? [String: Any])
        XCTAssertEqual(document["schema"] as? String, "WorkweftCanvasV1")
        let nodes = try XCTUnwrap(document["nodes"] as? [[String: Any]])
        XCTAssertTrue(nodes[0]["ref_id"] is NSNull)
        XCTAssertTrue(nodes[0]["parent_id"] is NSNull)
        XCTAssertEqual(try JSONDecoder().decode(WorkweftBridgePackage.self, from: data), package)
    }

    func testValidationRejectsInvalidIdentityGeometryAndParentCycles() throws {
        var doc = WorkweftCanvasDocument(nodes: [.init(id: "n", kind: "note", title: "Note")])
        try doc.validate()
        doc.nodes.append(doc.nodes[0])
        XCTAssertThrowsError(try doc.validate())
        doc.nodes.removeLast()
        doc.nodes[0].width = .infinity
        XCTAssertThrowsError(try doc.validate())
        doc.nodes = [.init(id: "g", kind: "group", parentID: "g", title: "Group")]
        XCTAssertThrowsError(try doc.validate())
        doc.nodes = [.init(id: "task:task", kind: "task", refID: "task", title: "forged canonical title")]
        XCTAssertThrowsError(try doc.validate())
        doc.nodes[0].title = ""
        try doc.validate()
    }

    func testMergeCombinesIndependentFieldsAndIgnoresArrayOrder() throws {
        let base = WorkweftCanvasDocument(nodes: [.init(id: "a", kind: "note", title: "A"), .init(id: "b", kind: "note", title: "B")])
        var local = base, incoming = base
        local.nodes[0].x = 75
        incoming.nodes[0].body = "new body"
        incoming.nodes.reverse()
        let preview = try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming)
        XCTAssertTrue(preview.conflicts.isEmpty)
        XCTAssertEqual(preview.document.nodes.first { $0.id == "a" }?.x, 75)
        XCTAssertEqual(preview.document.nodes.first { $0.id == "a" }?.body, "new body")
        XCTAssertTrue(base.semanticallyEquals(.init(nodes: base.nodes.reversed())))
    }

    func testMergeRequiresExplicitChoiceForConcurrentEditAndDelete() throws {
        let base = WorkweftCanvasDocument(nodes: [.init(id: "a", kind: "note", title: "A")])
        var local = base, incoming = base
        local.nodes[0].title = "local"
        incoming.nodes[0].title = "incoming"
        let preview = try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming)
        let conflict = try XCTUnwrap(preview.conflicts.first)
        XCTAssertEqual(preview.conflicts.count, 1)
        let resolved = try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming, choices: [conflict.id: .incoming])
        XCTAssertEqual(resolved.document.nodes[0].title, "incoming")
        XCTAssertTrue(resolved.unresolved.isEmpty)
        incoming.nodes = []
        XCTAssertEqual(try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming).conflicts.count, 1)
    }

    func testSharedLimitsAndReservedLinkedIdentityAreEnforced() throws {
        var doc = WorkweftCanvasDocument(nodes: [.init(id: "wrong", kind: "task", refID: "t")])
        XCTAssertThrowsError(try doc.validate())
        doc.nodes[0].id = "task:t"; try doc.validate()
        doc.nodes = [.init(id: "task:spoof", kind: "note", title: "Spoof")]
        XCTAssertThrowsError(try doc.validate())
        doc.nodes = [.init(id: String(repeating: "n", count: 161), kind: "note", title: "Long id")]
        XCTAssertThrowsError(try doc.validate())
        doc.nodes = (0..<80).map { .init(id: "n\($0)", kind: "note", title: "N", body: String(repeating: "x", count: 10000)) }
        XCTAssertThrowsError(try doc.validate())
        doc.nodes = [.init(id: "a", kind: "note", title: "A"), .init(id: "b", kind: "note", title: "B")]
        doc.edges = [.init(id: "e", source: "a", target: "b", label: String(repeating: "x", count: 161))]
        XCTAssertThrowsError(try doc.validate())
    }

    func testStructuralMergeHasExplicitWholeGraphResolution() throws {
        let base = WorkweftCanvasDocument(nodes: [.init(id: "g", kind: "group", title: "Group"), .init(id: "n", kind: "note", title: "Note")])
        var local = base, incoming = base
        local.nodes[1].parentID = "g"
        incoming.nodes.removeAll { $0.id == "g" }
        let preview = try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming)
        XCTAssertEqual(preview.conflicts.map(\.id), ["structure"])
        XCTAssertEqual(preview.unresolved.count, 1)
        let resolved = try WorkweftBridgeMerge.preview(base: base, local: local, incoming: incoming, choices: ["structure": .incoming])
        XCTAssertTrue(resolved.document.semanticallyEquals(incoming))
        XCTAssertTrue(resolved.unresolved.isEmpty)
    }
}
