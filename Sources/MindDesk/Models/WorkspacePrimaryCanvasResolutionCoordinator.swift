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
        phase: WorkspacePrimaryCanvasResolutionPhase = .initialLookup,
        registerCancellation: WorkspacePrimaryCanvasCancellationRegistrar? = nil,
        worker: @escaping WorkspacePrimaryCanvasResolutionWorker
    ) -> Foundation.UUID? {
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
}
