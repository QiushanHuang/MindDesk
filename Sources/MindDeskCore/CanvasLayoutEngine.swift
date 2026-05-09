import Foundation

public struct CanvasLayoutNode: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CanvasLayoutEdge: Codable, Equatable, Sendable {
    public var sourceNodeId: String
    public var targetNodeId: String

    public init(sourceNodeId: String, targetNodeId: String) {
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }
}

public enum CanvasLayoutEngine {
    public static func autoArrange(
        _ nodes: [CanvasLayoutNode],
        columns: Int = 3,
        spacing: Double = 48
    ) -> [CanvasLayoutNode] {
        gridArrange(
            nodes,
            columns: columns,
            startX: 0,
            startY: 0,
            horizontalSpacing: spacing,
            verticalSpacing: spacing
        )
    }

    public static func autoArrange(
        _ nodes: [CanvasLayoutNode],
        edges: [CanvasLayoutEdge],
        horizontalSpacing: Double = 96,
        verticalSpacing: Double = 56,
        disconnectedColumns: Int = 3
    ) -> [CanvasLayoutNode] {
        guard !nodes.isEmpty else { return nodes }

        let indexById = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })
        let validEdges = edges.filter { edge in
            edge.sourceNodeId != edge.targetNodeId &&
            indexById[edge.sourceNodeId] != nil &&
            indexById[edge.targetNodeId] != nil
        }

        guard !validEdges.isEmpty else {
            return gridArrange(
                nodes,
                columns: disconnectedColumns,
                startX: 0,
                startY: 0,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            )
        }

        let connectedIDs = Set(validEdges.flatMap { [$0.sourceNodeId, $0.targetNodeId] })
        let connectedNodes = nodes.filter { connectedIDs.contains($0.id) }
        let disconnectedNodes = nodes.filter { !connectedIDs.contains($0.id) }
        let layers = workflowLayers(nodes: connectedNodes, edges: validEdges, indexById: indexById)
        var arranged = arrangeLayers(
            nodes: connectedNodes,
            layers: layers,
            startX: 0,
            startY: 0,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )

        if !disconnectedNodes.isEmpty {
            let workflowBottom = arranged.map { $0.y + $0.height }.max() ?? 0
            arranged += gridArrange(
                disconnectedNodes,
                columns: disconnectedColumns,
                startX: 0,
                startY: workflowBottom + verticalSpacing * 2,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing
            )
        }

        let arrangedById = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0) })
        return nodes.map { arrangedById[$0.id] ?? $0 }
    }

    public static func alignLeft(_ nodes: [CanvasLayoutNode]) -> [CanvasLayoutNode] {
        guard let minX = nodes.map(\.x).min() else { return nodes }
        return nodes.map { node in
            var aligned = node
            aligned.x = minX
            return aligned
        }
    }

    public static func alignTop(_ nodes: [CanvasLayoutNode]) -> [CanvasLayoutNode] {
        guard let minY = nodes.map(\.y).min() else { return nodes }
        return nodes.map { node in
            var aligned = node
            aligned.y = minY
            return aligned
        }
    }

    private static func workflowLayers(
        nodes: [CanvasLayoutNode],
        edges: [CanvasLayoutEdge],
        indexById: [String: Int]
    ) -> [[String]] {
        let nodeIDs = Set(nodes.map(\.id))
        var adjacency: [String: [String]] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, []) })
        var incomingCount: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })

        for edge in edges where nodeIDs.contains(edge.sourceNodeId) && nodeIDs.contains(edge.targetNodeId) {
            adjacency[edge.sourceNodeId, default: []].append(edge.targetNodeId)
            incomingCount[edge.targetNodeId, default: 0] += 1
        }

        var layerById: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        var visitOrder: [String: Int] = [:]
        var ready = nodes
            .filter { incomingCount[$0.id, default: 0] == 0 }
            .map(\.id)
            .sorted { (indexById[$0] ?? 0) < (indexById[$1] ?? 0) }
        var readyOrder = Dictionary(uniqueKeysWithValues: ready.enumerated().map { ($0.element, $0.offset) })
        var nextReadyOrder = ready.count
        var visited: Set<String> = []

        while !ready.isEmpty {
            ready.sort {
                let lhsLayer = layerById[$0, default: 0]
                let rhsLayer = layerById[$1, default: 0]
                if lhsLayer != rhsLayer { return lhsLayer < rhsLayer }
                let lhsReady = readyOrder[$0] ?? Int.max
                let rhsReady = readyOrder[$1] ?? Int.max
                if lhsReady != rhsReady { return lhsReady < rhsReady }
                return (indexById[$0] ?? 0) < (indexById[$1] ?? 0)
            }
            let id = ready.removeFirst()
            guard !visited.contains(id) else { continue }
            visited.insert(id)
            visitOrder[id] = visitOrder.count

            for target in adjacency[id, default: []] {
                layerById[target] = max(layerById[target, default: 0], layerById[id, default: 0] + 1)
                incomingCount[target, default: 0] -= 1
                if incomingCount[target, default: 0] == 0 {
                    if readyOrder[target] == nil {
                        readyOrder[target] = nextReadyOrder
                        nextReadyOrder += 1
                    }
                    ready.append(target)
                }
            }
        }

        let cycleNodes = nodes
            .filter { !visited.contains($0.id) }
            .sorted { (indexById[$0.id] ?? 0) < (indexById[$1.id] ?? 0) }
        for node in cycleNodes {
            let incomingLayers = edges
                .filter { $0.targetNodeId == node.id && nodeIDs.contains($0.sourceNodeId) }
                .compactMap { layerById[$0.sourceNodeId] }
            if let maxIncoming = incomingLayers.max() {
                layerById[node.id] = max(layerById[node.id, default: 0], maxIncoming + 1)
            }
            visitOrder[node.id] = visitOrder.count
        }

        let grouped = Dictionary(grouping: nodes.map(\.id)) { layerById[$0, default: 0] }
        return grouped.keys.sorted().map { layer in
            grouped[layer, default: []].sorted {
                let lhsOrder = visitOrder[$0] ?? Int.max
                let rhsOrder = visitOrder[$1] ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return (indexById[$0] ?? 0) < (indexById[$1] ?? 0)
            }
        }
    }

    private static func arrangeLayers(
        nodes: [CanvasLayoutNode],
        layers: [[String]],
        startX: Double,
        startY: Double,
        horizontalSpacing: Double,
        verticalSpacing: Double
    ) -> [CanvasLayoutNode] {
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let layerWidths = layers.map { layer in
            layer.compactMap { nodeById[$0]?.width }.max() ?? 0
        }
        var x = startX
        var arrangedById: [String: CanvasLayoutNode] = [:]

        for (layerIndex, layer) in layers.enumerated() {
            var y = startY
            for id in layer {
                guard var node = nodeById[id] else { continue }
                node.x = x
                node.y = y
                arrangedById[id] = node
                y += node.height + verticalSpacing
            }
            x += layerWidths[layerIndex] + horizontalSpacing
        }

        return nodes.compactMap { arrangedById[$0.id] }
    }

    private static func gridArrange(
        _ nodes: [CanvasLayoutNode],
        columns: Int,
        startX: Double,
        startY: Double,
        horizontalSpacing: Double,
        verticalSpacing: Double
    ) -> [CanvasLayoutNode] {
        let safeColumns = max(columns, 1)
        let columnWidths = (0..<safeColumns).map { column in
            nodes.enumerated()
                .filter { $0.offset % safeColumns == column }
                .map(\.element.width)
                .max() ?? 0
        }
        let rows = stride(from: 0, to: nodes.count, by: safeColumns).map { rowStart in
            Array(nodes[rowStart..<min(rowStart + safeColumns, nodes.count)])
        }
        let rowHeights = rows.map { row in
            row.map(\.height).max() ?? 0
        }

        var xOffsets: [Double] = []
        var nextX = startX
        for width in columnWidths {
            xOffsets.append(nextX)
            nextX += width + horizontalSpacing
        }

        var arranged: [CanvasLayoutNode] = []
        var nextY = startY
        for (rowIndex, row) in rows.enumerated() {
            for (column, node) in row.enumerated() {
                var arrangedNode = node
                arrangedNode.x = xOffsets[column]
                arrangedNode.y = nextY
                arranged.append(arrangedNode)
            }
            nextY += rowHeights[rowIndex] + verticalSpacing
        }
        return arranged
    }
}
