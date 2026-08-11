import Foundation
import XCTest
@testable import MindDesk

@MainActor
final class WorkspaceCanvasNodeOpenRequestTests: XCTestCase {
    func testNewTargetAtomicallyReplacesPendingCorrelationAndRevokesOlderDeferredIssuedRequest() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
        let first = target(1, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(first)
        XCTAssertTrue(controller.beginCanvasNodeTargetLaunch(first, focus: focus, fingerprint: "fp", launchID: uuid(20)))
        XCTAssertTrue(controller.acceptCanvasNodeTargetLaunch(first, launchID: uuid(20), operationID: uuid(21)))
        let issued = try issued(controller.issueCanvasNodeOpenRequest(for: first, scope: scope, nodeObservationFingerprint: "nodes-1"))
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(issued, readiness: .dataNotReady), .defer)

        let replacement = target(2, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-b")
        controller.claimCanvasNodeTarget(replacement)

        XCTAssertEqual(controller.activeCanvasNodeTarget, replacement)
        XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
        XCTAssertNil(controller.canvasNodeLaunchCorrelation)
        XCTAssertNil(controller.lastConsumedCanvasNodeOpenRequestSequence)
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(issued, readiness: .readyOwned), .rejectAndConsume)
        XCTAssertEqual(controller.activeCanvasNodeTarget, replacement)
    }

    func testTargetCorrelationTransfersInitialToProvisioningAndReusesProvisioningOperationAcrossPreAndPostSave() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let pending = target(3, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        XCTAssertTrue(controller.beginCanvasNodeTargetLaunch(pending, focus: focus, fingerprint: "fp", launchID: uuid(30)))
        XCTAssertTrue(controller.acceptCanvasNodeTargetLaunch(pending, launchID: uuid(30), operationID: uuid(31)))

        XCTAssertTrue(controller.handoffCanvasNodeTargetOperation(from: uuid(31), to: uuid(32), target: pending))
        XCTAssertEqual(controller.canvasNodeLaunchCorrelation, .accepted(operationID: uuid(32)))
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(pending, with: uuid(32)))
        XCTAssertEqual(controller.canvasNodeLaunchCorrelation, .accepted(operationID: uuid(32)))
        XCTAssertFalse(controller.handoffCanvasNodeTargetOperation(from: uuid(31), to: uuid(33), target: pending))
    }

    func testTargetLaunchHandshakeRetainsCurrentTargetOnRegistrationFailureWhileStaleFailureMutatesNothing() {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let first = target(4, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(first)
        XCTAssertTrue(controller.beginCanvasNodeTargetLaunch(first, focus: focus, fingerprint: "fp", launchID: uuid(40)))
        XCTAssertTrue(controller.failCanvasNodeTargetLaunch(first, launchID: uuid(40), message: "  database /private/tmp/raw.sqlite failed  "))
        XCTAssertEqual(controller.activeCanvasNodeTarget, first)
        XCTAssertNil(controller.canvasNodeLaunchCorrelation)
        XCTAssertFalse((controller.canvasNodeOpenRecoverableError ?? "").contains("/private/"))

        let replacement = target(5, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-b")
        controller.claimCanvasNodeTarget(replacement)
        let state = controller.canvasNodeOpenFlow
        XCTAssertFalse(controller.failCanvasNodeTargetLaunch(first, launchID: uuid(40), message: "late"))
        XCTAssertEqual(controller.canvasNodeOpenFlow, state)
    }

    func testTerminalIssueOrClearRequiresExactOperationIDAndFourFieldTarget() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
        let pending = target(6, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(pending, with: uuid(60)))

        XCTAssertFalse(controller.resolveCanvasNodeTarget(pending, operationID: uuid(61), resolution: .unique(canvasID: "canvas-a")))
        XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
        XCTAssertTrue(controller.resolveCanvasNodeTarget(pending, operationID: uuid(60), resolution: .unique(canvasID: "canvas-a")))
        _ = try issued(controller.issueCanvasNodeOpenRequest(for: pending, scope: scope, nodeObservationFingerprint: "nodes"))
        XCTAssertNotNil(controller.issuedCanvasNodeOpenRequest)

        let impostor = target(7, workspaceID: pending.workspaceID, canvasID: pending.canvasID, nodeID: pending.nodeID)
        XCTAssertFalse(controller.clearCanvasNodeTarget(impostor))
        XCTAssertTrue(controller.clearCanvasNodeTarget(pending))
        XCTAssertNil(controller.activeCanvasNodeTarget)
    }

    func testExactRecoverableErrorClearsWhileCancellationAndStaleOutcomesRetainTarget() {
        let controller = WorkspaceWindowScopeController()
        _ = controller.focus(workspaceID: "workspace-a")
        let first = target(8, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(first)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(first, with: uuid(80)))
        controller.observeCanvasNodeTargetCancellation(first, operationID: uuid(80))
        XCTAssertEqual(controller.activeCanvasNodeTarget, first)
        XCTAssertFalse(controller.resolveCanvasNodeTarget(first, operationID: uuid(81), recoverableError: "late"))
        XCTAssertEqual(controller.activeCanvasNodeTarget, first)
        XCTAssertTrue(controller.resolveCanvasNodeTarget(first, operationID: uuid(80), recoverableError: "Unavailable"))
        XCTAssertNil(controller.activeCanvasNodeTarget)
        XCTAssertEqual(controller.canvasNodeOpenRecoverableError, "Unavailable")
    }

    func testPendingOrDeferredIssuedTargetReassociatesAcrossSameWorkspaceObservationRotationAndOnlyNewestAToBToAOutcomeMayIssueOrClear() throws {
        let controller = WorkspaceWindowScopeController()
        let focusA1 = controller.focus(workspaceID: "workspace-a")
        let scopeA1 = try bind(controller, focus: focusA1, canvasID: "canvas-a")
        let pending = target(9, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        let oldRequest = try issued(controller.issueCanvasNodeOpenRequest(for: pending, scope: scopeA1, nodeObservationFingerprint: "nodes"))
        let focusA2 = try XCTUnwrap(controller.invalidatePrimaryResolution(for: focusA1))
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(oldRequest, readiness: .readyOwned), .rejectAndConsume)

        _ = controller.focus(workspaceID: "workspace-b")
        XCTAssertNil(controller.activeCanvasNodeTarget)
        let newest = target(10, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-b")
        controller.claimCanvasNodeTarget(newest)
        let focusA3 = controller.focus(workspaceID: "workspace-a")
        XCTAssertNotEqual(focusA2, focusA3)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(newest, with: uuid(90)))
        XCTAssertFalse(controller.resolveCanvasNodeTarget(pending, operationID: uuid(90), recoverableError: "old"))
        XCTAssertTrue(controller.resolveCanvasNodeTarget(newest, operationID: uuid(90), recoverableError: "new"))
    }

    func testSequenceStartsAtOneAndRotationResetsRequestStateWhileMatchingActiveTargetReentersPending() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
        let pending = target(11, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        let first = try issued(controller.issueCanvasNodeOpenRequest(for: pending, scope: scope, nodeObservationFingerprint: "nodes"))
        XCTAssertEqual(first.sequence, 1)
        XCTAssertEqual(controller.nextCanvasNodeOpenRequestSequence, 2)
        let rotated = try XCTUnwrap(controller.invalidatePrimaryResolution(for: focus))
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
        XCTAssertEqual(controller.nextCanvasNodeOpenRequestSequence, 1)
        let rebound = try bind(controller, focus: rotated, canvasID: "canvas-a")
        let second = try issued(controller.issueCanvasNodeOpenRequest(for: pending, scope: rebound, nodeObservationFingerprint: "nodes-2"))
        XCTAssertEqual(second.sequence, 1)
    }

    func testIdentityMismatchRejectsWithoutMutatingReceivingScope() throws {
        let controller = WorkspaceWindowScopeController()
        let focusA = controller.focus(workspaceID: "workspace-a")
        let scopeA = try bind(controller, focus: focusA, canvasID: "canvas-a")
        let targetA = target(12, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(targetA)
        let requestA = try issued(controller.issueCanvasNodeOpenRequest(for: targetA, scope: scopeA, nodeObservationFingerprint: "nodes"))

        let other = WorkspaceWindowScopeController()
        let focusOther = other.focus(workspaceID: "workspace-a")
        _ = try bind(other, focus: focusOther, canvasID: "canvas-a")
        let otherTarget = target(13, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-b")
        other.claimCanvasNodeTarget(otherTarget)
        let before = other.canvasNodeOpenFlow
        XCTAssertEqual(other.decideCanvasNodeOpenRequest(requestA, readiness: .readyOwned), .rejectAndConsume)
        XCTAssertEqual(other.canvasNodeOpenFlow, before)
        XCTAssertNil(other.lastConsumedCanvasNodeOpenRequestSequence)
    }

    func testUnissuedReplacedAndReplayedSequencesRejectWithoutAdvancing() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
        let firstTarget = target(14, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(firstTarget)
        let first = try issued(controller.issueCanvasNodeOpenRequest(for: firstTarget, scope: scope, nodeObservationFingerprint: "nodes"))
        let neverIssued = controller.makeCanvasNodeOpenRequestForTesting(sequence: 999, scope: scope, nodeID: "node-x")
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(neverIssued, readiness: .readyOwned), .rejectAndConsume)
        XCTAssertNil(controller.lastConsumedCanvasNodeOpenRequestSequence)

        let secondTarget = target(15, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-b")
        controller.claimCanvasNodeTarget(secondTarget)
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(first, readiness: .readyOwned), .rejectAndConsume)
        let second = try issued(controller.issueCanvasNodeOpenRequest(for: secondTarget, scope: scope, nodeObservationFingerprint: "nodes"))
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(second, readiness: .readyOwned), .accept)
        XCTAssertEqual(controller.lastConsumedCanvasNodeOpenRequestSequence, second.sequence)
        XCTAssertEqual(controller.decideCanvasNodeOpenRequest(second, readiness: .readyOwned), .rejectAndConsume)
        XCTAssertEqual(controller.lastConsumedCanvasNodeOpenRequestSequence, second.sequence)
    }

    func testDataNotReadyRetainsIssuedFlowWhileReadyOwnedAndConfirmedAbsenceConsumeExactTarget() throws {
        for (offset, readiness, decision) in [
            (16, WorkspaceCanvasNodeReadiness.dataNotReady, WorkspaceCanvasNodeOpenRequestDecision.defer),
            (17, .readyOwned, .accept),
            (18, .definitelyAbsentOrCrossCanvas, .rejectAndConsume),
        ] {
            let controller = WorkspaceWindowScopeController()
            let focus = controller.focus(workspaceID: "workspace-a")
            let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
            let pending = target(offset, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
            controller.claimCanvasNodeTarget(pending)
            let request = try issued(controller.issueCanvasNodeOpenRequest(for: pending, scope: scope, nodeObservationFingerprint: "nodes"))
            XCTAssertEqual(controller.decideCanvasNodeOpenRequest(request, readiness: readiness), decision)
            if readiness == .dataNotReady {
                XCTAssertEqual(controller.issuedCanvasNodeOpenRequest, request)
                XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
            } else {
                XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
                XCTAssertNil(controller.activeCanvasNodeTarget)
            }
        }
    }

    func testAllocatorOverflowEmitsNothingInvalidatesOnceAndStartsOneCorrelatedFreshLookup() throws {
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: "workspace-a")
        let scope = try bind(controller, focus: focus, canvasID: "canvas-a")
        let pending = target(19, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        controller.seedNextCanvasNodeOpenRequestSequenceForTesting(UInt64.max)
        let result = controller.issueCanvasNodeOpenRequest(for: pending, scope: scope, nodeObservationFingerprint: "nodes")
        guard case let .overflowInvalidated(rotatedFocus) = result else {
            return XCTFail("Expected overflow invalidation")
        }
        XCTAssertNotEqual(rotatedFocus, focus)
        XCTAssertNil(controller.issuedCanvasNodeOpenRequest)
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertNil(controller.primaryResolution)
        XCTAssertNil(controller.boundCanvas)
        XCTAssertTrue(controller.beginCanvasNodeTargetLaunch(pending, focus: rotatedFocus, fingerprint: "fp", launchID: uuid(190)))
        XCTAssertTrue(controller.acceptCanvasNodeTargetLaunch(pending, launchID: uuid(190), operationID: uuid(191)))
        XCTAssertFalse(controller.beginCanvasNodeTargetLaunch(pending, focus: rotatedFocus, fingerprint: "fp", launchID: uuid(192)))
    }

    func testCrossWorkspaceQuickOpenClaimsTargetThenUsesOneObservationDrivenLookupAndArrayLookupIsNotAuthorizationEvidence() {
        let controller = WorkspaceWindowScopeController()
        _ = controller.focus(workspaceID: "workspace-a")
        let pending = target(20, workspaceID: "workspace-b", canvasID: "canvas-b", nodeID: "node-b")
        controller.claimCanvasNodeTarget(pending)
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertNil(controller.canvasNodeLaunchCorrelation)
        let focusB = controller.focus(workspaceID: "workspace-b")
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertTrue(controller.beginCanvasNodeTargetLaunch(pending, focus: focusB, fingerprint: "fp-b", launchID: uuid(200)))
        XCTAssertTrue(controller.acceptCanvasNodeTargetLaunch(pending, launchID: uuid(200), operationID: uuid(201)))
        XCTAssertFalse(controller.beginCanvasNodeTargetLaunch(pending, focus: focusB, fingerprint: "fp-b", launchID: uuid(202)))
    }

    func testMissingDefersOnlyDuringAcceptedProvisioningWhileInactiveMissingDuplicateAndTargetMismatchClearExactTarget() {
        let controller = WorkspaceWindowScopeController()
        _ = controller.focus(workspaceID: "workspace-a")
        let pending = target(21, workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "node-a")
        controller.claimCanvasNodeTarget(pending)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(pending, with: uuid(210)))
        XCTAssertFalse(controller.resolveCanvasNodeTarget(pending, operationID: uuid(210), resolution: .missing, provisioningIsActive: true))
        XCTAssertEqual(controller.activeCanvasNodeTarget, pending)
        XCTAssertTrue(controller.resolveCanvasNodeTarget(pending, operationID: uuid(210), resolution: .missing))
        XCTAssertNil(controller.activeCanvasNodeTarget)

        controller.claimCanvasNodeTarget(pending)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(pending, with: uuid(211)))
        XCTAssertTrue(controller.resolveCanvasNodeTarget(pending, operationID: uuid(211), resolution: .duplicate(canvasIDs: ["canvas-a", "canvas-b"])))
        XCTAssertNil(controller.activeCanvasNodeTarget)

        controller.claimCanvasNodeTarget(pending)
        XCTAssertTrue(controller.reassociateCanvasNodeTarget(pending, with: uuid(212)))
        XCTAssertTrue(controller.resolveCanvasNodeTarget(pending, operationID: uuid(212), resolution: .unique(canvasID: "canvas-other")))
        XCTAssertNil(controller.activeCanvasNodeTarget)
    }

    func testLegacyIntRequestTargetPolicyAndCanvasConsumerSymbolsAreAbsent() throws {
        let content = try source("Sources/MindDesk/Views/ContentView.swift")
        let canvas = try source("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift")
        let combined = content + canvas
        XCTAssertFalse(combined.contains("WorkspaceCanvasNodeOpenRequestPolicy"))
        XCTAssertFalse(combined.contains("handledOpenCanvasNodeRequestID"))
        XCTAssertFalse(combined.contains("openCanvasNodeRequestID"))
        XCTAssertFalse(canvas.contains("handleOpenCanvasNodeRequest"))
        XCTAssertFalse(canvas.contains("openCanvasNodeRequest:"))
        XCTAssertTrue(content.contains("claimCanvasNodeTarget"))
        XCTAssertTrue(content.contains("onChange(of: primaryCanvasSceneObservation, initial: true)"))
    }

    private func bind(
        _ controller: WorkspaceWindowScopeController,
        focus: WorkspaceFocusScopeIdentity,
        canvasID: String
    ) throws -> WorkspaceCanvasScopeIdentity {
        guard case let .bound(scope) = controller.bind(.unique(canvasID: canvasID), for: focus) else {
            throw TestError.expectedBoundScope
        }
        return scope
    }

    private func issued(_ result: WorkspaceCanvasNodeOpenRequestIssueResult) throws -> WorkspaceCanvasNodeOpenRequest {
        guard case let .issued(request) = result else {
            throw TestError.expectedIssuedRequest
        }
        return request
    }

    private func target(
        _ value: Int,
        workspaceID: String,
        canvasID: String,
        nodeID: String
    ) -> PendingWorkspaceCanvasNodeTarget {
        PendingWorkspaceCanvasNodeTarget(
            requestID: uuid(value),
            workspaceID: workspaceID,
            canvasID: canvasID,
            nodeID: nodeID
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func source(_ relativePath: String) throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
        let root = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private enum TestError: Error {
        case expectedBoundScope
        case expectedIssuedRequest
    }
}
