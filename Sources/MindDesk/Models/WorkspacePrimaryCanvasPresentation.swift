import Foundation
import MindDeskCore

struct WorkspacePrimaryCanvasSceneObservation: Equatable, Sendable {
    let workspaceID: String?
    let fingerprint: String?
}

struct WorkspacePrimaryCanvasQueryRecord: Equatable, Sendable {
    let id: String
    let workspaceID: String
}

enum WorkspacePrimaryCanvasAvailability: Equatable, Sendable {
    case checking
    case preparing
    case ready(canvasID: String)
    case missing
    case duplicate
    case recoverableError(message: String)
    case unavailable
}

enum WorkspacePrimaryCanvasTerminalOutcomeKind: Equatable, Sendable {
    case resolution(WorkspacePrimaryCanvasResolution)
    case recoverableError(message: String)
}

struct WorkspacePrimaryCanvasTerminalOutcome: Equatable, Sendable {
    let operationID: Foundation.UUID
    let attempt: WorkspacePrimaryCanvasResolutionAttempt
    let kind: WorkspacePrimaryCanvasTerminalOutcomeKind
}

struct WorkspacePrimaryCanvasOperationHandoff: Equatable, Sendable {
    let oldOperationID: Foundation.UUID
    let newOperationID: Foundation.UUID
    let newAttempt: WorkspacePrimaryCanvasResolutionAttempt
}

enum WorkspacePrimaryCanvasPresentation {
    static let missingTitle = "Canvas isn't available yet."
    static let missingMessage =
        "MindDesk could not make a Canvas available for this workspace. Tasks, resources, snippets, and Overview remain available."
    static let duplicateTitle = "Canvas editing is paused."
    static let duplicateMessage =
        "MindDesk could not identify one safe Canvas for this workspace. Canvas editing is paused to protect your data. Tasks, resources, snippets, and Overview remain available. No Canvas was deleted."
    static let unavailableTitle = "Canvas is unavailable."
    static let unavailableMessage =
        "Canvas editing is unavailable right now. Tasks, resources, snippets, and Overview remain available."
    static let blocksNonCanvasSurfaces = false

    static func sanitizedErrorMessage(_ error: Error) -> String {
        ValidationDisplayTextSanitizer.safeDiagnosticMessage(
            error.localizedDescription
        )
    }

    static func renderableCanvasID(
        boundCanvas: WorkspaceCanvasScopeIdentity?,
        canvases: [WorkspacePrimaryCanvasQueryRecord]
    ) -> String? {
        guard let boundCanvas else {
            return nil
        }
        let exactMatches = canvases.filter {
            $0.id == boundCanvas.canvasID
                && $0.workspaceID == boundCanvas.focus.workspaceID
        }
        guard exactMatches.count == 1 else {
            return nil
        }
        return exactMatches[0].id
    }

    @MainActor
    static func availability(
        controller: WorkspaceWindowScopeController,
        canvases: [WorkspacePrimaryCanvasQueryRecord]
    ) -> WorkspacePrimaryCanvasAvailability {
        if let slot = controller.primaryCanvasResolutionSlot,
           controller.accepts(slot.attempt.focus) {
            switch slot.attempt.phase {
            case .initialLookup:
                return .checking
            case .preInsertRecheck, .postSaveRecheck:
                return .preparing
            }
        }

        if let canvasID = renderableCanvasID(
            boundCanvas: controller.boundCanvas,
            canvases: canvases
        ) {
            return .ready(canvasID: canvasID)
        }

        if let message = controller.primaryCanvasRecoverableError {
            return .recoverableError(message: message)
        }

        switch controller.primaryResolution {
        case .missing:
            return .missing
        case .duplicate:
            return .duplicate
        case .unique, nil:
            return .unavailable
        }
    }
}
