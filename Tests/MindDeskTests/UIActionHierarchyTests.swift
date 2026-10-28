import XCTest
@testable import MindDesk

final class UIActionHierarchyTests: XCTestCase {
    func testResourceActionsKeepFrequentControlsVisibleAndEverythingElseInMenu() {
        for isPinned in [false, true] {
            let primary = ResourceRowActionPresentationPolicy.primaryActions(isPinned: isPinned)
            let more = ResourceRowActionPresentationPolicy.moreMenuActions(canRemove: true)
            let context = ResourceRowActionPresentationPolicy.contextMenuActions(isPinned: isPinned, canRemove: true)

            XCTAssertEqual(primary.map(\.id), [.open, .pinToggle])
            XCTAssertEqual(Set(primary.map(\.id) + more.map(\.id)), Set(context.map(\.id)))
            XCTAssertEqual(Set(primary.map(\.id)).intersection(Set(more.map(\.id))), [])
            XCTAssertEqual(primary.last?.title, isPinned ? "Unpin" : "Pin")
            XCTAssertFalse(ResourceRowActionPresentationPolicy.moreMenuActions(canRemove: false).contains { $0.id == .remove })
        }
    }
}
