import MindDeskCore
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum SidebarSelection: Hashable {
    case home
    case global
    case pinnedFolders
    case pinnedFiles
    case resource(String)
    case snippets
    case workspace(String)
}

private struct ManifestExportOptions {
    let scope: ManifestExportScope
    let includesUsageDates: Bool
}

private struct ManifestImportSummary {
    var workspaces: Int
    var resources: Int
    var snippets: Int
    var canvases: Int
    var nodes: Int
    var edges: Int
    var aliases: Int
    var todoGroups: Int
    var todos: Int

    var statusText: String {
        let parts = [
            "\(workspaces) workspace\(workspaces == 1 ? "" : "s")",
            "\(resources) resource\(resources == 1 ? "" : "s")",
            "\(snippets) snippet\(snippets == 1 ? "" : "s")",
            "\(canvases) canvas\(canvases == 1 ? "" : "es")",
            "\(nodes) card\(nodes == 1 ? "" : "s")",
            "\(edges) link\(edges == 1 ? "" : "s")",
            "\(aliases) alias\(aliases == 1 ? "" : "es")",
            "\(todoGroups) task group\(todoGroups == 1 ? "" : "s")",
            "\(todos) task\(todos == 1 ? "" : "s")"
        ]
        return parts.joined(separator: ", ")
    }
}

struct MindDeskFocusedCommands {
    var newWorkspace: () -> Void
    var quickOpen: () -> Void
    var importManifest: () -> Void
    var exportManifest: () -> Void
}

private struct MindDeskFocusedCommandsKey: FocusedValueKey {
    typealias Value = MindDeskFocusedCommands
}

extension FocusedValues {
    var mindDeskCommands: MindDeskFocusedCommands? {
        get { self[MindDeskFocusedCommandsKey.self] }
        set { self[MindDeskFocusedCommandsKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkspaceModel.updatedAt, order: .reverse) private var workspaces: [WorkspaceModel]
    @Query(sort: \ResourcePinModel.updatedAt, order: .reverse) private var resources: [ResourcePinModel]
    @Query(sort: \SnippetModel.updatedAt, order: .reverse) private var snippets: [SnippetModel]
    @Query(sort: \WorkspaceTodoModel.updatedAt, order: .reverse) private var todos: [WorkspaceTodoModel]
    @Query(sort: \WorkspaceTodoGroupModel.updatedAt, order: .reverse) private var todoGroups: [WorkspaceTodoGroupModel]
    @Query private var canvases: [CanvasModel]
    @Query private var nodes: [CanvasNodeModel]
    @Query private var edges: [CanvasEdgeModel]
    @Query private var aliases: [FinderAliasRecordModel]
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = AppPreferenceDefaults.canvasDefaultZoomPercent
    @AppStorage(AppPreferenceKeys.startupDestination) private var startupDestinationRaw = AppPreferenceDefaults.startupDestination
    @AppStorage(AppPreferenceKeys.manifestExportScope) private var manifestExportScopeRaw = AppPreferenceDefaults.manifestExportScope
    @AppStorage(AppPreferenceKeys.manifestExportIncludesUsageDates) private var manifestExportIncludesUsageDates = AppPreferenceDefaults.manifestExportIncludesUsageDates

    @State private var selection: SidebarSelection? = .home
    @State private var inspectorSelection: InspectorSelection?
    @State private var statusMessage = "Ready"
    @State private var workspaceCanvasTabActive = false
    @State private var pinnedFoldersExpanded = true
    @State private var pinnedFilesExpanded = true
    @State private var renamingWorkspace: WorkspaceModel?
    @State private var workspaceToDelete: WorkspaceModel?
    @State private var renamingResource: ResourcePinModel?
    @State private var resourceToRemove: ResourcePinModel?
    @State private var editingSnippet: SnippetModel?
    @State private var snippetToDelete: SnippetModel?
    @State private var pinnedFoldersDropTarget = false
    @State private var pinnedFilesDropTarget = false
    @State private var isInspectorVisible = false
    @State private var isQuickOpenPresented = false
    @State private var quickOpenRecordsSnapshot: [QuickOpenRecord] = []
    @State private var didApplyStartupDestination = false

    private var defaultCanvasZoom: Double {
        CanvasZoomBaseline.actualZoom(
            percent: canvasDefaultZoomPercent,
            standardBaseline: CanvasZoomBaseline.standardBaseline,
            minimum: CanvasZoomBaseline.minimumZoom,
            maximum: CanvasZoomBaseline.maximumZoom
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Workbench") {
                    Label("Home", systemImage: "house")
                        .tag(SidebarSelection.home)
                    Label("Global Library", systemImage: "tray.full")
                        .tag(SidebarSelection.global)
                    Label("Snippet Library", systemImage: "text.quote")
                        .tag(SidebarSelection.snippets)
                }

                Section("Pinned") {
                    DisclosureGroup(isExpanded: $pinnedFoldersExpanded) {
                        ForEach(pinnedFolders) { resource in
                            SidebarResourceRow(
                                resource: resource,
                                onCopy: { copyResourcePath(resource) },
                                onOpen: { openResource(resource) }
                            )
                                .tag(SidebarSelection.resource(resource.id))
                                .contextMenu {
                                    resourceContextMenu(for: resource)
                                }
                        }
                    } label: {
                        HStack {
                            Label("Pinned Folders", systemImage: "folder")
                            Spacer()
                            Button {
                                selection = .pinnedFolders
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                            .buttonStyle(.plain)
                            .help("Open folders list")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = .pinnedFolders
                        }
                    }
                    .tag(SidebarSelection.pinnedFolders)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $pinnedFoldersDropTarget) { providers in
                        FileDropLoader.loadFileURLs(from: providers) { urls in
                            importPinnedDrop(urls, targetFilter: .folder)
                        }
                    }

                    DisclosureGroup(isExpanded: $pinnedFilesExpanded) {
                        ForEach(pinnedFiles) { resource in
                            SidebarResourceRow(
                                resource: resource,
                                onCopy: { copyResourcePath(resource) },
                                onOpen: { openResource(resource) }
                            )
                                .tag(SidebarSelection.resource(resource.id))
                                .contextMenu {
                                    resourceContextMenu(for: resource)
                                }
                        }
                    } label: {
                        HStack {
                            Label("Pinned Files", systemImage: "doc")
                            Spacer()
                            Button {
                                selection = .pinnedFiles
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                            .buttonStyle(.plain)
                            .help("Open files list")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = .pinnedFiles
                        }
                    }
                    .tag(SidebarSelection.pinnedFiles)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $pinnedFilesDropTarget) { providers in
                        FileDropLoader.loadFileURLs(from: providers) { urls in
                            importPinnedDrop(urls, targetFilter: .file)
                        }
                    }
                }

                Section("Workspaces") {
                    ForEach(orderedWorkspaces) { workspace in
                        SidebarWorkspaceRow(workspace: workspace)
                            .tag(SidebarSelection.workspace(workspace.id))
                            .contextMenu {
                                workspaceContextMenu(for: workspace)
                            }
                    }
                    .onMove(perform: moveWorkspaces)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: WorkbenchSidebarMetrics.minimumWidth,
                ideal: WorkbenchSidebarMetrics.idealWidth,
                max: WorkbenchSidebarMetrics.maximumWidth
            )
            .navigationTitle("MindDesk")
            .toolbar {
                Button {
                    addWorkspace()
                } label: {
                    Label("New Workspace", systemImage: "plus")
                }
            }
        } detail: {
            HStack(spacing: 0) {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if shouldShowInspector {
                    Divider()
                    InspectorView(
                        selection: inspectorSelection,
                        resources: resources,
                        snippets: snippets,
                        nodes: nodes,
                        statusMessage: statusMessage
                    )
                    .frame(width: 300)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(.bar)
            }
            .toolbar {
                Button {
                    openQuickOpen()
                } label: {
                    Label("Quick Open", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
                Button {
                    exportManifest()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button {
                    importManifest()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Button {
                    isInspectorVisible.toggle()
                } label: {
                    Label(isInspectorVisible ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
            }
            .navigationTitle(detailNavigationTitle)
            .onAppear {
                do {
                    try SeedData.seedIfNeeded(context: modelContext, workspaces: workspaces, resources: resources, snippets: snippets, canvases: canvases, nodes: nodes)
                } catch {
                    setStatus(error.localizedDescription)
                }
                applyStartupDestinationIfNeeded()
            }
            .onChange(of: workspaces.map(\.id)) { _, _ in
                applyStartupDestinationIfNeeded()
            }
            .onChange(of: selection) { _, newValue in
                if case .workspace = newValue {
                    return
                }
                workspaceCanvasTabActive = false
            }
        }
        .sheet(item: $renamingWorkspace) { workspace in
            WorkspaceRenameSheet(workspace: workspace) {
                saveWorkspaceRename(workspace)
            }
        }
        .sheet(item: $renamingResource) { resource in
            ResourceRenameSheet(resource: resource) {
                saveResourceRename(resource)
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditor(snippet: snippet, scope: snippet.scope, workspaceId: snippet.workspaceId, resources: resources) { draft in
                saveSnippet(snippet, draft: draft)
            }
        }
        .sheet(isPresented: $isQuickOpenPresented, onDismiss: {
            quickOpenRecordsSnapshot = []
        }) {
            QuickOpenPanel(
                records: quickOpenRecordsSnapshot,
                onOpen: openQuickOpenRecord
            )
        }
        .alert("Delete workspace metadata?", isPresented: Binding(
            get: { workspaceToDelete != nil },
            set: { if !$0 { workspaceToDelete = nil } }
        )) {
            Button("Delete MindDesk Metadata", role: .destructive) {
                if let workspaceToDelete {
                    deleteWorkspace(workspaceToDelete)
                }
                workspaceToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                workspaceToDelete = nil
            }
        } message: {
            if let workspaceToDelete {
                Text(workspaceDeletionImpactMessage(for: workspaceToDelete))
            }
        }
        .alert("Remove source metadata?", isPresented: Binding(
            get: { resourceToRemove != nil },
            set: { if !$0 { resourceToRemove = nil } }
        )) {
            Button("Remove From MindDesk", role: .destructive) {
                if let resourceToRemove {
                    removeResourceFromLibrary(resourceToRemove)
                }
                resourceToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                resourceToRemove = nil
            }
        } message: {
            if let resourceToRemove {
                Text("This removes \(resourceToRemove.displayName) and related MindDesk canvas cards/aliases from MindDesk metadata only. Finder files and folders are not deleted, renamed, or moved.")
            }
        }
        .alert("Delete snippet metadata?", isPresented: Binding(
            get: { snippetToDelete != nil },
            set: { if !$0 { snippetToDelete = nil } }
        )) {
            Button("Delete From MindDesk", role: .destructive) {
                if let snippetToDelete {
                    deleteSnippet(snippetToDelete)
                }
                snippetToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                snippetToDelete = nil
            }
        } message: {
            if let snippetToDelete {
                Text("This removes \(snippetToDelete.title), related canvas snippet cards, and MindDesk alias metadata. Finder files and folders are not deleted, renamed, or moved.")
            }
        }
        .focusedValue(\.mindDeskCommands, MindDeskFocusedCommands(
            newWorkspace: addWorkspace,
            quickOpen: openQuickOpen,
            importManifest: importManifest,
            exportManifest: exportManifest
        ))
    }

    private var shouldShowInspector: Bool {
        isInspectorVisible
    }

    private var detailNavigationTitle: String {
        switch selection ?? .home {
        case .home:
            return "Home"
        case .global:
            return "Global Library"
        case .pinnedFolders:
            return "Pinned Folders"
        case .pinnedFiles:
            return "Pinned Files"
        case .resource(let id):
            return resources.first(where: { $0.id == id })?.displayName ?? "Resource"
        case .snippets:
            return "Snippet Library"
        case .workspace(let id):
            return workspaces.first(where: { $0.id == id })?.title ?? "Workspace"
        }
    }

    private var orderedWorkspaces: [WorkspaceModel] {
        let records = workspaces.map {
            WorkspaceSidebarOrderRecord(id: $0.id, isPinned: $0.isPinned, sortIndex: $0.sortIndex, updatedAt: $0.updatedAt)
        }
        let orderedIds = WorkspaceSidebarOrdering.ordered(records).map(\.id)
        let rankById = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($0.element, $0.offset) })
        return workspaces.sorted {
            (rankById[$0.id] ?? Int.max) < (rankById[$1.id] ?? Int.max)
        }
    }

    private var pinnedFolders: [ResourcePinModel] {
        orderedResources.filter { $0.isPinned && $0.targetType == .folder }
    }

    private var pinnedFiles: [ResourcePinModel] {
        orderedResources.filter { $0.isPinned && $0.targetType == .file }
    }

    private var orderedResources: [ResourcePinModel] {
        resources.sorted {
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            let nameComparison = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    private var quickOpenRecords: [QuickOpenRecord] {
        var records: [QuickOpenRecord] = []
        records.append(contentsOf: orderedWorkspaces.map {
            QuickOpenRecord(id: "workspace:\($0.id)", kind: .workspace, title: $0.title, subtitle: $0.details)
        })
        records.append(contentsOf: orderedResources.map {
            QuickOpenRecord(id: "resource:\($0.id)", kind: .resource, title: $0.displayName, subtitle: $0.displayPath)
        })
        let snippetRecords = snippets.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            let titleComparison = $0.title.localizedCaseInsensitiveCompare($1.title)
            if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
            return $0.id < $1.id
        }.map {
            QuickOpenRecord(id: "snippet:\($0.id)", kind: .snippet, title: $0.title, subtitle: $0.details)
        }
        records.append(contentsOf: snippetRecords)
        let webCards = nodes.compactMap { node -> QuickOpenRecord? in
            guard node.objectType == "webURL", let url = WebCardURL.normalized(node.objectId ?? node.body) else { return nil }
            return QuickOpenRecord(id: "webCard:\(node.id)", kind: .webCard, title: node.title, subtitle: url.absoluteString)
        }.sorted {
            let titleComparison = $0.title.localizedCaseInsensitiveCompare($1.title)
            if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
            let subtitleComparison = $0.subtitle.localizedCaseInsensitiveCompare($1.subtitle)
            if subtitleComparison != .orderedSame { return subtitleComparison == .orderedAscending }
            return $0.id < $1.id
        }
        records.append(contentsOf: webCards)
        return records
    }

    private func applyStartupDestinationIfNeeded() {
        guard !didApplyStartupDestination else { return }

        switch AppStartupDestination.resolved(startupDestinationRaw) {
        case .home:
            selection = .home
            didApplyStartupDestination = true
        case .mostRecentWorkspace:
            if let workspace = mostRecentWorkspace {
                selection = .workspace(workspace.id)
                didApplyStartupDestination = true
            } else {
                selection = .home
            }
        case .globalLibrary:
            selection = .global
            didApplyStartupDestination = true
        case .pinnedFolders:
            selection = .pinnedFolders
            didApplyStartupDestination = true
        case .pinnedFiles:
            selection = .pinnedFiles
            didApplyStartupDestination = true
        case .snippets:
            selection = .snippets
            didApplyStartupDestination = true
        }
    }

    private var mostRecentWorkspace: WorkspaceModel? {
        recentWorkspaces.first
    }

    private var recentWorkspaces: [WorkspaceModel] {
        let records = workspaces.map {
            WorkspaceRecencyRecord(id: $0.id, lastOpenedAt: $0.lastOpenedAt, updatedAt: $0.updatedAt)
        }
        let orderedIDs = WorkspaceRecencyOrdering.recent(records, limit: 6).map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0) })
        return orderedIDs.compactMap { byID[$0] }
    }

    private var homeWorkspaceBriefsByID: [String: WorkspaceReentryBrief] {
        WorkspaceReentryBriefMapper.briefsByWorkspaceID(
            workspaces: Array(recentWorkspaces.prefix(6)),
            resources: resources,
            snippets: snippets,
            todos: todos,
            canvases: canvases,
            nodes: nodes,
            edges: edges,
            now: Date()
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .home {
        case .home:
            HomeView(
                workspaces: recentWorkspaces,
                workspaceBriefsByID: homeWorkspaceBriefsByID,
                resources: orderedResources.filter(\.isPinned),
                snippets: snippets,
                onSelectWorkspace: { selection = .workspace($0.id) },
                onSelectResource: { selection = .resource($0.id) },
                onOpenResource: { openResource($0) },
                onCopyResourcePath: { copyResourcePath($0) },
                onInspectResource: {
                    showInspector(.resource($0.id))
                    setStatus("Showing info for \($0.displayName)")
                },
                onCopySnippet: copySnippet,
                onEditSnippet: { editingSnippet = $0 },
                onDeleteSnippet: { snippetToDelete = $0 },
                onInspectSnippet: { showInspector(.snippet($0.id)) }
            )
        case .global:
            GlobalLibraryView(
                title: "Global Library",
                resources: resources,
                knownResources: resources,
                workspaces: workspaces,
                canvases: canvases,
                nodes: nodes,
                snippets: snippets.filter { $0.scope == .global },
                onSelectResource: { selection = .resource($0.id) },
                onStatus: setStatus,
                onInspect: showInspector,
                onRemove: { resourceToRemove = $0 },
                onEditSnippet: { editingSnippet = $0 },
                onDeleteSnippet: { snippetToDelete = $0 },
                onSelectWorkspace: { selection = .workspace($0) }
            )
        case .pinnedFolders:
            ResourceListView(
                title: "Pinned Folders",
                resources: pinnedFolders,
                knownResources: resources,
                scope: .global,
                workspaceId: nil,
                targetFilter: .folder,
                pinImported: true,
                onSelect: { selection = .resource($0.id) },
                onStatus: setStatus,
                onInspect: showInspector,
                onRemove: { resourceToRemove = $0 }
            )
            .padding()
        case .pinnedFiles:
            ResourceListView(
                title: "Pinned Files",
                resources: pinnedFiles,
                knownResources: resources,
                scope: .global,
                workspaceId: nil,
                targetFilter: .file,
                pinImported: true,
                onSelect: { selection = .resource($0.id) },
                onStatus: setStatus,
                onInspect: showInspector,
                onRemove: { resourceToRemove = $0 }
            )
            .padding()
        case .resource(let id):
            if let resource = resources.first(where: { $0.id == id }) {
                ResourcePreviewView(
                    resource: resource,
                    onStatus: setStatus,
                    onInspect: showInspector,
                    onRemove: { resourceToRemove = $0 }
                )
                .onAppear {
                    showInspector(.resource(resource.id))
                }
            } else {
                ContentUnavailableView("Pinned item missing", systemImage: "questionmark.folder")
            }
        case .snippets:
            SnippetLibraryView(
                snippets: snippets,
                resources: resources,
                scope: nil,
                workspaceId: nil,
                onStatus: setStatus,
                onInspect: showInspector,
                onEdit: { editingSnippet = $0 },
                onDelete: { snippetToDelete = $0 }
            )
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .workspace(let id):
            if let workspace = workspaces.first(where: { $0.id == id }) {
                WorkspaceDetailView(
                    workspace: workspace,
                    reentryBrief: WorkspaceReentryBriefMapper.brief(
                        for: workspace,
                        resources: resources,
                        snippets: snippets,
                        todos: todos,
                        canvases: canvases,
                        nodes: nodes,
                        edges: edges,
                        now: Date()
                    ),
                    workspaces: workspaces,
                    resources: resources,
                    snippets: snippets,
                    todos: todos,
                    todoGroups: todoGroups,
                    canvases: canvases,
                    nodes: nodes,
                    edges: edges,
                    onStatus: setStatus,
                    onInspect: showInspector,
                    onCanvasTabActiveChange: setWorkspaceCanvasTabActive,
                    onRenameWorkspace: { renamingWorkspace = $0 },
                    onDeleteWorkspace: { workspaceToDelete = $0 },
                    onToggleWorkspacePinned: { toggleWorkspacePinned($0) },
                    onRemoveResource: { resourceToRemove = $0 },
                    onEditSnippet: { editingSnippet = $0 },
                    onDeleteSnippet: { snippetToDelete = $0 },
                    onSelectWorkspace: { selection = .workspace($0) }
                )
            } else {
                ContentUnavailableView("Workspace missing", systemImage: "questionmark.folder")
            }
        }
    }

    private func showInspector(_ selection: InspectorSelection) {
        inspectorSelection = selection
        isInspectorVisible = true
    }

    private func setWorkspaceCanvasTabActive(_ isActive: Bool) {
        workspaceCanvasTabActive = isActive
        if isActive {
            isInspectorVisible = false
            inspectorSelection = nil
        }
    }

    @ViewBuilder
    private func workspaceContextMenu(for workspace: WorkspaceModel) -> some View {
        Button("Rename") {
            renamingWorkspace = workspace
        }
        Button(workspace.isPinned ? "Unpin from Top" : "Pin to Top") {
            toggleWorkspacePinned(workspace)
        }
        Button("Move Up") {
            moveWorkspace(workspace, direction: .up)
        }
        .disabled(!canMoveWorkspace(workspace, direction: .up))
        Button("Move Down") {
            moveWorkspace(workspace, direction: .down)
        }
        .disabled(!canMoveWorkspace(workspace, direction: .down))
        Divider()
        Button("Delete MindDesk Metadata", role: .destructive) {
            workspaceToDelete = workspace
        }
    }

    @ViewBuilder
    private func resourceContextMenu(for resource: ResourcePinModel) -> some View {
        Button("Open in Finder") {
            openResource(resource)
        }
        Button("Reveal in Finder") {
            revealResource(resource)
        }
        Button("Copy Full Path") {
            copyResourcePath(resource)
        }
        Button("Rename in MindDesk") {
            renamingResource = resource
        }
        Button(resource.isPinned ? "Unpin Shortcut" : "Pin Shortcut") {
            toggleResourcePinned(resource)
        }
        Divider()
        Button("Remove from MindDesk", role: .destructive) {
            resourceToRemove = resource
        }
    }

    private func toggleResourcePinned(_ resource: ResourcePinModel) {
        resource.isPinned.toggle()
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try modelContext.save()
            setStatus(resource.isPinned ? "Pinned \(resource.displayName)" : "Unpinned \(resource.displayName)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func importPinnedDrop(_ urls: [URL], targetFilter: ResourceTargetType? = nil) {
        guard !urls.isEmpty else {
            setStatus("Drop did not include files or folders.")
            return
        }
        let acceptedURLs = urls.filter { url in
            ResourceDropTargetPolicy.accepts(
                targetType: ResourceImportService.targetType(for: url).rawValue,
                targetFilter: targetFilter?.rawValue
            )
        }
        let skippedCount = urls.count - acceptedURLs.count
        guard !acceptedURLs.isEmpty else {
            let targetDescription = targetFilter == .folder ? "folders" : targetFilter == .file ? "files" : "files or folders"
            setStatus("Drop did not include matching \(targetDescription).")
            return
        }
        do {
            let summary = try ResourceImportService().importURLs(
                acceptedURLs,
                existingResources: resources,
                into: modelContext,
                scope: .global,
                workspaceId: nil,
                pinImported: true
            )
            let skippedText = skippedCount > 0 ? " Skipped \(skippedCount) unmatched item\(skippedCount == 1 ? "" : "s")." : ""
            setStatus("Pinned drop: \(summary.statusText)\(skippedText)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func addWorkspace() {
        let nextIndex = (orderedWorkspaces.map(\.sortIndex).max() ?? -1) + 1
        let workspace = WorkspaceModel(title: "New Workspace", details: "Describe this workspace.", sortIndex: nextIndex)
        let canvas = CanvasModel(workspaceId: workspace.id, title: "Workspace Map", zoom: defaultCanvasZoom)
        modelContext.insert(workspace)
        modelContext.insert(canvas)
        do {
            try modelContext.save()
            selection = .workspace(workspace.id)
            setStatus("Created workspace: \(workspace.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func setStatus(_ message: String) {
        statusMessage = message
    }

    private func openQuickOpen() {
        quickOpenRecordsSnapshot = quickOpenRecords
        isQuickOpenPresented = true
    }

    private func openQuickOpenRecord(_ record: QuickOpenRecord) {
        let id = payloadID(from: record)
        switch record.kind {
        case .workspace:
            selection = .workspace(id)
            setStatus("Opened workspace: \(record.title)")
        case .resource:
            selection = .resource(id)
            setStatus("Opened resource record: \(record.title)")
        case .snippet:
            selection = .snippets
            showInspector(.snippet(id))
            setStatus("Showing snippet: \(record.title)")
        case .webCard:
            guard let node = nodes.first(where: { $0.id == id }),
                  let url = WebCardURL.normalized(node.objectId ?? node.body) else {
                setStatus("Web card is missing a valid URL")
                return
            }
            NSWorkspace.shared.open(url)
            if let canvas = canvases.first(where: { $0.id == node.canvasId }) {
                selection = .workspace(canvas.workspaceId)
            }
            setStatus("Opened web page: \(url.absoluteString)")
        }
        isQuickOpenPresented = false
    }

    private func payloadID(from record: QuickOpenRecord) -> String {
        record.id.split(separator: ":", maxSplits: 1).last.map(String.init) ?? record.id
    }

    private func saveWorkspaceRename(_ workspace: WorkspaceModel) {
        do {
            let trimmedTitle = workspace.title.trimmingCharacters(in: .whitespacesAndNewlines)
            workspace.title = trimmedTitle.isEmpty ? "Untitled Workspace" : trimmedTitle
            workspace.updatedAt = .now
            try modelContext.save()
            setStatus("Renamed workspace: \(workspace.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func saveResourceRename(_ resource: ResourcePinModel) {
        do {
            resource.updatedAt = .now
            try modelContext.save()
            setStatus("Renamed MindDesk metadata: \(resource.displayName)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func copySnippet(_ snippet: SnippetModel) {
        ClipboardService().copy(snippet.body)
        snippet.lastCopiedAt = .now
        snippet.updatedAt = .now
        do {
            try modelContext.save()
            setStatus("Copied \(snippet.kind.rawValue): \(snippet.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func saveSnippet(_ snippet: SnippetModel, draft: SnippetEditorDraft) {
        do {
            snippet.workspaceId = draft.scope == .workspace ? draft.workspaceId : nil
            snippet.title = draft.title
            snippet.kindRaw = draft.kind.rawValue
            snippet.body = draft.body
            snippet.details = draft.details
            snippet.tags = draft.tags
            snippet.scopeRaw = draft.scope.rawValue
            snippet.workingDirectoryRef = draft.kind == .command ? draft.workingDirectoryRef : nil
            snippet.requiresConfirmation = draft.kind == .command
            snippet.updatedAt = .now
            try modelContext.save()
            setStatus("Updated snippet: \(snippet.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func toggleWorkspacePinned(_ workspace: WorkspaceModel) {
        workspace.isPinned.toggle()
        workspace.updatedAt = .now
        if workspace.isPinned {
            workspace.sortIndex = 0
        } else {
            workspace.sortIndex = (orderedWorkspaces.filter { !$0.isPinned }.map(\.sortIndex).max() ?? -1) + 1
        }
        renumberWorkspaceSection(isPinned: workspace.isPinned)
        do {
            try modelContext.save()
            setStatus(workspace.isPinned ? "Pinned workspace: \(workspace.title)" : "Unpinned workspace: \(workspace.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func canMoveWorkspace(_ workspace: WorkspaceModel, direction: SidebarMoveDirection) -> Bool {
        let ids = orderedWorkspaces.filter { $0.isPinned == workspace.isPinned }.map(\.id)
        return WorkspaceSidebarOrdering.movedIDs(ids, moving: workspace.id, direction: direction) != ids
    }

    private func moveWorkspace(_ workspace: WorkspaceModel, direction: SidebarMoveDirection) {
        let peers = orderedWorkspaces.filter { $0.isPinned == workspace.isPinned }
        let movedIds = WorkspaceSidebarOrdering.movedIDs(peers.map(\.id), moving: workspace.id, direction: direction)
        guard movedIds != peers.map(\.id) else { return }
        for (index, id) in movedIds.enumerated() {
            guard let peer = workspaces.first(where: { $0.id == id }) else { continue }
            peer.sortIndex = index
            peer.updatedAt = .now
        }
        do {
            try modelContext.save()
            setStatus("Reordered workspace: \(workspace.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func moveWorkspaces(fromOffsets source: IndexSet, toOffset destination: Int) {
        let ids = orderedWorkspaces.map(\.id)
        let movedIds = WorkspaceSidebarOrdering.movedIDs(ids, fromOffsets: source, toOffset: destination)
        guard movedIds != ids else { return }
        let pinnedIds = Set(workspaces.filter(\.isPinned).map(\.id))
        guard WorkspaceSidebarOrdering.keepsPinnedPrefix(movedIds, pinnedIDs: pinnedIds) else {
            setStatus("Drag sorting keeps pinned workspaces in the pinned section")
            return
        }

        let now = Date.now
        let orderedPinnedIds = movedIds.filter { id in
            workspaces.first(where: { $0.id == id })?.isPinned == true
        }
        let unpinnedIds = movedIds.filter { id in
            workspaces.first(where: { $0.id == id })?.isPinned == false
        }
        renumberWorkspaces(ids: orderedPinnedIds, now: now)
        renumberWorkspaces(ids: unpinnedIds, now: now)

        do {
            try modelContext.save()
            setStatus("Reordered workspaces")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func renumberWorkspaces(ids: [String], now: Date) {
        for (index, id) in ids.enumerated() {
            guard let workspace = workspaces.first(where: { $0.id == id }) else { continue }
            workspace.sortIndex = index
            workspace.updatedAt = now
        }
    }

    private func renumberWorkspaceSection(isPinned: Bool) {
        let peers = orderedWorkspaces.filter { $0.isPinned == isPinned }
        for (index, workspace) in peers.enumerated() {
            workspace.sortIndex = index
        }
    }

    private func workspaceDeletionImpactMessage(for workspace: WorkspaceModel) -> String {
        let workspaceCanvases = canvases.filter { $0.workspaceId == workspace.id }
        let workspaceResources = resources.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
        let workspaceSnippets = snippets.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
        let resourceIds = Set(workspaceResources.map(\.id))
        let snippetIds = Set(workspaceSnippets.map(\.id))
        let deletionPlan = workspaceDeletionPlan(for: workspace)
        let aliasCount = aliases.filter {
            ($0.sourceObjectType == "resourcePin" && resourceIds.contains($0.sourceObjectId)) ||
                ($0.sourceObjectType == "snippet" && snippetIds.contains($0.sourceObjectId))
        }.count
        let todoCount = todos.filter { $0.workspaceId == workspace.id }.count
        let todoGroupCount = todoGroups.filter { $0.workspaceId == workspace.id }.count

        return """
        This removes \(workspace.title) from MindDesk metadata only.

        Workspace pins: \(workspaceResources.count)
        Workspace snippets: \(workspaceSnippets.count)
        Canvas maps: \(workspaceCanvases.count)
        Canvas cards/references: \(deletionPlan.nodeIds.count)
        Links: \(deletionPlan.edgeIds.count)
        Command working directories cleared: \(deletionPlan.snippetIdsClearingWorkingDirectory.count)
        Alias records marked missing: \(aliasCount)
        Todo groups/tasks: \(todoGroupCount)/\(todoCount)
        Finder items affected: 0
        """
    }

    private func workspaceDeletionPlan(for workspace: WorkspaceModel) -> WorkspaceDeletionPlan {
        let workspaceResources = resources.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
        let workspaceSnippets = snippets.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
        return WorkspaceDeletionPolicy.plan(
            workspaceId: workspace.id,
            canvases: canvases.map { WorkspaceDeletionCanvasRecord(id: $0.id, workspaceId: $0.workspaceId) },
            nodes: nodes.map {
                WorkspaceDeletionNodeRecord(
                    id: $0.id,
                    canvasId: $0.canvasId,
                    objectType: $0.objectType,
                    objectId: $0.objectId
                )
            },
            edges: edges.map {
                WorkspaceDeletionEdgeRecord(
                    id: $0.id,
                    canvasId: $0.canvasId,
                    sourceNodeId: $0.sourceNodeId,
                    targetNodeId: $0.targetNodeId
                )
            },
            snippets: snippets.map {
                WorkspaceDeletionSnippetRecord(id: $0.id, workingDirectoryRef: $0.workingDirectoryRef)
            },
            resourceIds: Set(workspaceResources.map(\.id)),
            snippetIds: Set(workspaceSnippets.map(\.id))
        )
    }

    private func deleteWorkspace(_ workspace: WorkspaceModel) {
        do {
            let workspaceCanvases = canvases.filter { $0.workspaceId == workspace.id }
            let workspaceResources = resources.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
            let workspaceSnippets = snippets.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
            let workspaceTodos = todos.filter { $0.workspaceId == workspace.id }
            let workspaceTodoGroups = todoGroups.filter { $0.workspaceId == workspace.id }
            let deletedResourceIds = Set(workspaceResources.map(\.id))
            let deletedSnippetIds = Set(workspaceSnippets.map(\.id))
            let deletionPlan = workspaceDeletionPlan(for: workspace)
            let nodeIds = Set(deletionPlan.nodeIds)
            let edgeIds = Set(deletionPlan.edgeIds)
            let snippetIdsClearingWorkingDirectory = Set(deletionPlan.snippetIdsClearingWorkingDirectory)
            let now = Date.now

            for edge in edges where edgeIds.contains(edge.id) {
                modelContext.delete(edge)
            }
            for node in nodes where nodeIds.contains(node.id) {
                modelContext.delete(node)
            }
            for canvas in workspaceCanvases {
                modelContext.delete(canvas)
            }
            for alias in aliases where
                (alias.sourceObjectType == "resourcePin" && deletedResourceIds.contains(alias.sourceObjectId)) ||
                (alias.sourceObjectType == "snippet" && deletedSnippetIds.contains(alias.sourceObjectId)) {
                alias.status = .missing
            }
            for snippet in snippets where snippetIdsClearingWorkingDirectory.contains(snippet.id) {
                snippet.workingDirectoryRef = nil
                snippet.updatedAt = now
            }
            for resource in workspaceResources {
                modelContext.delete(resource)
            }
            for snippet in workspaceSnippets {
                modelContext.delete(snippet)
            }
            for todo in workspaceTodos {
                modelContext.delete(todo)
            }
            for group in workspaceTodoGroups {
                modelContext.delete(group)
            }
            modelContext.delete(workspace)
            try modelContext.save()
            selection = orderedWorkspaces.first { $0.id != workspace.id }.map { .workspace($0.id) } ?? .home
            inspectorSelection = nil
            workspaceCanvasTabActive = false
            let workingDirectoryStatus = snippetIdsClearingWorkingDirectory.isEmpty
                ? ""
                : " Cleared \(snippetIdsClearingWorkingDirectory.count) command working directory reference\(snippetIdsClearingWorkingDirectory.count == 1 ? "" : "s")."
            setStatus("Deleted MindDesk workspace metadata. Finder items affected: 0.\(workingDirectoryStatus)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func openResource(_ resource: ResourcePinModel) {
        performResource(resource, actionName: "Opened in Finder") { url in
            switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
            case .open:
                try FinderService().open(url)
            case .reveal:
                try FinderService().reveal(url)
            }
            resource.lastOpenedAt = .now
        }
    }

    private func revealResource(_ resource: ResourcePinModel) {
        performResource(resource, actionName: "Revealed") { url in
            try FinderService().reveal(url)
        }
    }

    private func copyResourcePath(_ resource: ResourcePinModel) {
        ClipboardService().copy(resource.displayPath)
        setStatus("Copied path: \(resource.displayPath)")
    }

    private func performResource(_ resource: ResourcePinModel, actionName: String, action: (URL) throws -> Void) {
        let bookmarkService = BookmarkService()
        do {
            let resolved = try bookmarkService.resolveAuthorizedBookmark(
                resource.securityScopedBookmarkData,
                fallbackPath: resource.lastResolvedPath,
                statusRaw: resource.statusRaw
            )
            try bookmarkService.access(resolved.url) {
                try action(resolved.url)
            }
            resource.lastResolvedPath = resolved.url.path
            resource.displayPath = resolved.url.path
            resource.status = .available
            resource.updatedAt = .now
            try modelContext.save()
            setStatus("\(actionName) \(resource.displayName)")
        } catch {
            resource.status = ResourceAccessStatusResolver.failureStatus(for: error, fallbackPath: resource.lastResolvedPath)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
            setStatus(error.localizedDescription)
        }
    }

    private func removeResourceFromLibrary(_ resource: ResourcePinModel) {
        do {
            let index = ReferenceIndex(
                canvasObjects: canvasObjectReferences(),
                todoLinks: todos.map {
                    TodoResourceReference(todoId: $0.id, workspaceId: $0.workspaceId, linkedResourceId: $0.linkedResourceId)
                },
                snippetWorkingDirectories: snippets.map {
                    SnippetWorkingDirectoryReference(snippetId: $0.id, resourceId: $0.workingDirectoryRef)
                },
                aliases: aliases.map {
                    AliasObjectReference(aliasId: $0.id, sourceObjectType: $0.sourceObjectType, sourceObjectId: $0.sourceObjectId)
                }
            )
            let cleanup = CleanupPlan.deletingResource(resourceId: resource.id, index: index)
            let resourceNodeIds = Set(cleanup.canvasNodeIdsToDelete)
            let todoIdsClearingLinkedResource = Set(cleanup.todoIdsClearingLinkedResource)
            let snippetIdsClearingWorkingDirectory = Set(cleanup.snippetIdsClearingWorkingDirectory)
            let aliasIdsMarkingMissing = Set(cleanup.aliasIdsMarkingMissing)
            for edge in edges where resourceNodeIds.contains(edge.sourceNodeId) || resourceNodeIds.contains(edge.targetNodeId) {
                modelContext.delete(edge)
            }
            for node in nodes where resourceNodeIds.contains(node.id) {
                modelContext.delete(node)
            }
            for todo in todos where todoIdsClearingLinkedResource.contains(todo.id) {
                todo.linkedResourceId = nil
                todo.updatedAt = .now
            }
            for snippet in snippets where snippetIdsClearingWorkingDirectory.contains(snippet.id) {
                snippet.workingDirectoryRef = nil
                snippet.updatedAt = .now
            }
            for alias in aliases where aliasIdsMarkingMissing.contains(alias.id) {
                alias.status = .missing
            }
            modelContext.delete(resource)
            try modelContext.save()
            if selection == .resource(resource.id) {
                selection = .home
                inspectorSelection = nil
            }
            setStatus("Removed \(resource.displayName) from MindDesk metadata. Finder items affected: 0")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func canvasObjectReferences() -> [CanvasObjectReference] {
        let workspaceIdByCanvasId = Dictionary(uniqueKeysWithValues: canvases.map { ($0.id, $0.workspaceId) })
        return nodes.map {
            CanvasObjectReference(
                nodeId: $0.id,
                canvasId: $0.canvasId,
                workspaceId: workspaceIdByCanvasId[$0.canvasId] ?? "",
                objectType: $0.objectType,
                objectId: $0.objectId
            )
        }
    }

    private func deleteSnippet(_ snippet: SnippetModel) {
        do {
            let snippetNodeIds = Set(nodes.filter { $0.objectType == "snippet" && $0.objectId == snippet.id }.map(\.id))
            for edge in edges where snippetNodeIds.contains(edge.sourceNodeId) || snippetNodeIds.contains(edge.targetNodeId) {
                modelContext.delete(edge)
            }
            for node in nodes where snippetNodeIds.contains(node.id) {
                modelContext.delete(node)
            }
            for alias in aliases where alias.sourceObjectType == "snippet" && alias.sourceObjectId == snippet.id {
                alias.status = .missing
            }
            modelContext.delete(snippet)
            try modelContext.save()
            if inspectorSelection == .snippet(snippet.id) {
                inspectorSelection = nil
            }
            setStatus("Deleted snippet metadata: \(snippet.title)")
        } catch {
            modelContext.rollback()
            setStatus(error.localizedDescription)
        }
    }

    private func exportManifest() {
        guard let exportOptions = requestManifestExportOptions() else { return }
        guard let url = FileDialogs.saveJSON() else { return }
        do {
            let baseManifest = ImportExportService().makeManifest(
                workspaces: workspaces,
                resources: resources,
                snippets: snippets,
                canvases: canvases,
                nodes: nodes,
                edges: edges,
                aliases: aliases,
                todoGroups: todoGroups,
                todos: todos
            )
            let scopedManifest = ExportManifestScopePolicy.manifest(
                from: baseManifest,
                scope: exportOptions.scope
            )
            let manifest = exportOptions.includesUsageDates
                ? scopedManifest
                : ExportManifestUsageDatePolicy.removingUsageDates(from: scopedManifest)
            let data = try JSONEncoder.minddesk.encode(manifest)
            try data.write(to: url, options: .atomic)
            setStatus("Exported MindDesk manifest to \(url.path)")
        } catch {
            setStatus(error.localizedDescription)
        }
    }

    private func requestManifestExportOptions() -> ManifestExportOptions? {
        let currentScope = ManifestExportScope.resolved(manifestExportScopeRaw)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Export MindDesk JSON"
        alert.informativeText = "Choose what this export contains. Complete Workspace Map is the only portable backup-style JSON export."
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")

        let scopeLabel = NSTextField(labelWithString: "Scope")
        scopeLabel.alignment = .right
        scopeLabel.widthAnchor.constraint(equalToConstant: 118).isActive = true

        let scopePicker = NSPopUpButton(frame: .zero, pullsDown: false)
        for scope in ManifestExportScope.allCases {
            scopePicker.addItem(withTitle: exportScopeTitle(scope))
            scopePicker.lastItem?.representedObject = scope.rawValue
        }
        scopePicker.selectItem(withTitle: exportScopeTitle(currentScope))
        scopePicker.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let scopeRow = NSStackView(views: [scopeLabel, scopePicker])
        scopeRow.orientation = .horizontal
        scopeRow.alignment = .centerY
        scopeRow.spacing = 8

        let includeUsageDates = NSButton(
            checkboxWithTitle: "Include usage dates such as last opened or last run",
            target: nil,
            action: nil
        )
        includeUsageDates.state = manifestExportIncludesUsageDates ? .on : .off

        let helpText = NSTextField(wrappingLabelWithString: "Global Library Only excludes workspaces, canvases, cards, links, and aliases. Portable JSON never includes security-scoped bookmark authorization data, but it can include paths, notes, snippets, and canvas text.")
        helpText.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [scopeRow, includeUsageDates, helpText])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 420).isActive = true
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let scopeRaw = scopePicker.selectedItem?.representedObject as? String
        let scope = ManifestExportScope.resolved(scopeRaw ?? currentScope.rawValue)
        let includesUsageDates = includeUsageDates.state == .on
        manifestExportScopeRaw = scope.rawValue
        manifestExportIncludesUsageDates = includesUsageDates
        return ManifestExportOptions(scope: scope, includesUsageDates: includesUsageDates)
    }

    private func exportScopeTitle(_ scope: ManifestExportScope) -> String {
        switch scope {
        case .completeWorkspaceMap:
            "Complete Workspace Map"
        case .globalLibraryOnly:
            "Global Library Only"
        }
    }

    private func importManifest() {
        guard let url = FileDialogs.openJSON() else { return }
        setStatus("Importing MindDesk manifest...")
        Task { @MainActor in
            do {
                let manifest = try await Self.loadManifest(from: url)
                let summary = try importRecords(from: manifest)
                let authorizationNote = summary.resources > 0 ? " Resources require reauthorization." : ""
                setStatus("Imported \(summary.statusText).\(authorizationNote)")
            } catch {
                modelContext.rollback()
                setStatus(error.localizedDescription)
            }
        }
    }

    nonisolated private static func loadManifest(from url: URL) async throws -> ExportManifest {
        try await Task.detached(priority: .userInitiated) {
            let data = try readManifestData(from: url)
            return try ImportExportService().decodeManifest(from: data)
        }.value
    }

    nonisolated private static func readManifestData(from url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            throw WorkbenchError.invalidManifestReferences("Manifest import blocked: choose a regular JSON file.")
        }
        guard let fileSize = values.fileSize else {
            throw WorkbenchError.invalidManifestReferences("Manifest import blocked: file size could not be read.")
        }
        guard fileSize <= ManifestImportLimits.maximumManifestBytes else {
            throw WorkbenchError.invalidManifestReferences("Manifest import blocked: file is larger than 64 MiB.")
        }

        let data = try Data(contentsOf: url)
        guard data.count <= ManifestImportLimits.maximumManifestBytes else {
            throw WorkbenchError.invalidManifestReferences("Manifest import blocked: file is larger than 64 MiB.")
        }
        return data
    }

    private func importRecords(from manifest: ExportManifest) throws -> ManifestImportSummary {
        let validationIssues = ManifestImportValidation.issues(in: manifest)
        guard validationIssues.isEmpty else {
            let details = validationIssues.prefix(5).joined(separator: " ")
            let suffix = validationIssues.count > 5 ? " \(validationIssues.count - 5) more issue\(validationIssues.count - 5 == 1 ? "" : "s")." : ""
            throw WorkbenchError.invalidManifestReferences("Manifest import blocked: \(details)\(suffix)")
        }

        var workspaceMap: [String: String] = [:]
        var resourceMap: [String: String] = [:]
        var snippetMap: [String: String] = [:]
        var canvasMap: [String: String] = [:]
        var nodeMap: [String: String] = [:]
        var importedNodeParents: [(node: CanvasNodeModel, parentNodeId: String?)] = []
        var importedEdgeCount = 0
        var importedAliasCount = 0
        var importedTodoGroupCount = 0
        var importedTodoCount = 0

        for record in manifest.workspaces {
            let workspace = WorkspaceModel(title: record.title, details: record.details, createdAt: record.createdAt, updatedAt: record.updatedAt, lastOpenedAt: record.lastOpenedAt, isPinned: record.isPinned, sortIndex: record.sortIndex, schemaVersion: manifest.schemaVersion)
            workspaceMap[record.id] = workspace.id
            modelContext.insert(workspace)
        }

        for record in manifest.resources {
            let scope = WorkbenchScope(rawValue: record.scope) ?? .global
            let resource = ResourcePinModel(
                workspaceId: scope == .workspace ? record.workspaceId.flatMap { workspaceMap[$0] } : nil,
                title: record.title,
                targetType: ResourceTargetType(rawValue: record.targetType) ?? .folder,
                displayPath: record.displayPath,
                lastResolvedPath: record.lastResolvedPath,
                note: record.note,
                tags: record.tags,
                scope: scope,
                sortIndex: record.sortIndex,
                isPinned: record.isPinned,
                originalName: record.originalName,
                customName: record.customName,
                searchText: record.searchText,
                status: .unavailable
            )
            resource.createdAt = record.createdAt
            resource.updatedAt = record.updatedAt
            resource.lastOpenedAt = record.lastOpenedAt
            resourceMap[record.id] = resource.id
            modelContext.insert(resource)
        }

        for record in manifest.snippets {
            let scope = WorkbenchScope(rawValue: record.scope) ?? .global
            let snippet = SnippetModel(
                workspaceId: scope == .workspace ? record.workspaceId.flatMap { workspaceMap[$0] } : nil,
                title: record.title,
                kind: SnippetKind(rawValue: record.kind) ?? .prompt,
                body: record.body,
                details: record.details,
                tags: record.tags,
                scope: scope,
                workingDirectoryRef: record.workingDirectoryRef.flatMap { resourceMap[$0] },
                requiresConfirmation: SnippetImportTrustPolicy.requiresConfirmation(
                    kind: record.kind,
                    exportedRequiresConfirmation: record.requiresConfirmation
                ),
                lastCopiedAt: record.lastCopiedAt,
                lastUsedAt: record.lastUsedAt,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            snippetMap[record.id] = snippet.id
            modelContext.insert(snippet)
        }

        for record in manifest.canvases {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let canvas = CanvasModel(workspaceId: workspaceId, title: record.title, viewportX: record.viewportX, viewportY: record.viewportY, zoom: record.zoom, linkAnimationThemeRaw: record.linkAnimationTheme, animationsEnabled: record.animationsEnabled, createdAt: record.createdAt, updatedAt: record.updatedAt)
            canvasMap[record.id] = canvas.id
            modelContext.insert(canvas)
        }

        for record in manifest.nodes {
            guard let canvasId = canvasMap[record.canvasId] else { continue }
            let mappedObjectId = CanvasNodeObjectReferenceMapper.mappedObjectId(
                objectType: record.objectType,
                objectId: record.objectId,
                body: record.body,
                resourceMap: resourceMap,
                snippetMap: snippetMap,
                workspaceMap: workspaceMap
            )
            let node = CanvasNodeModel(
                canvasId: canvasId,
                title: record.title,
                body: record.body,
                nodeType: CanvasNodeKind(rawValue: record.nodeType) ?? .note,
                objectType: record.objectType,
                objectId: mappedObjectId,
                x: record.x,
                y: record.y,
                width: record.width,
                height: record.height,
                collapsed: record.collapsed,
                parentNodeId: nil,
                zIndex: record.zIndex,
                locked: record.locked,
                styleRaw: record.style,
                accentColorRaw: record.accentColor,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            nodeMap[record.id] = node.id
            importedNodeParents.append((node: node, parentNodeId: record.parentNodeId))
            modelContext.insert(node)
        }

        for importedNodeParent in importedNodeParents {
            importedNodeParent.node.parentNodeId = CanvasManifestParentMapper.mappedParentNodeId(
                importedNodeParent.parentNodeId,
                nodeMap: nodeMap
            )
        }

        for record in manifest.edges {
            guard let canvasId = canvasMap[record.canvasId],
                  let sourceId = nodeMap[record.sourceNodeId],
                  let targetId = nodeMap[record.targetNodeId] else { continue }
            modelContext.insert(CanvasEdgeModel(canvasId: canvasId, sourceNodeId: sourceId, targetNodeId: targetId, label: record.label, style: record.style, sourceArrowRaw: record.sourceArrow, targetArrowRaw: record.targetArrow, animated: record.animated, animationThemeRaw: record.animationTheme, controlPointX: record.controlPointX, controlPointY: record.controlPointY, createdAt: record.createdAt, updatedAt: record.updatedAt))
            importedEdgeCount += 1
        }

        for record in manifest.aliases {
            let mappedSourceId = AliasImportSourceMapper.mappedSourceObjectId(
                sourceObjectType: record.sourceObjectType,
                sourceObjectId: record.sourceObjectId,
                resourceMap: resourceMap,
                snippetMap: snippetMap
            )
            modelContext.insert(FinderAliasRecordModel(sourceObjectType: record.sourceObjectType, sourceObjectId: mappedSourceId, aliasDisplayPath: record.aliasDisplayPath, status: AliasStatus(rawValue: record.status) ?? .missing, createdAt: record.createdAt))
            importedAliasCount += 1
        }

        var todoGroupMap: [String: String] = [:]
        for record in manifest.todoGroups {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let group = WorkspaceTodoGroupModel(
                workspaceId: workspaceId,
                title: record.title,
                isPinned: record.isPinned,
                sortIndex: record.sortIndex,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            todoGroupMap[record.id] = group.id
            modelContext.insert(group)
            importedTodoGroupCount += 1
        }

        for record in manifest.todos {
            guard let workspaceId = workspaceMap[record.workspaceId] else { continue }
            let todo = WorkspaceTodoModel(
                workspaceId: workspaceId,
                groupId: record.groupId.flatMap { todoGroupMap[$0] },
                title: record.title,
                details: record.details,
                isCompleted: record.isCompleted,
                isPinned: record.isPinned,
                sortIndex: record.sortIndex,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                completedAt: record.completedAt,
                dueAt: record.dueAt,
                linkedResourceId: record.linkedResourceId.flatMap { resourceMap[$0] }
            )
            modelContext.insert(todo)
            importedTodoCount += 1
        }

        try modelContext.save()
        return ManifestImportSummary(
            workspaces: workspaceMap.count,
            resources: resourceMap.count,
            snippets: snippetMap.count,
            canvases: canvasMap.count,
            nodes: nodeMap.count,
            edges: importedEdgeCount,
            aliases: importedAliasCount,
            todoGroups: importedTodoGroupCount,
            todos: importedTodoCount
        )
    }
}

enum InspectorSelection: Equatable {
    case resource(String)
    case snippet(String)
    case node(String)
}

struct QuickOpenPanel: View {
    @Environment(\.dismiss) private var dismiss
    let records: [QuickOpenRecord]
    let onOpen: (QuickOpenRecord) -> Void
    @FocusState private var isSearchFocused: Bool
    @State private var query = ""
    @State private var results: [QuickOpenRecord] = []
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Quick Open", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if results.isEmpty {
                ContentUnavailableView("No matching items", systemImage: "magnifyingglass", description: Text(query.isEmpty ? "Start typing to search MindDesk." : query))
                    .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                ScrollViewReader { proxy in
                    List(Array(results.enumerated()), id: \.element.id) { index, record in
                        Button {
                            selectedIndex = index
                            openSelectedResult()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: record.kind.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.title)
                                        .font(.body.weight(.semibold))
                                        .lineLimit(1)
                                    Text(record.subtitle.isEmpty ? record.kind.title : record.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .background(selectedIndex == index ? Color.accentColor.opacity(0.16) : Color.clear)
                        }
                        .id(record.id)
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                selectedIndex = index
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 320)
                    .onChange(of: selectedIndex) { _, _ in
                        scrollSelectedResult(with: proxy, results: results)
                    }
                    .onChange(of: results.map(\.id)) { _, _ in
                        selectedIndex = QuickOpenSelectionPolicy.normalizedIndex(selectedIndex, resultCount: results.count)
                        scrollSelectedResult(with: proxy, results: results)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 560, height: 430)
        .background(QuickOpenKeyMonitor { event in
            handleKeyDown(event)
        })
        .onAppear {
            refreshResults(resetSelection: true)
            Task { @MainActor in
                isSearchFocused = true
            }
        }
        .onChange(of: query) { _, _ in
            refreshResults(resetSelection: true)
        }
        .onChange(of: records) { _, _ in
            refreshResults(resetSelection: false)
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                selectedIndex = QuickOpenSelectionPolicy.movedIndex(current: selectedIndex, delta: 1, resultCount: results.count)
            case .up:
                selectedIndex = QuickOpenSelectionPolicy.movedIndex(current: selectedIndex, delta: -1, resultCount: results.count)
            default:
                break
            }
        }
    }

    private func refreshResults(resetSelection: Bool) {
        results = QuickOpenIndex.results(for: query, in: records, limit: 20)
        if resetSelection {
            selectedIndex = 0
        } else {
            selectedIndex = QuickOpenSelectionPolicy.normalizedIndex(selectedIndex, resultCount: results.count)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 36, 76:
            openSelectedResult()
            return true
        case 53:
            dismiss()
            return true
        case 125:
            selectedIndex = QuickOpenSelectionPolicy.movedIndex(current: selectedIndex, delta: 1, resultCount: results.count)
            return true
        case 126:
            selectedIndex = QuickOpenSelectionPolicy.movedIndex(current: selectedIndex, delta: -1, resultCount: results.count)
            return true
        default:
            return false
        }
    }

    private func scrollSelectedResult(with proxy: ScrollViewProxy, results: [QuickOpenRecord]) {
        guard !results.isEmpty else { return }
        let index = QuickOpenSelectionPolicy.normalizedIndex(selectedIndex, resultCount: results.count)
        let id = results[index].id
        proxy.scrollTo(id, anchor: .center)
    }

    private func openSelectedResult() {
        guard !results.isEmpty else { return }
        let index = QuickOpenSelectionPolicy.normalizedIndex(selectedIndex, resultCount: results.count)
        onOpen(results[index])
        dismiss()
    }
}

private struct QuickOpenKeyMonitor: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context _: Context) -> QuickOpenKeyMonitorView {
        let view = QuickOpenKeyMonitorView()
        view.onKeyDown = onKeyDown
        view.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ nsView: QuickOpenKeyMonitorView, context _: Context) {
        nsView.onKeyDown = onKeyDown
    }

    static func dismantleNSView(_ nsView: QuickOpenKeyMonitorView, coordinator _: ()) {
        nsView.removeMonitor()
    }
}

private final class QuickOpenKeyMonitorView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    private var monitor: Any?

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window,
                  event.window === window else {
                return event
            }
            return onKeyDown?(event) == true ? nil : event
        }
    }

    func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

private extension QuickOpenRecordKind {
    var systemImage: String {
        switch self {
        case .workspace: "rectangle.3.group"
        case .resource: "folder"
        case .webCard: "globe"
        case .snippet: "text.quote"
        }
    }

    var title: String {
        switch self {
        case .workspace: "Workspace"
        case .resource: "Resource"
        case .webCard: "Web Page"
        case .snippet: "Snippet"
        }
    }
}

struct SidebarWorkspaceRow: View {
    let workspace: WorkspaceModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: workspace.isPinned ? "pin.fill" : "rectangle.3.group")
                .foregroundStyle(workspace.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 16)
            Text(workspace.title)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
        .help(workspace.details.isEmpty ? workspace.title : workspace.details)
    }
}

struct SidebarResourceRow: View {
    let resource: ResourcePinModel
    let onCopy: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: resource.targetType == .folder ? "folder" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(resource.displayName)
                    .lineLimit(1)
                Text(resource.displayPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help("Copy full path")
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .help(resource.displayPath)
    }
}

struct WorkspaceRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workspace: WorkspaceModel
    let onSave: () -> Void
    @State private var title: String
    @State private var details: String

    init(workspace: WorkspaceModel, onSave: @escaping () -> Void) {
        self.workspace = workspace
        self.onSave = onSave
        _title = State(initialValue: workspace.title)
        _details = State(initialValue: workspace.details)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Workspace")
                .font(.title2.bold())
            TextField("Title", text: $title)
            TextField("Description", text: $details, axis: .vertical)
                .lineLimit(3...6)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    workspace.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Workspace" : title
                    workspace.details = details
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}

struct ResourceRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let resource: ResourcePinModel
    let onSave: () -> Void
    @State private var title: String
    @State private var note: String

    init(resource: ResourcePinModel, onSave: @escaping () -> Void) {
        self.resource = resource
        self.onSave = onSave
        _title = State(initialValue: resource.customName.isEmpty ? resource.title : resource.customName)
        _note = State(initialValue: resource.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Resource")
                .font(.title2.bold())
            TextField("Title in MindDesk", text: $title)
            Text("Original: \(resource.originalName.isEmpty ? resource.displayPath : resource.originalName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(resource.displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            TextField("Note", text: $note, axis: .vertical)
                .lineLimit(3...6)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    resource.applyRename(titleInput: title, note: note)
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
    }
}

struct HomeView: View {
    let workspaces: [WorkspaceModel]
    let workspaceBriefsByID: [String: WorkspaceReentryBrief]
    let resources: [ResourcePinModel]
    let snippets: [SnippetModel]
    let onSelectWorkspace: (WorkspaceModel) -> Void
    let onSelectResource: (ResourcePinModel) -> Void
    let onOpenResource: (ResourcePinModel) -> Void
    let onCopyResourcePath: (ResourcePinModel) -> Void
    let onInspectResource: (ResourcePinModel) -> Void
    let onCopySnippet: (SnippetModel) -> Void
    let onEditSnippet: (SnippetModel) -> Void
    let onDeleteSnippet: (SnippetModel) -> Void
    let onInspectSnippet: (SnippetModel) -> Void
    @State private var expandedSnippetIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("MindDesk")
                    .font(.largeTitle.bold())
                Text("Personal workspace for folders, files, commands, prompts, and workflow maps.")
                    .foregroundStyle(.secondary)

                DashboardSection(title: "Recent Workspaces") {
                    CardGrid {
                        ForEach(workspaces.prefix(6)) { workspace in
                            HomeWorkspaceResumeCard(
                                workspace: workspace,
                                brief: workspaceBriefsByID[workspace.id],
                                onSelect: { onSelectWorkspace(workspace) }
                            )
                        }
                    }
                }

                DashboardSection(title: "Pinned Resources") {
                    if resources.isEmpty {
                        DashboardEmptyState(
                            title: "No pinned resources",
                            message: "Drop files or folders into the pinned lists to keep them close.",
                            systemImage: "pin"
                        )
                    } else {
                        CardGrid {
                            ForEach(resources.prefix(8)) { resource in
                                HomeResourceCard(
                                    resource: resource,
                                    onSelect: { onSelectResource(resource) },
                                    onOpen: { onOpenResource(resource) },
                                    onCopy: { onCopyResourcePath(resource) },
                                    onInspect: { onInspectResource(resource) }
                                )
                            }
                        }
                    }
                }

                DashboardSection(title: "Recent Snippets") {
                    CardGrid {
                        ForEach(snippets.prefix(8)) { snippet in
                            SnippetActionCard(
                                snippet: snippet,
                                isExpanded: expandedSnippetIDs.contains(snippet.id),
                                compact: true,
                                onToggleExpanded: { toggleSnippet(snippet) },
                                onCopy: { onCopySnippet(snippet) },
                                onEdit: { onEditSnippet(snippet) },
                                onDelete: { onDeleteSnippet(snippet) },
                                onInspect: { onInspectSnippet(snippet) },
                                onOpenTerminal: nil,
                                onRun: nil
                            )
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toggleSnippet(_ snippet: SnippetModel) {
        withAnimation(.easeInOut(duration: 0.16)) {
            if expandedSnippetIDs.contains(snippet.id) {
                expandedSnippetIDs.remove(snippet.id)
            } else {
                expandedSnippetIDs.insert(snippet.id)
            }
        }
    }
}

struct HomeWorkspaceResumeCard: View {
    let workspace: WorkspaceModel
    let brief: WorkspaceReentryBrief?
    let onSelect: () -> Void

    private var canvasText: String {
        guard let brief else { return "Canvas" }
        if brief.isLargeDataDegraded {
            return "Large workspace"
        }
        return "\(brief.canvasSummary.cardCount) cards · \(brief.canvasSummary.validLinkCount) links"
    }

    private var taskText: String? {
        guard let brief, brief.openTaskCount > 0 else { return nil }
        return "\(brief.openTaskCount) open"
    }

    private var issueText: String? {
        guard let brief, brief.resourceIssueCount > 0 else { return nil }
        return "\(brief.resourceIssueCount) issue\(brief.resourceIssueCount == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: workspace.isPinned ? "pin.fill" : "rectangle.3.group")
                        .font(.title3)
                        .foregroundStyle(workspace.isPinned ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(workspace.details.isEmpty ? "No description" : workspace.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }

                if let brief, !brief.badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(brief.badges) { badge in
                            WorkspaceResumeBadgeView(badge: badge)
                        }
                    }
                    .frame(height: 22, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Label(canvasText, systemImage: "rectangle.connected.to.line.below")
                        .lineLimit(1)
                        .help(canvasText)
                    if let taskText {
                        Label(taskText, systemImage: "checklist")
                            .lineLimit(1)
                            .help(taskText)
                    }
                    if let issueText {
                        Label(issueText, systemImage: "exclamationmark.triangle")
                            .lineLimit(1)
                            .help(issueText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 18, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(workspace.details.isEmpty ? workspace.title : workspace.details)
        .accessibilityLabel("\(workspace.title), \(canvasText)")
    }
}

struct WorkspaceResumeBriefView: View {
    let brief: WorkspaceReentryBrief
    let todosByID: [String: WorkspaceTodoModel]
    let resourcesByID: [String: ResourcePinModel]
    let snippetsByID: [String: SnippetModel]
    let onShowCanvas: () -> Void
    let onShowResources: () -> Void
    let onShowSnippets: () -> Void

    private var canvasText: String {
        if brief.isLargeDataDegraded {
            return "Large workspace"
        }
        return "\(brief.canvasSummary.cardCount) cards · \(brief.canvasSummary.validLinkCount) links"
    }

    private var taskTitles: [String] {
        brief.nextTaskIds.compactMap { todosByID[$0]?.title }
    }

    private var resourceIssueTitles: [String] {
        brief.resourceIssueIds.compactMap { resourcesByID[$0]?.displayName }
    }

    private var snippetTitles: [String] {
        brief.recentSnippetIds.compactMap { snippetsByID[$0]?.title }
    }

    private var taskSummary: String {
        if brief.openTaskCount == 0 {
            return "No open tasks"
        }
        return "\(brief.openTaskCount) open task\(brief.openTaskCount == 1 ? "" : "s")"
    }

    private var resourceSummary: String {
        if brief.resourceIssueCount == 0 {
            return "No resource issues"
        }
        return "\(brief.resourceIssueCount) resource issue\(brief.resourceIssueCount == 1 ? "" : "s")"
    }

    private var snippetSummary: String {
        if snippetTitles.isEmpty {
            return "No recent snippets"
        }
        return "\(snippetTitles.count) recent snippet\(snippetTitles.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(brief.badges) { badge in
                    WorkspaceResumeBadgeView(badge: badge)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 22, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 8)], spacing: 8) {
                resumeButton(
                    title: "Canvas",
                    value: canvasText,
                    detail: canvasDetailText,
                    systemImage: "rectangle.connected.to.line.below",
                    action: onShowCanvas
                )
                resumeItem(
                    title: "Next",
                    value: taskSummary,
                    detail: joined(taskTitles),
                    systemImage: "checklist"
                )
                resumeButton(
                    title: "Resources",
                    value: resourceSummary,
                    detail: joined(resourceIssueTitles),
                    systemImage: "externaldrive.badge.exclamationmark",
                    action: onShowResources
                )
                resumeButton(
                    title: "Snippets",
                    value: snippetSummary,
                    detail: joined(snippetTitles),
                    systemImage: "text.quote",
                    action: onShowSnippets
                )
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private var canvasDetailText: String {
        if brief.unresolvedReferenceCount > 0 {
            return "\(brief.unresolvedReferenceCount) unresolved reference\(brief.unresolvedReferenceCount == 1 ? "" : "s")"
        }
        return "Workspace map"
    }

    private func joined(_ titles: [String]) -> String {
        titles.isEmpty ? "None" : titles.joined(separator: ", ")
    }

    private func resumeButton(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            resumeContent(title: title, value: value, detail: detail, systemImage: systemImage)
        }
        .buttonStyle(.borderless)
        .help("\(title): \(value)")
        .accessibilityLabel("\(title), \(value)")
    }

    private func resumeItem(
        title: String,
        value: String,
        detail: String,
        systemImage: String
    ) -> some View {
        resumeContent(title: title, value: value, detail: detail, systemImage: systemImage)
            .help("\(title): \(value)")
            .accessibilityLabel("\(title), \(value)")
    }

    private func resumeContent(
        title: String,
        value: String,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WorkspaceResumeBadgeView: View {
    let badge: WorkspaceReentryBadge

    private var label: String {
        switch badge.kind {
        case .overdueTasks:
            return "\(badge.count) overdue"
        case .dueSoonTasks:
            return "\(badge.count) due"
        case .openTasks:
            return "\(badge.count) open"
        case .resourceIssues:
            return "\(badge.count) issue\(badge.count == 1 ? "" : "s")"
        }
    }

    private var systemImage: String {
        switch badge.kind {
        case .overdueTasks:
            return "exclamationmark.circle"
        case .dueSoonTasks:
            return "clock"
        case .openTasks:
            return "circle"
        case .resourceIssues:
            return "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch badge.kind {
        case .overdueTasks:
            return .red
        case .dueSoonTasks, .resourceIssues:
            return .orange
        case .openTasks:
            return .secondary
        }
    }

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .help(label)
            .accessibilityLabel(label)
    }
}

struct HomeResourceCard: View {
    let resource: ResourcePinModel
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onInspect: () -> Void
    @State private var feedback: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: resource.targetType == .folder ? "folder" : "doc")
                        .font(.title3)
                        .frame(width: 24)
                        .foregroundStyle(resource.targetType == .folder ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resource.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(resource.displayPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 76)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded { _ in onOpen() })

            HStack(spacing: 5) {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(CardIconButtonStyle())
                .help(resource.targetType == .folder ? "Open in Finder" : "Reveal in Finder")
                Button {
                    onCopy()
                    showFeedback("Copied")
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(CardIconButtonStyle())
                .help("Copy full path")
                Button(action: onInspect) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(CardIconButtonStyle())
                .help("Show details")
            }
            .padding(8)

            if let feedback {
                Text(feedback)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.92))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 36)
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contextMenu {
            Button(resource.targetType == .folder ? "Open in Finder" : "Reveal in Finder", action: onOpen)
            Button("Copy Full Path") {
                onCopy()
                showFeedback("Copied")
            }
            Button("Details", action: onInspect)
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            feedback = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard feedback == text else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                feedback = nil
            }
        }
    }
}

struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

struct CardGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            content
        }
    }
}

struct DashboardEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

struct DashboardCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle.isEmpty ? "No description" : subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct GlobalLibraryView: View {
    let title: String
    let resources: [ResourcePinModel]
    let knownResources: [ResourcePinModel]
    let workspaces: [WorkspaceModel]
    let canvases: [CanvasModel]
    let nodes: [CanvasNodeModel]
    let snippets: [SnippetModel]
    let onSelectResource: (ResourcePinModel) -> Void
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onRemove: (ResourcePinModel) -> Void
    let onEditSnippet: (SnippetModel) -> Void
    let onDeleteSnippet: (SnippetModel) -> Void
    let onSelectWorkspace: (String) -> Void
    @State private var workspaceFilterId = ""

    private var selectedWorkspaceFilterId: String? {
        workspaceFilterId.isEmpty ? nil : workspaceFilterId
    }

    private var displayRecords: [GlobalResourceLibraryRecord] {
        GlobalResourceLibrary.displayRecords(
            resources: resources.map(resourceLibraryRecord),
            workspaces: workspaces.map { WorkspaceLibraryRecord(id: $0.id, title: $0.title) },
            canvasUsages: canvasResourceUsageRecords,
            workspaceFilterId: selectedWorkspaceFilterId
        )
    }

    private var displayResources: [ResourcePinModel] {
        let resourceById = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        return displayRecords.compactMap { resourceById[$0.resource.id] }
    }

    private var workspaceUsageByResourceID: [String: [ResourceWorkspaceUsage]] {
        Dictionary(uniqueKeysWithValues: displayRecords.map { record in
            let usage = zip(record.workspaceIDs, record.workspaceTitles).map {
                ResourceWorkspaceUsage(id: $0.0, title: $0.1)
            }
            return (record.resource.id, usage)
        })
    }

    private var canvasResourceUsageRecords: [ResourceCanvasUsageRecord] {
        let workspaceIdByCanvasId = Dictionary(uniqueKeysWithValues: canvases.map { ($0.id, $0.workspaceId) })
        return nodes.compactMap { node in
            guard node.objectType == "resourcePin",
                  let resourceId = node.objectId,
                  let workspaceId = workspaceIdByCanvasId[node.canvasId] else {
                return nil
            }
            return ResourceCanvasUsageRecord(resourceId: resourceId, workspaceId: workspaceId)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(title)
                        .font(.title.bold())
                    Spacer()
                    Picker("Used By", selection: $workspaceFilterId) {
                        Text("All Workspaces").tag("")
                        ForEach(workspaces) { workspace in
                            Text(workspace.title).tag(workspace.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }
                ResourceListView(
                    title: "Folders",
                    resources: displayResources,
                    knownResources: knownResources,
                    scope: .global,
                    workspaceId: nil,
                    targetFilter: .folder,
                    pinImported: false,
                    onSelect: onSelectResource,
                    onStatus: onStatus,
                    onInspect: onInspect,
                    onRemove: onRemove,
                    workspaceUsageByResourceID: workspaceUsageByResourceID,
                    onSelectWorkspace: onSelectWorkspace,
                    listMinHeight: 122,
                    listMaxHeight: 240,
                    compactEmptyState: true
                )
                ResourceListView(
                    title: "Files",
                    resources: displayResources,
                    knownResources: knownResources,
                    scope: .global,
                    workspaceId: nil,
                    targetFilter: .file,
                    pinImported: false,
                    onSelect: onSelectResource,
                    onStatus: onStatus,
                    onInspect: onInspect,
                    onRemove: onRemove,
                    workspaceUsageByResourceID: workspaceUsageByResourceID,
                    onSelectWorkspace: onSelectWorkspace,
                    listMinHeight: 122,
                    listMaxHeight: 240,
                    compactEmptyState: true
                )
                Divider()
                SnippetLibraryView(
                    snippets: snippets,
                    resources: resources,
                    scope: .global,
                    workspaceId: nil,
                    onStatus: onStatus,
                    onInspect: onInspect,
                    onEdit: onEditSnippet,
                    onDelete: onDeleteSnippet,
                    listMinHeight: 160,
                    listMaxHeight: 320,
                    compactEmptyState: true
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func resourceLibraryRecord(for resource: ResourcePinModel) -> ResourceLibraryRecord {
        ResourceLibraryRecord(
            id: resource.id,
            targetType: resource.targetTypeRaw,
            title: resource.title,
            originalName: resource.originalName,
            customName: resource.customName,
            displayPath: resource.displayPath,
            lastResolvedPath: resource.lastResolvedPath,
            isPinned: resource.isPinned,
            updatedAt: resource.updatedAt,
            sortIndex: resource.sortIndex,
            scope: resource.scopeRaw,
            workspaceId: resource.workspaceId
        )
    }
}

struct WorkspaceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let workspace: WorkspaceModel
    let reentryBrief: WorkspaceReentryBrief
    let workspaces: [WorkspaceModel]
    let resources: [ResourcePinModel]
    let snippets: [SnippetModel]
    let todos: [WorkspaceTodoModel]
    let todoGroups: [WorkspaceTodoGroupModel]
    let canvases: [CanvasModel]
    let nodes: [CanvasNodeModel]
    let edges: [CanvasEdgeModel]
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onCanvasTabActiveChange: (Bool) -> Void
    let onRenameWorkspace: (WorkspaceModel) -> Void
    let onDeleteWorkspace: (WorkspaceModel) -> Void
    let onToggleWorkspacePinned: (WorkspaceModel) -> Void
    let onRemoveResource: (ResourcePinModel) -> Void
    let onEditSnippet: (SnippetModel) -> Void
    let onDeleteSnippet: (SnippetModel) -> Void
    let onSelectWorkspace: (String) -> Void
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = AppPreferenceDefaults.canvasDefaultZoomPercent
    @State private var tab = "Canvas"
    @State private var createdCanvasByWorkspaceId: [String: CanvasModel] = [:]

    private var defaultCanvasZoom: Double {
        CanvasZoomBaseline.actualZoom(
            percent: canvasDefaultZoomPercent,
            standardBaseline: CanvasZoomBaseline.standardBaseline,
            minimum: CanvasZoomBaseline.minimumZoom,
            maximum: CanvasZoomBaseline.maximumZoom
        )
    }

    private var currentWorkspaceResources: [ResourcePinModel] {
        resources.filter { $0.scope == .workspace && $0.workspaceId == workspace.id }
    }

    private var workspaceAvailableResources: [ResourcePinModel] {
        resources.filter { $0.scope == .global || $0.workspaceId == workspace.id }
    }

    private var workspaceSnippets: [SnippetModel] {
        snippets.filter { $0.scope == .global || $0.workspaceId == workspace.id }
    }

    private var workspaceTodos: [WorkspaceTodoModel] {
        todos.filter { $0.workspaceId == workspace.id }
    }

    private var workspaceTodosByID: [String: WorkspaceTodoModel] {
        Dictionary(workspaceTodos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var resourcesByID: [String: ResourcePinModel] {
        Dictionary(resources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var snippetsByID: [String: SnippetModel] {
        Dictionary(snippets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var workspaceTodoGroups: [WorkspaceTodoGroupModel] {
        todoGroups.filter { $0.workspaceId == workspace.id }
    }

    private var workspaceCanvas: CanvasModel? {
        canvases.first { $0.workspaceId == workspace.id } ?? createdCanvasByWorkspaceId[workspace.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.title)
                        .font(.title.bold())
                    Text(workspace.details)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onToggleWorkspacePinned(workspace)
                } label: {
                    Label(workspace.isPinned ? "Pinned" : "Pin", systemImage: workspace.isPinned ? "pin.fill" : "pin")
                }
                Button {
                    onRenameWorkspace(workspace)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDeleteWorkspace(workspace)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Picker("View", selection: $tab) {
                    Text("Canvas").tag("Canvas")
                    Text("Resources").tag("Resources")
                    Text("Snippets").tag("Snippets")
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }

            WorkspaceResumeBriefView(
                brief: reentryBrief,
                todosByID: workspaceTodosByID,
                resourcesByID: resourcesByID,
                snippetsByID: snippetsByID,
                onShowCanvas: { tab = "Canvas" },
                onShowResources: { tab = "Resources" },
                onShowSnippets: { tab = "Snippets" }
            )

            switch tab {
            case "Resources":
                ResourceListView(title: "Workspace Resources", resources: currentWorkspaceResources, knownResources: resources, scope: .workspace, workspaceId: workspace.id, targetFilter: nil, pinImported: false, onSelect: nil, onStatus: onStatus, onInspect: onInspect, onRemove: onRemoveResource)
            case "Snippets":
                SnippetLibraryView(snippets: workspaceSnippets, resources: workspaceAvailableResources, scope: .workspace, workspaceId: workspace.id, onStatus: onStatus, onInspect: onInspect, onEdit: onEditSnippet, onDelete: onDeleteSnippet)
            default:
                if let canvas = workspaceCanvas {
                    WorkspaceCanvasView(
                        canvas: canvas,
                        resources: workspaceAvailableResources,
                        allResources: resources,
                        workspaces: workspaces,
                        snippets: workspaceSnippets,
                        todos: workspaceTodos,
                        todoGroups: workspaceTodoGroups,
                        nodes: nodes.filter { $0.canvasId == canvas.id },
                        edges: edges.filter { $0.canvasId == canvas.id },
                        onStatus: onStatus,
                        onInspect: onInspect,
                        onOpenWorkspace: onSelectWorkspace
                    )
                } else {
                    ProgressView("Preparing canvas...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            ensureCanvas()
                        }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 0)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            onCanvasTabActiveChange(tab == "Canvas")
            ensureCanvas()
            markWorkspaceOpened()
        }
        .onChange(of: workspace.id) { _, _ in
            onCanvasTabActiveChange(tab == "Canvas")
            ensureCanvas()
            markWorkspaceOpened()
        }
        .onChange(of: tab) { _, newValue in
            onCanvasTabActiveChange(newValue == "Canvas")
        }
    }

    private func markWorkspaceOpened() {
        workspace.lastOpenedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func ensureCanvas() {
        guard canvases.first(where: { $0.workspaceId == workspace.id }) == nil else { return }
        guard createdCanvasByWorkspaceId[workspace.id] == nil else { return }
        let created = CanvasModel(workspaceId: workspace.id, title: "Workspace Map", zoom: defaultCanvasZoom)
        createdCanvasByWorkspaceId[workspace.id] = created
        modelContext.insert(created)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            createdCanvasByWorkspaceId[workspace.id] = nil
            onStatus(error.localizedDescription)
        }
    }
}

struct InspectorView: View {
    let selection: InspectorSelection?
    let resources: [ResourcePinModel]
    let snippets: [SnippetModel]
    let nodes: [CanvasNodeModel]
    let statusMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)

            switch selection {
            case .resource(let id):
                if let resource = resources.first(where: { $0.id == id }) {
                    InspectorRow(title: resource.displayName, subtitle: resource.displayPath, detail: resource.note, icon: resource.targetType == .folder ? "folder" : "doc")
                } else {
                    Text("Resource unavailable").foregroundStyle(.secondary)
                }
            case .snippet(let id):
                if let snippet = snippets.first(where: { $0.id == id }) {
                    InspectorRow(title: snippet.title, subtitle: snippet.kind.rawValue.capitalized, detail: snippet.body, icon: snippet.kind == .prompt ? "text.quote" : "terminal")
                } else {
                    Text("Snippet unavailable").foregroundStyle(.secondary)
                }
            case .node(let id):
                if let node = nodes.first(where: { $0.id == id }) {
                    InspectorRow(title: node.title, subtitle: node.nodeType.rawValue.capitalized, detail: node.body, icon: "rectangle.connected.to.line.below")
                } else {
                    Text("Node unavailable").foregroundStyle(.secondary)
                }
            case nil:
                Text("Select an item to inspect.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding()
    }
}

struct InspectorRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(detail.isEmpty ? "No notes yet." : detail)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
