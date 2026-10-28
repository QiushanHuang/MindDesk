import MindDeskCore
import XCTest
@testable import MindDesk

final class WorkweftBridgeReviewContentTests: XCTestCase {
    func testReviewShowsMergedContentLinksAndInheritedHiddenState() {
        let document = WorkweftCanvasDocument(
            nodes: [
                .init(id: "group", kind: "group", hidden: true, title: "Hidden group"),
                .init(id: "task:42", kind: "task", refID: "42", parentID: "group"),
                .init(id: "note", kind: "note", title: "Local note", body: "Draft text")
            ],
            edges: [.init(id: "link", source: "task:42", target: "note", label: "relates to")]
        )
        let references = [WorkweftBridgeReference(kind: "task", refID: "42", title: "Review draft", status: "Ready", body: "Linked description")]

        let content = WorkweftBridgeReviewContent.make(document: document, references: references)

        let linked = content.cards.first { $0.id == "task:42" }
        XCTAssertEqual(linked?.title, "Review draft")
        XCTAssertEqual(linked?.body, "Linked description")
        XCTAssertEqual(linked?.status, "Ready")
        XCTAssertEqual(linked?.isHidden, true)
        XCTAssertEqual(content.cards.first { $0.id == "note" }?.body, "Draft text")
        XCTAssertEqual(content.cards.first { $0.id == "note" }?.isHidden, false)
        XCTAssertEqual(content.links.first?.sourceTitle, "Review draft")
        XCTAssertEqual(content.links.first?.targetTitle, "Local note")
        XCTAssertEqual(content.links.first?.label, "relates to")
    }

    func testMissingReferenceMetadataUsesIdentityWithoutInventingContent() {
        let document = WorkweftCanvasDocument(nodes: [.init(id: "asset:source", kind: "asset", refID: "source")])
        let card = WorkweftBridgeReviewContent.make(document: document, references: nil).cards.first

        XCTAssertEqual(card?.title, "Asset: source")
        XCTAssertEqual(card?.body, "")
        XCTAssertNil(card?.status)
        XCTAssertEqual(card?.isHidden, false)
    }
}
