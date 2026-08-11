import Foundation
import MindDeskCore

enum WorkspacePrimaryCanvasFingerprint {
    static func make(canvasIDs: [String]) -> String {
        let sortedCanvasIDs = canvasIDs.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        var payload = Data()
        var recordCount = UInt64(sortedCanvasIDs.count).bigEndian
        withUnsafeBytes(of: &recordCount) { recordCountBytes in
            payload.append(contentsOf: recordCountBytes)
        }

        for canvasID in sortedCanvasIDs {
            let canvasIDBytes = Array(canvasID.utf8)
            var byteCount = UInt64(canvasIDBytes.count).bigEndian
            withUnsafeBytes(of: &byteCount) { byteCountBytes in
                payload.append(contentsOf: byteCountBytes)
            }
            payload.append(contentsOf: canvasIDBytes)
        }

        return payload.base64EncodedString()
    }
}

enum WorkspacePrimaryCanvasResolutionPhase: Equatable, Sendable {
    case initialLookup
    case preInsertRecheck
    case postSaveRecheck
}

struct WorkspacePrimaryCanvasResolutionAttempt: Equatable, Sendable {
    let requestID: Foundation.UUID
    let focus: WorkspaceFocusScopeIdentity
    let fingerprint: String
    let phase: WorkspacePrimaryCanvasResolutionPhase
}

@MainActor
struct WorkspacePrimaryCanvasResolutionSlot {
    var attempt: WorkspacePrimaryCanvasResolutionAttempt
    let operationID: Foundation.UUID
    let task: Task<Void, Never>
    var cancellationObserved: Bool
}

typealias WorkspacePrimaryCanvasResolutionWorker =
    @MainActor @Sendable (
        WorkspacePrimaryCanvasResolutionAttempt,
        Foundation.UUID
    ) async -> Void

typealias WorkspacePrimaryCanvasCancellationRegistrar =
    @MainActor (
        WorkspaceScopeOperationIdentity,
        @escaping @MainActor @Sendable () -> Void
    ) -> Foundation.UUID?

typealias WorkspacePrimaryCanvasTerminalCallback =
    @MainActor @Sendable (WorkspacePrimaryCanvasTerminalOutcome) -> Void

typealias WorkspacePrimaryCanvasHandoffCallback =
    @MainActor @Sendable (WorkspacePrimaryCanvasOperationHandoff) -> Void

@MainActor
private final class WorkspacePrimaryCanvasStartGate {
    let stream: AsyncStream<Void>
    private var continuation: AsyncStream<Void>.Continuation?

    init() {
        let pair = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        stream = pair.stream
        continuation = pair.continuation
    }

    func open() {
        continuation?.yield(())
        continuation?.finish()
        continuation = nil
    }

    func finish() {
        continuation?.finish()
        continuation = nil
    }
}

@MainActor
private final class WorkspacePrimaryCanvasLaunchState {
    var operationID: Foundation.UUID?
}

@MainActor
private final class WorkspacePrimaryCanvasTaskBox {
    var task: Task<Void, Never>?
}

@MainActor
extension WorkspaceWindowScopeController {
    @discardableResult
    func startPrimaryCanvasResolution(
        for focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback = { _ in },
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback = { _ in }
    ) -> Foundation.UUID? {
        startPrimaryCanvasResolution(
            for: focus,
            fingerprint: fingerprint
        ) { [weak controller = self] attempt, operationID in
            controller?.runInitialPrimaryCanvasLookup(
                attempt: attempt,
                operationID: operationID,
                store: store,
                onTerminalOutcome: onTerminalOutcome,
                onOperationHandoff: onOperationHandoff
            )
        }
    }

    @discardableResult
    func invalidatePrimaryCanvasResolutionAndStart(
        for focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback = { _ in },
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback = { _ in }
    ) -> Foundation.UUID? {
        guard let freshFocus = invalidatePrimaryResolution(for: focus) else {
            return nil
        }
        return startPrimaryCanvasResolution(
            for: freshFocus,
            fingerprint: fingerprint,
            store: store,
            onTerminalOutcome: onTerminalOutcome,
            onOperationHandoff: onOperationHandoff
        )
    }

    @discardableResult
    func retryPrimaryCanvasResolution(
        fingerprint: String,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback = { _ in },
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback = { _ in }
    ) -> Foundation.UUID? {
        guard primaryResolution == .missing,
              primaryCanvasResolutionSlot == nil,
              let focus = pendingFocus
        else {
            return nil
        }
        return invalidatePrimaryCanvasResolutionAndStart(
            for: focus,
            fingerprint: fingerprint,
            store: store,
            onTerminalOutcome: onTerminalOutcome,
            onOperationHandoff: onOperationHandoff
        )
    }

    @discardableResult
    func startPrimaryCanvasResolution(
        for focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        phase: WorkspacePrimaryCanvasResolutionPhase = .initialLookup,
        registerCancellation: WorkspacePrimaryCanvasCancellationRegistrar? = nil,
        worker: @escaping WorkspacePrimaryCanvasResolutionWorker
    ) -> Foundation.UUID? {
        beginPrimaryCanvasResolution(for: focus)
        let attempt = WorkspacePrimaryCanvasResolutionAttempt(
            requestID: Foundation.UUID(),
            focus: focus,
            fingerprint: fingerprint,
            phase: phase
        )
        let gate = WorkspacePrimaryCanvasStartGate()
        let launchState = WorkspacePrimaryCanvasLaunchState()
        let taskBox = WorkspacePrimaryCanvasTaskBox()
        let controller = self
        let task = Task { @MainActor [weak controller] in
            var iterator = gate.stream.makeAsyncIterator()
            guard await iterator.next() != nil else {
                return
            }
            guard !Task.isCancelled, controller != nil else {
                return
            }
            guard let operationID = launchState.operationID else {
                return
            }
            await worker(attempt, operationID)
        }
        taskBox.task = task

        let registrar: WorkspacePrimaryCanvasCancellationRegistrar =
            registerCancellation ?? { [weak controller] scope, cancel in
                controller?.registerCancellation(for: scope, cancel: cancel)
            }
        let operationID = registrar(.focus(focus)) {
            [weak controller, weak taskBox] in
            taskBox?.task?.cancel()
            gate.finish()
            guard let operationID = launchState.operationID else {
                return
            }
            controller?.cancelPrimaryCanvasResolutionSlot(
                operationID: operationID
            )
        }
        guard let operationID else {
            task.cancel()
            gate.finish()
            return nil
        }
        launchState.operationID = operationID

        let slot = WorkspacePrimaryCanvasResolutionSlot(
            attempt: attempt,
            operationID: operationID,
            task: task,
            cancellationObserved: false
        )
        let displacedSlot = installPrimaryCanvasResolutionSlot(slot)
        gate.open()

        if let displacedSlot {
            displacedSlot.task.cancel()
            _ = complete(
                operationID: displacedSlot.operationID,
                for: .focus(displacedSlot.attempt.focus)
            )
        }
        return operationID
    }

    @discardableResult
    func invalidatePrimaryCanvasResolutionAndStart(
        for focus: WorkspaceFocusScopeIdentity,
        fingerprint: String,
        worker: @escaping WorkspacePrimaryCanvasResolutionWorker
    ) -> Foundation.UUID? {
        guard let freshFocus = invalidatePrimaryResolution(for: focus) else {
            return nil
        }
        return startPrimaryCanvasResolution(
            for: freshFocus,
            fingerprint: fingerprint,
            worker: worker
        )
    }

    func finishPrimaryCanvasResolution(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        resolution: WorkspacePrimaryCanvasResolution
    ) -> WorkspaceCanvasBindingResult? {
        guard resolutionSlotMatches(
            attempt: attempt,
            operationID: operationID
        ) else {
            return nil
        }
        guard accepts(attempt.focus) else {
            return nil
        }
        guard complete(
            operationID: operationID,
            for: .focus(attempt.focus)
        ) else {
            return nil
        }
        guard clearPrimaryCanvasResolutionSlot(
            attempt: attempt,
            operationID: operationID
        ) else {
            return nil
        }
        return bind(resolution, for: attempt.focus)
    }

    func handoffPrimaryCanvasResolution(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        to phase: WorkspacePrimaryCanvasResolutionPhase
    ) -> WorkspacePrimaryCanvasResolutionAttempt? {
        guard resolutionSlotMatches(
            attempt: attempt,
            operationID: operationID
        ) else {
            return nil
        }
        guard accepts(attempt.focus) else {
            return nil
        }
        let nextAttempt = WorkspacePrimaryCanvasResolutionAttempt(
            requestID: Foundation.UUID(),
            focus: attempt.focus,
            fingerprint: attempt.fingerprint,
            phase: phase
        )
        guard replacePrimaryCanvasResolutionAttempt(
            nextAttempt,
            operationID: operationID
        ) else {
            return nil
        }
        return nextAttempt
    }

    private func runInitialPrimaryCanvasLookup(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback,
        onOperationHandoff: @escaping WorkspacePrimaryCanvasHandoffCallback
    ) {
        guard attempt.phase == .initialLookup,
              !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: attempt,
                operationID: operationID
              )
        else {
            return
        }

        let scopedResolution: WorkspacePrimaryCanvasScopedResolution
        do {
            scopedResolution = try store.lookup(
                workspaceID: attempt.focus.workspaceID,
                phase: .initialLookup
            )
        } catch {
            finishPrimaryCanvasResolutionFailure(
                error,
                attempt: attempt,
                operationID: operationID,
                onTerminalOutcome: onTerminalOutcome
            )
            return
        }

        guard !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: attempt,
                operationID: operationID
              ),
              let result = finishPrimaryCanvasResolution(
                attempt: attempt,
                operationID: operationID,
                resolution: scopedResolution.resolution
              )
        else {
            return
        }
        guard case let .unbound(returnedFocus, .missing) = result else {
            onTerminalOutcome(
                WorkspacePrimaryCanvasTerminalOutcome(
                    operationID: operationID,
                    attempt: attempt,
                    kind: .resolution(scopedResolution.resolution)
                )
            )
            return
        }

        let provisioningOperationID = startPrimaryCanvasResolution(
            for: returnedFocus,
            fingerprint: attempt.fingerprint,
            phase: .preInsertRecheck
        ) { [weak controller = self] provisioningAttempt, provisioningOperationID in
            controller?.runPrimaryCanvasProvisioning(
                attempt: provisioningAttempt,
                operationID: provisioningOperationID,
                store: store,
                onTerminalOutcome: onTerminalOutcome
            )
        }
        if let provisioningOperationID,
           let newAttempt = primaryCanvasResolutionSlot?.attempt,
           primaryCanvasResolutionSlot?.operationID == provisioningOperationID {
            onOperationHandoff(
                WorkspacePrimaryCanvasOperationHandoff(
                    oldOperationID: operationID,
                    newOperationID: provisioningOperationID,
                    newAttempt: newAttempt
                )
            )
        } else if primaryCanvasResolutionSlot == nil,
                  pendingFocus == returnedFocus,
                  primaryResolution == .missing {
            onTerminalOutcome(
                WorkspacePrimaryCanvasTerminalOutcome(
                    operationID: operationID,
                    attempt: attempt,
                    kind: .resolution(.missing)
                )
            )
        }
    }

    private func runPrimaryCanvasProvisioning(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        store: WorkspacePrimaryCanvasStore,
        onTerminalOutcome: @escaping WorkspacePrimaryCanvasTerminalCallback
    ) {
        guard attempt.phase == .preInsertRecheck,
              !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: attempt,
                operationID: operationID
              )
        else {
            return
        }

        let scopedResolution: WorkspacePrimaryCanvasScopedResolution
        do {
            scopedResolution = try store.beginProvisioning(
                workspaceID: attempt.focus.workspaceID
            )
        } catch {
            finishPrimaryCanvasResolutionFailure(
                error,
                attempt: attempt,
                operationID: operationID,
                onTerminalOutcome: onTerminalOutcome
            )
            return
        }
        var provisioningContextWasDiscarded = false
        defer {
            if !provisioningContextWasDiscarded {
                store.discardProvisioning(contextID: scopedResolution.contextID)
            }
        }

        guard !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: attempt,
                operationID: operationID
              )
        else {
            if Task.isCancelled {
                store.discardProvisioning(contextID: scopedResolution.contextID)
                provisioningContextWasDiscarded = true
                _ = finishPrimaryCanvasResolutionCancellation(
                    attempt: attempt,
                    operationID: operationID
                )
            }
            return
        }

        guard scopedResolution.resolution == .missing else {
            store.discardProvisioning(contextID: scopedResolution.contextID)
            provisioningContextWasDiscarded = true
            guard finishPrimaryCanvasResolution(
                attempt: attempt,
                operationID: operationID,
                resolution: scopedResolution.resolution
            ) != nil else {
                return
            }
            onTerminalOutcome(
                WorkspacePrimaryCanvasTerminalOutcome(
                    operationID: operationID,
                    attempt: attempt,
                    kind: .resolution(scopedResolution.resolution)
                )
            )
            return
        }

        _ = store.saveProvisionedCanvas(
            contextID: scopedResolution.contextID,
            workspaceID: attempt.focus.workspaceID
        )
        store.discardProvisioning(contextID: scopedResolution.contextID)
        provisioningContextWasDiscarded = true

        guard !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: attempt,
                operationID: operationID
              ),
              let postSaveAttempt = handoffPrimaryCanvasResolution(
                attempt: attempt,
                operationID: operationID,
                to: .postSaveRecheck
              )
        else {
            if Task.isCancelled {
                _ = finishPrimaryCanvasResolutionCancellation(
                    attempt: attempt,
                    operationID: operationID
                )
            }
            return
        }

        let postSaveResolution: WorkspacePrimaryCanvasScopedResolution
        do {
            postSaveResolution = try store.lookup(
                workspaceID: postSaveAttempt.focus.workspaceID,
                phase: .postSaveRecheck
            )
        } catch {
            finishPrimaryCanvasResolutionFailure(
                error,
                attempt: postSaveAttempt,
                operationID: operationID,
                onTerminalOutcome: onTerminalOutcome
            )
            return
        }

        guard !Task.isCancelled,
              primaryCanvasAttemptIsCurrent(
                attempt: postSaveAttempt,
                operationID: operationID
              )
        else {
            if Task.isCancelled {
                _ = finishPrimaryCanvasResolutionCancellation(
                    attempt: postSaveAttempt,
                    operationID: operationID
                )
            }
            return
        }
        guard finishPrimaryCanvasResolution(
            attempt: postSaveAttempt,
            operationID: operationID,
            resolution: postSaveResolution.resolution
        ) != nil else {
            return
        }
        onTerminalOutcome(
            WorkspacePrimaryCanvasTerminalOutcome(
                operationID: operationID,
                attempt: postSaveAttempt,
                kind: .resolution(postSaveResolution.resolution)
            )
        )
    }

    private func finishPrimaryCanvasResolutionFailure(
        _ error: Error,
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        onTerminalOutcome: WorkspacePrimaryCanvasTerminalCallback
    ) {
        if error is CancellationError || Task.isCancelled {
            _ = finishPrimaryCanvasResolutionCancellation(
                attempt: attempt,
                operationID: operationID
            )
            return
        }
        let message = WorkspacePrimaryCanvasPresentation.sanitizedErrorMessage(error)
        guard finishPrimaryCanvasResolutionError(
            attempt: attempt,
            operationID: operationID,
            message: message
        ) else {
            return
        }
        onTerminalOutcome(
            WorkspacePrimaryCanvasTerminalOutcome(
                operationID: operationID,
                attempt: attempt,
                kind: .recoverableError(message: message)
            )
        )
    }

    private func primaryCanvasAttemptIsCurrent(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID
    ) -> Bool {
        resolutionSlotMatches(attempt: attempt, operationID: operationID)
            && accepts(attempt.focus)
    }
}
