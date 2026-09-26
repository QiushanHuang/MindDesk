import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import MindDesk

/// Opt-in documentation renderer. Only synthetic in-memory data is used.
@MainActor
final class DocumentationPreviewTests: XCTestCase {
    func testRenderDocumentationPreviews() async throws {
        guard let directory = ProcessInfo.processInfo.environment["MINDDESK_DOCUMENTATION_PREVIEWS"] else {
            throw XCTSkip("Opt-in documentation images")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: WorkspaceModel.self, ResourcePinModel.self, SnippetModel.self,
            WorkspaceTodoModel.self, WorkspaceTodoGroupModel.self,
            CanvasModel.self, CanvasNodeModel.self, CanvasEdgeModel.self, FinderAliasRecordModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let workspace = WorkspaceModel(id: "demo-project", title: "Research project", details: "Compare two approaches and plan the next experiment.")
        let canvas = CanvasModel(id: "demo-canvas", workspaceId: workspace.id, title: "Research map", viewportX: 24, viewportY: 24, zoom: 1, animationsEnabled: false)
        context.insert(workspace); context.insert(canvas)
        let nodes = [
            CanvasNodeModel(id: "references", canvasId: canvas.id, title: "01 · Understand the problem", nodeType: .groupFrame, x: 30, y: 45, width: 700, height: 300, zIndex: -1),
            CanvasNodeModel(id: "question", canvasId: canvas.id, title: "Research question", body: "Which approach is easier to reproduce?\nCompare setup time and clarity of results.", nodeType: .note, x: 60, y: 105, width: 290, height: 170, parentNodeId: "references", accentColorRaw: "blue"),
            CanvasNodeModel(id: "reading", canvasId: canvas.id, title: "Reading notes", body: "Approach A: fewer preparation steps.\nApproach B: more control over the inputs.\nKeep the evaluation conditions identical.", nodeType: .note, x: 395, y: 105, width: 300, height: 190, parentNodeId: "references", accentColorRaw: "green"),
            CanvasNodeModel(id: "next", canvasId: canvas.id, title: "02 · Next experiment", nodeType: .groupFrame, x: 30, y: 410, width: 700, height: 290, zIndex: -1),
            CanvasNodeModel(id: "plan", canvasId: canvas.id, title: "Comparison plan", body: "1. Use the same input sample.\n2. Record setup and processing time.\n3. Save the result beside the notes.", nodeType: .note, x: 60, y: 470, width: 290, height: 185, parentNodeId: "next", accentColorRaw: "orange"),
            CanvasNodeModel(id: "decision", canvasId: canvas.id, title: "Decision to make", body: "Choose the approach with a repeatable workflow.\nWrite down the trade-offs before proceeding.", nodeType: .note, x: 395, y: 470, width: 300, height: 170, parentNodeId: "next", accentColorRaw: "purple")
        ]
        for node in nodes { context.insert(node) }
        let edge = CanvasEdgeModel(id: "demo-link", canvasId: canvas.id, sourceNodeId: "reading", targetNodeId: "plan", label: "test the comparison", animated: false)
        context.insert(edge)
        let groups = [
            WorkspaceTodoGroupModel(id: "todo-experiment", workspaceId: workspace.id, title: "Next experiment", sortIndex: 0),
            WorkspaceTodoGroupModel(id: "todo-reading", workspaceId: workspace.id, title: "Reading", sortIndex: 1)
        ]
        let todos = [
            WorkspaceTodoModel(id: "task1", workspaceId: workspace.id, groupId: groups[0].id, title: "Prepare the shared input sample", details: "Use the same conditions for both approaches.", isPinned: true, sortIndex: 0),
            WorkspaceTodoModel(id: "task2", workspaceId: workspace.id, groupId: groups[0].id, title: "Run the comparison and record timing", details: "Save results beside the comparison notes.", sortIndex: 1),
            WorkspaceTodoModel(id: "task3", workspaceId: workspace.id, groupId: groups[0].id, title: "Write down the trade-offs", details: "Compare repeatability and setup effort.", sortIndex: 2),
            WorkspaceTodoModel(id: "task4", workspaceId: workspace.id, groupId: groups[0].id, title: "Define the comparison question", isCompleted: true, sortIndex: 3)
        ]
        for group in groups { context.insert(group) }
        for todo in todos { context.insert(todo) }
        try context.save()
        let settingsName = "MindDesk.DocumentationPreview." + UUID().uuidString
        let settings = try XCTUnwrap(UserDefaults(suiteName: settingsName))
        defer { settings.removePersistentDomain(forName: settingsName) }
        let controller = WorkspaceWindowScopeController()
        let focus = controller.focus(workspaceID: workspace.id)
        guard case let .bound(scope) = controller.bind(.unique(canvasID: canvas.id), for: focus) else {
            return XCTFail("Demo canvas could not bind")
        }
        let canvasView = WorkspaceCanvasView(
            workspaceWindowScopeController: controller, canvasScope: scope,
            nodeOwnershipReader: .live(container: container), canvas: canvas,
            resources: [], allResources: [], workspaces: [workspace], snippets: [],
            todos: todos, todoGroups: groups, nodes: nodes, edges: [edge],
            openTodoPanelRequest: nil, onOpenTodoPanelRequestHandled: { _ in },
            onStatus: { _ in }, onInspect: { _ in }, onOpenWorkspace: { _ in }
        )
        try await render(canvasView.padding(24).modelContainer(container).defaultAppStorage(settings), size: CGSize(width: 1200, height: 840), to: output.appendingPathComponent("canvas.png"))
        let taskView = WorkspaceTodoBoardView(
            workspaceId: workspace.id, resources: [], todos: todos, groups: groups,
            isOpen: .constant(true), isDoneColumnOpen: .constant(true), onStatus: { _ in },
            expandedHeight: 360
        )
        try await render(taskView.padding(24).modelContainer(container).defaultAppStorage(settings), size: CGSize(width: 1180, height: 408), to: output.appendingPathComponent("tasks.png"))
        let selection = OrganizationSelection(canvas: canvas, nodes: nodes.filter { $0.nodeType == .note }, contextNodes: nodes, edges: [edge])
        try await render(OrganizationSheet(selection: selection, apply: { _, _ in }).modelContainer(container).defaultAppStorage(settings), size: CGSize(width: 860, height: 820), to: output.appendingPathComponent("organizer.png"))
        try await render(OrganizationSheet(selection: selection, apply: { _, _ in }).modelContainer(container).defaultAppStorage(settings), size: CGSize(width: 860, height: 820), to: output.appendingPathComponent("organizer-dark.png"), scheme: .dark)
        try await render(OrganizationWorkflowEditor(workflows: [], seed: .init(id: "demo", title: "Weekly research plan", intent: .extractTasks, scope: .neighbors, instructions: "Keep observations separate from assumptions. Do not invent deadlines."), save: { _ in }), size: CGSize(width: 760, height: 560), to: output.appendingPathComponent("workflows.png"))
        try await render(QuickNoteCaptureSheet(save: { _, _ in }), size: CGSize(width: 560, height: 380), to: output.appendingPathComponent("quick-note.png"))
    }

    private func render<V: View>(_ view: V, size: CGSize, to url: URL, scheme: ColorScheme = .light) async throws {
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.controlActiveState, .active)
            .environment(\.colorScheme, scheme).preferredColorScheme(scheme))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.setFrameSize(size)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
        XCTAssertGreaterThan(data.count, 10_000)
        window.close()
    }
}
