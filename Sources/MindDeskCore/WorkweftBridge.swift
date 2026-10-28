import Foundation

public struct WorkweftBridgeError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct WorkweftCanvasViewport: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var zoom: Double
    public init(x: Double = 0, y: Double = 0, zoom: Double = 1) { self.x = x; self.y = y; self.zoom = zoom }
}

public struct WorkweftCanvasNode: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var refID: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var parentID: String?
    public var collapsed: Bool
    public var locked: Bool
    public var hidden: Bool
    public var title: String
    public var body: String
    public var isReference: Bool { ["task", "asset", "artifact"].contains(kind) }
    enum CodingKeys: String, CodingKey { case id, kind, x, y, width, height, collapsed, locked, hidden, title, body; case refID = "ref_id", parentID = "parent_id" }
    public init(id: String, kind: String, refID: String? = nil, x: Double = 0, y: Double = 0, width: Double = 240, height: Double = 160, parentID: String? = nil, collapsed: Bool = false, locked: Bool = false, hidden: Bool = false, title: String = "", body: String = "") {
        self.id = id; self.kind = kind; self.refID = refID; self.x = x; self.y = y; self.width = width; self.height = height; self.parentID = parentID; self.collapsed = collapsed; self.locked = locked; self.hidden = hidden; self.title = title; self.body = body
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(kind, forKey: .kind); try c.encode(refID, forKey: .refID)
        try c.encode(x, forKey: .x); try c.encode(y, forKey: .y); try c.encode(width, forKey: .width); try c.encode(height, forKey: .height)
        try c.encode(parentID, forKey: .parentID); try c.encode(collapsed, forKey: .collapsed); try c.encode(locked, forKey: .locked); try c.encode(hidden, forKey: .hidden)
        try c.encode(title, forKey: .title); try c.encode(body, forKey: .body)
    }
}

public struct WorkweftCanvasEdge: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var source: String
    public var target: String
    public var label: String
    public init(id: String, source: String, target: String, label: String = "") { self.id = id; self.source = source; self.target = target; self.label = label }
}

public struct WorkweftCanvasDocument: Codable, Equatable, Sendable {
    public var schema: String = "WorkweftCanvasV1"
    public var viewport: WorkweftCanvasViewport
    public var nodes: [WorkweftCanvasNode]
    public var edges: [WorkweftCanvasEdge]
    public init(viewport: WorkweftCanvasViewport = .init(), nodes: [WorkweftCanvasNode] = [], edges: [WorkweftCanvasEdge] = []) { self.viewport = viewport; self.nodes = nodes; self.edges = edges }
    public var canonical: Self { var copy = self; copy.nodes.sort { $0.id < $1.id }; copy.edges.sort { $0.id < $1.id }; return copy }
    public func semanticallyEquals(_ other: Self) -> Bool { canonical == other.canonical }
    public var effectiveHiddenIDs: Set<String> {
        var hidden = Set(nodes.filter(\.hidden).map(\.id))
        var previousCount = -1
        while previousCount != hidden.count {
            previousCount = hidden.count
            for node in nodes where node.parentID.map({ hidden.contains($0) }) == true { hidden.insert(node.id) }
        }
        return hidden
    }
    public func validate() throws {
        func validID(_ id: String) -> Bool { !id.isEmpty && id.unicodeScalars.count <= 160 && !id.contains(where: { $0.isNewline }) }
        func position(_ value: Double) -> Bool { value.isFinite && abs(value) <= 1_000_000 }
        guard schema == "WorkweftCanvasV1", nodes.count <= 1000, edges.count <= 2000,
              position(viewport.x), position(viewport.y), viewport.zoom.isFinite, (0.15...3).contains(viewport.zoom),
              Set(nodes.map(\.id)).count == nodes.count, Set(edges.map(\.id)).count == edges.count
        else { throw WorkweftBridgeError("Invalid canvas schema, size, identifiers, or viewport.") }
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            guard validID(node.id), ["note", "group", "task", "asset", "artifact"].contains(node.kind), position(node.x), position(node.y), node.width.isFinite, node.height.isFinite,
                  (160...2000).contains(node.width), (100...1600).contains(node.height), node.body.unicodeScalars.count <= 10000,
                  node.isReference ? (node.refID.map(validID) == true && node.id == node.kind + ":" + (node.refID ?? "") && node.title.isEmpty && node.body.isEmpty) : (node.refID == nil && (1...160).contains(node.title.unicodeScalars.count) && !["task:", "asset:", "artifact:"].contains(where: { node.id.hasPrefix($0) }))
            else { throw WorkweftBridgeError("Invalid card or reference: \(node.id). Linked text belongs to Workweft.") }
            var seen: Set<String> = [node.id]
            var parent = node.parentID
            while let id = parent {
                guard let group = byID[id], group.kind == "group", seen.insert(id).inserted else { throw WorkweftBridgeError("Invalid group hierarchy for \(node.id).") }
                parent = group.parentID
            }
        }
        for edge in edges {
            guard validID(edge.id), byID[edge.source] != nil, byID[edge.target] != nil, edge.source != edge.target, edge.label.unicodeScalars.count <= 160 else { throw WorkweftBridgeError("Invalid canvas link: \(edge.id).") }
        }
        guard try JSONEncoder().encode(self).count <= 750_000 else { throw WorkweftBridgeError("Canvas document exceeds 750 KB.") }
    }
}

public struct WorkweftBridgeReference: Codable, Equatable, Sendable {
    public var kind: String
    public var refID: String
    public var title: String
    public var status: String?
    public var body: String?
    enum CodingKeys: String, CodingKey { case kind, title, status, body; case refID = "ref_id" }
    public init(kind: String, refID: String, title: String, status: String? = nil, body: String? = nil) { self.kind = kind; self.refID = refID; self.title = title; self.status = status; self.body = body }
}

public struct WorkweftBridgePackage: Codable, Equatable, Sendable {
    public var format: String = "workweft.minddesk.bridge"
    public var version: Int = 1
    public var pairId: String
    public var projectId: String
    public var workspaceId: String?
    public var base: WorkweftCanvasDocument?
    public var document: WorkweftCanvasDocument
    public var references: [WorkweftBridgeReference]?
    enum CodingKeys: String, CodingKey { case format, version, pairId, projectId, workspaceId, base, document, references }
    public init(pairId: String, projectId: String, workspaceId: String? = nil, base: WorkweftCanvasDocument? = nil, document: WorkweftCanvasDocument, references: [WorkweftBridgeReference]? = nil) { self.pairId = pairId; self.projectId = projectId; self.workspaceId = workspaceId; self.base = base; self.document = document; self.references = references }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format); try c.encode(version, forKey: .version); try c.encode(pairId, forKey: .pairId); try c.encode(projectId, forKey: .projectId)
        try c.encode(workspaceId, forKey: .workspaceId); try c.encode(base, forKey: .base); try c.encode(document, forKey: .document); try c.encodeIfPresent(references, forKey: .references)
    }
    public func validate() throws {
        guard format == "workweft.minddesk.bridge", version == 1, !pairId.isEmpty, pairId.unicodeScalars.count <= 160, !projectId.isEmpty, projectId.unicodeScalars.count <= 160,
              workspaceId == nil || (!(workspaceId ?? "").isEmpty && (workspaceId?.unicodeScalars.count ?? 0) <= 160), (references?.count ?? 0) <= 2000 else { throw WorkweftBridgeError("Unsupported bridge package or pairing identity.") }
        try document.validate(); try base?.validate()
        var seen = Set<String>()
        for reference in references ?? [] {
            guard ["task", "asset", "artifact"].contains(reference.kind), !reference.refID.isEmpty, reference.refID.count <= 200, reference.title.count <= 1000, (reference.status?.count ?? 0) <= 200, (reference.body?.count ?? 0) <= 10000,
                  seen.insert(reference.kind + ":" + reference.refID).inserted else { throw WorkweftBridgeError("Invalid display-only reference metadata.") }
        }
    }
}

public enum WorkweftBridgeChoice: String, Codable, CaseIterable, Sendable { case local, incoming }
public struct WorkweftBridgeConflict: Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let local: String
    public let incoming: String
}
public struct WorkweftBridgeMergePreview: Sendable {
    public let document: WorkweftCanvasDocument
    public let conflicts: [WorkweftBridgeConflict]
    public let unresolved: [WorkweftBridgeConflict]
}

private enum BridgeScalar: Codable, Equatable {
    case null, text(String), number(Double), bool(Bool)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else { self = .text(try c.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .null: try c.encodeNil(); case .text(let value): try c.encode(value); case .number(let value): try c.encode(value); case .bool(let value): try c.encode(value) }
    }
    var display: String {
        switch self { case .null: "none"; case .text(let value): String(value.prefix(180)); case .number(let value): String(value); case .bool(let value): String(value) }
    }
}

public enum WorkweftBridgeMerge {
    public static func preview(base: WorkweftCanvasDocument, local: WorkweftCanvasDocument, incoming: WorkweftCanvasDocument, choices: [String: WorkweftBridgeChoice] = [:]) throws -> WorkweftBridgeMergePreview {
        try base.validate(); try local.validate(); try incoming.validate()
        var conflicts: [WorkweftBridgeConflict] = []
        func choose<T: Equatable>(_ b: T?, _ l: T?, _ r: T?, id: String, label: String, display: (T?) -> String) -> T? {
            if l == r { return l }; if l == b { return r }; if r == b { return l }
            conflicts.append(.init(id: id, label: label, local: display(l), incoming: display(r)))
            return choices[id] == .incoming ? r : l
        }
        func fields<T: Codable>(_ item: T) throws -> [String: BridgeScalar] { try JSONDecoder().decode([String: BridgeScalar].self, from: JSONEncoder().encode(item)) }
        func combine<T: Codable>(_ b: T, _ l: T, _ r: T, prefix: String) throws -> T {
            let b = try fields(b), l = try fields(l), r = try fields(r)
            var merged: [String: BridgeScalar] = [:]
            for key in Set(b.keys).union(l.keys).union(r.keys).sorted() {
                merged[key] = choose(b[key], l[key], r[key], id: prefix + ":" + key, label: prefix + " · " + key, display: { $0?.display ?? "deleted" })
            }
            return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(merged))
        }
        func records<T: Codable & Equatable & Identifiable>(_ b: [T], _ l: [T], _ r: [T], prefix: String) throws -> [T] where T.ID == String {
            let b = Dictionary(uniqueKeysWithValues: b.map { ($0.id, $0) }), l = Dictionary(uniqueKeysWithValues: l.map { ($0.id, $0) }), r = Dictionary(uniqueKeysWithValues: r.map { ($0.id, $0) })
            var merged: [T] = []
            for id in Set(b.keys).union(l.keys).union(r.keys).sorted() {
                if let bv = b[id], let lv = l[id], let rv = r[id] { merged.append(try combine(bv, lv, rv, prefix: prefix + ":" + id)) }
                else if let value = choose(b[id], l[id], r[id], id: prefix + ":" + id + ":record", label: prefix + " · " + id, display: { $0 == nil ? "deleted" : "present / changed" }) { merged.append(value) }
            }
            return merged
        }
        let viewport: WorkweftCanvasViewport = try combine(base.viewport, local.viewport, incoming.viewport, prefix: "viewport")
        let nodes = try records(base.nodes, local.nodes, incoming.nodes, prefix: "node")
        let edges = try records(base.edges, local.edges, incoming.edges, prefix: "edge")
        var document = WorkweftCanvasDocument(viewport: viewport, nodes: nodes, edges: edges)
        var structuralError: Error?
        do { try document.validate() } catch { structuralError = error }
        if structuralError != nil || choices["structure"] != nil {
            conflicts.append(.init(id: "structure", label: "Structure conflict: this choice replaces the WHOLE graph, including other field choices.", local: "Keep the entire local canvas", incoming: "Use the entire incoming canvas"))
            document = choices["structure"] == .incoming ? incoming : local
        }
        let unresolved = conflicts.filter { choices[$0.id] == nil }
        if unresolved.isEmpty { try document.validate() }
        guard Set(choices.keys).isSubset(of: Set(conflicts.map(\.id))) else { throw WorkweftBridgeError("Conflict choices do not belong to this preview.") }
        return .init(document: document.canonical, conflicts: conflicts, unresolved: unresolved)
    }
}
