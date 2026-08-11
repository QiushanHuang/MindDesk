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

    init(windowSessionID: Foundation.UUID = Foundation.UUID()) {
        self.windowSessionID = windowSessionID
    }

    @discardableResult
    func focus(workspaceID: String) -> WorkspaceFocusScopeIdentity {
        if let pendingFocus, pendingFocus.workspaceID == workspaceID {
            return pendingFocus
        }

        let focus = WorkspaceFocusScopeIdentity(
            windowSessionID: windowSessionID,
            workspaceID: workspaceID,
            focusRevision: WorkspaceFocusRevision(rawValue: Foundation.UUID())
        )
        primaryResolution = nil
        boundCanvas = nil
        pendingFocus = focus
        return focus
    }

    @discardableResult
    func invalidatePrimaryResolution(
        for focus: WorkspaceFocusScopeIdentity
    ) -> WorkspaceFocusScopeIdentity? {
        guard pendingFocus == focus else {
            return nil
        }

        let rotatedFocus = WorkspaceFocusScopeIdentity(
            windowSessionID: windowSessionID,
            workspaceID: focus.workspaceID,
            focusRevision: WorkspaceFocusRevision(rawValue: Foundation.UUID())
        )
        boundCanvas = nil
        primaryResolution = nil
        pendingFocus = rotatedFocus
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
        if primaryResolution == nil {
            bindingFocus = focus
        } else {
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

        switch resolution {
        case let .unique(canvasID):
            let identity = WorkspaceCanvasScopeIdentity(
                focus: bindingFocus,
                canvasID: canvasID
            )
            boundCanvas = identity
            return .bound(identity)
        case .missing, .duplicate:
            boundCanvas = nil
            return .unbound(focus: bindingFocus, resolution: resolution)
        }
    }
}
