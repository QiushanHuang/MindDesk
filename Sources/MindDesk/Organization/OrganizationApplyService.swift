import Foundation
import SwiftData

struct OrganizationSelection: Identifiable {
    let id = UUID()
    let workspaceID: String
    let canvasID: String
    let cards: [OrganizationSourceSnapshot]
    let selectedIDs: Set<String>
    let contextSources: [OrganizationSourceSnapshot]
    let contextLinks: [OrganizationLink]

    @MainActor
    init(canvas: CanvasModel, nodes: [CanvasNodeModel], contextNodes: [CanvasNodeModel] = [], edges: [CanvasEdgeModel] = []) {
        workspaceID = canvas.workspaceId
        canvasID = canvas.id
        selectedIDs = Set(nodes.filter { $0.canvasId == canvas.id }.map(\.id))
        let sources = contextNodes.isEmpty ? nodes : contextNodes
        contextSources = sources.filter { $0.canvasId == canvas.id }.sorted { $0.id < $1.id }.map(OrganizationSourceSnapshot.init)
        contextLinks = edges.filter { $0.canvasId == canvas.id }.map {
            .init(id: $0.id, sourceID: $0.sourceNodeId, targetID: $0.targetNodeId, label: $0.label,
                  sourceArrow: $0.sourceArrowRaw, targetArrow: $0.targetArrowRaw)
        }.sorted { $0.id < $1.id }
        cards = nodes.filter { $0.canvasId == canvas.id && !$0.locked && $0.nodeType != .groupFrame }
            .sorted { $0.id < $1.id }.map(OrganizationSourceSnapshot.init)
    }

    func request(intent: OrganizationIntent, scope: OrganizationContextScope = .selection, instructions: String = "", feedback: String = "", previous: OrganizationProposal? = nil) -> OrganizationRequest {
        let targetIDs = Set(cards.map { $0.card.id })
        var included = selectedIDs
        if scope == .neighbors {
            for link in contextLinks where selectedIDs.contains(link.sourceID) || selectedIDs.contains(link.targetID) {
                included.formUnion([link.sourceID, link.targetID])
            }
        }
        var previousIDs = Set<String>()
        while included != previousIDs {
            previousIDs = included
            for source in contextSources where included.contains(source.card.id) {
                if let parent = source.parentID { included.insert(parent) }
            }
        }
        let references = contextSources.filter { included.contains($0.card.id) && !targetIDs.contains($0.card.id) }.map(\.card)
        let knownIDs = targetIDs.union(references.map(\.id))
        return OrganizationRequest(workspaceID: workspaceID, canvasID: canvasID, intent: intent,
            cards: cards.map(\.card), sourceID: id.uuidString, contextScope: scope, referenceCards: references,
            links: contextLinks.filter { knownIDs.contains($0.sourceID) && knownIDs.contains($0.targetID) },
            instructions: instructions, revisionFeedback: feedback, previousProposal: previous)

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
        card = OrganizationCard(id: node.id, title: node.title, body: node.body, kind: node.nodeTypeRaw, parentID: node.parentNodeId, locked: node.locked)
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
        var sourceRequest = request
        sourceRequest.instructions = ""
        sourceRequest.revisionFeedback = ""
        sourceRequest.previousProposal = nil
        guard canvas.id == selection.canvasID, canvas.workspaceId == selection.workspaceID,
              sourceRequest == selection.request(intent: request.intent, scope: request.contextScope) else {
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

        let edges = try context.fetch(FetchDescriptor<CanvasEdgeModel>())
        let currentSelection = OrganizationSelection(canvas: canvas,
            nodes: nodes.filter { selection.selectedIDs.contains($0.id) }, contextNodes: nodes, edges: edges)
        let currentRequest = currentSelection.request(intent: request.intent, scope: request.contextScope)
        guard request.referenceCards == currentRequest.referenceCards, request.links == currentRequest.links else {
            throw OrganizationApplyError.staleSelection
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
