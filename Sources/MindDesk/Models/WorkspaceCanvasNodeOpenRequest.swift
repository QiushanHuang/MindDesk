import Foundation
import MindDeskCore

struct PendingWorkspaceCanvasNodeTarget: Equatable, Sendable {
    let requestID: UUID
    let workspaceID: String
    let canvasID: String
    let nodeID: String
}

struct WorkspaceCanvasNodeOpenRequest: Equatable, Sendable {
    let sequence: UInt64
    let scopeIdentity: WorkspaceCanvasScopeIdentity
    let nodeID: String

    fileprivate init(
        sequence: UInt64,
        scopeIdentity: WorkspaceCanvasScopeIdentity,
        nodeID: String
    ) {
        self.sequence = sequence
        self.scopeIdentity = scopeIdentity
        self.nodeID = nodeID
    }
}

enum WorkspaceCanvasNodeReadiness: Equatable, Sendable {
    case dataNotReady
    case definitelyAbsentOrCrossCanvas
    case readyOwned
}

enum WorkspaceCanvasNodeOpenRequestDecision: Equatable, Sendable {
    case accept
    case rejectAndConsume
    case `defer`
}

enum WorkspaceCanvasNodeLaunchCorrelation: Equatable, Sendable {
    case starting(
        launchID: UUID,
        focus: WorkspaceFocusScopeIdentity,
        fingerprint: String
    )
    case accepted(operationID: UUID)
}

enum WorkspaceCanvasNodeOwnershipEvidence: Equatable, Sendable {
    case ready(
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    )
    case dirty(
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    )
}

enum WorkspaceCanvasNodeOpenFlow: Equatable, Sendable {
    case idle
    case pending(
        target: PendingWorkspaceCanvasNodeTarget,
        correlation: WorkspaceCanvasNodeLaunchCorrelation?
    )
    case issued(
        target: PendingWorkspaceCanvasNodeTarget,
        request: WorkspaceCanvasNodeOpenRequest,
        evidence: WorkspaceCanvasNodeOwnershipEvidence
    )
}

enum WorkspaceCanvasNodeOpenRequestIssueResult: Equatable, Sendable {
    case issued(WorkspaceCanvasNodeOpenRequest)
    case deferred
    case overflowInvalidated(WorkspaceFocusScopeIdentity)
}

@MainActor
extension WorkspaceWindowScopeController {
    var activeCanvasNodeTarget: PendingWorkspaceCanvasNodeTarget? {
        switch canvasNodeOpenFlow {
        case .idle:
            return nil
        case let .pending(target, _), let .issued(target, _, _):
            return target
        }
    }

    var canvasNodeLaunchCorrelation: WorkspaceCanvasNodeLaunchCorrelation? {
        guard case let .pending(_, correlation) = canvasNodeOpenFlow else {
            return nil
        }
        return correlation
    }

    var issuedCanvasNodeOpenRequest: WorkspaceCanvasNodeOpenRequest? {
        guard case let .issued(_, request, _) = canvasNodeOpenFlow else {
            return nil
        }
        return request
    }

    func reducePrimaryCanvasSceneObservation(
        from previous: WorkspacePrimaryCanvasSceneObservation?,
        to current: WorkspacePrimaryCanvasSceneObservation,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback = { _ in },
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback = { _ in }
    ) {
        guard let workspaceID = current.workspaceID,
              let fingerprint = current.fingerprint
        else {
            clear()
            return
        }

        guard previous?.workspaceID == workspaceID,
              pendingFocus?.workspaceID == workspaceID
        else {
            let focus = focus(workspaceID: workspaceID)
            _ = startPrimaryCanvasResolutionForActiveCanvasNodeTarget(
                for: focus,
                fingerprint: fingerprint,
                store: store,
                onTerminalOutcome: onTerminalOutcome,
                onOperationHandoff: onOperationHandoff
            )
            return
        }

        guard previous?.fingerprint != fingerprint,
              let focus = pendingFocus,
              let freshFocus = invalidatePrimaryResolution(for: focus)
        else {
            return
        }
        _ = startPrimaryCanvasResolutionForActiveCanvasNodeTarget(
            for: freshFocus,
            fingerprint: fingerprint,
            store: store,
            onTerminalOutcome: onTerminalOutcome,
            onOperationHandoff: onOperationHandoff
        )
    }

    @discardableResult
    func claimCanvasNodeTarget(
        workspaceID: String,
        canvasID: String,
        nodeID: String,
        requestID: UUID = UUID()
    ) -> PendingWorkspaceCanvasNodeTarget {
        let target = PendingWorkspaceCanvasNodeTarget(
            requestID: requestID,
            workspaceID: workspaceID,
            canvasID: canvasID,
            nodeID: nodeID
        )
        claimCanvasNodeTarget(target)
        return target
    }

    func claimCanvasNodeTarget(_ target: PendingWorkspaceCanvasNodeTarget) {
        let correlation: WorkspaceCanvasNodeLaunchCorrelation?
        if let slot = primaryCanvasResolutionSlot,
           slot.attempt.focus.workspaceID == target.workspaceID {
            correlation = .accepted(operationID: slot.operationID)
        } else {
            correlation = nil
        }
        canvasNodeOpenFlow = .pending(target: target, correlation: correlation)
        canvasNodeOpenRecoverableError = nil
    }

    @discardableResult
    func clearCanvasNodeTarget(_ target: PendingWorkspaceCanvasNodeTarget) -> Bool {
        guard activeCanvasNodeTarget == target else {
            return false
        }
        canvasNodeOpenFlow = .idle
        return true
    }

    func clearCanvasNodeOpenFlow() {
        canvasNodeOpenFlow = .idle
        canvasNodeOpenRecoverableError = nil
        resetCanvasNodeRequestAllocator()
    }

    func prepareCanvasNodeFlowForFocus(workspaceID: String) {
        if let target = activeCanvasNodeTarget,
           target.workspaceID == workspaceID {
            canvasNodeOpenFlow = .pending(target: target, correlation: nil)
        } else {
            canvasNodeOpenFlow = .idle
        }
        canvasNodeOpenRecoverableError = nil
        resetCanvasNodeRequestAllocator()
    }

    func prepareCanvasNodeFlowForSameWorkspaceRotation(
        preservingPendingCorrelation: Bool = false
    ) {
        if let target = activeCanvasNodeTarget {
            let correlation = preservingPendingCorrelation
                ? canvasNodeLaunchCorrelation
                : nil
            canvasNodeOpenFlow = .pending(
                target: target,
                correlation: correlation
            )
        }
        resetCanvasNodeRequestAllocator()
    }

    @discardableResult
    func beginCanvasNodeTargetLaunch(
        _ target: PendingWorkspaceCanvasNodeTarget,
        focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        launchID: UUID = UUID()
    ) -> Bool {
        guard accepts(focus),
              focus.workspaceID == target.workspaceID,
              case let .pending(currentTarget, correlation) = canvasNodeOpenFlow,
              currentTarget == target,
              correlation == nil
        else {
            return false
        }
        canvasNodeOpenFlow = .pending(
            target: target,
            correlation: .starting(
                launchID: launchID,
                focus: focus,
                fingerprint: fingerprint
            )
        )
        canvasNodeOpenRecoverableError = nil
        return true
    }

    @discardableResult
    func acceptCanvasNodeTargetLaunch(
        _ target: PendingWorkspaceCanvasNodeTarget,
        launchID: UUID,
        operationID: UUID
    ) -> Bool {
        guard case let .pending(currentTarget, correlation) = canvasNodeOpenFlow,
              currentTarget == target,
              case let .starting(currentLaunchID, focus, _) = correlation,
              currentLaunchID == launchID,
              accepts(focus)
        else {
            return false
        }
        canvasNodeOpenFlow = .pending(
            target: target,
            correlation: .accepted(operationID: operationID)
        )
        return true
    }

    @discardableResult
    func failCanvasNodeTargetLaunch(
        _ target: PendingWorkspaceCanvasNodeTarget,
        launchID: UUID,
        message: String
    ) -> Bool {
        guard case let .pending(currentTarget, correlation) = canvasNodeOpenFlow,
              currentTarget == target,
              case let .starting(currentLaunchID, _, _) = correlation,
              currentLaunchID == launchID
        else {
            return false
        }
        canvasNodeOpenFlow = .pending(target: target, correlation: nil)
        canvasNodeOpenRecoverableError =
            ValidationDisplayTextSanitizer.safeDiagnosticMessage(message)
        return true
    }

    @discardableResult
    func reassociateCanvasNodeTarget(
        _ target: PendingWorkspaceCanvasNodeTarget,
        with operationID: UUID
    ) -> Bool {
        guard case let .pending(currentTarget, _) = canvasNodeOpenFlow,
              currentTarget == target
        else {
            return false
        }
        canvasNodeOpenFlow = .pending(
            target: target,
            correlation: .accepted(operationID: operationID)
        )
        return true
    }

    @discardableResult
    func handoffCanvasNodeTargetOperation(
        from oldOperationID: UUID,
        to newOperationID: UUID,
        target: PendingWorkspaceCanvasNodeTarget
    ) -> Bool {
        guard case let .pending(currentTarget, correlation) = canvasNodeOpenFlow,
              currentTarget == target,
              correlation == .accepted(operationID: oldOperationID)
        else {
            return false
        }
        canvasNodeOpenFlow = .pending(
            target: target,
            correlation: .accepted(operationID: newOperationID)
        )
        return true
    }

    func observeCanvasNodeTargetCancellation(
        _ target: PendingWorkspaceCanvasNodeTarget,
        operationID: UUID
    ) {
        guard activeCanvasNodeTarget == target,
              canvasNodeLaunchCorrelation == .accepted(operationID: operationID)
        else {
            return
        }
    }

    @discardableResult
    func resolveCanvasNodeTarget(
        _ target: PendingWorkspaceCanvasNodeTarget,
        operationID: UUID,
        recoverableError message: String
    ) -> Bool {
        guard activeCanvasNodeTarget == target,
              canvasNodeLaunchCorrelation == .accepted(operationID: operationID)
        else {
            return false
        }
        canvasNodeOpenFlow = .idle
        canvasNodeOpenRecoverableError =
            ValidationDisplayTextSanitizer.safeDiagnosticMessage(message)
        return true
    }

    @discardableResult
    func resolveCanvasNodeTarget(
        _ target: PendingWorkspaceCanvasNodeTarget,
        operationID: UUID,
        resolution: WorkspacePrimaryCanvasResolution,
        provisioningIsActive: Bool = false
    ) -> Bool {
        guard activeCanvasNodeTarget == target,
              canvasNodeLaunchCorrelation == .accepted(operationID: operationID)
        else {
            return false
        }
        switch resolution {
        case let .unique(canvasID) where canvasID == target.canvasID:
            canvasNodeOpenFlow = .pending(target: target, correlation: nil)
            return true
        case .missing where provisioningIsActive:
            return false
        case .missing, .duplicate, .unique:
            canvasNodeOpenFlow = .idle
            return true
        }
    }

    func handleCanvasNodePrimaryCanvasOutcome(
        _ outcome: WorkspacePrimaryCanvasTerminalOutcome
    ) {
        guard let target = activeCanvasNodeTarget else {
            return
        }
        switch outcome.kind {
        case let .resolution(resolution):
            _ = resolveCanvasNodeTarget(
                target,
                operationID: outcome.operationID,
                resolution: resolution
            )
        case let .recoverableError(message):
            _ = resolveCanvasNodeTarget(
                target,
                operationID: outcome.operationID,
                recoverableError: message
            )
        }
    }

    func handleCanvasNodePrimaryCanvasHandoff(
        _ handoff: WorkspacePrimaryCanvasOperationHandoff
    ) {
        guard let target = activeCanvasNodeTarget else {
            return
        }
        _ = handoffCanvasNodeTargetOperation(
            from: handoff.oldOperationID,
            to: handoff.newOperationID,
            target: target
        )
    }

    @discardableResult
    func startPrimaryCanvasResolutionForActiveCanvasNodeTarget(
        for focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback = { _ in },
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback = { _ in }
    ) -> UUID? {
        guard let target = activeCanvasNodeTarget,
              target.workspaceID == focus.workspaceID
        else {
            return startPrimaryCanvasResolution(
                for: focus,
                fingerprint: fingerprint,
                store: store,
                onTerminalOutcome: onTerminalOutcome,
                onOperationHandoff: onOperationHandoff
            )
        }
        if case let .accepted(operationID) = canvasNodeLaunchCorrelation,
           primaryCanvasResolutionSlot?.operationID == operationID {
            return operationID
        }

        let launchID = UUID()
        guard beginCanvasNodeTargetLaunch(
            target,
            focus: focus,
            fingerprint: fingerprint,
            launchID: launchID
        ) else {
            return nil
        }
        let operationID = startPrimaryCanvasResolution(
            for: focus,
            fingerprint: fingerprint,
            store: store
        ) { [weak controller = self] outcome in
            controller?.handleCanvasNodePrimaryCanvasOutcome(outcome)
            onTerminalOutcome(outcome)
        } onOperationHandoff: { [weak controller = self] handoff in
            controller?.handleCanvasNodePrimaryCanvasHandoff(handoff)
            onOperationHandoff(handoff)
        }
        guard let operationID else {
            _ = failCanvasNodeTargetLaunch(
                target,
                launchID: launchID,
                message: "Canvas lookup could not start. Try Again."
            )
            return nil
        }
        _ = acceptCanvasNodeTargetLaunch(
            target,
            launchID: launchID,
            operationID: operationID
        )
        return operationID
    }

    func issueCanvasNodeOpenRequest(
        for target: PendingWorkspaceCanvasNodeTarget,
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    ) -> WorkspaceCanvasNodeOpenRequestIssueResult {
        if case let .issued(currentTarget, request, _) = canvasNodeOpenFlow,
           currentTarget == target,
           request.scopeIdentity == scope {
            return .issued(request)
        }
        guard case let .pending(currentTarget, _) = canvasNodeOpenFlow,
              currentTarget == target,
              boundCanvas == scope,
              scope.focus.workspaceID == target.workspaceID,
              scope.canvasID == target.canvasID
        else {
            return .deferred
        }

        let sequence = nextCanvasNodeOpenRequestSequence
        let (advancedSequence, overflow) = sequence.addingReportingOverflow(1)
        guard !overflow else {
            guard let rotatedFocus = invalidatePrimaryResolution(for: scope.focus) else {
                return .deferred
            }
            return .overflowInvalidated(rotatedFocus)
        }
        let request = WorkspaceCanvasNodeOpenRequest(
            sequence: sequence,
            scopeIdentity: scope,
            nodeID: target.nodeID
        )
        nextCanvasNodeOpenRequestSequence = advancedSequence
        canvasNodeOpenFlow = .issued(
            target: target,
            request: request,
            evidence: .ready(
                scope: scope,
                nodeObservationFingerprint: nodeObservationFingerprint
            )
        )
        return .issued(request)
    }

    func decideCanvasNodeOpenRequest(
        _ request: WorkspaceCanvasNodeOpenRequest,
        readiness: WorkspaceCanvasNodeReadiness
    ) -> WorkspaceCanvasNodeOpenRequestDecision {
        guard request.scopeIdentity == boundCanvas else {
            return .rejectAndConsume
        }
        guard case let .issued(_, currentRequest, _) = canvasNodeOpenFlow,
              currentRequest == request,
              lastConsumedCanvasNodeOpenRequestSequence != request.sequence
        else {
            return .rejectAndConsume
        }
        switch readiness {
        case .dataNotReady:
            return .defer
        case .definitelyAbsentOrCrossCanvas:
            consumeCanvasNodeOpenRequest(request)
            return .rejectAndConsume
        case .readyOwned:
            consumeCanvasNodeOpenRequest(request)
            return .accept
        }
    }

    func markCanvasNodeOpenRequestDirty(
        target: PendingWorkspaceCanvasNodeTarget,
        request: WorkspaceCanvasNodeOpenRequest,
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    ) -> Bool {
        guard case let .issued(currentTarget, currentRequest, _) = canvasNodeOpenFlow,
              currentTarget == target,
              currentRequest == request,
              request.scopeIdentity == scope,
              boundCanvas == scope
        else {
            return false
        }
        canvasNodeOpenFlow = .issued(
            target: target,
            request: request,
            evidence: .dirty(
                scope: scope,
                nodeObservationFingerprint: nodeObservationFingerprint
            )
        )
        return true
    }

    func installCanvasNodeOpenRequestReadyEvidence(
        target: PendingWorkspaceCanvasNodeTarget,
        request: WorkspaceCanvasNodeOpenRequest,
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    ) -> Bool {
        guard case let .issued(currentTarget, currentRequest, evidence) = canvasNodeOpenFlow,
              currentTarget == target,
              currentRequest == request,
              evidence == .dirty(
                  scope: scope,
                  nodeObservationFingerprint: nodeObservationFingerprint
              ),
              boundCanvas == scope
        else {
            return false
        }
        canvasNodeOpenFlow = .issued(
            target: target,
            request: request,
            evidence: .ready(
                scope: scope,
                nodeObservationFingerprint: nodeObservationFingerprint
            )
        )
        return true
    }

    func consumeConfirmedAbsentCanvasNodeTarget(
        target: PendingWorkspaceCanvasNodeTarget,
        request: WorkspaceCanvasNodeOpenRequest,
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String
    ) -> Bool {
        guard case let .issued(currentTarget, currentRequest, evidence) = canvasNodeOpenFlow,
              currentTarget == target,
              currentRequest == request,
              evidence == .dirty(
                  scope: scope,
                  nodeObservationFingerprint: nodeObservationFingerprint
              ),
              boundCanvas == scope
        else {
            return false
        }
        consumeCanvasNodeOpenRequest(request)
        return true
    }

    func seedNextCanvasNodeOpenRequestSequenceForTesting(_ sequence: UInt64) {
        nextCanvasNodeOpenRequestSequence = sequence
    }

    func makeCanvasNodeOpenRequestForTesting(
        sequence: UInt64,
        scope: WorkspaceCanvasScopeIdentity,
        nodeID: String
    ) -> WorkspaceCanvasNodeOpenRequest {
        WorkspaceCanvasNodeOpenRequest(
            sequence: sequence,
            scopeIdentity: scope,
            nodeID: nodeID
        )
    }

    private func consumeCanvasNodeOpenRequest(
        _ request: WorkspaceCanvasNodeOpenRequest
    ) {
        lastConsumedCanvasNodeOpenRequestSequence = request.sequence
        canvasNodeOpenFlow = .idle
    }

    private func resetCanvasNodeRequestAllocator() {
        nextCanvasNodeOpenRequestSequence = 1
        lastConsumedCanvasNodeOpenRequestSequence = nil
    }
}
