import MindDeskCore
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum CanvasInteractionMode: String, CaseIterable, Identifiable {
    case select
    case connect
    case boxSelect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select"
        case .connect: "Connect"
        case .boxSelect: "Box Select"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .connect: "point.3.connected.trianglepath.dotted"
        case .boxSelect: "selection.pin.in.out"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .select: "1"
        case .connect: "2"
        case .boxSelect: "3"
        }
    }
}

private struct CanvasEdgeSegment: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
    let startDirection: CGPoint
    let endDirection: CGPoint
    let control: CGPoint?
    let routePoints: [CGPoint]
    let isControlPointLocked: Bool
}

private struct CanvasNodeDeletionSnapshot {
    let id: String
    let canvasId: String
    let title: String
    let body: String
    let nodeTypeRaw: String
    let objectType: String?
    let objectId: String?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let collapsed: Bool
    let parentNodeId: String?
    let zIndex: Double
    let locked: Bool
    let styleRaw: String
    let accentColorRaw: String
    let createdAt: Date
    let updatedAt: Date

    init(_ node: CanvasNodeModel) {
        id = node.id
        canvasId = node.canvasId
        title = node.title
        body = node.body
        nodeTypeRaw = node.nodeTypeRaw
        objectType = node.objectType
        objectId = node.objectId
        x = node.x
        y = node.y
        width = node.width
        height = node.height
        collapsed = node.collapsed
        parentNodeId = node.parentNodeId
        zIndex = node.zIndex
        locked = node.locked
        styleRaw = node.styleRaw
        accentColorRaw = node.accentColorRaw
        createdAt = node.createdAt
        updatedAt = node.updatedAt
    }

    func makeModel() -> CanvasNodeModel {
        CanvasNodeModel(
            id: id,
            canvasId: canvasId,
            title: title,
            body: body,
            nodeType: CanvasNodeKind(rawValue: nodeTypeRaw) ?? .note,
            objectType: objectType,
            objectId: objectId,
            x: x,
            y: y,
            width: width,
            height: height,
            collapsed: collapsed,
            parentNodeId: parentNodeId,
            zIndex: zIndex,
            locked: locked,
            styleRaw: styleRaw,
            accentColorRaw: accentColorRaw,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct CanvasEdgeDeletionSnapshot {
    let id: String
    let canvasId: String
    let sourceNodeId: String
    let targetNodeId: String
    let label: String
    let style: String
    let sourceArrowRaw: String
    let targetArrowRaw: String
    let animated: Bool
    let animationThemeRaw: String
    let controlPointX: Double?
    let controlPointY: Double?
    let createdAt: Date
    let updatedAt: Date

    init(_ edge: CanvasEdgeModel) {
        id = edge.id
        canvasId = edge.canvasId
        sourceNodeId = edge.sourceNodeId
        targetNodeId = edge.targetNodeId
        label = edge.label
        style = edge.style
        sourceArrowRaw = edge.sourceArrowRaw
        targetArrowRaw = edge.targetArrowRaw
        animated = edge.animated
        animationThemeRaw = edge.animationThemeRaw
        controlPointX = edge.controlPointX
        controlPointY = edge.controlPointY
        createdAt = edge.createdAt
        updatedAt = edge.updatedAt
    }

    func makeModel() -> CanvasEdgeModel {
        CanvasEdgeModel(
            id: id,
            canvasId: canvasId,
            sourceNodeId: sourceNodeId,
            targetNodeId: targetNodeId,
            label: label,
            style: style,
            sourceArrowRaw: sourceArrowRaw,
            targetArrowRaw: targetArrowRaw,
            animated: animated,
            animationThemeRaw: animationThemeRaw,
            controlPointX: controlPointX,
            controlPointY: controlPointY,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct CanvasChildParentSnapshot {
    let id: String
    let parentNodeId: String?

    init(_ node: CanvasNodeModel) {
        id = node.id
        parentNodeId = node.parentNodeId
    }
}

private func fetchCanvasNodeForUndo(id: String, in context: ModelContext) -> CanvasNodeModel? {
    let nodeId = id
    let descriptor = FetchDescriptor<CanvasNodeModel>(
        predicate: #Predicate { node in
            node.id == nodeId
        }
    )
    return try? context.fetch(descriptor).first
}

enum CanvasGlowTheme: String, CaseIterable, Identifiable {
    case blue
    case minimal
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blue"
        case .minimal: "Minimal"
        case .off: "Off"
        }
    }
}

private enum CanvasNodeMetrics {
    static let cardWidth = 214.0
    static let cardHeight = 132.0
    static let cardMinWidth = 180.0
    static let cardMinHeight = 112.0
    static let noteWidth = 240.0
    static let noteHeight = 180.0
    static let noteMinWidth = 180.0
    static let noteMinHeight = 140.0
    static let frameWidth = 360.0
    static let frameHeight = 250.0
    static let frameMinWidth = 240.0
    static let frameMinHeight = 160.0
    static let edgeTargetClearance = CanvasEdgeRouteDefaults.targetClearance
    static let edgeRoutingClearance = CanvasEdgeRouteDefaults.routingClearance
    static let zoomBaseline = CanvasZoomBaseline.standardBaseline
    static let zoomMinimum = CanvasZoomBaseline.minimumZoom
    static let zoomMaximum = CanvasZoomBaseline.maximumZoom
    static let zoomDisplayStep = 0.1
    static let interactionHitSlop = CanvasInteractionMetrics.nodeHitSlop
    static let viewportOverscan = 240.0
    static let denseEdgeHandleLimit = 48
    static let scrollZoomCommitDelayNanos: UInt64 = 450_000_000
    static let scrollZoomCommitZoomEpsilon = 0.001
    static let scrollZoomCommitViewportEpsilon = 0.5
    static let textEditCommitDelayNanos: UInt64 = 350_000_000
}

private struct CanvasRenderSnapshot {
    let workflowNodes: [CanvasNodeModel]
    let nodeById: [String: CanvasNodeModel]
    let resourcesById: [String: ResourcePinModel]
    let snippetsById: [String: SnippetModel]
    let visibleEdges: [CanvasEdgeModel]
    let frameNodes: [CanvasNodeModel]
    let cardNodes: [CanvasNodeModel]
    let connectedNodeIDs: Set<String>

    init(nodes: [CanvasNodeModel], resources: [ResourcePinModel], snippets: [SnippetModel], edges: [CanvasEdgeModel]) {
        let nodeLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        workflowNodes = nodes
        nodeById = nodeLookup
        resourcesById = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        snippetsById = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
        visibleEdges = edges.filter { nodeLookup[$0.sourceNodeId] != nil && nodeLookup[$0.targetNodeId] != nil }
        frameNodes = nodes.filter { $0.nodeType == .groupFrame }.sorted { $0.updatedAt < $1.updatedAt }
        cardNodes = nodes.filter { $0.nodeType != .groupFrame }.sorted { $0.zIndex < $1.zIndex }
        connectedNodeIDs = Set(visibleEdges.flatMap { [$0.sourceNodeId, $0.targetNodeId] })
    }

    func resource(for node: CanvasNodeModel) -> ResourcePinModel? {
        guard node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    func snippet(for node: CanvasNodeModel) -> SnippetModel? {
        guard node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    func edgeSegments(
        targetClearance: Double,
        routingClearance: Double,
        usesObstacleRouting: Bool = true,
        rectFor: (CanvasNodeModel) -> CanvasFrameRect,
        controlPointFor: (CanvasEdgeModel) -> CGPoint?,
        shouldIncludeEdge: ((CanvasEdgeModel, CanvasFrameRect, CanvasFrameRect, CGPoint?) -> Bool)? = nil
    ) -> [CanvasEdgeSegment] {
        let nodeRects: [String: CanvasFrameRect] = Dictionary(uniqueKeysWithValues: workflowNodes.map { ($0.id, rectFor($0)) })
        let obstacleRects = nodeRects.compactMap { id, rect -> (id: String, rect: CanvasFrameRect)? in
            guard nodeById[id]?.nodeType != .groupFrame else { return nil }
            return (id: id, rect: rect)
        }
        return visibleEdges.compactMap { edge -> CanvasEdgeSegment? in
            guard let source = nodeById[edge.sourceNodeId],
                  let target = nodeById[edge.targetNodeId],
                  let sourceRect = nodeRects[source.id],
                  let targetRect = nodeRects[target.id] else {
                return nil
            }
            let control = controlPointFor(edge)
            if let shouldIncludeEdge, !shouldIncludeEdge(edge, sourceRect, targetRect, control) {
                return nil
            }
            let controlPoint = control.map { CanvasEdgePoint(x: $0.x, y: $0.y) }
            let anchors = CanvasEdgeAnchoring.anchors(
                source: sourceRect,
                target: targetRect,
                control: controlPoint,
                targetClearance: targetClearance
            )
            let routePoints: [CanvasEdgePoint]
            if usesObstacleRouting {
                let edgeObstacleRects = obstacleRects.compactMap { obstacle -> CanvasFrameRect? in
                    obstacle.id == source.id || obstacle.id == target.id ? nil : obstacle.rect
                }
                if let controlPoint {
                    routePoints = CanvasEdgeRoutePlanner.routePoints(
                        start: anchors.start,
                        end: anchors.end,
                        waypoints: [controlPoint],
                        startDirection: anchors.startDirection,
                        endDirection: anchors.endDirection,
                        obstacles: edgeObstacleRects,
                        clearance: routingClearance
                    )
                } else {
                    routePoints = CanvasEdgeRoutePlanner.routePoints(
                        start: anchors.start,
                        end: anchors.end,
                        startDirection: anchors.startDirection,
                        endDirection: anchors.endDirection,
                        obstacles: edgeObstacleRects,
                        clearance: routingClearance
                    )
                }
            } else if let controlPoint {
                routePoints = [controlPoint]
            } else {
                routePoints = []
            }
            return CanvasEdgeSegment(
                id: edge.id,
                start: CGPoint(x: anchors.start.x, y: anchors.start.y),
                end: CGPoint(x: anchors.end.x, y: anchors.end.y),
                startDirection: CGPoint(x: anchors.startDirection.x, y: anchors.startDirection.y),
                endDirection: CGPoint(x: anchors.endDirection.x, y: anchors.endDirection.y),
                control: control,
                routePoints: routePoints.map { CGPoint(x: $0.x, y: $0.y) },
                isControlPointLocked: CanvasEdgeStyleOptions.isControlPointLocked(edge.style)
            )
        }
    }
}

private struct CanvasNodeDragSnapshot {
    let id: String
    let nodeType: CanvasNodeKind
    let rect: CanvasFrameRect
}

private struct CanvasNodeDragStart {
    let x: Double
    let y: Double
    let parentNodeId: String?
}

private struct CanvasEdgeControlPointSnapshot {
    let id: String
    let x: Double
    let y: Double
}

private struct WorkspaceResourceMenuGroup {
    let workspaceId: String
    let title: String
    let resources: [ResourcePinModel]
}

struct WorkspaceCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferenceKeys.canvasScrollZoomDirection) private var scrollZoomDirectionRaw = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen) private var todoPanelDefaultOpen = true
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen) private var todoDoneColumnDefaultOpen = false
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen) private var isTodoDoneColumnOpen = false
    @AppStorage(AppPreferenceKeys.canvasConnectSingleShot) private var connectSingleShot = true
    let canvas: CanvasModel
    let resources: [ResourcePinModel]
    let allResources: [ResourcePinModel]
    let workspaces: [WorkspaceModel]
    let snippets: [SnippetModel]
    let todos: [WorkspaceTodoModel]
    let todoGroups: [WorkspaceTodoGroupModel]
    let nodes: [CanvasNodeModel]
    let edges: [CanvasEdgeModel]
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onOpenWorkspace: (String) -> Void

    @State private var selectedNodeIDs: Set<String> = []
    @State private var selectedEdgeIDs: Set<String> = []
    @State private var mode: CanvasInteractionMode = .select
    @State private var connectionSourceNodeId: String?
    @State private var selectionRect: CGRect?
    @State private var nodeDragStart: [String: CanvasNodeDragStart] = [:]
    @State private var nodeDragSnapshots: [String: CanvasNodeDragSnapshot] = [:]
    @State private var transientNodeOffsets: [String: CGSize] = [:]
    @State private var transientViewportOffset: CGSize = .zero
    @State private var transientZoomViewportOffset: CGSize = .zero
    @State private var zoomStart: Double?
    @State private var transientZoom: Double?
    @State private var isDropTarget = false
    @State private var suppressedTapNodeId: String?
    @State private var resizeStartSizes: [String: CGSize] = [:]
    @State private var transientNodeSizes: [String: CGSize] = [:]
    @State private var resizingNodeId: String?
    @State private var isCanvasInspectorVisible = false
    @State private var isTodoPanelOpen = true
    @State private var isTodoPanelInitialized = false
    @State private var didAlignLeftRailScroll = false
    @State private var edgeControlDragStart: [String: CGPoint] = [:]
    @State private var transientEdgeControlPoints: [String: CGPoint] = [:]
    @State private var frameDragControlPointEdgeIDs: Set<String> = []
    @State private var webCardDraft = ""
    @State private var pendingScrollZoomCommit: Task<Void, Never>?
    @State private var pendingNodeTextCommitTasks: [String: Task<Void, Never>] = [:]
    @Environment(\.undoManager) private var undoManager

    private var zoom: CGFloat {
        CGFloat(effectiveZoom)
    }

    private var effectiveZoom: Double {
        CanvasZoomScale.clamped(transientZoom ?? canvas.zoom, minimum: CanvasNodeMetrics.zoomMinimum, maximum: CanvasNodeMetrics.zoomMaximum)
    }

    private var zoomBaseline: Double {
        CanvasZoomBaseline.actualZoom(
            percent: canvasDefaultZoomPercent,
            standardBaseline: CanvasNodeMetrics.zoomBaseline,
            minimum: CanvasNodeMetrics.zoomMinimum,
            maximum: CanvasNodeMetrics.zoomMaximum
        )
    }

    private var effectiveViewportX: Double {
        canvas.viewportX + Double(transientViewportOffset.width) + Double(transientZoomViewportOffset.width)
    }

    private var effectiveViewportY: Double {
        canvas.viewportY + Double(transientViewportOffset.height) + Double(transientZoomViewportOffset.height)
    }

    private var workflowNodes: [CanvasNodeModel] {
        nodes
    }

    private var workflowNodeById: [String: CanvasNodeModel] {
        Dictionary(uniqueKeysWithValues: workflowNodes.map { ($0.id, $0) })
    }

    private var resourcesById: [String: ResourcePinModel] {
        Dictionary(uniqueKeysWithValues: allResources.map { ($0.id, $0) })
    }

    private var snippetsById: [String: SnippetModel] {
        Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
    }

    private var workspacesById: [String: WorkspaceModel] {
        Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0) })
    }

    private var visibleEdges: [CanvasEdgeModel] {
        edges.filter { workflowNodeById[$0.sourceNodeId] != nil && workflowNodeById[$0.targetNodeId] != nil }
    }

    private var glowTheme: CanvasGlowTheme {
        CanvasGlowTheme(rawValue: canvas.linkAnimationThemeRaw) ?? .blue
    }

    private var shouldAnimateGlow: Bool {
        shouldAnimateGlow(edgeCount: visibleEdges.count)
    }

    private func shouldAnimateGlow(edgeCount: Int) -> Bool {
        CanvasEdgeAnimationPolicy.shouldAnimateEdge(
            theme: canvas.linkAnimationThemeRaw,
            animationsEnabled: canvas.animationsEnabled,
            reduceMotion: reduceMotion,
            edgeCount: edgeCount,
            isInteracting: isCanvasInteracting
        )
    }

    private var isCanvasInteracting: Bool {
        !nodeDragStart.isEmpty ||
            transientViewportOffset != .zero ||
            transientZoomViewportOffset != .zero ||
            transientZoom != nil ||
            resizingNodeId != nil ||
            !edgeControlDragStart.isEmpty
    }

    private var renderSnapshot: CanvasRenderSnapshot {
        CanvasRenderSnapshot(nodes: workflowNodes, resources: allResources, snippets: snippets, edges: edges)
    }

    private var globalResources: [ResourcePinModel] {
        orderedResourceMenuItems(allResources.filter { $0.scope == .global })
    }

    private var currentWorkspaceResources: [ResourcePinModel] {
        orderedResourceMenuItems(allResources.filter { $0.scope == .workspace && $0.workspaceId == canvas.workspaceId })
    }

    private var otherWorkspaceResourceGroups: [WorkspaceResourceMenuGroup] {
        let titleByWorkspaceId = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0.title) })
        let grouped = Dictionary(grouping: allResources.filter { $0.scope == .workspace && $0.workspaceId != canvas.workspaceId }) {
            $0.workspaceId ?? ""
        }
        return grouped
            .filter { !$0.key.isEmpty }
            .map { workspaceId, resources in
                WorkspaceResourceMenuGroup(
                    workspaceId: workspaceId,
                    title: titleByWorkspaceId[workspaceId] ?? workspaceId,
                    resources: orderedResourceMenuItems(resources)
                )
            }
            .sorted {
                let comparison = $0.title.localizedStandardCompare($1.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return $0.workspaceId < $1.workspaceId
            }
    }

    private func orderedResourceMenuItems(_ resources: [ResourcePinModel]) -> [ResourcePinModel] {
        resources.sorted {
            let nameComparison = $0.displayName.localizedStandardCompare($1.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    @discardableResult
    private func saveModelChanges(failurePrefix: String, successStatus: String? = nil) -> Bool {
        do {
            try modelContext.save()
            if let successStatus {
                onStatus(successStatus)
            }
            return true
        } catch {
            modelContext.rollback()
            onStatus("\(failurePrefix): \(error.localizedDescription)")
            return false
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let taskPanelHeight = todoPanelHeight(for: proxy.size.height)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    canvasLeftRail
                        .frame(width: CanvasSideRailLayout.leftRailWidth)
                    canvasSurface
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if isCanvasInspectorVisible {
                        canvasRightRail
                            .frame(width: CanvasSideRailLayout.rightRailWidth(availableWidth: proxy.size.width))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }

                WorkspaceTodoBoardView(
                    workspaceId: canvas.workspaceId,
                    resources: resources,
                    todos: todos,
                    groups: todoGroups,
                    isOpen: $isTodoPanelOpen,
                    isDoneColumnOpen: $isTodoDoneColumnOpen,
                    onStatus: onStatus,
                    expandedHeight: taskPanelHeight
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.16), value: isCanvasInspectorVisible)
        .animation(.easeInOut(duration: 0.16), value: isTodoPanelOpen)
        .animation(.easeInOut(duration: 0.16), value: isTodoDoneColumnOpen)
        .onAppear {
            if !isTodoPanelInitialized {
                isTodoPanelOpen = todoPanelDefaultOpen
                isTodoDoneColumnOpen = todoDoneColumnDefaultOpen
                isTodoPanelInitialized = true
            }
        }
            .onDisappear {
                flushPendingScrollZoomCommit()
                flushPendingNodeTextCommits()
            }
            .onChange(of: canvasDefaultZoomPercent) { _, _ in
                setZoom(zoomBaseline)
                onStatus("Canvas 100% baseline updated")
            }
            .onChange(of: edges.map(\.id)) { _, edgeIDs in
                selectedEdgeIDs.formIntersection(Set(edgeIDs))
            }
            .background(canvasCommandShortcuts.frame(width: 0, height: 0).opacity(0))
    }

    private var canvasCommandShortcuts: some View {
        Group {
            Button("Start Link From Selected Card") {
                startLinkCommand()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(selectedNode == nil)

            Button("Connect Selected Cards") {
                connectSelected()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(selectedNodeIDs.count != 2)

            Button("Reverse Selected Link") {
                reverseSelectedLink()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(selectedEdgeIDs.count != 1)
        }
        .accessibilityHidden(true)
    }

    private func todoPanelHeight(for availableHeight: CGFloat) -> CGFloat {
        guard isTodoPanelOpen else { return 42 }
        return min(220, max(120, availableHeight * 0.16))
    }

    private var canvasLeftRail: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                Color.clear
                    .frame(height: 0)
                    .id("canvas-left-rail-top")

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Canvas")
                            .font(.headline)
                        Text("Place resources and connect the workflow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button {
                        isCanvasInspectorVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(isCanvasInspectorVisible ? .accentColor : nil)
                    .help(isCanvasInspectorVisible ? "Hide canvas inspector" : "Show canvas inspector")
                }

                Button {
                    isTodoPanelOpen.toggle()
                } label: {
                    Label(isTodoPanelOpen ? "Close Todo Page" : "Open Todo Page", systemImage: "checklist")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(isTodoPanelOpen ? .accentColor : nil)
                .help(isTodoPanelOpen ? "Close workspace todo page" : "Open workspace todo page")

                GroupBox("Add") {
                    VStack(alignment: .leading, spacing: 8) {
                        Menu {
                            resourceMenuSection(title: "Global Library", resources: globalResources)
                            if !currentWorkspaceResources.isEmpty {
                                Divider()
                                resourceMenuSection(title: "Current Workspace", resources: currentWorkspaceResources)
                            }
                            if !otherWorkspaceResourceGroups.isEmpty {
                                Divider()
                                ForEach(otherWorkspaceResourceGroups, id: \.workspaceId) { group in
                                    Menu(group.title) {
                                        ForEach(group.resources) { resource in
                                            Button(resource.displayName) { addResourceNode(resource) }
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Resource", systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(allResources.isEmpty)

	                        Menu {
	                            ForEach(snippets) { snippet in
	                                Button(snippet.title) { addSnippetNode(snippet) }
	                            }
	                        } label: {
                            Label("Prompt / Command", systemImage: "text.badge.plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
	                        }
	                        .disabled(snippets.isEmpty)

	                        Menu {
	                            ForEach(workspaces.filter { $0.id != canvas.workspaceId }) { workspace in
	                                Button(workspace.title) { addWorkspaceNode(workspace) }
	                            }
	                        } label: {
	                            Label("Workspace", systemImage: "rectangle.3.group")
	                                .frame(maxWidth: .infinity, alignment: .leading)
	                        }
	                        .disabled(workspaces.filter { $0.id != canvas.workspaceId }.isEmpty)

	                        HStack(spacing: 6) {
	                            TextField("example.com", text: $webCardDraft)
	                                .textFieldStyle(.roundedBorder)
	                                .onSubmit(addWebNode)
	                            Button {
	                                addWebNode()
	                            } label: {
	                                Image(systemName: "globe.badge.plus")
	                                    .frame(width: 22)
	                            }
	                            .help("Add web page card")
	                        }

	                        Button {
	                            addNoteNode()
	                        } label: {
                            Label("Note", systemImage: "note.text.badge.plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            addFrameNode()
                        } label: {
                            Label("Organization Frame", systemImage: "rectangle.dashed")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                GroupBox("Mode") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(CanvasInteractionMode.allCases) { item in
                            Button {
                                mode = item
                                selectionRect = nil
                                connectionSourceNodeId = nil
                            } label: {
                                Label(item.title, systemImage: item.systemImage)
                                    .frame(maxWidth: .infinity, alignment: .leading)
	                            }
	                            .buttonStyle(.bordered)
	                            .tint(mode == item ? .accentColor : nil)
	                            .keyboardShortcut(item.shortcut, modifiers: .command)
	                        }

                        Toggle("Single Connect", isOn: $connectSingleShot)
                            .toggleStyle(.checkbox)
                            .help("After creating a link, return to Select mode.")
                    }
                }

                GroupBox("Zoom") {
                    HStack {
                        Button {
                            setZoom(effectiveZoom - zoomBaseline * CanvasNodeMetrics.zoomDisplayStep)
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        Button {
                            setZoom(zoomBaseline)
                        } label: {
                            Text("\(CanvasZoomScale.displayPercent(forZoom: effectiveZoom, baseline: zoomBaseline))%")
                                .monospacedDigit()
                        }
                        .help("Reset canvas scale to 100%")
                        Button {
                            setZoom(effectiveZoom + zoomBaseline * CanvasNodeMetrics.zoomDisplayStep)
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                GroupBox("Glow") {
                    Picker("Glow", selection: Binding(
                        get: { glowTheme },
                        set: { theme in
                            canvas.linkAnimationThemeRaw = theme.rawValue
                            canvas.animationsEnabled = theme != .off
                            canvas.updatedAt = .now
                            saveModelChanges(failurePrefix: "Could not save glow setting")
                        }
                    )) {
                        ForEach(CanvasGlowTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .defaultScrollAnchor(.top)
            .onAppear {
            guard !didAlignLeftRailScroll else { return }
            didAlignLeftRailScroll = true
            DispatchQueue.main.async {
                proxy.scrollTo("canvas-left-rail-top", anchor: .top)
            }
        }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func resourceMenuSection(title: String, resources: [ResourcePinModel]) -> some View {
        if resources.isEmpty {
            Text("\(title): None")
                .foregroundStyle(.secondary)
        } else {
            Menu(title) {
                ForEach(resources) { resource in
                    Button(resource.displayName) { addResourceNode(resource) }
                }
            }
        }
    }

    private var canvasRightRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("Selection") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

	                        Button { openSelectedNode() } label: {
	                            Label("Open", systemImage: "arrow.up.forward.app")
	                                .frame(maxWidth: .infinity, alignment: .leading)
	                        }
	                        .disabled(selectedNode == nil)

                        Button { copySelectedNode() } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNode == nil)

                        Button { createAliasForSelectedNode() } label: {
                            Label("Alias", systemImage: "arrowshape.turn.up.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedResource == nil)

                        Button(role: .destructive) { deleteSelectedNodes() } label: {
                            Label("Delete Card", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNodeIDs.isEmpty)
                    }
                    .buttonStyle(.bordered)
                }

                GroupBox("Connections") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(connectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button { connectSelected() } label: {
                            Label("Connect Selected", systemImage: "link")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNodeIDs.count != 2)

                        Button { startLinkCommand() } label: {
                            Label("Start Link From Card", systemImage: "arrowshape.turn.up.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNode == nil)

                        Button { reverseSelectedLink() } label: {
                            Label("Reverse Selected Link", systemImage: "arrow.left.arrow.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedEdgeIDs.count != 1)

		                        Button(role: .destructive) { deleteSelectedConnections() } label: {
		                            Label(selectedEdgeIDs.isEmpty ? "Delete Link Between Cards" : "Delete Selected Link", systemImage: "link.badge.minus")
		                                .frame(maxWidth: .infinity, alignment: .leading)
	                        }
	                        .disabled(selectedEdgeIDs.isEmpty && selectedNodeIDs.count != 2)
                    }
                    .buttonStyle(.bordered)
                }

                GroupBox("Card Color") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let selectedNode {
                            CanvasCardColorEditor(
                                styleRaw: selectedNode.accentColorRaw,
                                onStyleChange: { updateNodeColor(selectedNode, to: $0) }
                            )
                        } else {
                            Text("Select one card to edit its color.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                GroupBox("Layout") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { alignLeft() } label: {
                            Label("Align Left", systemImage: "align.horizontal.left")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNodeIDs.count < 2)

                        Button { alignTop() } label: {
                            Label("Align Top", systemImage: "align.vertical.top")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(selectedNodeIDs.count < 2)

                        Button { autoArrange() } label: {
                            Label("Auto Arrange", systemImage: "square.grid.3x3")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canvasSurface: some View {
        GeometryReader { proxy in
            let snapshot = renderSnapshot
            let nodeVisibleRect = visibleScreenRect(for: proxy.size)
            let edgeVisibleRect = edgeVisibleScreenRect(for: proxy.size)
            let visibleFrameNodes = snapshot.frameNodes.filter { shouldRenderNode($0, in: nodeVisibleRect) }
            let visibleCardNodes = snapshot.cardNodes.filter { shouldRenderNode($0, in: nodeVisibleRect) }
            let visibleResizeNodes = visibleFrameNodes + visibleCardNodes
            let usesObstacleRouting = CanvasPerformancePolicy.usesObstacleRouting(
                edgeCount: snapshot.visibleEdges.count,
                obstacleCount: snapshot.cardNodes.count,
                isInteracting: isCanvasInteracting
            )
            let edgeSegments = snapshot.edgeSegments(
                targetClearance: CanvasNodeMetrics.edgeTargetClearance,
                routingClearance: CanvasNodeMetrics.edgeRoutingClearance,
                usesObstacleRouting: usesObstacleRouting,
                rectFor: screenRect(for:),
                controlPointFor: screenControlPoint(for:),
                shouldIncludeEdge: { edge, sourceRect, targetRect, control in
                    selectedEdgeIDs.contains(edge.id) ||
                        isPotentialEdgeVisible(sourceRect: sourceRect, targetRect: targetRect, control: control, in: edgeVisibleRect)
                }
            )
            .filter { isEdgeSegmentVisible($0, in: edgeVisibleRect) || selectedEdgeIDs.contains($0.id) }
            let animateVisibleEdges = shouldAnimateGlow(edgeCount: edgeSegments.count)
            ZStack(alignment: .topLeading) {
                    canvasBackground

                    ForEach(visibleFrameNodes) { node in
                        CanvasFrameCard(
                            node: node,
                            isSelected: selectedNodeIDs.contains(node.id),
                            isConnected: snapshot.connectedNodeIDs.contains(node.id),
                            glowTheme: glowTheme,
                            animateGlow: animateVisibleEdges,
                            glowPulse: animateVisibleEdges,
                            isConnectionSource: connectionSourceNodeId == node.id,
                            onInfo: { performCardButtonAction(node) { inspect(node) } },
                            onCopy: { performCardButtonAction(node) { copyNodePayload(node) } },
                            onStartLink: { performCardButtonAction(node) { startConnection(from: node) } },
                            onConnect: { performCardButtonAction(node) { connectButtonTapped(node) } },
                            onDelete: { performCardButtonAction(node) { delete(node) } },
                            onTitleChange: { updateNodeTitle(node, to: $0) },
                            onNoteChange: { updateNodeBody(node, to: $0) }
                        )
                        .frame(width: nodeSize(for: node).width, height: nodeSize(for: node).height)
                        .scaleEffect(zoom)
                        .frame(width: nodeSize(for: node).width * Double(zoom), height: nodeSize(for: node).height * Double(zoom))
                        .padding(CanvasNodeMetrics.interactionHitSlop)
                        .contentShape(.interaction, Rectangle())
                        .position(screenPoint(for: node))
                        .highPriorityGesture(dragGesture(for: node))
                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                            handleNodeTap(node)
                        })
                        .zIndex(0)
                    }

                edgeStrokeLayer(edgeSegments, animateVisibleEdges: animateVisibleEdges, canvasSize: proxy.size)
                    .zIndex(1.2)

	                ForEach(visibleCardNodes) { node in
	                    CanvasNodeCard(
	                        node: node,
	                        resource: snapshot.resource(for: node),
	                        snippet: snapshot.snippet(for: node),
	                        workspace: workspace(for: node),
	                        webURL: webURL(for: node),
	                        isSelected: selectedNodeIDs.contains(node.id),
                        isConnectionSource: connectionSourceNodeId == node.id,
                        isConnected: snapshot.connectedNodeIDs.contains(node.id),
                        glowTheme: glowTheme,
                        animateGlow: animateVisibleEdges,
                        glowPulse: animateVisibleEdges,
                        onOpen: { open(node) },
                        onInfo: { performCardButtonAction(node) { inspect(node) } },
                        onCopy: { performCardButtonAction(node) { copyNodePayload(node) } },
                        onStartLink: { performCardButtonAction(node) { startConnection(from: node) } },
                        onConnect: { performCardButtonAction(node) { connectButtonTapped(node) } },
                        onToggleNote: { performCardButtonAction(node) { toggleNote(for: node) } },
                        onDelete: { performCardButtonAction(node) { delete(node) } },
                        onTitleChange: { updateNodeTitle(node, to: $0) },
                        onNoteChange: { updateNodeBody(node, to: $0) }
                    )
                    .frame(width: nodeSize(for: node).width, height: nodeSize(for: node).height)
                    .scaleEffect(zoom)
                    .frame(width: nodeSize(for: node).width * Double(zoom), height: nodeSize(for: node).height * Double(zoom))
                    .padding(CanvasNodeMetrics.interactionHitSlop)
                    .contentShape(.interaction, Rectangle())
                    .position(screenPoint(for: node))
                    .highPriorityGesture(dragGesture(for: node))
                    .onTapGesture(count: 2) {
                        open(node)
                    }
                    .simultaneousGesture(TapGesture(count: 1).onEnded {
                        handleNodeTap(node)
                    })
                    .zIndex(2)
                }

                CanvasEdgeArrowHeadLayer(
                    segments: edgeSegments,
                    transientControlPoints: transientEdgeControlPoints,
                    selectedEdgeIDs: selectedEdgeIDs,
                    theme: glowTheme,
                    isAnimated: animateVisibleEdges,
                    arrowScale: zoom,
                    canvasSize: proxy.size
                )
                    .zIndex(2.7)

                ForEach(visibleResizeNodes) { node in
                    resizeHandle(for: node)
                        .zIndex(3.4)
                }

                ForEach(edgeSegments) { segment in
                    if shouldShowEdgeControlHandle(for: segment, edgeCount: snapshot.visibleEdges.count) {
                        EdgeControlHandle(
                            isCustom: (transientEdgeControlPoints[segment.id] ?? segment.control) != nil,
                            isLocked: segment.control != nil && segment.isControlPointLocked,
                            zoom: zoom
                        )
                            .position(edgeControlPoint(for: segment))
                            .highPriorityGesture(edgeControlDragGesture(for: segment))
                            .contextMenu {
                                if segment.control == nil {
                                    Button("Select Link") {
                                        selectEdge(segment.id)
                                    }
                                    Button("Add Free Bend Here") {
                                        addEdgeControlPoint(for: segment)
                                    }
                                } else {
                                    Button("Select Link") {
                                        selectEdge(segment.id)
                                    }
                                    Button(segment.isControlPointLocked ? "Unlock Anchor" : "Lock Anchor") {
                                        setEdgeControlPointLocked(!segment.isControlPointLocked, for: segment)
                                    }
                                    Button("Delete Bend", role: .destructive) {
                                        deleteEdgeControlPoint(for: segment)
                                    }
                                }
                                Divider()
                                Button("Reverse Link Direction") {
                                    selectedEdgeIDs = [segment.id]
                                    selectedNodeIDs = []
                                    reverseSelectedLink()
                                }
                                Button("Delete Link", role: .destructive) {
                                    selectedEdgeIDs = [segment.id]
                                    selectedNodeIDs = []
                                    deleteSelectedConnections()
                                }
                            }
                            .zIndex(3.1)
                    }
                }

                if let selectionRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay {
                            Rectangle()
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                        .zIndex(3)
                }
            }
            .overlay {
                CanvasScrollWheelMonitor { deltaY, location in
                    zoomFromScroll(deltaY: deltaY, location: location)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDropTarget ? Color.accentColor : .clear, lineWidth: 2)
            }
	            .gesture(backgroundDrag(in: proxy.size, edgeSegments: edgeSegments))
	            .simultaneousGesture(SpatialTapGesture().onEnded { value in
	                guard !backgroundDragStartsOnNode(value.location) else { return }
	                if !selectEdge(at: value.location, in: edgeSegments), mode == .select {
	                    selectedEdgeIDs = []
                        selectedNodeIDs = []
                        connectionSourceNodeId = nil
	                }
	            })
	            .onDeleteCommand(perform: handleDeleteCommand)
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                let start = zoomStart ?? canvas.zoom
                if zoomStart == nil {
                    zoomStart = start
                }
                transientZoom = CanvasZoomScale.clamped(
                    start * Double(value.magnification),
                    minimum: CanvasNodeMetrics.zoomMinimum,
                    maximum: CanvasNodeMetrics.zoomMaximum
                )
            }.onEnded { _ in
                if let transientZoom {
                    canvas.zoom = transientZoom
                    canvas.updatedAt = .now
                    saveModelChanges(failurePrefix: "Could not save canvas zoom")
                }
                zoomStart = nil
                transientZoom = nil
            })
            .onDrop(
                of: [UTType.fileURL],
                delegate: CanvasFileDropDelegate(isTargeted: $isDropTarget) { providers, location in
                    _ = FileDropLoader.loadFileURLs(from: providers) { urls in
                        importDroppedResources(urls, at: location)
                    }
                }
            )
        }
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canvasBackground: some View {
        Rectangle()
            .fill(.background)
            .overlay {
                GridPattern()
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .zIndex(-10)
    }

    @ViewBuilder
    private func edgeStrokeLayer(_ segments: [CanvasEdgeSegment], animateVisibleEdges: Bool, canvasSize: CGSize) -> some View {
        if animateVisibleEdges {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                CanvasEdgeStrokeLayer(
                    segments: segments,
                    transientControlPoints: transientEdgeControlPoints,
                    selectedEdgeIDs: selectedEdgeIDs,
                    theme: glowTheme,
                    dashPhase: CanvasEdgeFlowPhase.dashPhase(
                        elapsed: timeline.date.timeIntervalSinceReferenceDate,
                        duration: 1.6,
                        cycleLength: 172
                    ),
                    lineScale: zoom,
                    canvasSize: canvasSize
                )
            }
        } else {
            CanvasEdgeStrokeLayer(
                segments: segments,
                transientControlPoints: transientEdgeControlPoints,
                selectedEdgeIDs: selectedEdgeIDs,
                theme: glowTheme,
                dashPhase: nil,
                lineScale: zoom,
                canvasSize: canvasSize
            )
        }
    }

    private func visibleScreenRect(for size: CGSize) -> CGRect {
        let overscan = CGFloat(nodeOverscanPixels)
        return CGRect(origin: .zero, size: size).insetBy(
            dx: -overscan,
            dy: -overscan
        )
    }

    private func edgeVisibleScreenRect(for size: CGSize) -> CGRect {
        let overscan = CGFloat(nodeOverscanPixels + CanvasNodeMetrics.viewportOverscan)
        return CGRect(origin: .zero, size: size).insetBy(
            dx: -overscan,
            dy: -overscan
        )
    }

    private var nodeOverscanPixels: Double {
        min(640, max(220, 320 * sqrt(effectiveZoom / 0.35)))
    }

    private func isNodeVisible(_ node: CanvasNodeModel, in visibleRect: CGRect) -> Bool {
        let rect = screenRect(for: node)
        let nodeRect = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            .insetBy(dx: -CanvasNodeMetrics.interactionHitSlop, dy: -CanvasNodeMetrics.interactionHitSlop)
        return visibleRect.intersects(nodeRect)
    }

    private func isEdgeSegmentVisible(_ segment: CanvasEdgeSegment, in visibleRect: CGRect) -> Bool {
        let points = [segment.start] + segment.routePoints + (segment.control.map { [$0] } ?? []) + [segment.end]
        guard let first = points.first else { return false }
        let bounds = points.reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
        return visibleRect.intersects(
            bounds.insetBy(dx: -CanvasNodeMetrics.interactionHitSlop, dy: -CanvasNodeMetrics.interactionHitSlop)
        )
    }

    private func isPotentialEdgeVisible(sourceRect: CanvasFrameRect, targetRect: CanvasFrameRect, control: CGPoint?, in visibleRect: CGRect) -> Bool {
        let sourceBounds = CGRect(x: sourceRect.x, y: sourceRect.y, width: sourceRect.width, height: sourceRect.height)
        let targetBounds = CGRect(x: targetRect.x, y: targetRect.y, width: targetRect.width, height: targetRect.height)
        var bounds = sourceBounds.union(targetBounds)
        if let control {
            bounds = bounds.union(CGRect(origin: control, size: .zero))
        }
        let routingOverscan = CGFloat(max(CanvasNodeMetrics.viewportOverscan * 2, 900))
        return visibleRect.intersects(bounds.insetBy(dx: -routingOverscan, dy: -routingOverscan))
    }

    private func shouldShowEdgeControlHandle(for segment: CanvasEdgeSegment, edgeCount: Int) -> Bool {
        if selectedEdgeIDs.contains(segment.id) || transientEdgeControlPoints[segment.id] != nil {
            return true
        }
        if isCanvasInteracting {
            return false
        }
        if segment.control != nil || segment.isControlPointLocked {
            return true
        }
        return edgeCount <= 24 && effectiveZoom >= 0.30
    }

    private func shouldRenderNode(_ node: CanvasNodeModel, in visibleRect: CGRect) -> Bool {
        isNodeVisible(node, in: visibleRect) ||
            selectedNodeIDs.contains(node.id) ||
            nodeDragStart[node.id] != nil ||
            transientNodeOffsets[node.id] != nil ||
            connectionSourceNodeId == node.id
    }

    private func screenPoint(for node: CanvasNodeModel) -> CGPoint {
        let offset = transientNodeOffsets[node.id] ?? .zero
        let size = nodeSize(for: node)
        let point = CanvasViewportProjection.screenPoint(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height,
            offsetX: Double(offset.width),
            offsetY: Double(offset.height),
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
        return CGPoint(
            x: point.x,
            y: point.y
        )
    }

    private func screenRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let offset = transientNodeOffsets[node.id] ?? .zero
        let size = nodeSize(for: node)
        return CanvasViewportProjection.screenRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height,
            offsetX: Double(offset.width),
            offsetY: Double(offset.height),
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
    }

    private func screenHitRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let size = nodeSize(for: node)
        return CanvasViewportProjection.screenRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height,
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
    }

    private func backgroundDragStartsOnNode(_ point: CGPoint) -> Bool {
        let target = CanvasHitTesting.target(
            at: CanvasEdgePoint(x: Double(point.x), y: Double(point.y)),
            nodes: workflowNodes.map(screenHitRect(for:)),
            hitSlop: CanvasNodeMetrics.interactionHitSlop
        )
        if case .node = target {
            return true
        }
        return false
    }

    private func nodeSize(for node: CanvasNodeModel) -> (width: Double, height: Double) {
        if let size = transientNodeSizes[node.id] {
            return (Double(size.width), Double(size.height))
        }

        let size: CanvasNodeSize
        switch node.nodeType {
        case .groupFrame:
            size = CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.frameWidth,
                defaultHeight: CanvasNodeMetrics.frameHeight,
                minimumWidth: CanvasNodeMetrics.frameMinWidth,
                minimumHeight: CanvasNodeMetrics.frameMinHeight
            )
        case .note:
            size = CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.noteWidth,
                defaultHeight: CanvasNodeMetrics.noteHeight,
                minimumWidth: CanvasNodeMetrics.noteMinWidth,
                minimumHeight: CanvasNodeMetrics.noteMinHeight
            )
        case .resource, .snippet:
            size = CanvasNodeSizePolicy.size(
                kind: node.nodeType.rawValue,
                storedWidth: node.width,
                storedHeight: node.height,
                defaultWidth: CanvasNodeMetrics.cardWidth,
                defaultHeight: CanvasNodeMetrics.cardHeight,
                minimumWidth: CanvasNodeMetrics.cardMinWidth,
                minimumHeight: CanvasNodeMetrics.cardMinHeight
            )
        }
        return (size.width, size.height)
    }

    private func frameRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let size = nodeSize(for: node)
        return CanvasFrameRect(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
    }

    private func screenControlPoint(for edge: CanvasEdgeModel) -> CGPoint? {
        guard let x = edge.controlPointX, let y = edge.controlPointY else { return nil }
        let point = CanvasViewportProjection.screenPoint(
            x: x,
            y: y,
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
        return CGPoint(x: point.x, y: point.y)
    }

    private func edgeControlPoint(for segment: CanvasEdgeSegment) -> CGPoint {
        transientEdgeControlPoints[segment.id] ?? EdgePathFactory.handlePoint(
            start: segment.start,
            end: segment.end,
            control: segment.control,
            routePoints: segment.routePoints
        )
    }

    private func resizeHandle(for node: CanvasNodeModel) -> some View {
        let center = resizeHandleCenter(for: node)
        let hitSize = CanvasResizeHandleGeometry.baseHitSize * effectiveZoom
        return FrameResizeHandle(helpText: node.nodeType == .groupFrame ? "Resize frame" : "Resize card")
            .scaleEffect(zoom)
            .frame(width: hitSize, height: hitSize)
            .contentShape(.interaction, Rectangle())
            .position(center)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        resizeNode(node, screenTranslation: value.translation, commit: false)
                    }
                    .onEnded { value in
                        resizeNode(node, screenTranslation: value.translation, commit: true)
                    }
            )
    }

    private func resizeHandleCenter(for node: CanvasNodeModel) -> CGPoint {
        let screenRect = screenRect(for: node)
        let center = CanvasResizeHandleGeometry.center(in: screenRect, zoom: effectiveZoom)
        return CGPoint(x: center.x, y: center.y)
    }

    private func edgeControlDragGesture(for segment: CanvasEdgeSegment) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !(segment.control != nil && segment.isControlPointLocked) else { return }
                if edgeControlDragStart[segment.id] == nil {
                    edgeControlDragStart[segment.id] = edgeControlPoint(for: segment)
                }
                guard let start = edgeControlDragStart[segment.id] else { return }
                transientEdgeControlPoints[segment.id] = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
            }
            .onEnded { value in
                guard !(segment.control != nil && segment.isControlPointLocked) else {
                    transientEdgeControlPoints[segment.id] = nil
                    edgeControlDragStart[segment.id] = nil
                    onStatus("Anchor is locked")
                    return
                }
                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= 2 || segment.control != nil else {
                    transientEdgeControlPoints[segment.id] = nil
                    edgeControlDragStart[segment.id] = nil
                    return
                }
                let start = edgeControlDragStart[segment.id] ?? edgeControlPoint(for: segment)
	                let screenPoint = CGPoint(
	                    x: start.x + value.translation.width,
	                    y: start.y + value.translation.height
	                )
	                saveEdgeControlPoint(screenPoint, for: segment, status: "Adjusted link bend")
	                transientEdgeControlPoints[segment.id] = nil
	                edgeControlDragStart[segment.id] = nil
	            }
    }

    private func addEdgeControlPoint(for segment: CanvasEdgeSegment) {
        saveEdgeControlPoint(edgeControlPoint(for: segment), for: segment, status: "Added link anchor")
    }

    private func deleteEdgeControlPoint(for segment: CanvasEdgeSegment) {
        guard let edge = visibleEdges.first(where: { $0.id == segment.id }) else { return }
        let oldX = edge.controlPointX
        let oldY = edge.controlPointY
        let oldStyle = edge.style
        edge.controlPointX = nil
        edge.controlPointY = nil
        edge.style = CanvasEdgeStyleOptions.style(edge.style, controlPointLocked: false)
        edge.updatedAt = .now
        guard saveModelChanges(failurePrefix: "Could not delete link bend") else { return }
        undoManager?.registerUndo(withTarget: edge) { edge in
            edge.controlPointX = oldX
            edge.controlPointY = oldY
            edge.style = oldStyle
            edge.updatedAt = .now
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                onStatus("Could not undo link bend deletion: \(error.localizedDescription)")
            }
        }
        undoManager?.setActionName("Delete Link Bend")
        transientEdgeControlPoints[segment.id] = nil
        edgeControlDragStart[segment.id] = nil
        onStatus("Deleted link anchor")
    }

    private func setEdgeControlPointLocked(_ locked: Bool, for segment: CanvasEdgeSegment) {
        guard let edge = visibleEdges.first(where: { $0.id == segment.id }) else { return }
        if edge.controlPointX == nil || edge.controlPointY == nil {
            let point = edgeControlPoint(for: segment)
            let canvasPoint = CanvasViewportProjection.canvasPoint(
                screenX: Double(point.x),
                screenY: Double(point.y),
                zoom: effectiveZoom,
                viewportX: effectiveViewportX,
                viewportY: effectiveViewportY
            )
            edge.controlPointX = canvasPoint.x
            edge.controlPointY = canvasPoint.y
        }
        edge.style = CanvasEdgeStyleOptions.style(edge.style, controlPointLocked: locked)
        edge.updatedAt = .now
        saveModelChanges(
            failurePrefix: "Could not save link anchor",
            successStatus: locked ? "Locked link anchor" : "Unlocked link anchor"
        )
    }

    private func saveEdgeControlPoint(_ screenPoint: CGPoint, for segment: CanvasEdgeSegment, status: String) {
        let canvasPoint = CanvasViewportProjection.canvasPoint(
            screenX: Double(screenPoint.x),
            screenY: Double(screenPoint.y),
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
        if let edge = visibleEdges.first(where: { $0.id == segment.id }) {
            let oldX = edge.controlPointX
            let oldY = edge.controlPointY
            edge.controlPointX = canvasPoint.x
            edge.controlPointY = canvasPoint.y
            edge.updatedAt = .now
            guard saveModelChanges(failurePrefix: "Could not save link bend") else { return }
            undoManager?.registerUndo(withTarget: edge) { edge in
                edge.controlPointX = oldX
                edge.controlPointY = oldY
                edge.updatedAt = .now
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    onStatus("Could not undo link bend move: \(error.localizedDescription)")
                }
            }
            undoManager?.setActionName("Move Link Bend")
            onStatus(status)
        }
    }

    private var selectionSummary: String {
        if !selectedEdgeIDs.isEmpty {
            return selectedEdgeIDs.count == 1 ? "1 link selected" : "\(selectedEdgeIDs.count) links selected"
        }
        if selectedNodeIDs.isEmpty {
            return "Select a card to open, copy, alias, or delete it."
        }
        if selectedNodeIDs.count == 1, let node = selectedNode {
            return node.title
        }
        return "\(selectedNodeIDs.count) cards selected"
    }

    private var connectionSummary: String {
        if !selectedEdgeIDs.isEmpty {
            return "Delete removes only the selected link. Drag the blue handle to add or move a free bend."
        }
        if mode == .connect {
            if let source = connectionSourceNode {
                return "Connect mode: click the target card for \(source.title)."
            }
            return "Connect mode: click the first card, then the target card."
        }
        if selectedNodeIDs.count == 2 {
            return "Connect or delete the single link between these two cards."
        }
        return "Use Connect mode, select two cards, or click a line."
    }

    private var selectedNode: CanvasNodeModel? {
        guard selectedNodeIDs.count == 1, let id = selectedNodeIDs.first else { return nil }
        return workflowNodeById[id]
    }

    private var connectionSourceNode: CanvasNodeModel? {
        guard let connectionSourceNodeId else { return nil }
        return workflowNodeById[connectionSourceNodeId]
    }

    private var selectedResource: ResourcePinModel? {
        guard let node = selectedNode, node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    private var selectedSnippet: SnippetModel? {
        guard let node = selectedNode, node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    private var selectedWorkspace: WorkspaceModel? {
        guard let node = selectedNode else { return nil }
        return workspace(for: node)
    }

    private var selectedWebURL: URL? {
        guard let node = selectedNode else { return nil }
        return webURL(for: node)
    }

    private func resource(for node: CanvasNodeModel) -> ResourcePinModel? {
        guard node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    private func snippet(for node: CanvasNodeModel) -> SnippetModel? {
        guard node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    private func workspace(for node: CanvasNodeModel) -> WorkspaceModel? {
        guard node.objectType == "workspace", let objectId = node.objectId else { return nil }
        return workspacesById[objectId]
    }

    private func webURL(for node: CanvasNodeModel) -> URL? {
        guard node.objectType == "webURL" else { return nil }
        return WebCardURL.normalized(node.objectId ?? node.body)
    }

    private func dragGesture(for node: CanvasNodeModel) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizingNodeId == node.id {
                    return
                }
                if nodeDragStart.isEmpty {
                    beginNodeDrag(for: node)
                }
                guard !nodeDragStart.isEmpty else { return }
                let delta = nodeDragDelta(for: value)
                for id in nodeDragStart.keys {
                    transientNodeOffsets[id] = delta
                }
                updateFrameDragControlPointOffsets(delta: delta)
            }
            .onEnded { value in
                if resizingNodeId == node.id {
                    resetNodeDragState()
                    return
                }
                commitNodeDrag(delta: nodeDragDelta(for: value))
            }
    }

    private func beginNodeDrag(for node: CanvasNodeModel) {
        let allSnapshots = workflowNodes.map(nodeDragSnapshot(for:))
        nodeDragSnapshots = Dictionary(allSnapshots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        nodeDragStart = Dictionary(
            draggedNodes(for: node).map { draggedNode in
                (
                    draggedNode.id,
                    CanvasNodeDragStart(
                        x: draggedNode.x,
                        y: draggedNode.y,
                        parentNodeId: draggedNode.parentNodeId
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
        if !selectedNodeIDs.contains(node.id) || selectedNodeIDs.count <= 1 {
            selectedNodeIDs = [node.id]
        }
        selectedEdgeIDs = []
    }

    private func nodeDragSnapshot(for node: CanvasNodeModel) -> CanvasNodeDragSnapshot {
        CanvasNodeDragSnapshot(
            id: node.id,
            nodeType: node.nodeType,
            rect: frameRect(for: node)
        )
    }

    private func nodeDragDelta(for value: DragGesture.Value) -> CGSize {
        let safeZoom = max(zoom, 0.01)
        return CGSize(
            width: value.translation.width / safeZoom,
            height: value.translation.height / safeZoom
        )
    }

    private func commitNodeDrag(delta: CGSize) {
        let dragStart = nodeDragStart
        let snapshots = nodeDragSnapshots
        let movedIDs = Set(dragStart.keys)
        defer {
            resetNodeDragState(movedIDs: movedIDs)
        }
        guard !dragStart.isEmpty else { return }

        let deltaX = Double(delta.width)
        let deltaY = Double(delta.height)
        let liveNodesById = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let movedRects = CanvasFrameGeometry.movedRects(
            snapshots.values.map(\.rect),
            movedIDs: movedIDs,
            deltaX: deltaX,
            deltaY: deltaY
        )
        let movedRectById = Dictionary(movedRects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let frameRects = movedRects.filter { snapshots[$0.id]?.nodeType == .groupFrame }
        let movedFrameOriginalRects = snapshots.values
            .filter { movedIDs.contains($0.id) && $0.nodeType == .groupFrame }
            .map(\.rect)
        let movedControlPointStarts = edgeControlPointSnapshots(in: movedFrameOriginalRects)
        let now = Date.now

        for (id, start) in dragStart {
            guard let movedNode = liveNodesById[id] else { continue }
            movedNode.x = start.x + deltaX
            movedNode.y = start.y + deltaY
            movedNode.updatedAt = now
        }

        for id in movedIDs {
            guard let movedNode = liveNodesById[id],
                  snapshots[id]?.nodeType != .groupFrame,
                  let movedRect = movedRectById[id] else {
                continue
            }
            movedNode.parentNodeId = CanvasFrameGeometry.containingFrameId(for: movedRect, frames: frameRects)
        }
        moveContainedEdgeControlPoints(
            in: movedFrameOriginalRects,
            deltaX: deltaX,
            deltaY: deltaY,
            now: now
        )

        do {
            try modelContext.save()
            registerNodePositionUndo(dragStart, edgeControlPointSnapshots: movedControlPointStarts)
        } catch {
            modelContext.rollback()
            onStatus("Could not save canvas move: \(error.localizedDescription)")
        }
    }

    private func registerNodePositionUndo(
        _ dragStart: [String: CanvasNodeDragStart],
        edgeControlPointSnapshots: [CanvasEdgeControlPointSnapshot]
    ) {
        for (id, start) in dragStart {
            guard let node = workflowNodeById[id] else { continue }
            undoManager?.registerUndo(withTarget: node) { node in
                node.x = start.x
                node.y = start.y
                node.parentNodeId = start.parentNodeId
                node.updatedAt = .now
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    onStatus("Could not undo card move: \(error.localizedDescription)")
                }
            }
        }
        for snapshot in edgeControlPointSnapshots {
            guard let edge = visibleEdges.first(where: { $0.id == snapshot.id }) else { continue }
            undoManager?.registerUndo(withTarget: edge) { edge in
                edge.controlPointX = snapshot.x
                edge.controlPointY = snapshot.y
                edge.updatedAt = .now
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    onStatus("Could not undo link bend move: \(error.localizedDescription)")
                }
            }
        }
        undoManager?.setActionName(dragStart.count == 1 ? "Move Card" : "Move Cards")
    }

    private func edgeControlPointSnapshots(in frames: [CanvasFrameRect]) -> [CanvasEdgeControlPointSnapshot] {
        guard !frames.isEmpty else { return [] }
        return visibleEdges.compactMap { edge in
            guard let x = edge.controlPointX,
                  let y = edge.controlPointY else {
                return nil
            }
            let point = CanvasFramePosition(id: edge.id, x: x, y: y)
            guard frames.contains(where: { CanvasFrameGeometry.contains(point, in: $0) }) else {
                return nil
            }
            return CanvasEdgeControlPointSnapshot(id: edge.id, x: x, y: y)
        }
    }

    private func updateFrameDragControlPointOffsets(delta: CGSize) {
        let movedFrameRects = nodeDragSnapshots.values
            .filter { nodeDragStart.keys.contains($0.id) && $0.nodeType == .groupFrame }
            .map(\.rect)
        guard !movedFrameRects.isEmpty else {
            clearFrameDragControlPointOffsets()
            return
        }

        let deltaX = Double(delta.width)
        let deltaY = Double(delta.height)
        var updatedEdgeIDs: Set<String> = []
        for edge in visibleEdges {
            guard let x = edge.controlPointX,
                  let y = edge.controlPointY else {
                continue
            }
            let point = CanvasFramePosition(id: edge.id, x: x, y: y)
            guard movedFrameRects.contains(where: { CanvasFrameGeometry.contains(point, in: $0) }) else {
                continue
            }
            let screenPoint = CanvasViewportProjection.screenPoint(
                x: x + deltaX,
                y: y + deltaY,
                zoom: effectiveZoom,
                viewportX: effectiveViewportX,
                viewportY: effectiveViewportY
            )
            transientEdgeControlPoints[edge.id] = CGPoint(x: screenPoint.x, y: screenPoint.y)
            updatedEdgeIDs.insert(edge.id)
        }

        for id in frameDragControlPointEdgeIDs.subtracting(updatedEdgeIDs) {
            transientEdgeControlPoints[id] = nil
        }
        frameDragControlPointEdgeIDs = updatedEdgeIDs
    }

    private func moveContainedEdgeControlPoints(
        in frames: [CanvasFrameRect],
        deltaX: Double,
        deltaY: Double,
        now: Date
    ) {
        guard !frames.isEmpty, deltaX != 0 || deltaY != 0 else { return }
        for edge in visibleEdges {
            guard let x = edge.controlPointX,
                  let y = edge.controlPointY else {
                continue
            }
            let point = CanvasFramePosition(id: edge.id, x: x, y: y)
            guard frames.contains(where: { CanvasFrameGeometry.contains(point, in: $0) }) else {
                continue
            }
            edge.controlPointX = x + deltaX
            edge.controlPointY = y + deltaY
            edge.updatedAt = now
        }
    }

    private func clearFrameDragControlPointOffsets() {
        for id in frameDragControlPointEdgeIDs {
            transientEdgeControlPoints[id] = nil
        }
        frameDragControlPointEdgeIDs.removeAll()
    }

    private func resetNodeDragState(movedIDs: Set<String>? = nil) {
        let ids = movedIDs ?? Set(nodeDragStart.keys)
        for id in ids {
            transientNodeOffsets[id] = nil
        }
        clearFrameDragControlPointOffsets()
        nodeDragStart.removeAll()
        nodeDragSnapshots.removeAll()
    }

    private func draggedNodes(for node: CanvasNodeModel) -> [CanvasNodeModel] {
        guard node.nodeType == .groupFrame else {
            guard selectedNodeIDs.contains(node.id), selectedNodeIDs.count > 1 else {
                return [node]
            }
            return workflowNodes.filter { selectedNodeIDs.contains($0.id) }
        }

        let cards = renderSnapshot.cardNodes
        let candidates = cards.map(frameRect(for:))
        let childIDs = Set(CanvasFrameGeometry.childNodeIDs(inside: frameRect(for: node), candidates: candidates))
        let children = cards.filter { childIDs.contains($0.id) || $0.parentNodeId == node.id }
        return [node] + children
    }

    private func containingFrameId(for node: CanvasNodeModel) -> String? {
        let candidate = frameRect(for: node)
        let frames = workflowNodes
            .filter { $0.nodeType == .groupFrame }
            .map(frameRect(for:))
        return CanvasFrameGeometry.containingFrameId(for: candidate, frames: frames)
    }

    private func resizeNode(_ node: CanvasNodeModel, screenTranslation: CGSize, commit: Bool) {
        resizingNodeId = node.id
        if resizeStartSizes[node.id] == nil {
            let size = nodeSize(for: node)
            resizeStartSizes[node.id] = CGSize(width: size.width, height: size.height)
        }
        guard let startSize = resizeStartSizes[node.id] else { return }

        let startFrame = CanvasFrameRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: Double(startSize.width),
            height: Double(startSize.height)
        )
        let minimumSize = minimumSize(for: node.nodeType)
        let resized = CanvasFrameGeometry.resizedFrame(
            startFrame,
            deltaWidth: Double(screenTranslation.width) / effectiveZoom,
            deltaHeight: Double(screenTranslation.height) / effectiveZoom,
            minimumWidth: minimumSize.width,
            minimumHeight: minimumSize.height
        )

        if commit {
            let oldWidth = node.width
            let oldHeight = node.height
            node.width = resized.width
            node.height = resized.height
            node.updatedAt = .now
            transientNodeSizes[node.id] = nil
            resizeStartSizes[node.id] = nil
            resizingNodeId = nil
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
            do {
                try modelContext.save()
                undoManager?.registerUndo(withTarget: node) { node in
                    node.width = oldWidth
                    node.height = oldHeight
                    node.updatedAt = .now
                    do {
                        try modelContext.save()
                    } catch {
                        modelContext.rollback()
                        onStatus("Could not undo card resize: \(error.localizedDescription)")
                    }
                }
                undoManager?.setActionName("Resize Card")
                onStatus(node.nodeType == .groupFrame ? "Resized organization frame" : "Resized card")
            } catch {
                modelContext.rollback()
                onStatus("Could not save card size: \(error.localizedDescription)")
            }
        } else {
            transientNodeSizes[node.id] = CGSize(width: resized.width, height: resized.height)
        }
    }

    private func minimumSize(for nodeType: CanvasNodeKind) -> (width: Double, height: Double) {
        switch nodeType {
        case .groupFrame:
            return (CanvasNodeMetrics.frameMinWidth, CanvasNodeMetrics.frameMinHeight)
        case .note:
            return (CanvasNodeMetrics.noteMinWidth, CanvasNodeMetrics.noteMinHeight)
        case .resource, .snippet:
            return (CanvasNodeMetrics.cardMinWidth, CanvasNodeMetrics.cardMinHeight)
        }
    }

    private func backgroundDrag(in size: CGSize, edgeSegments: [CanvasEdgeSegment]) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !backgroundDragStartsOnNode(value.startLocation) else {
                    selectionRect = nil
                    transientViewportOffset = .zero
                    return
                }
                if mode == .boxSelect {
                    selectionRect = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                } else {
                    transientViewportOffset = value.translation
                }
            }
            .onEnded { value in
                guard !backgroundDragStartsOnNode(value.startLocation) else {
                    selectionRect = nil
                    transientViewportOffset = .zero
                    return
                }
                if let rect = selectionRect {
                    selectedNodeIDs = Set(workflowNodes.filter { rect.contains(screenPoint(for: $0)) }.map(\.id))
                    selectedEdgeIDs = []
                    selectionRect = nil
                    onStatus("Selected \(selectedNodeIDs.count) cards")
                } else if transientViewportOffset != .zero {
                    canvas.viewportX += Double(transientViewportOffset.width)
                    canvas.viewportY += Double(transientViewportOffset.height)
                    canvas.updatedAt = .now
                    saveModelChanges(failurePrefix: "Could not save canvas position")
                } else if selectEdge(at: value.location, in: edgeSegments) {
                    transientViewportOffset = .zero
                }
                transientViewportOffset = .zero
            }
    }

    private func handleNodeTap(_ node: CanvasNodeModel) {
        if suppressedTapNodeId == node.id {
            suppressedTapNodeId = nil
            return
        }
        switch mode {
        case .connect:
            selectedEdgeIDs = []
            connectByTap(node)
        case .select, .boxSelect:
            if selectedNodeIDs.contains(node.id), selectedNodeIDs.count > 1 {
                selectedNodeIDs.remove(node.id)
            } else {
                selectedNodeIDs = [node.id]
            }
            selectedEdgeIDs = []
            connectionSourceNodeId = nil
        }
    }

    private func connectByTap(_ node: CanvasNodeModel) {
        selectedEdgeIDs = []
        if let sourceId = connectionSourceNodeId {
            if sourceId == node.id {
                connectionSourceNodeId = nil
                selectedNodeIDs = [node.id]
                onStatus("Connection source cleared")
                return
            }
            if createEdge(from: sourceId, to: node.id) {
                selectedNodeIDs = [sourceId, node.id]
                applyConnectionCompletion(targetNodeId: node.id)
            }
            return
        }

        startConnection(from: node)
    }

    private func startConnection(from node: CanvasNodeModel) {
        let command = CanvasConnectSourcePolicy.start(from: node.id)
        connectionSourceNodeId = command.nextSourceNodeId
        selectedNodeIDs = command.selectedNodeIDs
        selectedEdgeIDs = []
        if command.entersConnectMode {
            mode = .connect
        }
        onStatus("Choose a target card to connect from \(node.title)")
    }

    private func startLinkCommand() {
        guard let node = selectedNode else { return }
        selectedEdgeIDs = []
        if let sourceId = connectionSourceNodeId, sourceId != node.id {
            if createEdge(from: sourceId, to: node.id) {
                selectedNodeIDs = [sourceId, node.id]
                applyConnectionCompletion(targetNodeId: node.id)
            }
        } else {
            startConnection(from: node)
        }
    }

    private func setZoom(_ value: Double) {
        flushPendingScrollZoomCommit()
        transientZoom = nil
        transientZoomViewportOffset = .zero
        canvas.zoom = CanvasZoomScale.clamped(
            value,
            minimum: CanvasNodeMetrics.zoomMinimum,
            maximum: CanvasNodeMetrics.zoomMaximum
        )
        canvas.updatedAt = .now
        saveModelChanges(failurePrefix: "Could not save canvas zoom")
    }

    private func zoomFromScroll(deltaY: Double, location: CGPoint) {
        let oldZoom = effectiveZoom
        let newZoom = CanvasZoomScale.zoom(
            forScrollDeltaY: deltaY,
            current: oldZoom,
            minimum: CanvasNodeMetrics.zoomMinimum,
            maximum: CanvasNodeMetrics.zoomMaximum,
            direction: CanvasScrollZoomDirection.resolved(scrollZoomDirectionRaw)
        )
        guard abs(newZoom - oldZoom) > 0.0001 else { return }

        let anchor = CanvasViewportProjection.canvasPoint(
            screenX: Double(location.x),
            screenY: Double(location.y),
            zoom: oldZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
        let viewport = CanvasZoomScale.viewport(
            keepingScreenX: Double(location.x),
            screenY: Double(location.y),
            canvasX: anchor.x,
            canvasY: anchor.y,
            zoom: newZoom
        )

        transientZoom = newZoom
        transientZoomViewportOffset = CGSize(
            width: viewport.x - canvas.viewportX,
            height: viewport.y - canvas.viewportY
        )
        scheduleScrollZoomCommit()
    }

    private func scheduleScrollZoomCommit() {
        pendingScrollZoomCommit?.cancel()
        pendingScrollZoomCommit = Task { @MainActor in
            try? await Task.sleep(nanoseconds: CanvasNodeMetrics.scrollZoomCommitDelayNanos)
            guard !Task.isCancelled else { return }
            commitScrollZoom()
        }
    }

    private func flushPendingScrollZoomCommit() {
        pendingScrollZoomCommit?.cancel()
        pendingScrollZoomCommit = nil
        commitScrollZoom()
    }

    private func commitScrollZoom() {
        guard let transientZoom else { return }
        let viewportX = canvas.viewportX + Double(transientZoomViewportOffset.width)
        let viewportY = canvas.viewportY + Double(transientZoomViewportOffset.height)
        let shouldPersist =
            abs(transientZoom - canvas.zoom) >= CanvasNodeMetrics.scrollZoomCommitZoomEpsilon ||
            abs(viewportX - canvas.viewportX) >= CanvasNodeMetrics.scrollZoomCommitViewportEpsilon ||
            abs(viewportY - canvas.viewportY) >= CanvasNodeMetrics.scrollZoomCommitViewportEpsilon
        guard shouldPersist else {
            self.transientZoom = nil
            transientZoomViewportOffset = .zero
            pendingScrollZoomCommit = nil
            return
        }
        canvas.zoom = transientZoom
        canvas.viewportX = viewportX
        canvas.viewportY = viewportY
        canvas.updatedAt = .now
        if saveModelChanges(failurePrefix: "Could not save canvas zoom") {
            self.transientZoom = nil
            transientZoomViewportOffset = .zero
        }
        pendingScrollZoomCommit = nil
    }

    private func openSelectedNode() {
        guard let selectedNode else { return }
        open(selectedNode)
    }

    private func copySelectedNode() {
        guard let selectedNode else { return }
        copyNodePayload(selectedNode)
    }

    private func open(_ node: CanvasNodeModel) {
        selectedEdgeIDs = []
        if let workspace = workspace(for: node) {
            selectedNodeIDs = [node.id]
            onOpenWorkspace(workspace.id)
            onStatus("Opened workspace: \(workspace.title)")
            return
        }
        if let url = webURL(for: node) {
            NSWorkspace.shared.open(url)
            selectedNodeIDs = [node.id]
            onStatus("Opened web page: \(url.absoluteString)")
            return
        }
        guard let resource = resource(for: node) else {
            if let snippet = snippet(for: node) {
                ClipboardService().copy(snippet.body)
                snippet.lastCopiedAt = .now
                snippet.updatedAt = .now
                saveModelChanges(failurePrefix: "Could not update snippet copy time")
                selectedNodeIDs = [node.id]
                onStatus("Copied snippet: \(snippet.title)")
                return
            }
            selectedNodeIDs = [node.id]
            onStatus("Selected note: \(node.title)")
            return
        }
        let bookmarkService = BookmarkService()
        do {
            let resolved = try bookmarkService.resolveAuthorizedBookmark(
                resource.securityScopedBookmarkData,
                fallbackPath: resource.lastResolvedPath,
                statusRaw: resource.statusRaw
            )
            try bookmarkService.access(resolved.url) {
                switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                case .open:
                    try FinderService().open(resolved.url)
                case .reveal:
                    try FinderService().reveal(resolved.url)
                }
            }
            resource.lastOpenedAt = .now
            resource.status = .available
            resource.updatedAt = .now
            try modelContext.save()
            onStatus("Opened \(resource.displayName) in Finder")
            selectedNodeIDs = [node.id]
        } catch {
            let actionError = error
            resource.status = .unavailable
            if saveModelChanges(failurePrefix: "Could not update resource status") {
                onStatus(actionError.localizedDescription)
            }
        }
    }

    private func inspect(_ node: CanvasNodeModel) {
        selectedNodeIDs = [node.id]
        selectedEdgeIDs = []
        if let resource = resource(for: node) {
            onInspect(.resource(resource.id))
            onStatus("Showing info for \(resource.displayName)")
        } else if let snippet = snippet(for: node) {
            onInspect(.snippet(snippet.id))
            onStatus("Showing info for \(snippet.title)")
        } else {
            onInspect(.node(node.id))
            onStatus("Showing info for \(node.title)")
        }
    }

    private func copyNodePayload(_ node: CanvasNodeModel) {
        selectedEdgeIDs = []
        if let resource = resource(for: node) {
            ClipboardService().copy(resource.displayPath)
            selectedNodeIDs = [node.id]
            onStatus("Copied path: \(resource.displayPath)")
        } else if let snippet = snippet(for: node) {
            ClipboardService().copy(snippet.body)
            snippet.lastCopiedAt = .now
            snippet.updatedAt = .now
            saveModelChanges(failurePrefix: "Could not update snippet copy time")
            selectedNodeIDs = [node.id]
            onStatus("Copied snippet: \(snippet.title)")
        } else if let workspace = workspace(for: node) {
            ClipboardService().copy(workspace.title)
            selectedNodeIDs = [node.id]
            onStatus("Copied workspace title: \(workspace.title)")
        } else if let url = webURL(for: node) {
            ClipboardService().copy(url.absoluteString)
            selectedNodeIDs = [node.id]
            onStatus("Copied URL: \(url.absoluteString)")
        } else {
            ClipboardService().copy(node.body.isEmpty ? node.title : node.body)
            selectedNodeIDs = [node.id]
            onStatus("Copied node text: \(node.title)")
        }
    }

    private func connectButtonTapped(_ node: CanvasNodeModel) {
        selectedEdgeIDs = []
        if connectionSourceNodeId == node.id {
            connectionSourceNodeId = nil
            selectedNodeIDs = [node.id]
            onStatus("Connection source cleared")
            return
        }

        if let sourceId = connectionSourceNodeId {
            if createEdge(from: sourceId, to: node.id) {
                selectedNodeIDs = [sourceId, node.id]
                applyConnectionCompletion(targetNodeId: node.id)
            }
        } else {
            startConnection(from: node)
        }
    }

    private func performCardButtonAction(_ node: CanvasNodeModel, action: () -> Void) {
        suppressedTapNodeId = node.id
        action()
        DispatchQueue.main.async {
            if suppressedTapNodeId == node.id {
                suppressedTapNodeId = nil
            }
        }
    }

    private func updateNodeTitle(_ node: CanvasNodeModel, to title: String) {
        guard node.nodeType == .note || node.nodeType == .groupFrame else { return }
        guard node.title != title else { return }
        node.title = title
        node.updatedAt = .now
        scheduleNodeTextCommit(for: node.id)
    }

    private func updateNodeBody(_ node: CanvasNodeModel, to body: String) {
        guard node.body != body else { return }
        node.body = body
        node.updatedAt = .now
        scheduleNodeTextCommit(for: node.id)
    }

    private func scheduleNodeTextCommit(for nodeId: String) {
        pendingNodeTextCommitTasks[nodeId]?.cancel()
        pendingNodeTextCommitTasks[nodeId] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: CanvasNodeMetrics.textEditCommitDelayNanos)
            guard !Task.isCancelled else { return }
            pendingNodeTextCommitTasks[nodeId] = nil
            saveModelChanges(failurePrefix: "Could not save card text")
        }
    }

    private func flushPendingNodeTextCommits() {
        guard !pendingNodeTextCommitTasks.isEmpty else { return }
        for task in pendingNodeTextCommitTasks.values {
            task.cancel()
        }
        pendingNodeTextCommitTasks.removeAll()
        saveModelChanges(failurePrefix: "Could not save card text")
    }

    private func updateNodeColor(_ node: CanvasNodeModel, to rawValue: String) {
        let normalized = CanvasNodeColorStyle(rawValue: rawValue)?.normalizedRawValue ?? ""
        guard node.accentColorRaw != normalized else { return }
        node.accentColorRaw = normalized
        node.updatedAt = .now
        saveModelChanges(
            failurePrefix: "Could not save card color",
            successStatus: normalized.isEmpty ? "Reset card color" : "Updated card color"
        )
    }

    private func createAliasForSelectedNode() {
        guard let resource = selectedResource else { return }
        guard let requestedAliasURL = FileDialogs.saveAlias(defaultName: "\(resource.title) alias") else { return }
        let destination = requestedAliasURL.deletingLastPathComponent()
        let name = requestedAliasURL.lastPathComponent
        let bookmarkService = BookmarkService()

        do {
            let resolved = try bookmarkService.resolveAuthorizedBookmark(
                resource.securityScopedBookmarkData,
                fallbackPath: resource.lastResolvedPath,
                statusRaw: resource.statusRaw
            )
            let aliasURL = try bookmarkService.access(resolved.url) {
                try bookmarkService.access(destination) {
                    try AliasService().createAlias(source: resolved.url, destinationDirectory: destination, name: name)
                }
            }
            let aliasRecord = FinderAliasRecordModel(
                sourceObjectType: "resourcePin",
                sourceObjectId: resource.id,
                aliasDisplayPath: aliasURL.path,
                aliasFileBookmarkData: try? bookmarkService.makeBookmark(for: aliasURL),
                aliasTargetBookmarkData: resource.securityScopedBookmarkData
            )
            modelContext.insert(aliasRecord)
            try modelContext.save()
            onStatus("Created Finder alias: \(aliasURL.path)")
        } catch {
            let aliasError = error
            let failed = FinderAliasRecordModel(sourceObjectType: "resourcePin", sourceObjectId: resource.id, aliasDisplayPath: requestedAliasURL.path, status: .failed)
            modelContext.insert(failed)
            if saveModelChanges(failurePrefix: "Could not save failed alias record") {
                onStatus(aliasError.localizedDescription)
            }
        }
    }

    private func addResourceNode(_ resource: ResourcePinModel) {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: resource.effectiveName, body: resource.note, nodeType: .resource, objectType: "resourcePin", objectId: resource.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add resource node", successStatus: "Added resource node") {
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func addSnippetNode(_ snippet: SnippetModel) {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: snippet.title, body: snippet.details, nodeType: .snippet, objectType: "snippet", objectId: snippet.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add snippet node", successStatus: "Added snippet node") {
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func addWorkspaceNode(_ workspace: WorkspaceModel) {
        let point = nextNodePosition()
        let body = workspace.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let node = CanvasNodeModel(
            canvasId: canvas.id,
            title: workspace.title,
            body: body.isEmpty ? "Workspace reference" : body,
            nodeType: .snippet,
            objectType: "workspace",
            objectId: workspace.id,
            x: point.x,
            y: point.y,
            width: CanvasNodeMetrics.cardWidth,
            height: CanvasNodeMetrics.cardHeight,
            collapsed: true,
            accentColorRaw: "#8C5CF6D1"
        )
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add workspace card", successStatus: "Added workspace card") {
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func addWebNode() {
        guard let url = WebCardURL.normalized(webCardDraft) else {
            onStatus("Enter a valid http or https URL")
            return
        }
        let point = nextNodePosition()
        let title = url.host ?? url.absoluteString
        let node = CanvasNodeModel(
            canvasId: canvas.id,
            title: title,
            body: url.absoluteString,
            nodeType: .snippet,
            objectType: "webURL",
            objectId: url.absoluteString,
            x: point.x,
            y: point.y,
            width: CanvasNodeMetrics.cardWidth,
            height: CanvasNodeMetrics.cardHeight,
            collapsed: true,
            accentColorRaw: "#33D499D1"
        )
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add web page card", successStatus: "Added web page card") {
            webCardDraft = ""
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func addNoteNode() {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Note", body: "Write a workflow note here.", nodeType: .note, x: point.x, y: point.y, width: CanvasNodeMetrics.noteWidth, height: CanvasNodeMetrics.noteHeight, collapsed: false)
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add note card", successStatus: "Added note card") {
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func addFrameNode() {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Organization Frame", body: "Describe this part of the workflow.", nodeType: .groupFrame, x: point.x, y: point.y, width: CanvasNodeMetrics.frameWidth, height: CanvasNodeMetrics.frameHeight, collapsed: false, zIndex: -10)
        modelContext.insert(node)
        if saveModelChanges(failurePrefix: "Could not add organization frame", successStatus: "Added organization frame") {
            selectedNodeIDs = [node.id]
            selectedEdgeIDs = []
        }
    }

    private func importDroppedResources(_ urls: [URL], at dropLocation: CGPoint) {
        guard !urls.isEmpty else { return }
        do {
            let summary = try ResourceImportService().importURLs(
                urls,
                existingResources: resources,
                into: modelContext,
                scope: .workspace,
                workspaceId: canvas.workspaceId,
                pinImported: false,
                saveChanges: false
            )
            var addedIDs: [String] = []
            for (index, resource) in summary.resources.enumerated() {
                let point = dropNodePosition(at: dropLocation, offset: index)
                let node = CanvasNodeModel(canvasId: canvas.id, title: resource.effectiveName, body: resource.note, nodeType: .resource, objectType: "resourcePin", objectId: resource.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
                modelContext.insert(node)
                addedIDs.append(node.id)
            }
            try modelContext.save()
            selectedNodeIDs = Set(addedIDs)
            selectedEdgeIDs = []
            onStatus("Canvas drop: \(summary.statusText)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func dropNodePosition(at location: CGPoint, offset index: Int) -> (x: Double, y: Double) {
        let stagger = Double(index * 28)
        let origin = CanvasDropPlacement.cardOrigin(
            dropX: Double(location.x),
            dropY: Double(location.y),
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY,
            zoom: effectiveZoom,
            cardWidth: CanvasNodeMetrics.cardWidth,
            cardHeight: CanvasNodeMetrics.cardHeight
        )
        return (x: origin.x + stagger, y: origin.y + stagger)
    }

    private func connectSelected() {
        selectedEdgeIDs = []
        let selected = workflowNodes
            .filter { selectedNodeIDs.contains($0.id) }
            .sorted {
                if $0.x != $1.x { return $0.x < $1.x }
                if $0.y != $1.y { return $0.y < $1.y }
                return $0.id < $1.id
            }
        guard selected.count == 2 else { return }
        let sourceId = selected[0].id
        let targetId = selected[1].id
        if createEdge(from: sourceId, to: targetId) {
            selectedNodeIDs = [sourceId, targetId]
            applyConnectionCompletion(targetNodeId: targetId)
        }
    }

    private func createEdge(from sourceId: String, to targetId: String) -> Bool {
        guard sourceId != targetId else { return false }
        let identities = visibleEdges.map { CanvasEdgeIdentity(sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId) }
        let exists = CanvasEdgeIdentity.exists(sourceNodeId: sourceId, targetNodeId: targetId, in: identities)
        guard !exists else {
            onStatus("Cards are already connected in that direction")
            return false
        }
        let edge = CanvasEdgeModel(canvasId: canvas.id, sourceNodeId: sourceId, targetNodeId: targetId, targetArrowRaw: "arrow", animated: shouldAnimateGlow, animationThemeRaw: canvas.linkAnimationThemeRaw)
        modelContext.insert(edge)
        do {
            try modelContext.save()
            onStatus("Connected cards with arrow")
            return true
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
            return false
        }
    }

    private func reverseSelectedLink() {
        guard selectedEdgeIDs.count == 1,
              let id = selectedEdgeIDs.first,
              let edge = visibleEdges.first(where: { $0.id == id }) else {
            return
        }

        let record = CanvasEdgeDirectionRecord(
            id: edge.id,
            sourceNodeId: edge.sourceNodeId,
            targetNodeId: edge.targetNodeId,
            sourceArrow: edge.sourceArrowRaw,
            targetArrow: edge.targetArrowRaw
        )
        let endpoints = visibleEdges.map {
            CanvasEdgeEndpointRecord(id: $0.id, sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId)
        }
        guard CanvasEdgeDirectionPolicy.canReverse(record, existingEdges: endpoints) else {
            onStatus("A reverse link already exists. Select that link instead.")
            return
        }

        let previousSource = edge.sourceNodeId
        let previousTarget = edge.targetNodeId
        let previousSourceArrow = edge.sourceArrowRaw
        let previousTargetArrow = edge.targetArrowRaw
        let reversed = CanvasEdgeDirectionPolicy.reversed(record)
        edge.sourceNodeId = reversed.sourceNodeId
        edge.targetNodeId = reversed.targetNodeId
        edge.sourceArrowRaw = reversed.sourceArrow
        edge.targetArrowRaw = reversed.targetArrow
        edge.updatedAt = .now

        do {
            try modelContext.save()
            undoManager?.registerUndo(withTarget: edge) { edge in
                edge.sourceNodeId = previousSource
                edge.targetNodeId = previousTarget
                edge.sourceArrowRaw = previousSourceArrow
                edge.targetArrowRaw = previousTargetArrow
                edge.updatedAt = .now
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    onStatus("Could not undo link reversal: \(error.localizedDescription)")
                }
            }
            undoManager?.setActionName("Reverse Link")
            selectedEdgeIDs = [edge.id]
            selectedNodeIDs = []
            connectionSourceNodeId = nil
            onStatus("Reversed link direction")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func applyConnectionCompletion(targetNodeId: String) {
        let completion = CanvasConnectionPolicy.completion(targetNodeId: targetNodeId, singleShot: connectSingleShot)
        connectionSourceNodeId = completion.nextSourceNodeId
        if completion.returnsToSelectMode {
            mode = .select
        }
    }

    private func alignLeft() {
        let selected = workflowNodes.filter { selectedNodeIDs.contains($0.id) }
        let layout = selected.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        if apply(CanvasLayoutEngine.alignLeft(layout)) {
            onStatus("Aligned left")
        }
    }

    private func alignTop() {
        let selected = workflowNodes.filter { selectedNodeIDs.contains($0.id) }
        let layout = selected.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        if apply(CanvasLayoutEngine.alignTop(layout)) {
            onStatus("Aligned top")
        }
    }

    private func autoArrange() {
        let layout = workflowNodes.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        let layoutEdges = visibleEdges.map {
            CanvasLayoutEdge(sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId)
        }
        if apply(CanvasLayoutEngine.autoArrange(
            layout,
            edges: layoutEdges,
            horizontalSpacing: 96,
            verticalSpacing: 56,
            disconnectedColumns: 3
        )) {
            onStatus("Auto arranged canvas")
        }
    }

    private func apply(_ layout: [CanvasLayoutNode]) -> Bool {
        for item in layout {
            guard let node = workflowNodeById[item.id] else { continue }
            node.x = item.x
            node.y = item.y
            node.updatedAt = .now
        }
        return saveModelChanges(failurePrefix: "Could not save canvas layout")
    }

    private func toggleNote(for node: CanvasNodeModel) {
        node.collapsed.toggle()
        node.updatedAt = .now
        saveModelChanges(failurePrefix: "Could not save note state")
    }

    private func delete(_ node: CanvasNodeModel) {
        selectedNodeIDs = [node.id]
        selectedEdgeIDs = []
        deleteSelectedNodes()
    }

    private func deleteSelectedNodes() {
        flushPendingNodeTextCommits()
        let ids = selectedNodeIDs
        guard !ids.isEmpty else { return }
        let edgeIds = Set(CanvasNodeDeletionPolicy.incidentEdgeIDs(
            selectedNodeIDs: ids,
            edges: visibleEdges.map {
                CanvasEdgeEndpointRecord(id: $0.id, sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId)
            }
        ))
        let removedNodes = workflowNodes.filter { ids.contains($0.id) }
        let removedEdges = visibleEdges.filter { edgeIds.contains($0.id) }
        let childParentSnapshots = workflowNodes
            .filter { node in
                guard let parentNodeId = node.parentNodeId else { return false }
                return ids.contains(parentNodeId) && !ids.contains(node.id)
            }
            .map(CanvasChildParentSnapshot.init)
        let nodeSnapshots = removedNodes.map(CanvasNodeDeletionSnapshot.init)
        let edgeSnapshots = removedEdges.map(CanvasEdgeDeletionSnapshot.init)

        for child in workflowNodes where childParentSnapshots.contains(where: { $0.id == child.id }) {
            child.parentNodeId = nil
            child.updatedAt = .now
        }
        for edge in removedEdges {
            modelContext.delete(edge)
        }
        for node in removedNodes {
            modelContext.delete(node)
        }
        if saveModelChanges(
            failurePrefix: "Could not delete cards",
            successStatus: "Deleted \(ids.count) card\(ids.count == 1 ? "" : "s")"
        ) {
            registerCanvasNodeDeletionUndo(
                nodes: nodeSnapshots,
                edges: edgeSnapshots,
                childParents: childParentSnapshots
            )
            selectedNodeIDs = []
            selectedEdgeIDs = []
            connectionSourceNodeId = nil
        }
    }

    private func deleteSelectedConnections() {
        flushPendingNodeTextCommits()
        let endpointRecords = visibleEdges.map {
            CanvasEdgeEndpointRecord(id: $0.id, sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId)
        }
        let idsToDelete = Set(CanvasEdgeDeletionPolicy.edgeIDsToDelete(
            selectedEdgeIDs: selectedEdgeIDs,
            selectedNodeIDs: selectedNodeIDs,
            edges: endpointRecords
        ))
        guard !idsToDelete.isEmpty else {
            if selectedNodeIDs.count == 1 {
                onStatus("Select a link directly to delete a single connection.")
            } else if selectedNodeIDs.count == 2 {
                onStatus("Select one line when multiple directions exist between the cards.")
            }
            return
        }
        let removedEdges = visibleEdges.filter { idsToDelete.contains($0.id) }
        let edgeSnapshots = removedEdges.map(CanvasEdgeDeletionSnapshot.init)
        for edge in removedEdges {
            modelContext.delete(edge)
        }
        if saveModelChanges(
            failurePrefix: "Could not delete links",
            successStatus: "Deleted \(removedEdges.count) link\(removedEdges.count == 1 ? "" : "s")"
        ) {
            registerCanvasEdgeDeletionUndo(edgeSnapshots)
            selectedEdgeIDs.subtract(idsToDelete)
        }
    }

    private func registerCanvasNodeDeletionUndo(
        nodes: [CanvasNodeDeletionSnapshot],
        edges: [CanvasEdgeDeletionSnapshot],
        childParents: [CanvasChildParentSnapshot]
    ) {
        guard !nodes.isEmpty || !edges.isEmpty || !childParents.isEmpty else { return }
        undoManager?.registerUndo(withTarget: modelContext) { context in
            for snapshot in nodes {
                context.insert(snapshot.makeModel())
            }
            for snapshot in childParents {
                if let child = fetchCanvasNodeForUndo(id: snapshot.id, in: context) {
                    child.parentNodeId = snapshot.parentNodeId
                    child.updatedAt = .now
                }
            }
            for snapshot in edges {
                context.insert(snapshot.makeModel())
            }
            do {
                try context.save()
                onStatus("Restored deleted cards")
            } catch {
                context.rollback()
                onStatus("Could not undo card deletion: \(error.localizedDescription)")
            }
        }
        undoManager?.setActionName(nodes.count == 1 ? "Delete Card" : "Delete Cards")
    }

    private func registerCanvasEdgeDeletionUndo(_ edges: [CanvasEdgeDeletionSnapshot]) {
        guard !edges.isEmpty else { return }
        undoManager?.registerUndo(withTarget: modelContext) { context in
            for snapshot in edges {
                context.insert(snapshot.makeModel())
            }
            do {
                try context.save()
                onStatus("Restored deleted links")
            } catch {
                context.rollback()
                onStatus("Could not undo link deletion: \(error.localizedDescription)")
            }
        }
        undoManager?.setActionName(edges.count == 1 ? "Delete Link" : "Delete Links")
    }

    private func handleDeleteCommand() {
        if !selectedEdgeIDs.isEmpty {
            deleteSelectedConnections()
            return
        }
        if selectedNodeIDs.count == 2 {
            let matchingEdges = visibleEdges.filter {
                selectedNodeIDs.contains($0.sourceNodeId) &&
                    selectedNodeIDs.contains($0.targetNodeId)
            }
            guard matchingEdges.isEmpty else {
                deleteSelectedConnections()
                return
            }
        }
        deleteSelectedNodes()
    }

    private func selectEdge(_ id: String) {
        guard visibleEdges.contains(where: { $0.id == id }) else { return }
        selectedEdgeIDs = [id]
        selectedNodeIDs = []
        connectionSourceNodeId = nil
        onStatus("Selected link")
    }

    @discardableResult
    private func selectEdge(at location: CGPoint, in edgeSegments: [CanvasEdgeSegment]) -> Bool {
        let records = edgeSegments.map(edgeHitRecord(for:))
        let point = CanvasEdgePoint(x: Double(location.x), y: Double(location.y))
        guard let id = CanvasEdgeHitTesting.nearestEdgeID(
            at: point,
            edges: records,
            threshold: max(10, 12 * Double(zoom))
        ) else {
            return false
        }
        selectEdge(id)
        return true
    }

    private func edgeHitRecord(for segment: CanvasEdgeSegment) -> CanvasEdgeHitRecord {
        var points = [edgePoint(segment.start)]
        if segment.routePoints.isEmpty {
            if let control = transientEdgeControlPoints[segment.id] ?? segment.control {
                points.append(edgePoint(control))
            }
        } else {
            points.append(contentsOf: segment.routePoints.map { edgePoint($0) })
        }
        points.append(edgePoint(segment.end))
        return CanvasEdgeHitRecord(id: segment.id, points: points)
    }

    private func edgePoint(_ point: CGPoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: Double(point.x), y: Double(point.y))
    }

    private func nextNodePosition(offset additionalOffset: Int = 0) -> (x: Double, y: Double) {
        let index = workflowNodes.count + additionalOffset
        let offset = Double((index % 6) * 28)
        return (
            x: (96 - effectiveViewportX) / Double(zoom) + offset,
            y: (96 - effectiveViewportY) / Double(zoom) + offset
        )
    }
}

private extension CanvasNodeColorStyle {
    var cardFill: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    var pickerColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    static func fromPickerColor(_ color: Color, opacity: Double) -> CanvasNodeColorStyle? {
        guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
        return CanvasNodeColorStyle(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            opacity: opacity
        )
    }
}

private struct CanvasCardColorEditor: View {
    let styleRaw: String
    let onStyleChange: (String) -> Void
    @State private var pickerColor = Color.accentColor
    @State private var opacity = 0.82
    @State private var colorCode = ""
    @State private var hasInvalidCode = false

    private var style: CanvasNodeColorStyle? {
        CanvasNodeColorStyle(rawValue: styleRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let style {
                    Circle()
                        .fill(style.cardFill)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        }
                } else {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                Spacer()
                Button("Reset") {
                    onStyleChange("")
                    syncFromRawValue("")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 6), spacing: 8) {
                ForEach(CanvasNodeColorPreset.common) { preset in
                    Button {
                        apply(preset.style)
                    } label: {
                        Circle()
                            .fill(preset.style.cardFill)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(preset.title)
                }
            }

            ColorPicker("Custom", selection: $pickerColor, supportsOpacity: false)
                .onChange(of: pickerColor) { _, newValue in
                    guard let style = CanvasNodeColorStyle.fromPickerColor(newValue, opacity: opacity) else { return }
                    apply(style)
                }

            HStack(spacing: 8) {
                TextField("#RRGGBB", text: $colorCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(applyColorCode)
                    .overlay {
                        if hasInvalidCode {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        }
                    }
                Button {
                    applyColorCode()
                } label: {
                    Image(systemName: "checkmark")
                }
                .help("Apply color code")
            }

            HStack(spacing: 10) {
                Text("Opacity")
                Slider(value: $opacity, in: 0...1) { editing in
                    if !editing {
                        applyOpacity()
                    }
                }
                Text("\(Int((opacity * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            syncFromRawValue(styleRaw)
        }
        .onChange(of: styleRaw) { _, newValue in
            syncFromRawValue(newValue)
        }
    }

    private func applyColorCode() {
        guard let parsed = CanvasNodeColorStyle(rawValue: colorCode) else {
            hasInvalidCode = true
            return
        }
        apply(parsed)
    }

    private func applyOpacity() {
        let baseStyle = style ?? CanvasNodeColorStyle.fromPickerColor(pickerColor, opacity: opacity)
        guard let baseStyle else { return }
        apply(baseStyle.withOpacity(opacity))
    }

    private func apply(_ style: CanvasNodeColorStyle) {
        hasInvalidCode = false
        pickerColor = style.pickerColor
        opacity = style.opacity
        colorCode = style.normalizedRawValue
        onStyleChange(style.normalizedRawValue)
    }

    private func syncFromRawValue(_ rawValue: String) {
        guard let style = CanvasNodeColorStyle(rawValue: rawValue) else {
            pickerColor = Color.accentColor
            opacity = 0.82
            colorCode = ""
            hasInvalidCode = false
            return
        }
        pickerColor = style.pickerColor
        opacity = style.opacity
        colorCode = style.normalizedRawValue
        hasInvalidCode = false
    }
}

struct CanvasNodeCard: View {
    let node: CanvasNodeModel
    let resource: ResourcePinModel?
    let snippet: SnippetModel?
    let workspace: WorkspaceModel?
    let webURL: URL?
    let isSelected: Bool
    let isConnectionSource: Bool
    let isConnected: Bool
    let glowTheme: CanvasGlowTheme
    let animateGlow: Bool
    let glowPulse: Bool
    let onOpen: () -> Void
    let onInfo: () -> Void
    let onCopy: () -> Void
    let onStartLink: () -> Void
    let onConnect: () -> Void
    let onToggleNote: () -> Void
    let onDelete: () -> Void
    let onTitleChange: (String) -> Void
    let onNoteChange: (String) -> Void
    @State private var feedback: String?
    @State private var isEditingTitle = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                if node.nodeType == .note {
                    noteCardContent(cardSize: proxy.size)
                } else {
                    resourceCardContent(cardSize: proxy.size)
                }

                if let feedback {
                    Text(feedback)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.92))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(8)
                        .transition(.opacity.combined(with: .scale))
                }

            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .contextMenu {
            Button("Open") { onOpen() }
            Button("Copy") {
                triggerFeedback("Copied") {
                    onCopy()
                }
            }
            Button("Show Details") { onInfo() }
            Button("Start Link From This Card") { onStartLink() }
            Button("Connect") { onConnect() }
            Button("Toggle Note") { onToggleNote() }
            Button("Delete Card", role: .destructive) { onDelete() }
        }
    }

    private func resourceCardContent(cardSize: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            titleView(cardSize: cardSize)
            Divider()
                .opacity(0.38)
            detailsSection(cardSize: cardSize)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(resourceCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected || isConnectionSource ? 2 : 1)
        }
        .overlay(glowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: glowShadowColor, radius: glowShadowRadius, y: isSelected ? 2 : 1)
    }

    private func noteCardContent(cardSize: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            titleView(cardSize: cardSize)
            Divider()
                .opacity(0.28)
            CanvasNativeTextEditor(
                text: noteBinding,
                fontSize: bodyFontSize(for: cardSize),
                weight: .regular,
                textColor: .labelColor
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(noteCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(noteBorderColor, lineWidth: isSelected || isConnectionSource ? 2 : 1.2)
        }
        .overlay(glowOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: glowShadowColor, radius: glowShadowRadius, y: isSelected ? 2 : 1)
    }

    private var header: some View {
        HStack(spacing: 6) {
            CanvasSharpSymbol(systemName: icon, pointSize: 12.5, weight: .semibold)
                .frame(width: 15, height: 15)
            CanvasSharpText(
                text: subtitle,
                fontSize: 12.5,
                weight: .semibold,
                textColor: .labelColor,
                lineLimit: 1
            )
            .frame(width: chromeTextWidth(subtitle, fontSize: 12.5, weight: .semibold), height: 16, alignment: .leading)
            Spacer(minLength: 6)
            Button {
                triggerFeedback("Copied") {
                    onCopy()
                }
            } label: {
                CanvasSharpSymbol(systemName: "doc.on.doc", pointSize: 12, weight: .semibold)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(CardIconButtonStyle())
            .help(copyHelpText)
            Button(action: onInfo) {
                CanvasSharpSymbol(systemName: "info.circle", pointSize: 12, weight: .semibold)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(CardIconButtonStyle())
            .help("Show details")
            Button(role: .destructive, action: onDelete) {
                CanvasSharpSymbol(systemName: "trash", pointSize: 12, weight: .semibold)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(CardIconButtonStyle())
            .help("Delete card")
        }
    }

    @ViewBuilder
    private func titleView(cardSize: CGSize) -> some View {
        if canRenameTitle {
            if isEditingTitle {
                TextField("Title", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: titleFontSize(for: cardSize), weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: titleBoxHeight(for: cardSize), maxHeight: titleBoxHeight(for: cardSize), alignment: .center)
                    .clipped()
                    .onSubmit {
                        isEditingTitle = false
                    }
                    .onExitCommand {
                        isEditingTitle = false
                    }
            } else {
                adaptiveTitleText(cardSize: cardSize)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        isEditingTitle = true
                    }
                    .help("Double-click to rename")
            }
        } else {
            adaptiveTitleText(cardSize: cardSize)
        }
    }

    private func adaptiveTitleText(cardSize: CGSize) -> some View {
        AdaptiveTitleText(
            text: titleText,
            baseFontSize: titleFontSize(for: cardSize),
            minimumFontSize: 0.6,
            weight: .semibold
        )
        .frame(maxWidth: .infinity, minHeight: titleBoxHeight(for: cardSize), maxHeight: titleBoxHeight(for: cardSize), alignment: .center)
        .clipped()
    }

    private func detailsSection(cardSize: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: onToggleNote) {
                HStack(spacing: 4) {
                    CanvasSharpSymbol(systemName: node.collapsed ? "chevron.right" : "chevron.down", pointSize: 12, weight: .semibold)
                        .frame(width: 12, height: 12)
                    CanvasSharpText(
                        text: detailTitle,
                        fontSize: 12.5,
                        weight: .semibold,
                        textColor: .labelColor,
                        lineLimit: 1
                    )
                    .frame(width: chromeTextWidth(detailTitle, fontSize: 12.5, weight: .semibold), height: 16, alignment: .leading)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if node.collapsed {
                CanvasSharpText(
                    text: notePreview,
                    fontSize: 12,
                    weight: .semibold,
                    textColor: NSColor.labelColor.withAlphaComponent(0.86),
                    lineLimit: 3
                )
                    .frame(minHeight: 18, maxHeight: 46, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleNote()
                    }
            } else {
                CanvasNativeTextEditor(
                    text: noteBinding,
                    fontSize: bodyFontSize(for: cardSize),
                    weight: .semibold,
                    textColor: NSColor.labelColor.withAlphaComponent(0.86)
                )
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var glowOverlay: some View {
        Group {
            if isConnected && glowTheme != .off {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(glowColor.opacity(glowTheme == .blue ? 0.56 : 0.28), lineWidth: glowTheme == .blue ? 2 : 1)
                    .blur(radius: glowTheme == .blue ? 4 : 1)
                    .opacity(animateGlow ? (glowPulse ? 0.95 : 0.42) : 0.55)
            }
        }
    }

    private var borderColor: Color {
        if isConnectionSource {
            return .accentColor
        }
        return isSelected ? .accentColor : Color.secondary.opacity(0.25)
    }

    private var icon: String {
        if workspace != nil {
            return "rectangle.3.group"
        }
        if webURL != nil {
            return "globe"
        }
        if let resource {
            return resource.targetType == .folder ? "folder" : "doc"
        }
        if let snippet {
            return snippet.kind == .prompt ? "text.quote" : "terminal"
        }
        switch node.nodeType {
        case .resource:
            return "folder"
        case .snippet:
            return "text.quote"
        case .note:
            return "note.text"
        case .groupFrame:
            return "rectangle.dashed"
        }
    }

    private var titleText: String {
        if let resource {
            return resource.displayName
        }
        return node.title
    }

    private var canRenameTitle: Bool {
        node.nodeType == .note
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { node.title },
            set: { onTitleChange($0) }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { node.body },
            set: { onNoteChange($0) }
        )
    }

    private var subtitle: String {
        if workspace != nil {
            return "Workspace"
        }
        if webURL != nil {
            return "Web Page"
        }
        if let resource {
            return resource.targetType == .folder ? "Folder" : "File"
        }
        if let snippet {
            return snippet.kind == .prompt ? "Prompt" : "Command"
        }
        return node.nodeType.rawValue.capitalized
    }

    private var detailTitle: String {
        snippet == nil && workspace == nil && webURL == nil ? "Note" : "Details"
    }

    private var copyHelpText: String {
        if resource != nil {
            return "Copy full path"
        }
        if webURL != nil {
            return "Copy URL"
        }
        if workspace != nil {
            return "Copy workspace title"
        }
        return "Copy text"
    }

    private var notePreview: String {
        let trimmed = node.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No description yet." : trimmed
    }

    private var noteBackground: Color {
        Color(red: 1.0, green: 0.94, blue: 0.62).opacity(0.72)
    }

    @ViewBuilder
    private var resourceCardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.regularMaterial)
        if let colorStyle {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorStyle.cardFill)
        }
    }

    @ViewBuilder
    private var noteCardBackground: some View {
        if let colorStyle {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorStyle.cardFill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(noteBackground)
        }
    }

    private var colorStyle: CanvasNodeColorStyle? {
        CanvasNodeColorStyle(rawValue: node.accentColorRaw)
    }

    private var noteBorderColor: Color {
        if isConnectionSource || isSelected {
            return .accentColor
        }
        if let colorStyle {
            return colorStyle.cardFill.opacity(0.9)
        }
        return Color(red: 0.86, green: 0.64, blue: 0.14).opacity(0.48)
    }

    private var secondaryLabelFont: Font {
        .system(size: 12.5, weight: .semibold)
    }

    private var secondaryBodyFont: Font {
        .system(size: 12, weight: .semibold)
    }

    private var secondaryTextColor: Color {
        Color.primary.opacity(0.94)
    }

    private var secondaryBodyColor: Color {
        Color.primary.opacity(0.86)
    }

    private func titleFontSize(for size: CGSize) -> CGFloat {
        let widthDriven = size.width / 13.5
        let heightDriven = size.height / 10
        return min(21, max(12, min(widthDriven, heightDriven)))
    }

    private func bodyFontSize(for size: CGSize) -> CGFloat {
        min(14, max(11, size.width / 18))
    }

    private func chromeTextWidth(_ text: String, fontSize: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return min(86, max(30, ceil(width) + 3))
    }

    private func titleMaxHeight(for size: CGSize) -> CGFloat {
        CGFloat(CanvasCardTitleLayoutPolicy.maxTitleHeight(
            kind: node.nodeType.rawValue,
            cardHeight: Double(size.height)
        ))
    }

    private var titleMinHeight: CGFloat {
        CGFloat(CanvasCardTitleLayoutPolicy.minTitleHeight(kind: node.nodeType.rawValue))
    }

    private func titleBoxHeight(for size: CGSize) -> CGFloat {
        max(titleMinHeight, titleMaxHeight(for: size))
    }

    private var glowColor: Color {
        glowTheme == .blue ? .blue : .accentColor
    }

    private var glowShadowColor: Color {
        if isConnected && glowTheme == .blue {
            return .blue.opacity(0.22)
        }
        return .black.opacity(isSelected ? 0.18 : 0.08)
    }

    private var glowShadowRadius: CGFloat {
        if isConnected && glowTheme == .blue {
            return isSelected ? 9 : 6
        }
        return isSelected ? 5 : 1
    }

    private func triggerFeedback(_ message: String, action: () -> Void) {
        action()
        withAnimation(.easeOut(duration: 0.12)) {
            feedback = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard feedback == message else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                feedback = nil
            }
        }
    }

}

struct CardIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .center) {
            configuration.label
                .frame(
                    width: CanvasIconButtonMetrics.symbolDiameter,
                    height: CanvasIconButtonMetrics.symbolDiameter,
                    alignment: .center
                )
        }
            .frame(
                width: CanvasIconButtonMetrics.circleDiameter,
                height: CanvasIconButtonMetrics.circleDiameter,
                alignment: .center
            )
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.22 : 0.08), radius: configuration.isPressed ? 1 : 2, y: configuration.isPressed ? 0 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive {
            return Color.accentColor.opacity(isPressed ? 0.34 : 0.22)
        }
        return Color.secondary.opacity(isPressed ? 0.22 : 0.1)
    }
}

private struct CanvasSharpSymbol: NSViewRepresentable {
    let systemName: String
    let pointSize: CGFloat
    let weight: NSFont.Weight
    var textColor: NSColor = .labelColor

    func makeNSView(context _: Context) -> SharpSymbolImageView {
        let imageView = SharpSymbolImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleNone
        imageView.configure(systemName: systemName, pointSize: pointSize, weight: weight, textColor: textColor)
        return imageView
    }

    func updateNSView(_ nsView: SharpSymbolImageView, context _: Context) {
        nsView.configure(systemName: systemName, pointSize: pointSize, weight: weight, textColor: textColor)
    }
}

private final class SharpSymbolImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(systemName: String, pointSize: CGFloat, weight: NSFont.Weight, textColor: NSColor) {
        imageAlignment = .alignCenter
        imageScaling = .scaleNone
        image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: weight))
        contentTintColor = textColor
        symbolConfiguration = .init(pointSize: pointSize, weight: weight)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(systemName)
        needsDisplay = true
    }
}

private struct CanvasSharpText: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let weight: NSFont.Weight
    let textColor: NSColor
    let lineLimit: Int
    var alignment: NSTextAlignment = .left

    func makeNSView(context _: Context) -> SharpTextDrawingView {
        let view = SharpTextDrawingView()
        view.configure(text: text, fontSize: fontSize, weight: weight, textColor: textColor, lineLimit: lineLimit, alignment: alignment)
        return view
    }

    func updateNSView(_ nsView: SharpTextDrawingView, context _: Context) {
        nsView.configure(text: text, fontSize: fontSize, weight: weight, textColor: textColor, lineLimit: lineLimit, alignment: alignment)
    }
}

private final class SharpTextDrawingView: NSView {
    private var text = " "
    private var fontSize: CGFloat = 12
    private var weight: NSFont.Weight = .regular
    private var textColor: NSColor = .labelColor
    private var lineLimit = 1
    private var alignment: NSTextAlignment = .left

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var intrinsicContentSize: NSSize {
        guard lineLimit == 1 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    func configure(
        text: String,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        textColor: NSColor,
        lineLimit: Int,
        alignment: NSTextAlignment
    ) {
        self.text = text.isEmpty ? " " : text
        self.fontSize = fontSize
        self.weight = weight
        self.textColor = textColor
        self.lineLimit = max(1, lineLimit)
        self.alignment = alignment
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(self.text)
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 1, bounds.height > 1 else { return }

        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineLimit == 1 ? .byTruncatingTail : .byWordWrapping
        paragraph.allowsDefaultTighteningForTruncation = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let options: NSString.DrawingOptions = lineLimit == 1
            ? [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            : [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: bounds.width, height: .greatestFiniteMagnitude),
            options: options,
            attributes: attributes
        )
        let drawHeight = lineLimit == 1 ? min(bounds.height, ceil(measured.height)) : bounds.height
        let drawRect = NSRect(
            x: 0,
            y: lineLimit == 1 ? max(0, (bounds.height - drawHeight) / 2) : 0,
            width: bounds.width,
            height: drawHeight
        )
        (text as NSString).draw(with: drawRect, options: options, attributes: attributes)
    }
}

private struct CanvasNativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let weight: NSFont.Weight
    let textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CardTextScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 0)
        configureTextView(textView)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.update(text: $text, modelText: text)
        if !context.coordinator.isEditing, textView.string != text {
            textView.string = text
            context.coordinator.acceptModelText(text)
        }
        configureTextView(textView)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let textView = nsView.documentView as? NSTextView {
            coordinator.commitDeferred(textView.string)
        } else {
            coordinator.cancelPendingCommit()
        }
    }

    private func configureTextView(_ textView: NSTextView) {
        textView.font = .systemFont(ofSize: fontSize, weight: weight)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        private var latestText: String
        private var pendingCommitTask: Task<Void, Never>?
        private(set) var isEditing = false

        init(text: Binding<String>) {
            self.text = text
            latestText = text.wrappedValue
        }

        func update(text: Binding<String>, modelText: String) {
            self.text = text
            if !isEditing {
                latestText = modelText
            }
        }

        func acceptModelText(_ value: String) {
            latestText = value
        }

        func textDidBeginEditing(_: Notification) {
            isEditing = true
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            latestText = textView.string
            scheduleCommit()
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            if let textView = notification.object as? NSTextView {
                commitImmediately(textView.string)
            } else {
                commitImmediately(latestText)
            }
        }

        func commitImmediately(_ value: String) {
            cancelPendingCommit()
            latestText = value
            guard text.wrappedValue != value else { return }
            text.wrappedValue = value
        }

        func commitDeferred(_ value: String) {
            cancelPendingCommit()
            latestText = value
            Task { @MainActor [weak self] in
                self?.commitImmediately(value)
            }
        }

        func cancelPendingCommit() {
            pendingCommitTask?.cancel()
            pendingCommitTask = nil
        }

        private func scheduleCommit() {
            pendingCommitTask?.cancel()
            let value = latestText
            pendingCommitTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: CanvasNodeMetrics.textEditCommitDelayNanos)
                guard !Task.isCancelled else { return }
                self?.pendingCommitTask = nil
                self?.commitImmediately(value)
            }
        }
    }
}

private final class CardTextScrollView: NSScrollView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

private struct AdaptiveTitleText: NSViewRepresentable {
    let text: String
    let baseFontSize: CGFloat
    let minimumFontSize: CGFloat
    let weight: NSFont.Weight

    func makeNSView(context _: Context) -> FittingTitleDrawingView {
        let view = FittingTitleDrawingView()
        view.configure(text: text, baseFontSize: baseFontSize, minimumFontSize: minimumFontSize, weight: weight)
        return view
    }

    func updateNSView(_ nsView: FittingTitleDrawingView, context _: Context) {
        nsView.configure(text: text, baseFontSize: baseFontSize, minimumFontSize: minimumFontSize, weight: weight)
    }
}

private final class FittingTitleDrawingView: NSView {
    private var titleText = " "
    private var baseFontSize: CGFloat = 14
    private var minimumFontSize: CGFloat = 0.6
    private var fittingWeight: NSFont.Weight = .semibold
    private let absoluteMinimumFontSize: CGFloat = 0.2

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(text: String, baseFontSize: CGFloat, minimumFontSize: CGFloat, weight: NSFont.Weight) {
        titleText = text.isEmpty ? " " : text
        self.baseFontSize = max(baseFontSize, minimumFontSize)
        self.minimumFontSize = max(absoluteMinimumFontSize, minimumFontSize)
        fittingWeight = weight
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(titleText)
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let available = bounds.size
        guard available.width > 2, available.height > 2 else { return }

        let fontSize = fittingFontSize(in: available)
        let font = NSFont.systemFont(ofSize: fontSize, weight: fittingWeight)
        let paragraph = paragraphStyle()
        let attributes = drawingAttributes(font: font, paragraph: paragraph)
        let measured = Self.measuredSize(
            titleText,
            width: available.width,
            attributes: attributes
        )
        let drawHeight = min(available.height, ceil(measured.height))
        let drawRect = NSRect(
            x: 0,
            y: max(0, (available.height - drawHeight) / 2),
            width: available.width,
            height: drawHeight
        )

        (titleText as NSString).draw(
            with: drawRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
    }

    private func fittingFontSize(in available: CGSize) -> CGFloat {
        guard available.width > 2, available.height > 2 else {
            return baseFontSize
        }

        if titleFits(fontSize: baseFontSize, in: available) {
            return baseFontSize
        }

        var low = minimumFontSize
        while low > absoluteMinimumFontSize && !titleFits(fontSize: low, in: available) {
            low = max(absoluteMinimumFontSize, low * 0.65)
        }

        var high = max(baseFontSize, low)
        var best = low
        for _ in 0..<14 {
            let candidate = (low + high) / 2
            if titleFits(fontSize: candidate, in: available) {
                best = candidate
                low = candidate
            } else {
                high = candidate
            }
        }
        return best
    }

    private func titleFits(fontSize: CGFloat, in size: CGSize) -> Bool {
        let paragraph = paragraphStyle()
        let attributes = drawingAttributes(
            font: NSFont.systemFont(ofSize: fontSize, weight: fittingWeight),
            paragraph: paragraph
        )
        let measured = Self.measuredSize(titleText, width: size.width, attributes: attributes)
        return measured.width <= size.width + 0.5 && measured.height <= size.height + 0.5
    }

    private func paragraphStyle() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.allowsDefaultTighteningForTruncation = false
        return paragraph
    }

    private func drawingAttributes(font: NSFont, paragraph: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    private static func measuredSize(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGSize {
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
    }
}

private struct CanvasScrollWheelMonitor: NSViewRepresentable {
    let onScroll: (Double, CGPoint) -> Void

    func makeNSView(context _: Context) -> ScrollWheelMonitorView {
        let view = ScrollWheelMonitorView()
        view.onScroll = onScroll
        view.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ nsView: ScrollWheelMonitorView, context _: Context) {
        nsView.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: ScrollWheelMonitorView, coordinator _: ()) {
        nsView.removeMonitor()
    }
}

private final class ScrollWheelMonitorView: NSView {
    var onScroll: ((Double, CGPoint) -> Void)?
    private var monitor: Any?

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let window,
                  event.window === window else {
                return event
            }

            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else {
                return event
            }
            guard !shouldPassThroughScrollEvent(event) else {
                return event
            }

            let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
            guard abs(deltaY) > 0.01 else {
                return nil
            }

            onScroll?(deltaY, location)
            return nil
        }
    }

    private func shouldPassThroughScrollEvent(_ event: NSEvent) -> Bool {
        guard let hitView = window?.contentView?.hitTest(event.locationInWindow) else {
            return false
        }

        var current: NSView? = hitView
        while let view = current {
            if view is NSTextView || view is NSTextField || view is NSScroller {
                return true
            }
            if let scrollView = view as? NSScrollView, scrollView.documentView is NSTextView {
                return true
            }
            current = view.superview
        }
        return false
    }

    func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

private struct CanvasFileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider], CGPoint) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [UTType.fileURL]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.fileURL])
        guard !providers.isEmpty else {
            isTargeted = false
            return false
        }
        isTargeted = false
        onDrop(providers, info.location)
        return true
    }
}

struct CanvasFrameCard: View {
    let node: CanvasNodeModel
    let isSelected: Bool
    let isConnected: Bool
    let glowTheme: CanvasGlowTheme
    let animateGlow: Bool
    let glowPulse: Bool
    let isConnectionSource: Bool
    let onInfo: () -> Void
    let onCopy: () -> Void
    let onStartLink: () -> Void
    let onConnect: () -> Void
    let onDelete: () -> Void
    let onTitleChange: (String) -> Void
    let onNoteChange: (String) -> Void
    @State private var feedback: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    CanvasSharpSymbol(systemName: "rectangle.dashed", pointSize: 12.5, weight: .semibold)
                        .frame(width: 15, height: 15)
                    TextField("Frame name", text: titleBinding)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        triggerFeedback("Copied") {
                            onCopy()
                        }
                    } label: {
                        CanvasSharpSymbol(systemName: "doc.on.doc", pointSize: 12, weight: .semibold)
                            .frame(width: 13, height: 13)
                    }
                    .buttonStyle(CardIconButtonStyle())
                    Button(action: onInfo) {
                        CanvasSharpSymbol(systemName: "info.circle", pointSize: 12, weight: .semibold)
                            .frame(width: 13, height: 13)
                    }
                    .buttonStyle(CardIconButtonStyle())
                    Button(role: .destructive, action: onDelete) {
                        CanvasSharpSymbol(systemName: "trash", pointSize: 12, weight: .semibold)
                            .frame(width: 13, height: 13)
                    }
                    .buttonStyle(CardIconButtonStyle())
                }

                CanvasNativeTextEditor(
                    text: noteBinding,
                    fontSize: 12,
                    weight: .semibold,
                    textColor: NSColor.labelColor.withAlphaComponent(0.86)
                )
                    .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 72)
                Spacer()
            }
            .padding(12)
            .background(frameBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, style: StrokeStyle(lineWidth: isSelected || isConnectionSource ? 2 : 1.4, dash: [8, 5]))
            }
            .overlay {
                if isConnected && glowTheme != .off {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((glowTheme == .blue ? Color.blue : Color.accentColor).opacity(glowTheme == .blue ? 0.48 : 0.24), lineWidth: 2)
                        .blur(radius: glowTheme == .blue ? 5 : 1)
                        .opacity(animateGlow ? (glowPulse ? 0.9 : 0.38) : 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isConnected && glowTheme == .blue ? .blue.opacity(0.16) : .black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 6 : 2, y: 1)

            if let feedback {
                Text(feedback)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.92))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(8)
                    .transition(.opacity.combined(with: .scale))
            }

        }
        .contextMenu {
            Button("Copy Note") {
                triggerFeedback("Copied") {
                    onCopy()
                }
            }
            Button("Show Details", action: onInfo)
            Button("Start Link From This Frame", action: onStartLink)
            Button("Connect", action: onConnect)
            Button("Delete Frame", role: .destructive, action: onDelete)
        }
    }

    private var borderColor: Color {
        if isConnectionSource {
            return .accentColor
        }
        return isSelected ? .accentColor : Color.secondary.opacity(0.45)
    }

    @ViewBuilder
    private var frameBackground: some View {
        if let colorStyle {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorStyle.cardFill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.045))
        }
    }

    private var colorStyle: CanvasNodeColorStyle? {
        CanvasNodeColorStyle(rawValue: node.accentColorRaw)
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { node.title },
            set: { onTitleChange($0) }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { node.body },
            set: { onNoteChange($0) }
        )
    }

    private func triggerFeedback(_ message: String, action: () -> Void) {
        action()
        withAnimation(.easeOut(duration: 0.12)) {
            feedback = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard feedback == message else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                feedback = nil
            }
        }
    }

}

private struct CanvasEdgeStrokeLayer: View {
    let segments: [CanvasEdgeSegment]
    let transientControlPoints: [String: CGPoint]
    let selectedEdgeIDs: Set<String>
    let theme: CanvasGlowTheme
    let dashPhase: Double?
    let lineScale: CGFloat
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            for segment in segments {
                let curve = EdgePathFactory.curve(
                    start: segment.start,
                    end: segment.end,
                    startDirection: segment.startDirection,
                    endDirection: segment.endDirection,
                    control: transientControlPoints[segment.id] ?? segment.control,
                    routePoints: segment.routePoints
                )

                context.stroke(
                    curve,
                    with: .color(Color.secondary.opacity(0.36)),
                    style: StrokeStyle(lineWidth: 1.7 * lineScale, lineCap: .round, lineJoin: .round)
                )

                if selectedEdgeIDs.contains(segment.id) {
                    context.stroke(
                        curve,
                        with: .color(Color.accentColor.opacity(0.92)),
                        style: StrokeStyle(lineWidth: max(2.6, 3.2 * lineScale), lineCap: .round, lineJoin: .round)
                    )
                }

                if let dashPhase {
                    context.stroke(
                        curve,
                        with: .color(flowColor.opacity(theme == .blue ? 1 : 0.9)),
                        style: StrokeStyle(
                            lineWidth: (theme == .blue ? 3.4 : 2.4) * lineScale,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [24 * lineScale, 148 * lineScale],
                            dashPhase: dashPhase * lineScale
                        )
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var flowColor: Color {
        theme == .blue ? .blue : .accentColor
    }
}

private struct CanvasEdgeArrowHeadLayer: View {
    let segments: [CanvasEdgeSegment]
    let transientControlPoints: [String: CGPoint]
    let selectedEdgeIDs: Set<String>
    let theme: CanvasGlowTheme
    let isAnimated: Bool
    let arrowScale: CGFloat
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            for segment in segments {
                let arrow = EdgePathFactory.arrowHead(end: segment.end, direction: segment.endDirection, scale: arrowScale)
                context.fill(arrow, with: .color(arrowColor(isSelected: selectedEdgeIDs.contains(segment.id))))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func arrowColor(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.95)
        }
        guard isAnimated, theme != .off else {
            return Color.primary.opacity(0.72)
        }
        return (theme == .blue ? Color.blue : Color.accentColor).opacity(1)
    }
}

struct FlowingArrowEdge: View {
    let start: CGPoint
    let end: CGPoint
    let startDirection: CGPoint
    let endDirection: CGPoint
    let control: CGPoint?
    let routePoints: [CGPoint]
    let theme: CanvasGlowTheme
    let dashPhase: Double?
    let isSelected: Bool
    let lineScale: CGFloat
    let canvasSize: CGSize

    var body: some View {
        edgeCanvas(dashPhase: dashPhase)
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var flowColor: Color {
        theme == .blue ? .blue : .accentColor
    }

    private func edgeCanvas(dashPhase: Double?) -> some View {
        Canvas { context, _ in
            let curve = EdgePathFactory.curve(
                start: start,
                end: end,
                startDirection: startDirection,
                endDirection: endDirection,
                control: control,
                routePoints: routePoints
            )

            context.stroke(
                curve,
                with: .color(Color.secondary.opacity(0.36)),
                style: StrokeStyle(lineWidth: 1.7 * lineScale, lineCap: .round, lineJoin: .round)
            )

            if isSelected {
                context.stroke(
                    curve,
                    with: .color(Color.accentColor.opacity(0.92)),
                    style: StrokeStyle(lineWidth: max(2.6, 3.2 * lineScale), lineCap: .round, lineJoin: .round)
                )
            }

            if let dashPhase {
                context.stroke(
                    curve,
                    with: .color(flowColor.opacity(theme == .blue ? 1 : 0.9)),
                    style: StrokeStyle(
                        lineWidth: (theme == .blue ? 3.4 : 2.4) * lineScale,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [24 * lineScale, 148 * lineScale],
                        dashPhase: dashPhase * lineScale
                    )
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

struct FlowingArrowHead: View {
    let start: CGPoint
    let end: CGPoint
    let endDirection: CGPoint
    let control: CGPoint?
    let theme: CanvasGlowTheme
    let isAnimated: Bool
    let isSelected: Bool
    let arrowScale: CGFloat
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            let arrow = EdgePathFactory.arrowHead(end: end, direction: endDirection, scale: arrowScale)
            context.fill(arrow, with: .color(arrowColor))
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var arrowColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.95)
        }
        guard isAnimated, theme != .off else {
            return Color.primary.opacity(0.72)
        }
        return (theme == .blue ? Color.blue : Color.accentColor).opacity(1)
    }
}

struct EdgeControlHandle: View {
    let isCustom: Bool
    let isLocked: Bool
    let zoom: CGFloat

    var body: some View {
        let diameter = CGFloat(CanvasEdgeControlHandleMetrics.diameter(zoom: Double(zoom), baseDiameter: 13))
        let strokeWidth = max(0.5, 2 * zoom)
        ZStack {
            Circle()
                .fill(handleFill)
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(6, 5.5 * zoom), weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
                Circle()
                    .stroke(Color.blue.opacity(0.95), lineWidth: strokeWidth)
        }
        .shadow(color: .black.opacity(0.16), radius: 2 * zoom, y: zoom)
        .contentShape(Circle())
        .help(isLocked ? "Anchor locked. Right-click to unlock or delete." : "Drag to bend this link. Right-click for anchor actions.")
    }

    private var handleFill: Color {
        if isLocked {
            return .orange
        }
        if isCustom {
            return .blue
        }
        return Color(nsColor: .controlBackgroundColor)
    }
}

private struct FrameResizeHandle: View {
    var helpText: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.background.opacity(0.78))
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(width: 22, height: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
        }
        .help(helpText)
    }
}

private enum EdgePathFactory {
    static func curve(
        start: CGPoint,
        end: CGPoint,
        startDirection: CGPoint,
        endDirection: CGPoint,
        control: CGPoint? = nil,
        routePoints: [CGPoint] = []
    ) -> Path {
        var path = Path()
        path.move(to: start)
        if !routePoints.isEmpty {
            for point in routePoints {
                path.addLine(to: point)
            }
            path.addLine(to: end)
            return path
        }
        if let control {
            let segments = CanvasEdgeCurveGeometry.controlsThroughPoint(
                start: edgePoint(start),
                control: edgePoint(control),
                end: edgePoint(end),
                startDirection: edgePoint(startDirection),
                endDirection: edgePoint(endDirection)
            )
            path.addCurve(
                to: control,
                control1: point(segments.first.control1),
                control2: point(segments.first.control2)
            )
            path.addCurve(
                to: end,
                control1: point(segments.second.control1),
                control2: point(segments.second.control2)
            )
            return path
        }
        let controls = CanvasEdgeCurveGeometry.automaticControls(
            start: edgePoint(start),
            end: edgePoint(end),
            startDirection: edgePoint(startDirection),
            endDirection: edgePoint(endDirection)
        )
        path.addCurve(
            to: end,
            control1: point(controls.control1),
            control2: point(controls.control2)
        )
        return path
    }

    static func handlePoint(start: CGPoint, end: CGPoint, control: CGPoint?, routePoints: [CGPoint] = []) -> CGPoint {
        if let control {
            return control
        }
        if !routePoints.isEmpty {
            return routePoints[routePoints.count / 2]
        }
        return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }

    static func arrowHead(end: CGPoint, direction: CGPoint, scale: CGFloat = 1) -> Path {
        let angle = CGFloat(
            CanvasEdgeCurveGeometry.terminalAngleRadians(
                endDirection: edgePoint(direction)
            )
        )
        let arrowLength: CGFloat = 13 * scale
        let halfWidth: CGFloat = 5.5 * scale
        let baseCenter = CGPoint(
            x: end.x - arrowLength * cos(angle),
            y: end.y - arrowLength * sin(angle)
        )
        let normal = angle + .pi / 2
        let left = CGPoint(
            x: baseCenter.x + halfWidth * cos(normal),
            y: baseCenter.y + halfWidth * sin(normal)
        )
        let right = CGPoint(
            x: baseCenter.x - halfWidth * cos(normal),
            y: baseCenter.y - halfWidth * sin(normal)
        )

        var path = Path()
        path.move(to: end)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private static func edgePoint(_ point: CGPoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: Double(point.x), y: Double(point.y))
    }

    private static func point(_ point: CanvasEdgePoint) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 32
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return path
    }
}
