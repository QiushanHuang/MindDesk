import XCTest
@testable import MindDesk

final class OrganizationProposalTests: XCTestCase {
    func testRejectsUnknownAndDuplicatePlacement() throws {
        let request = sampleRequest(.classify)
        XCTAssertThrowsError(try OrganizationProposal(summary: "", groups: [.init(name: "A", cardIDs: ["missing"])], tasks: []).validate(for: request))
        XCTAssertThrowsError(try OrganizationProposal(summary: "", groups: [.init(name: "A", cardIDs: ["a", "a"])], tasks: []).validate(for: request))
    }

    func testIntentCannotSmuggleOtherActions() {
        XCTAssertThrowsError(try OrganizationProposal(summary: "Summary", groups: [.init(name: "A", cardIDs: ["a"])], tasks: []).validate(for: sampleRequest(.summarize)))
        XCTAssertNoThrow(try OrganizationProposal(summary: "Summary", groups: [], tasks: []).validate(for: sampleRequest(.summarize)))
    }

    func testRejectsOversizeAndBlankInput() {
        var request = sampleRequest(.summarize)
        request.cards = Array(repeating: request.cards[0], count: 101)
        XCTAssertThrowsError(try request.validate())
        request.cards = [.init(id: "a", title: "", body: String(repeating: "x", count: 20_001), kind: "note")]
        XCTAssertThrowsError(try request.validate())
        XCTAssertThrowsError(try OrganizationProposal(summary: "  ", groups: [], tasks: []).validate(for: sampleRequest(.summarize)))
    }

    func testTasksNeedKnownSourcesAndNonblankTitles() {
        XCTAssertNoThrow(try OrganizationProposal(summary: "", groups: [], tasks: [.init(title: "Do it", details: "", sourceCardIDs: ["a"])]).validate(for: sampleRequest(.extractTasks)))
        XCTAssertThrowsError(try OrganizationProposal(summary: "", groups: [], tasks: [.init(title: " ", details: "", sourceCardIDs: ["a"])]).validate(for: sampleRequest(.extractTasks)))
    }
}

func sampleRequest(_ intent: OrganizationIntent) -> OrganizationRequest {
    .init(workspaceID: "workspace", canvasID: "canvas", intent: intent, cards: [.init(id: "a", title: "Note", body: "Hello", kind: "note")])
}
