import Foundation
import SwiftData

struct OrganizationSelection: Identifiable {
    let id = UUID()
    let workspaceID: String
    let canvasID: String
    let cards: [OrganizationSourceSnapshot]

    @MainActor
    init(canvas: CanvasModel, nodes: [CanvasNodeModel]) {
        workspaceID = canvas.workspaceId
        canvasID = canvas.id
        cards = nodes.filter { $0.canvasId == canvas.id && !$0.locked && $0.nodeType != .groupFrame }
            .sorted { $0.id < $1.id }.map(OrganizationSourceSnapshot.init)
    }

    func request(intent: OrganizationIntent) -> OrganizationRequest {
        OrganizationRequest(workspaceID: workspaceID, canvasID: canvasID, intent: intent,
                            cards: cards.map(\.card))
    }
}

struct OrganizationSourceSnapshot: Equatable {
    let card: OrganizationCard
    let canvasID: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let parentID: String?
    let updatedAt: Date
    let locked: Bool

    @MainActor
    init(_ node: CanvasNodeModel) {
        card = OrganizationCard(id: node.id, title: node.title, body: node.body, kind: node.nodeTypeRaw)
        canvasID = node.canvasId
        x = node.x; y = node.y; width = node.width; height = node.height
        parentID = node.parentNodeId; updatedAt = node.updatedAt; locked = node.locked
    }
}

enum OrganizationApplyError: LocalizedError {
    case staleSelection, unsavedChanges, invalidGeometry

    var errorDescription: String? {
        switch self {
        case .staleSelection: "These cards changed while the preview was open. Close it and generate a fresh preview."
        case .unsavedChanges: "Finish saving your current edits before applying this preview."
        case .invalidGeometry: "Some card dimensions cannot be arranged. No changes were made."
        }
    }
}

@MainActor
private final class OrganizationUndoState {
    let context: ModelContext
    let onError: (String) -> Void

    init(context: ModelContext, onError: @escaping (String) -> Void) {
        self.context = context
        self.onError = onError
    }
}

@MainActor
enum OrganizationApplyService {
    static func apply(
        _ proposal: OrganizationProposal,
        request: OrganizationRequest,
        selection: OrganizationSelection,
        canvas: CanvasModel,
        context: ModelContext,
        undoManager: UndoManager?,
        onUndoError: @escaping (String) -> Void = { _ in }
    ) throws {
        try proposal.validate(for: request)
        guard !context.hasChanges else { throw OrganizationApplyError.unsavedChanges }
        guard canvas.id == selection.canvasID, canvas.workspaceId == selection.workspaceID,
              request == selection.request(intent: request.intent) else {
            throw OrganizationApplyError.staleSelection
        }
        let nodes = try context.fetch(FetchDescriptor<CanvasNodeModel>())
        let byID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for snapshot in selection.cards {
            guard let node = byID[snapshot.card.id], OrganizationSourceSnapshot(node) == snapshot,
                  !node.locked else { throw OrganizationApplyError.staleSelection }
            guard [node.x, node.y, node.width, node.height].allSatisfy(\.isFinite),
                  node.width > 0, node.height > 0,
                  abs(node.x) < 10_000_000, abs(node.y) < 10_000_000,
                  node.width < 100_000, node.height < 100_000 else {
                throw OrganizationApplyError.invalidGeometry
            }
        }

        var createdNodeIDs: [String] = []
        var createdTaskIDs: [String] = []
        var moved: [OrganizationSourceSnapshot] = []
        let anchorX = selection.cards.map { $0.x + $0.width }.max() ?? 0
        let anchorY = selection.cards.map(\.y).min() ?? 0
        switch request.intent {
        case .summarize:
            let note = CanvasNodeModel(canvasId: canvas.id, title: "Summary", body: proposal.summary,
                                       nodeType: .note, x: anchorX + 80, y: anchorY, width: 320, height: 240)
            context.insert(note)
            createdNodeIDs.append(note.id)
        case .extractTasks:
            for (index, suggestion) in proposal.tasks.enumerated() {
                let sources = suggestion.sourceCardIDs.compactMap { byID[$0]?.title }.joined(separator: ", ")
                let task = WorkspaceTodoModel(workspaceId: canvas.workspaceId, title: suggestion.title,
                    details: suggestion.details + "\n\nSource cards: " + sources, sortIndex: index)
                context.insert(task)
                createdTaskIDs.append(task.id)
            }
        case .classify, .arrange:
            var groupY = anchorY
            for group in proposal.groups {
                let members = group.cardIDs.compactMap { byID[$0] }
                let columnWidth = (members.map(\.width).max() ?? 240) + 32
                let rowHeight = (members.map(\.height).max() ?? 180) + 32
                let columns = min(3, members.count)
                let rows = (members.count + columns - 1) / columns
                let frame = CanvasNodeModel(canvasId: canvas.id, title: group.name,
                    nodeType: .groupFrame, x: anchorX + 80, y: groupY,
                    width: Double(columns) * columnWidth + 32, height: Double(rows) * rowHeight + 64,
                    zIndex: -1)
                context.insert(frame)
                createdNodeIDs.append(frame.id)
                for (index, node) in members.enumerated() {
                    moved.append(OrganizationSourceSnapshot(node))
                    node.x = frame.x + 32 + Double(index % columns) * columnWidth
                    node.y = frame.y + 56 + Double(index / columns) * rowHeight
                    node.parentNodeId = frame.id
                    node.updatedAt = .now
                }
                groupY += frame.height + 64
            }
        }
        do { try context.save() }
        catch { context.rollback(); throw error }

        let nodeIDs = createdNodeIDs, taskIDs = createdTaskIDs, originals = moved
        let undoState = OrganizationUndoState(context: context, onError: onUndoError)
        undoManager?.registerUndo(withTarget: context) { _ in
            MainActor.assumeIsolated {
                let target = undoState.context
                guard !target.hasChanges else {
                    undoState.onError(OrganizationApplyError.unsavedChanges.localizedDescription)
                    return
                }
                do {
                    let allNodes = try target.fetch(FetchDescriptor<CanvasNodeModel>())
                    for node in allNodes {
                        if nodeIDs.contains(node.id) { target.delete(node) }
                        else if let original = originals.first(where: { $0.card.id == node.id }) {
                            node.x = original.x; node.y = original.y
                            node.parentNodeId = original.parentID; node.updatedAt = original.updatedAt
                        }
                    }
                    if !taskIDs.isEmpty {
                        for task in try target.fetch(FetchDescriptor<WorkspaceTodoModel>()) where taskIDs.contains(task.id) {
                            target.delete(task)
                        }
                    }
                    try target.save()
                } catch {
                    target.rollback()
                    undoState.onError("Could not undo organization: \(error.localizedDescription)")
                }
            }
        }
        undoManager?.setActionName("Organize Cards")
    }
}
