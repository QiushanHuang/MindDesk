import Foundation
import MindDeskCore
import SwiftData

struct WorkspaceCanvasNodeObservationRecord: Equatable, Sendable {
    let nodeID: String
    let canvasID: String
}

enum WorkspaceCanvasNodeObservationFingerprint {
    static func make(records: [WorkspaceCanvasNodeObservationRecord]) -> String {
        let ordered = records.sorted { left, right in
            let leftNode = Array(left.nodeID.utf8)
            let rightNode = Array(right.nodeID.utf8)
            if leftNode != rightNode {
                return leftNode.lexicographicallyPrecedes(rightNode)
            }
            return left.canvasID.utf8.lexicographicallyPrecedes(right.canvasID.utf8)
        }
        var payload = Data()
        append(UInt64(ordered.count), to: &payload)
        for record in ordered {
            append(record.nodeID, to: &payload)
            append(record.canvasID, to: &payload)
        }
        return payload.base64EncodedString()
    }

    private static func append(_ value: String, to payload: inout Data) {
        let bytes = Data(value.utf8)
        append(UInt64(bytes.count), to: &payload)
        payload.append(bytes)
    }

    private static func append(_ value: UInt64, to payload: inout Data) {
        var encoded = value.bigEndian
        withUnsafeBytes(of: &encoded) { payload.append(contentsOf: $0) }
    }
}

enum WorkspaceCanvasNodeLookup {
    static func canvasDescriptor(
        for scope: WorkspaceCanvasScopeIdentity
    ) -> FetchDescriptor<CanvasModel> {
        let canvasID = scope.canvasID
        let workspaceID = scope.focus.workspaceID
        var descriptor = FetchDescriptor<CanvasModel>(
            predicate: #Predicate { canvas in
                canvas.id == canvasID && canvas.workspaceId == workspaceID
            }
        )
        descriptor.sortBy = [SortDescriptor(\CanvasModel.id, comparator: .lexical)]
        descriptor.fetchLimit = 2
        return descriptor
    }

    static func nodeDescriptor(
        nodeID: String,
        scope: WorkspaceCanvasScopeIdentity
    ) -> FetchDescriptor<CanvasNodeModel> {
        let canvasID = scope.canvasID
        var descriptor = FetchDescriptor<CanvasNodeModel>(
            predicate: #Predicate { node in
                node.id == nodeID && node.canvasId == canvasID
            }
        )
        descriptor.sortBy = [SortDescriptor(\CanvasNodeModel.id, comparator: .lexical)]
        descriptor.fetchLimit = 2
        return descriptor
    }

    @MainActor
    static func resolve(
        nodeID: String,
        scope: WorkspaceCanvasScopeIdentity,
        in context: ModelContext
    ) throws -> WorkspaceCanvasNodeReadiness {
        guard try context.fetch(canvasDescriptor(for: scope)).count == 1 else {
            return .definitelyAbsentOrCrossCanvas
        }
        guard try context.fetch(nodeDescriptor(nodeID: nodeID, scope: scope)).count == 1 else {
            return .definitelyAbsentOrCrossCanvas
        }
        return .readyOwned
    }
}

@MainActor
struct WorkspaceCanvasNodeOwnershipReader {
    typealias Resolve = @MainActor (
        _ nodeID: String,
        _ scope: WorkspaceCanvasScopeIdentity
    ) throws -> WorkspaceCanvasNodeReadiness

    private let implementation: Resolve

    init(_ resolve: @escaping Resolve) {
        implementation = resolve
    }

    func resolve(
        nodeID: String,
        scope: WorkspaceCanvasScopeIdentity
    ) throws -> WorkspaceCanvasNodeReadiness {
        try implementation(nodeID, scope)
    }

    static func live(container: ModelContainer) -> WorkspaceCanvasNodeOwnershipReader {
        WorkspaceCanvasNodeOwnershipReader { nodeID, scope in
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return try WorkspaceCanvasNodeLookup.resolve(
                nodeID: nodeID,
                scope: scope,
                in: context
            )
        }
    }
}

enum WorkspaceCanvasNodeOwnershipReconciliationResult: Equatable {
    case ready(WorkspaceCanvasNodeOpenRequest)
    case deferred
    case consumed
}

struct WorkspaceCanvasNodeOwnershipObservation: Equatable {
    let scope: WorkspaceCanvasScopeIdentity
    let flow: WorkspaceCanvasNodeOpenFlow
    let fingerprint: String
}

@MainActor
extension WorkspaceWindowScopeController {
    func reconcileCanvasNodeOwnership(
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String,
        reader: WorkspaceCanvasNodeOwnershipReader
    ) -> WorkspaceCanvasNodeOwnershipReconciliationResult {
        guard boundCanvas == scope else {
            return .deferred
        }

        switch canvasNodeOpenFlow {
        case .idle:
            return .deferred

        case let .pending(target, _):
            guard target.workspaceID == scope.focus.workspaceID,
                  target.canvasID == scope.canvasID
            else {
                guard activeCanvasNodeTarget == target,
                      boundCanvas == scope,
                      clearCanvasNodeTarget(target)
                else {
                    return .deferred
                }
                canvasNodeOpenRecoverableError = nil
                return .consumed
            }
            let expectedFlow = canvasNodeOpenFlow
            let readiness: WorkspaceCanvasNodeReadiness
            do {
                readiness = try reader.resolve(
                    nodeID: target.nodeID,
                    scope: scope
                )
            } catch {
                if canvasNodeOpenFlow == expectedFlow, boundCanvas == scope {
                    canvasNodeOpenRecoverableError =
                        ValidationDisplayTextSanitizer.safeDiagnosticMessage(
                            error.localizedDescription
                        )
                }
                return .deferred
            }
            guard canvasNodeOpenFlow == expectedFlow, boundCanvas == scope else {
                return .deferred
            }
            switch readiness {
            case .readyOwned:
                switch issueCanvasNodeOpenRequest(
                    for: target,
                    scope: scope,
                    nodeObservationFingerprint: nodeObservationFingerprint
                ) {
                case let .issued(request):
                    canvasNodeOpenRecoverableError = nil
                    return .ready(request)
                case .deferred, .overflowInvalidated:
                    return .deferred
                }
            case .definitelyAbsentOrCrossCanvas:
                guard clearCanvasNodeTarget(target) else {
                    return .deferred
                }
                canvasNodeOpenRecoverableError = nil
                return .consumed
            case .dataNotReady:
                return .deferred
            }

        case let .issued(target, request, evidence):
            guard target.workspaceID == scope.focus.workspaceID,
                  target.canvasID == scope.canvasID,
                  request.scopeIdentity == scope
            else {
                return .deferred
            }
            if evidence == .ready(
                scope: scope,
                nodeObservationFingerprint: nodeObservationFingerprint
            ) {
                return .ready(request)
            }
            guard markCanvasNodeOpenRequestDirty(
                target: target,
                request: request,
                scope: scope,
                nodeObservationFingerprint: nodeObservationFingerprint
            ) else {
                return .deferred
            }
            let expectedDirtyFlow = canvasNodeOpenFlow
            let readiness: WorkspaceCanvasNodeReadiness
            do {
                readiness = try reader.resolve(
                    nodeID: target.nodeID,
                    scope: scope
                )
            } catch {
                if canvasNodeOpenFlow == expectedDirtyFlow, boundCanvas == scope {
                    canvasNodeOpenRecoverableError =
                        ValidationDisplayTextSanitizer.safeDiagnosticMessage(
                            error.localizedDescription
                        )
                }
                return .deferred
            }
            guard canvasNodeOpenFlow == expectedDirtyFlow, boundCanvas == scope else {
                return .deferred
            }
            switch readiness {
            case .readyOwned:
                guard installCanvasNodeOpenRequestReadyEvidence(
                    target: target,
                    request: request,
                    scope: scope,
                    nodeObservationFingerprint: nodeObservationFingerprint
                ) else {
                    return .deferred
                }
                canvasNodeOpenRecoverableError = nil
                return .ready(request)
            case .definitelyAbsentOrCrossCanvas:
                guard consumeConfirmedAbsentCanvasNodeTarget(
                    target: target,
                    request: request,
                    scope: scope,
                    nodeObservationFingerprint: nodeObservationFingerprint
                ) else {
                    return .deferred
                }
                canvasNodeOpenRecoverableError = nil
                return .consumed
            case .dataNotReady:
                return .deferred
            }
        }
    }

    func consumeCanvasNodeOpenRequestForRender(
        target: PendingWorkspaceCanvasNodeTarget,
        request: WorkspaceCanvasNodeOpenRequest,
        scope: WorkspaceCanvasScopeIdentity,
        nodeObservationFingerprint: String,
        renderedNodeIDs: [String],
        surfaceWidth: Double,
        surfaceHeight: Double
    ) -> WorkspaceCanvasNodeOpenRequestDecision {
        guard boundCanvas == scope,
              case let .issued(currentTarget, currentRequest, evidence) = canvasNodeOpenFlow,
              currentTarget == target,
              currentRequest == request,
              evidence == .ready(
                  scope: scope,
                  nodeObservationFingerprint: nodeObservationFingerprint
              )
        else {
            return .defer
        }
        let hasUsableSurface = surfaceWidth.isFinite
            && surfaceHeight.isFinite
            && surfaceWidth > 0
            && surfaceHeight > 0
        let readiness: WorkspaceCanvasNodeReadiness = hasUsableSurface
            && renderedNodeIDs.filter({ $0 == request.nodeID }).count == 1
            ? .readyOwned
            : .dataNotReady
        return decideCanvasNodeOpenRequest(request, readiness: readiness)
    }
}
