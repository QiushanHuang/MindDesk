import Foundation
import MindDeskCore
import SwiftData

private struct WorkweftBridgeState: Codable {
    var version = 1
    var pairId: String
    var projectId: String
    var workspaceId: String
    var canvasID: String
    var base: WorkweftCanvasDocument
    var outgoing: [WorkweftCanvasDocument] = []
    var nodeMap: [String: String] = [:]
    var edgeMap: [String: String] = [:]
    var knownNodes: [String: WorkweftCanvasNode] = [:]
    var knownEdges: [String: WorkweftCanvasEdge] = [:]
    var references: [WorkweftBridgeReference] = []
}

struct WorkweftBridgeImportPreview {
    let canvasID: String
    let workspaceID: String
    let package: WorkweftBridgePackage
    let merge: WorkweftBridgeMergePreview
    var isNew: Bool { before == nil }
    fileprivate let before: Data?
    fileprivate let local: WorkweftCanvasDocument
    fileprivate let base: WorkweftCanvasDocument
}

struct WorkweftBridgeUndoReceipt {
    let canvasID: String
    fileprivate let before: Data?
    fileprivate let after: Data
}

/// Data only: no path/bookmark resolution, task acceptance or legacy review APIs.
@MainActor
enum WorkweftBridgeService {
    static func review(preview: WorkweftBridgeImportPreview, choices: [String: WorkweftBridgeChoice]) throws -> WorkweftBridgeMergePreview {
        try WorkweftBridgeMerge.preview(base: preview.base, local: preview.local, incoming: preview.package.document, choices: choices)
    }
    static func preview(data: Data, workspaceID: String, context: ModelContext) throws -> WorkweftBridgeImportPreview {
        try clean(context)
        guard data.count <= 2_500_000 else { throw WorkweftBridgeError("Bridge package exceeds 2.5 MB.") }
        let package = try JSONDecoder().decode(WorkweftBridgePackage.self, from: data)
        try package.validate()
        guard try context.fetch(FetchDescriptor<WorkspaceModel>()).contains(where: { $0.id == workspaceID }), package.workspaceId == nil || package.workspaceId == workspaceID else { throw WorkweftBridgeError("Choose the workspace bound to this package.") }
        if let canvas = try paired(package.pairId, context) {
            let state = try state(canvas)
            guard state.projectId == package.projectId, state.workspaceId == workspaceID, canvas.workspaceId == workspaceID else { throw WorkweftBridgeError("This pair belongs to another project or workspace.") }
            let base: WorkweftCanvasDocument
            if let proposed = package.base, proposed.semanticallyEquals(state.base) || state.outgoing.contains(where: { proposed.semanticallyEquals($0) }) { base = proposed }
            else if package.base == nil && package.document.semanticallyEquals(state.base) { base = state.base }
            else { throw WorkweftBridgeError("The incoming base was never recorded here. Export a fresh package from the paired canvas.") }
            let local = try graph(canvas, state: state, context: context).document
            return .init(canvasID: canvas.id, workspaceID: workspaceID, package: package, merge: try WorkweftBridgeMerge.preview(base: base, local: local, incoming: package.document), before: try snapshot(canvas, context), local: local, base: base)
        }
        guard package.base == nil else { throw WorkweftBridgeError("An unknown pair must start with an empty shared base.") }
        let empty = WorkweftCanvasDocument()
        return .init(canvasID: UUID().uuidString, workspaceID: workspaceID, package: package, merge: try WorkweftBridgeMerge.preview(base: empty, local: empty, incoming: package.document), before: nil, local: empty, base: empty)
    }

    static func apply(preview: WorkweftBridgeImportPreview, choices: [String: WorkweftBridgeChoice] = [:], context: ModelContext) throws -> WorkweftBridgeUndoReceipt {
        try clean(context)
        guard try context.fetch(FetchDescriptor<WorkspaceModel>()).contains(where: { $0.id == preview.workspaceID }) else { throw WorkweftBridgeError("The selected workspace no longer exists.") }
        let existing = try paired(preview.package.pairId, context)
        if let before = preview.before {
            guard let existing, existing.id == preview.canvasID, try snapshot(existing, context) == before else { throw WorkweftBridgeError("The canvas changed after preview. Read the package again before applying.") }
        } else if try existing != nil || canvas(preview.canvasID, context) != nil { throw WorkweftBridgeError("This pair was created after preview. Read the package again.") }
        let result = try WorkweftBridgeMerge.preview(base: preview.base, local: preview.local, incoming: preview.package.document, choices: choices)
        guard result.unresolved.isEmpty else { throw WorkweftBridgeError("Choose local or incoming for every conflict before applying.") }
        let target = existing ?? CanvasModel(id: preview.canvasID, workspaceId: preview.workspaceID, title: "Workweft · " + preview.package.projectId)
        var pairing = try existing.map(state) ?? WorkweftBridgeState(pairId: preview.package.pairId, projectId: preview.package.projectId, workspaceId: preview.workspaceID, canvasID: target.id, base: preview.package.document)
        do {
            if existing == nil { context.insert(target) }
            // Verify the local graph against its OLD display metadata first.
            let current = try graph(target, state: pairing, context: context)
            pairing.nodeMap = current.nodeMap; pairing.edgeMap = current.edgeMap
            if let references = preview.package.references { pairing.references = references }
            try applyGraph(result.document, canvas: target, pairing: &pairing, context: context)
            pairing.base = preview.package.document.canonical
            target.workweftBridgeState = try encode(pairing); target.updatedAt = .now
            try context.save()
            return .init(canvasID: target.id, before: preview.before, after: try snapshot(target, context))
        } catch { context.rollback(); throw error }
    }

    static func export(canvasID: String, context: ModelContext) throws -> Data {
        try clean(context)
        guard let canvas = try canvas(canvasID, context) else { throw WorkweftBridgeError("The paired canvas no longer exists.") }
        var pairing = try state(canvas)
        let current = try graph(canvas, state: pairing, context: context)
        pairing.nodeMap = current.nodeMap; pairing.edgeMap = current.edgeMap
        pairing.knownNodes = Dictionary(uniqueKeysWithValues: current.document.nodes.map { ($0.id, $0) }); pairing.knownEdges = Dictionary(uniqueKeysWithValues: current.document.edges.map { ($0.id, $0) })
        if !pairing.outgoing.contains(where: { $0.semanticallyEquals(current.document) }) { pairing.outgoing.append(current.document.canonical) }
        pairing.outgoing = Array(pairing.outgoing.suffix(16))
        let package = WorkweftBridgePackage(pairId: pairing.pairId, projectId: pairing.projectId, workspaceId: pairing.workspaceId, base: pairing.base, document: current.document, references: pairing.references)
        try package.validate(); let output = try encode(package)
        do { canvas.workweftBridgeState = try encode(pairing); try context.save() }
        catch { context.rollback(); throw error }
        return output
    }

    static func undo(receipt: WorkweftBridgeUndoReceipt, context: ModelContext) throws {
        try clean(context)
        guard let target = try canvas(receipt.canvasID, context), try snapshot(target, context) == receipt.after else { throw WorkweftBridgeError("The canvas or pairing changed after import. Undo refused to protect later edits.") }
        do {
            if let before = receipt.before { try restore(before, target: target, context: context) }
            else {
                for edge in try edges(target.id, context) { context.delete(edge) }
                for node in try nodes(target.id, context) { context.delete(node) }
                context.delete(target)
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    private static func clean(_ context: ModelContext) throws {
        guard !context.hasChanges else { throw WorkweftBridgeError("Finish saving current edits before bridge preview, apply, export, or Undo.") }
    }
    private static func encode<T: Encodable>(_ value: T) throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value) }
    private static func state(_ canvas: CanvasModel) throws -> WorkweftBridgeState {
        guard let data = canvas.workweftBridgeState else { throw WorkweftBridgeError("This is not a paired Workweft canvas.") }
        let value = try JSONDecoder().decode(WorkweftBridgeState.self, from: data)
        guard value.version == 1, value.canvasID == canvas.id, value.workspaceId == canvas.workspaceId else { throw WorkweftBridgeError("The local pairing record no longer matches this canvas.") }
        return value
    }
    private static func paired(_ pairID: String, _ context: ModelContext) throws -> CanvasModel? {
        var matches: [CanvasModel] = []
        for item in try context.fetch(FetchDescriptor<CanvasModel>()) where item.workweftBridgeState != nil { if try state(item).pairId == pairID { matches.append(item) } }
        guard matches.count <= 1 else { throw WorkweftBridgeError("Duplicate local bridge pairing; no canvas was changed.") }
        return matches.first
    }
    private static func canvas(_ id: String, _ context: ModelContext) throws -> CanvasModel? { try context.fetch(FetchDescriptor<CanvasModel>(predicate: #Predicate { $0.id == id })).first }
    private static func nodes(_ id: String, _ context: ModelContext) throws -> [CanvasNodeModel] { try context.fetch(FetchDescriptor<CanvasNodeModel>(predicate: #Predicate { $0.canvasId == id })).sorted { $0.id < $1.id } }
    private static func edges(_ id: String, _ context: ModelContext) throws -> [CanvasEdgeModel] { try context.fetch(FetchDescriptor<CanvasEdgeModel>(predicate: #Predicate { $0.canvasId == id })).sorted { $0.id < $1.id } }
    private static func requireOwnership(nodeIDs: [String], edgeIDs: [String], canvasID: String, context: ModelContext) throws {
        let foreignNodes = try context.fetch(FetchDescriptor<CanvasNodeModel>(predicate: #Predicate { nodeIDs.contains($0.id) && $0.canvasId != canvasID }))
        let foreignEdges = try context.fetch(FetchDescriptor<CanvasEdgeModel>(predicate: #Predicate { edgeIDs.contains($0.id) && $0.canvasId != canvasID }))
        guard foreignNodes.isEmpty, foreignEdges.isEmpty else { throw WorkweftBridgeError("A mapped card or link now belongs to another native canvas. No identity was rebound.") }
    }
    private static func display(_ node: WorkweftCanvasNode, _ state: WorkweftBridgeState) -> (String, String) {
        let reference = state.references.first { $0.kind == node.kind && $0.refID == node.refID }
        return (reference?.title ?? "\(node.kind) · \(node.refID ?? node.id)", [reference?.status, reference?.body].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    // Exact local records protect stale previews/Undo, including native styles.
    // This snapshot is created locally, never supplied by an incoming package.
    private static func snapshot(_ canvas: CanvasModel, _ context: ModelContext) throws -> Data {
        let nodeValues: [[String: Any]] = try nodes(canvas.id, context).map { n in
            ["id": n.id, "title": n.title, "body": n.body, "kind": n.nodeTypeRaw, "objectType": n.objectType as Any? ?? NSNull(), "objectId": n.objectId as Any? ?? NSNull(), "x": n.x, "y": n.y, "width": n.width, "height": n.height, "parent": n.parentNodeId as Any? ?? NSNull(), "collapsed": n.collapsed, "locked": n.locked, "z": n.zIndex, "style": n.styleRaw, "color": n.accentColorRaw, "created": n.createdAt.timeIntervalSince1970, "updated": n.updatedAt.timeIntervalSince1970]
        }
        let edgeValues: [[String: Any]] = try edges(canvas.id, context).map { e in
            ["id": e.id, "source": e.sourceNodeId, "target": e.targetNodeId, "label": e.label, "style": e.style, "sourceArrow": e.sourceArrowRaw, "targetArrow": e.targetArrowRaw, "animated": e.animated, "theme": e.animationThemeRaw, "controlX": e.controlPointX as Any? ?? NSNull(), "controlY": e.controlPointY as Any? ?? NSNull(), "created": e.createdAt.timeIntervalSince1970, "updated": e.updatedAt.timeIntervalSince1970]
        }
        return try JSONSerialization.data(withJSONObject: ["id": canvas.id, "workspace": canvas.workspaceId, "title": canvas.title, "x": canvas.viewportX, "y": canvas.viewportY, "zoom": canvas.zoom, "theme": canvas.linkAnimationThemeRaw, "animated": canvas.animationsEnabled, "created": canvas.createdAt.timeIntervalSince1970, "updated": canvas.updatedAt.timeIntervalSince1970, "state": canvas.workweftBridgeState?.base64EncodedString() as Any? ?? NSNull(), "nodes": nodeValues, "edges": edgeValues], options: [.sortedKeys])
    }
    private static func restore(_ data: Data, target: CanvasModel, context: ModelContext) throws {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any], value["id"] as? String == target.id,
              let nodeValues = value["nodes"] as? [[String: Any]], let edgeValues = value["edges"] as? [[String: Any]] else { throw WorkweftBridgeError("Invalid local Undo receipt.") }
        try requireOwnership(nodeIDs: nodeValues.compactMap { $0["id"] as? String }, edgeIDs: edgeValues.compactMap { $0["id"] as? String }, canvasID: target.id, context: context)
        let oldNodes = try nodes(target.id, context), oldEdges = try edges(target.id, context)
        let byID = Dictionary(uniqueKeysWithValues: oldNodes.map { ($0.id, $0) }), edgeByID = Dictionary(uniqueKeysWithValues: oldEdges.map { ($0.id, $0) })
        for n in nodeValues {
            let id = n["id"] as! String
            let model = byID[id] ?? CanvasNodeModel(id: id, canvasId: target.id, title: "", nodeType: .note, x: 0, y: 0)
            if byID[id] == nil { context.insert(model) }
            model.title = n["title"] as! String; model.body = n["body"] as! String; model.nodeTypeRaw = n["kind"] as! String; model.objectType = n["objectType"] as? String; model.objectId = n["objectId"] as? String
            model.x = n["x"] as! Double; model.y = n["y"] as! Double; model.width = n["width"] as! Double; model.height = n["height"] as! Double; model.parentNodeId = n["parent"] as? String
            model.collapsed = n["collapsed"] as! Bool; model.locked = n["locked"] as! Bool; model.zIndex = n["z"] as! Double; model.styleRaw = n["style"] as! String; model.accentColorRaw = n["color"] as! String
            model.createdAt = Date(timeIntervalSince1970: n["created"] as! Double); model.updatedAt = Date(timeIntervalSince1970: n["updated"] as! Double)
        }
        let wanted = Set(nodeValues.compactMap { $0["id"] as? String })
        for node in oldNodes where !wanted.contains(node.id) { context.delete(node) }
        for e in edgeValues {
            let id = e["id"] as! String
            let model = edgeByID[id] ?? CanvasEdgeModel(id: id, canvasId: target.id, sourceNodeId: "", targetNodeId: "")
            if edgeByID[id] == nil { context.insert(model) }
            model.sourceNodeId = e["source"] as! String; model.targetNodeId = e["target"] as! String; model.label = e["label"] as! String; model.style = e["style"] as! String
            model.sourceArrowRaw = e["sourceArrow"] as! String; model.targetArrowRaw = e["targetArrow"] as! String; model.animated = e["animated"] as! Bool; model.animationThemeRaw = e["theme"] as! String
            model.controlPointX = e["controlX"] as? Double; model.controlPointY = e["controlY"] as? Double; model.createdAt = Date(timeIntervalSince1970: e["created"] as! Double); model.updatedAt = Date(timeIntervalSince1970: e["updated"] as! Double)
        }
        let wantedEdges = Set(edgeValues.compactMap { $0["id"] as? String }); for edge in oldEdges where !wantedEdges.contains(edge.id) { context.delete(edge) }
        target.title = value["title"] as! String; target.viewportX = value["x"] as! Double; target.viewportY = value["y"] as! Double; target.zoom = value["zoom"] as! Double
        target.linkAnimationThemeRaw = value["theme"] as! String; target.animationsEnabled = value["animated"] as! Bool; target.createdAt = Date(timeIntervalSince1970: value["created"] as! Double); target.updatedAt = Date(timeIntervalSince1970: value["updated"] as! Double)
        target.workweftBridgeState = (value["state"] as? String).flatMap { Data(base64Encoded: $0) }
    }

    private struct Graph { var document: WorkweftCanvasDocument; var nodeMap: [String: String]; var edgeMap: [String: String] }
    private static func graph(_ canvas: CanvasModel, state: WorkweftBridgeState, context: ModelContext) throws -> Graph {
        try requireOwnership(nodeIDs: Array(state.nodeMap.values), edgeIDs: Array(state.edgeMap.values), canvasID: canvas.id, context: context)
        var mapping = state.nodeMap, edgeMapping = state.edgeMap
        let native = try nodes(canvas.id, context), nativeEdges = try edges(canvas.id, context)
        var result: [WorkweftCanvasNode] = []
        for item in native where item.nodeType == .note || item.nodeType == .groupFrame {
            let foreignID = mapping.first { $0.value == item.id }?.key ?? "minddesk:" + item.id
            guard mapping[foreignID] == nil || mapping[foreignID] == item.id else { throw WorkweftBridgeError("New native card collides with a recorded foreign identity.") }
            if let known = state.knownNodes[foreignID], known.isReference {
                let expected = display(known, state)
                guard item.objectType == "workweft." + known.kind, item.objectId == known.refID, item.title == expected.0, item.body == expected.1 else { throw WorkweftBridgeError("Linked card metadata changed in MindDesk. Restore its Workweft text before exporting or merging.") }
            } else if item.objectType?.hasPrefix("workweft.") == true { throw WorkweftBridgeError("Unrecognized linked card identity.") }
            mapping[foreignID] = item.id
        }
        guard Set(mapping.values).count == mapping.count else { throw WorkweftBridgeError("Duplicate native identity in local pairing.") }
        let reverse = Dictionary(uniqueKeysWithValues: mapping.map { ($0.value, $0.key) })
        for item in native where item.nodeType == .note || item.nodeType == .groupFrame {
            guard let id = reverse[item.id] else { continue }
            let known = state.knownNodes[id], reference = known?.isReference == true
            result.append(.init(id: id, kind: reference ? known!.kind : item.nodeType == .groupFrame ? "group" : "note", refID: reference ? known?.refID : nil, x: item.x, y: item.y, width: item.width, height: item.height, parentID: item.parentNodeId.flatMap { reverse[$0] }, collapsed: item.collapsed, locked: item.locked, title: reference ? "" : item.title, body: reference ? "" : item.body))
        }
        let present = Set(result.map(\.id))
        let previouslyHidden = WorkweftCanvasDocument(nodes: Array(state.knownNodes.values)).effectiveHiddenIDs
        for (_, known) in state.knownNodes where !present.contains(known.id) {
            if previouslyHidden.contains(known.id) { result.append(known) }
            else if known.isReference { var hidden = known; hidden.hidden = true; result.append(hidden) }
        }
        let included = Set(result.map(\.id)), hidden = WorkweftCanvasDocument(nodes: result).effectiveHiddenIDs
        for index in result.indices where result[index].parentID.map({ !included.contains($0) }) == true { result[index].parentID = nil }
        var links: [WorkweftCanvasEdge] = []
        for edge in nativeEdges {
            guard let source = reverse[edge.sourceNodeId], let target = reverse[edge.targetNodeId], included.contains(source), included.contains(target) else { continue }
            let id = edgeMapping.first { $0.value == edge.id }?.key ?? "minddesk:" + edge.id
            guard edgeMapping[id] == nil || edgeMapping[id] == edge.id else { throw WorkweftBridgeError("New native link collides with a recorded foreign identity.") }
            edgeMapping[id] = edge.id; links.append(.init(id: id, source: source, target: target, label: edge.label))
        }
        let linkIDs = Set(links.map(\.id))
        for (_, edge) in state.knownEdges where !linkIDs.contains(edge.id) && included.contains(edge.source) && included.contains(edge.target) && (hidden.contains(edge.source) || hidden.contains(edge.target)) { links.append(edge) }
        let document = WorkweftCanvasDocument(viewport: .init(x: canvas.viewportX, y: canvas.viewportY, zoom: canvas.zoom), nodes: result, edges: links).canonical
        try document.validate()
        return .init(document: document, nodeMap: mapping, edgeMap: edgeMapping)
    }

    private static func applyGraph(_ document: WorkweftCanvasDocument, canvas: CanvasModel, pairing: inout WorkweftBridgeState, context: ModelContext) throws {
        let oldNodes = try nodes(canvas.id, context), oldEdges = try edges(canvas.id, context)
        let oldByID = Dictionary(uniqueKeysWithValues: oldNodes.map { ($0.id, $0) }), edgesByID = Dictionary(uniqueKeysWithValues: oldEdges.map { ($0.id, $0) })
        for node in document.nodes where pairing.nodeMap[node.id] == nil { pairing.nodeMap[node.id] = UUID().uuidString }
        var visible = Set<String>()
        let effectivelyHidden = document.effectiveHiddenIDs
        for node in document.nodes where !effectivelyHidden.contains(node.id) {
            let id = pairing.nodeMap[node.id]!
            let text = node.isReference ? display(node, pairing) : (node.title, node.body)
            let target = oldByID[id] ?? CanvasNodeModel(id: id, canvasId: canvas.id, title: text.0, nodeType: node.kind == "group" ? .groupFrame : .note, x: node.x, y: node.y)
            if oldByID[id] == nil { context.insert(target) }
            target.title = text.0; target.body = text.1; target.nodeTypeRaw = node.kind == "group" ? "groupFrame" : "note"
            target.objectType = node.isReference ? "workweft." + node.kind : nil; target.objectId = node.refID
            target.x = node.x; target.y = node.y; target.width = node.width; target.height = node.height; target.collapsed = node.collapsed; target.locked = node.locked
            target.parentNodeId = node.parentID.flatMap { parent in document.nodes.contains(where: { $0.id == parent && !$0.hidden }) ? pairing.nodeMap[parent] : nil }; target.updatedAt = .now
            visible.insert(id)
        }
        let managed = Set(pairing.nodeMap.values)
        for node in oldNodes where managed.contains(node.id) && !visible.contains(node.id) { context.delete(node) }
        for node in oldNodes where !managed.contains(node.id) && node.parentNodeId.map({ managed.contains($0) && !visible.contains($0) }) == true { node.parentNodeId = nil }
        var liveEdges = Set<String>()
        for edge in document.edges {
            guard let source = pairing.nodeMap[edge.source], let target = pairing.nodeMap[edge.target], visible.contains(source), visible.contains(target) else { continue }
            let id = pairing.edgeMap[edge.id] ?? UUID().uuidString; pairing.edgeMap[edge.id] = id
            let model = edgesByID[id] ?? CanvasEdgeModel(id: id, canvasId: canvas.id, sourceNodeId: source, targetNodeId: target)
            if edgesByID[id] == nil { context.insert(model) }
            model.sourceNodeId = source; model.targetNodeId = target; model.label = edge.label; model.updatedAt = .now; liveEdges.insert(id)
        }
        let managedEdges = Set(pairing.edgeMap.values)
        for edge in oldEdges where managedEdges.contains(edge.id) && !liveEdges.contains(edge.id) { context.delete(edge) }
        canvas.viewportX = document.viewport.x; canvas.viewportY = document.viewport.y; canvas.zoom = document.viewport.zoom
        pairing.knownNodes = Dictionary(uniqueKeysWithValues: document.nodes.map { ($0.id, $0) }); pairing.knownEdges = Dictionary(uniqueKeysWithValues: document.edges.map { ($0.id, $0) })
    }
}
