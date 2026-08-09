import XCTest
@testable import MindDeskCore

final class AgentIntegrationContractTests: XCTestCase {
    func testProposalOperationTargetsStayLimitedToActionableWorkbenchObjectKinds() throws {
        XCTAssertTrue(MindDeskProposalOperationKind.openObject.supportsTargetKind(.resourcePin))
        XCTAssertTrue(MindDeskProposalOperationKind.openObject.supportsTargetKind(.snippet))
        XCTAssertTrue(MindDeskProposalOperationKind.openObject.supportsTargetKind(.workspace))
        XCTAssertTrue(MindDeskProposalOperationKind.openObject.supportsTargetKind(.webURL))
        XCTAssertFalse(MindDeskProposalOperationKind.openObject.supportsTargetKind(.node))
        XCTAssertFalse(MindDeskProposalOperationKind.openObject.supportsTargetKind(.edge))
        XCTAssertFalse(MindDeskProposalOperationKind.openObject.supportsTargetKind(.todo))
    }
}
