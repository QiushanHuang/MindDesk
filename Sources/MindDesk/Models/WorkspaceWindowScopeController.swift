import Combine
import Foundation
import MindDeskCore

struct WorkspaceFocusRevision: Hashable, Sendable {
    fileprivate let rawValue: Foundation.UUID

    fileprivate init(rawValue: Foundation.UUID) {
        self.rawValue = rawValue
    }
}

struct WorkspaceFocusScopeIdentity: Hashable, Sendable {
    let windowSessionID: Foundation.UUID
    let workspaceID: String
    let focusRevision: WorkspaceFocusRevision

    fileprivate init(
        windowSessionID: Foundation.UUID,
        workspaceID: String,
        focusRevision: WorkspaceFocusRevision
    ) {
        self.windowSessionID = windowSessionID
        self.workspaceID = workspaceID
        self.focusRevision = focusRevision
    }
}

struct WorkspaceCanvasScopeIdentity: Hashable, Sendable {
    let focus: WorkspaceFocusScopeIdentity
    let canvasID: String

    fileprivate init(focus: WorkspaceFocusScopeIdentity, canvasID: String) {
        self.focus = focus
        self.canvasID = canvasID
    }
}

enum WorkspaceScopeOperationIdentity: Hashable, Sendable {
    case focus(WorkspaceFocusScopeIdentity)
    case canvas(WorkspaceCanvasScopeIdentity)
}

enum WorkspaceCanvasBindingResult: Equatable, Sendable {
    case stale
    case unbound(
        focus: WorkspaceFocusScopeIdentity,
        resolution: WorkspacePrimaryCanvasResolution
    )
    case bound(WorkspaceCanvasScopeIdentity)
}

@MainActor
final class WorkspaceWindowScopeController: ObservableObject {
    let windowSessionID: Foundation.UUID
    @Published private(set) var pendingFocus: WorkspaceFocusScopeIdentity?
    @Published private(set) var boundCanvas: WorkspaceCanvasScopeIdentity?
    @Published private(set) var primaryResolution: WorkspacePrimaryCanvasResolution?
    @Published private(set) var primaryCanvasRecoverableError: String?
    @Published private(set) var primaryCanvasResolutionSlot: WorkspacePrimaryCanvasResolutionSlot?

    private struct CancellationRegistration {
        let scope: WorkspaceScopeOperationIdentity
        let cancel: @MainActor () -> Void
    }

    private var cancellationRegistrations: [
        Foundation.UUID: CancellationRegistration
    ] = [:]

    init(windowSessionID: Foundation.UUID = Foundation.UUID()) {
        self.windowSessionID = windowSessionID
    }

    @discardableResult
    func focus(workspaceID: String) -> WorkspaceFocusScopeIdentity {
        if let pendingFocus, pendingFocus.workspaceID == workspaceID {
            return pendingFocus
        }

        let detachedRegistrations = detachCancellationRegistrations()
        let focus = WorkspaceFocusScopeIdentity(
            windowSessionID: windowSessionID,
            workspaceID: workspaceID,
            focusRevision: WorkspaceFocusRevision(rawValue: Foundation.UUID())
        )
        primaryResolution = nil
        primaryCanvasRecoverableError = nil
        boundCanvas = nil
        pendingFocus = focus
        cancel(detachedRegistrations)
        return focus
    }

    @discardableResult
    func invalidatePrimaryResolution(
        for focus: WorkspaceFocusScopeIdentity
    ) -> WorkspaceFocusScopeIdentity? {
        guard pendingFocus == focus else {
            return nil
        }

        let detachedRegistrations = detachCancellationRegistrations()
        let rotatedFocus = WorkspaceFocusScopeIdentity(
            windowSessionID: windowSessionID,
            workspaceID: focus.workspaceID,
            focusRevision: WorkspaceFocusRevision(rawValue: Foundation.UUID())
        )
        boundCanvas = nil
        primaryResolution = nil
        primaryCanvasRecoverableError = nil
        pendingFocus = rotatedFocus
        cancel(detachedRegistrations)
        return rotatedFocus
    }

    @discardableResult
    func bind(
        _ resolution: WorkspacePrimaryCanvasResolution,
        for focus: WorkspaceFocusScopeIdentity
    ) -> WorkspaceCanvasBindingResult {
        guard pendingFocus == focus else {
            return .stale
        }
        primaryCanvasRecoverableError = nil

        if primaryResolution == resolution {
            switch resolution {
            case let .unique(canvasID):
                guard
                    let boundCanvas,
                    boundCanvas.focus == focus,
                    boundCanvas.canvasID == canvasID
                else {
                    return .stale
                }
                return .bound(boundCanvas)
            case .missing, .duplicate:
                guard boundCanvas == nil else {
                    return .stale
                }
                return .unbound(focus: focus, resolution: resolution)
            }
        }

        let bindingFocus: WorkspaceFocusScopeIdentity
        let detachedRegistrations: [CancellationRegistration]
        if primaryResolution == nil {
            bindingFocus = focus
            detachedRegistrations = []
        } else {
            detachedRegistrations = detachCancellationRegistrations()
            let rotatedFocus = WorkspaceFocusScopeIdentity(
                windowSessionID: focus.windowSessionID,
                workspaceID: focus.workspaceID,
                focusRevision: WorkspaceFocusRevision(rawValue: Foundation.UUID())
            )
            boundCanvas = nil
            primaryResolution = nil
            pendingFocus = rotatedFocus
            bindingFocus = rotatedFocus
        }

        primaryResolution = resolution

        let bindingResult: WorkspaceCanvasBindingResult
        switch resolution {
        case let .unique(canvasID):
            let identity = WorkspaceCanvasScopeIdentity(
                focus: bindingFocus,
                canvasID: canvasID
            )
            boundCanvas = identity
            bindingResult = .bound(identity)
        case .missing, .duplicate:
            boundCanvas = nil
            bindingResult = .unbound(
                focus: bindingFocus,
                resolution: resolution
            )
        }
        cancel(detachedRegistrations)
        return bindingResult
    }

    func accepts(_ focus: WorkspaceFocusScopeIdentity) -> Bool {
        pendingFocus == focus
    }

    func accepts(_ canvas: WorkspaceCanvasScopeIdentity) -> Bool {
        pendingFocus == canvas.focus && boundCanvas == canvas
    }

    @discardableResult
    func registerCancellation(
        for scope: WorkspaceScopeOperationIdentity,
        cancel: @escaping @MainActor () -> Void
    ) -> Foundation.UUID? {
        guard accepts(scope) else {
            cancel()
            return nil
        }

        var operationID = Foundation.UUID()
        while cancellationRegistrations[operationID] != nil {
            operationID = Foundation.UUID()
        }
        cancellationRegistrations[operationID] = CancellationRegistration(
            scope: scope,
            cancel: cancel
        )
        return operationID
    }

    func complete(
        operationID: Foundation.UUID,
        for scope: WorkspaceScopeOperationIdentity
    ) -> Bool {
        guard cancellationRegistrations[operationID]?.scope == scope else {
            return false
        }
        cancellationRegistrations.removeValue(forKey: operationID)
        return true
    }

    func clear() {
        let detachedRegistrations = detachCancellationRegistrations()
        boundCanvas = nil
        primaryResolution = nil
        primaryCanvasRecoverableError = nil
        pendingFocus = nil
        cancel(detachedRegistrations)
    }

    func resolutionSlotMatches(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID
    ) -> Bool {
        primaryCanvasResolutionSlot?.attempt == attempt
            && primaryCanvasResolutionSlot?.operationID == operationID
    }

    func installPrimaryCanvasResolutionSlot(
        _ slot: WorkspacePrimaryCanvasResolutionSlot
    ) -> WorkspacePrimaryCanvasResolutionSlot? {
        let displacedSlot = primaryCanvasResolutionSlot
        primaryCanvasResolutionSlot = slot
        return displacedSlot
    }

    func beginPrimaryCanvasResolution(for focus: WorkspaceFocusScopeIdentity) {
        guard accepts(focus) else {
            return
        }
        primaryCanvasRecoverableError = nil
    }

    func finishPrimaryCanvasResolutionError(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID,
        message: String
    ) -> Bool {
        guard resolutionSlotMatches(
            attempt: attempt,
            operationID: operationID
        ), accepts(attempt.focus) else {
            return false
        }
        guard complete(
            operationID: operationID,
            for: .focus(attempt.focus)
        ) else {
            return false
        }
        guard clearPrimaryCanvasResolutionSlot(
            attempt: attempt,
            operationID: operationID
        ) else {
            return false
        }
        primaryCanvasRecoverableError = message
        return true
    }

    func finishPrimaryCanvasResolutionCancellation(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID
    ) -> Bool {
        guard resolutionSlotMatches(
            attempt: attempt,
            operationID: operationID
        ), accepts(attempt.focus) else {
            return false
        }
        guard complete(
            operationID: operationID,
            for: .focus(attempt.focus)
        ) else {
            return false
        }
        return clearPrimaryCanvasResolutionSlot(
            attempt: attempt,
            operationID: operationID
        )
    }

    func replacePrimaryCanvasResolutionAttempt(
        _ attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID
    ) -> Bool {
        guard var slot = primaryCanvasResolutionSlot,
              slot.operationID == operationID
        else {
            return false
        }
        slot.attempt = attempt
        primaryCanvasResolutionSlot = slot
        return true
    }

    func clearPrimaryCanvasResolutionSlot(
        attempt: WorkspacePrimaryCanvasResolutionAttempt,
        operationID: Foundation.UUID
    ) -> Bool {
        guard resolutionSlotMatches(
            attempt: attempt,
            operationID: operationID
        ) else {
            return false
        }
        primaryCanvasResolutionSlot = nil
        return true
    }

    func cancelPrimaryCanvasResolutionSlot(operationID: Foundation.UUID) {
        guard var slot = primaryCanvasResolutionSlot,
              slot.operationID == operationID
        else {
            return
        }
        slot.cancellationObserved = true
        primaryCanvasResolutionSlot = nil
        slot.task.cancel()
    }

    private func accepts(_ scope: WorkspaceScopeOperationIdentity) -> Bool {
        switch scope {
        case let .focus(focus):
            return accepts(focus)
        case let .canvas(canvas):
            return accepts(canvas)
        }
    }

    private func detachCancellationRegistrations() -> [CancellationRegistration] {
        let detachedRegistrations = Array(cancellationRegistrations.values)
        cancellationRegistrations = [:]
        return detachedRegistrations
    }

    private func cancel(_ registrations: [CancellationRegistration]) {
        for registration in registrations {
            registration.cancel()
        }
    }
}
