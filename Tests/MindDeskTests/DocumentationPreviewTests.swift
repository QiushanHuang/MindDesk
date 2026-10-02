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
        if ProcessInfo.processInfo.environment["MINDDESK_CANVAS_ZOOM_PREVIEWS"] == "1" {
            for zoom in [0.175, 0.35, 0.7, 1.4] {
                canvas.zoom = zoom
                try await render(canvasView.padding(24).modelContainer(container).defaultAppStorage(settings),
                    size: CGSize(width: 1200, height: 840),
                    to: output.appendingPathComponent("canvas-zoom-\(zoom).png"))
            }
            canvas.zoom = 0.7
            try await render(canvasView.padding(24).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 800, height: 620), to: output.appendingPathComponent("canvas-compact.png"))
            try await render(canvasView.padding(24).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 1200, height: 840), to: output.appendingPathComponent("canvas-dark.png"), scheme: .dark)
            canvas.zoom = 1
        }
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
        try await render(QuickNoteCaptureSheet(save: { _, _ in }), size: CGSize(width: 560, height: 460), to: output.appendingPathComponent("quick-note.png"))
        if ProcessInfo.processInfo.environment["MINDDESK_POLISH_PREVIEWS"] == "1" {
            try await render(taskView.padding(20).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 700, height: 408), to: output.appendingPathComponent("tasks-compact.png"))
            let collapsedTaskView = WorkspaceTodoBoardView(workspaceId: workspace.id, resources: [], todos: todos, groups: groups,
                isOpen: .constant(false), isDoneColumnOpen: .constant(true), onStatus: { _ in })
            try await render(collapsedTaskView.padding(20).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 560, height: 90), to: output.appendingPathComponent("tasks-collapsed.png"))
            let shortTaskView = WorkspaceTodoBoardView(workspaceId: workspace.id, resources: [], todos: todos, groups: groups,
                isOpen: .constant(true), isDoneColumnOpen: .constant(true), onStatus: { _ in }, expandedHeight: 180)
            try await render(shortTaskView.padding(20).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 700, height: 220), to: output.appendingPathComponent("tasks-short-panel.png"))
            try await render(taskView.padding(24).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 1180, height: 408), to: output.appendingPathComponent("tasks-dark.png"), scheme: .dark)
            let resources = [
                ResourcePinModel(id: "demo-resource-folder", title: "Shared experiment references and source material", targetType: .folder,
                    displayPath: "/Demo/Research project/Shared experiment references and source material", lastResolvedPath: "/Demo/References", scope: .global),
                ResourcePinModel(id: "demo-resource-file", title: "Comparison notes", targetType: .file,
                    displayPath: "/Demo/Research project/Comparison notes and reproducibility checklist.pdf", lastResolvedPath: "/Demo/Comparison.pdf", scope: .global,
                    originalName: "Comparison notes and reproducibility checklist.pdf", status: .unavailable)
            ]
            for resource in resources { context.insert(resource) }
            let usages = [ResourceWorkspaceUsage(id: "a", title: "Research project"),
                          ResourceWorkspaceUsage(id: "b", title: "Long-running comparison study"),
                          ResourceWorkspaceUsage(id: "c", title: "Writing and publication")]
            let resourceView = ResourceListView(title: "Resources", resources: resources, knownResources: resources,
                scope: .global, workspaceId: nil, targetFilter: nil, pinImported: false,
                onSelect: { _ in }, onStatus: { _ in }, onInspect: { _ in }, onRemove: { _ in },
                workspaceUsageByResourceID: Dictionary(uniqueKeysWithValues: resources.map { ($0.id, usages) }),
                onSelectWorkspace: { _ in })
            for width in [650.0, 1150.0] {
                try await render(resourceView.padding(24).modelContainer(container),
                    size: CGSize(width: width, height: 460), to: output.appendingPathComponent("resources-\(Int(width)).png"))
            }
            try await render(resourceView.padding(24).modelContainer(container),
                size: CGSize(width: 650, height: 460), to: output.appendingPathComponent("resources-dark.png"), scheme: .dark)
            let homeView = HomeView(workspaces: [workspace], workspaceBriefsByID: [:], resources: resources, snippets: [],
                onSelectWorkspace: { _ in }, onSelectResource: { _ in }, onOpenResource: { _ in },
                onCopyResourcePath: { _ in }, onInspectResource: { _ in }, onCopySnippet: { _ in },
                onEditSnippet: { _ in }, onDeleteSnippet: { _ in }, onInspectSnippet: { _ in })
            try await render(homeView.modelContainer(container), size: CGSize(width: 800, height: 650),
                to: output.appendingPathComponent("home.png"))
            let command = SnippetModel(id: "demo-command", title: "Run a reproducible comparison", kind: .command,
                body: "python compare.py --config demo.json", details: "Shared comparison command", scope: .global)
            context.insert(command)
            let commandCard = SnippetActionCard(snippet: command, isExpanded: false, compact: true,
                onToggleExpanded: {}, onCopy: {}, onEdit: {}, onDelete: {}, onInspect: {},
                onOpenTerminal: {}, onRun: {})
            for width in [244.0, 304.0] {
                try await render(commandCard.padding(12).modelContainer(container),
                    size: CGSize(width: width, height: 210), to: output.appendingPathComponent("command-card-\(Int(width - 24)).png"))
            }
            try await render(commandCard.padding(12).modelContainer(container),
                size: CGSize(width: 244, height: 210), to: output.appendingPathComponent("command-card-dark.png"), scheme: .dark)
            let listCommandCard = SnippetActionCard(snippet: command, isExpanded: false,
                onToggleExpanded: {}, onCopy: {}, onEdit: {}, onDelete: {}, onInspect: {},
                onOpenTerminal: {}, onRun: {})
            try await render(listCommandCard.padding(12).modelContainer(container),
                size: CGSize(width: 364, height: 180), to: output.appendingPathComponent("command-list-narrow.png"))
            try await render(shortTaskView.padding(20).modelContainer(container).defaultAppStorage(settings),
                size: CGSize(width: 520, height: 220), to: output.appendingPathComponent("tasks-inspector-width.png"))
        }
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
