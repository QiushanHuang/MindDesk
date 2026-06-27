import MindDeskCore
import AppKit
import Quartz
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ResourceWorkspaceUsage: Identifiable, Hashable {
    let id: String
    let title: String
}

enum ResourceListOrderingPolicy {
    static func ordered(_ resources: [ResourcePinModel]) -> [ResourcePinModel] {
        resources.sorted {
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            let displayComparison = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
            if displayComparison != .orderedSame {
                return displayComparison == .orderedAscending
            }
            return $0.id < $1.id
        }
    }
}

enum ResourceRowActionID: String, Equatable, Sendable {
    case open
    case reveal
    case copyPath
    case pinToggle
    case details
    case rename
    case createAlias
    case reauthorize
    case remove
}

struct ResourceRowActionPresentation: Equatable, Identifiable, Sendable {
    let id: ResourceRowActionID
    let title: String
    let systemImage: String?
    let helpText: String
}

enum ResourceRowActionPresentationPolicy {
    static let renameTitle = "Rename in MindDesk"
    static let createAliasTitle = "Create Finder Alias"
    static let reauthorizeTitle = "Reauthorize"
    static let removeTitle = "Remove from MindDesk"

    static func primaryActions(isPinned: Bool) -> [ResourceRowActionPresentation] {
        [
            ResourceRowActionPresentation(id: .open, title: "Open", systemImage: "arrow.up.forward.app", helpText: "Open"),
            ResourceRowActionPresentation(id: .reveal, title: "Reveal", systemImage: "arrow.right.square", helpText: "Reveal"),
            ResourceRowActionPresentation(id: .copyPath, title: "Copy Full Path", systemImage: "doc.on.doc", helpText: "Copy full path"),
            ResourceRowActionPresentation(
                id: .pinToggle,
                title: isPinned ? "Unpin" : "Pin",
                systemImage: isPinned ? "pin.slash" : "pin",
                helpText: isPinned ? "Unpin" : "Pin"
            ),
            ResourceRowActionPresentation(id: .details, title: "Details", systemImage: "info.circle", helpText: "Details")
        ]
    }

    static func moreMenuActions(canRemove: Bool) -> [ResourceRowActionPresentation] {
        var actions = [
            ResourceRowActionPresentation(id: .rename, title: renameTitle, systemImage: nil, helpText: renameTitle),
            ResourceRowActionPresentation(id: .createAlias, title: createAliasTitle, systemImage: nil, helpText: createAliasTitle),
            ResourceRowActionPresentation(id: .reauthorize, title: reauthorizeTitle, systemImage: nil, helpText: reauthorizeTitle)
        ]
        if canRemove {
            actions.append(ResourceRowActionPresentation(id: .remove, title: removeTitle, systemImage: nil, helpText: removeTitle))
        }
        return actions
    }

    static func moreMenuTitles(canRemove: Bool) -> [String] {
        moreMenuActions(canRemove: canRemove).map(\.title)
    }

    static func contextMenuActions(isPinned: Bool, canRemove: Bool) -> [ResourceRowActionPresentation] {
        var actions = [
            ResourceRowActionPresentation(id: .open, title: "Open in Finder", systemImage: nil, helpText: "Open"),
            ResourceRowActionPresentation(id: .reveal, title: "Reveal in Finder", systemImage: nil, helpText: "Reveal"),
            ResourceRowActionPresentation(id: .copyPath, title: "Copy Full Path", systemImage: nil, helpText: "Copy full path"),
            ResourceRowActionPresentation(id: .pinToggle, title: isPinned ? "Unpin" : "Pin", systemImage: nil, helpText: isPinned ? "Unpin" : "Pin"),
            ResourceRowActionPresentation(id: .details, title: "Details", systemImage: nil, helpText: "Details"),
            ResourceRowActionPresentation(id: .rename, title: renameTitle, systemImage: nil, helpText: renameTitle),
            ResourceRowActionPresentation(id: .createAlias, title: createAliasTitle, systemImage: nil, helpText: createAliasTitle),
            ResourceRowActionPresentation(id: .reauthorize, title: reauthorizeTitle, systemImage: nil, helpText: reauthorizeTitle)
        ]
        if canRemove {
            actions.append(ResourceRowActionPresentation(id: .remove, title: removeTitle, systemImage: nil, helpText: removeTitle))
        }
        return actions
    }

    static func contextMenuTitles(isPinned: Bool, canRemove: Bool) -> [String] {
        contextMenuActions(isPinned: isPinned, canRemove: canRemove).map(\.title)
    }
}

enum ResourceRowGestureActionPolicy {
    static let doubleClickActionID: ResourceRowActionID = .open
}

struct ResourceListView: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let resources: [ResourcePinModel]
    let knownResources: [ResourcePinModel]
    let scope: WorkbenchScope
    let workspaceId: String?
    let targetFilter: ResourceTargetType?
    let pinImported: Bool
    let onSelect: ((ResourcePinModel) -> Void)?
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onRemove: (ResourcePinModel) -> Void
    var canRemove: (ResourcePinModel) -> Bool = { _ in true }
    var workspaceUsageByResourceID: [String: [ResourceWorkspaceUsage]] = [:]
    var onSelectWorkspace: ((String) -> Void)?
    var listMinHeight: CGFloat = 220
    var listMaxHeight: CGFloat?
    var compactEmptyState = false
    @State private var searchText = ""
    @State private var isDropTarget = false
    @State private var renamingResource: ResourcePinModel?

    private var filteredResources: [ResourcePinModel] {
        let typed = resources.filter { resource in
            guard let targetFilter else { return true }
            return resource.targetType == targetFilter
        }
        let ordered = ResourceListOrderingPolicy.ordered(typed)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ordered }
        return ordered.filter {
            let cached = $0.searchText.isEmpty ? [
                $0.title,
                $0.originalName,
                $0.customName,
                $0.displayPath,
                $0.note,
                $0.tagsText
            ].joined(separator: " ").lowercased() : $0.searchText
            let usage = workspaceUsageByResourceID[$0.id, default: []].map(\.title).joined(separator: " ").lowercased()
            return "\(cached) \(usage)".contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    addResource()
                } label: {
                    Label("Add Resource", systemImage: "plus")
                }
            }
            TextField("Search resources", text: $searchText)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 0) {
                ResourceListHeader()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredResources.isEmpty {
                            ResourceEmptyState(title: emptyTitle)
                                .frame(maxWidth: .infinity, minHeight: compactEmptyState ? 72 : 112)
                        } else {
                            ForEach(filteredResources) { resource in
                                ResourceRowView(
                                    resource: resource,
                                    workspaceUsage: workspaceUsageByResourceID[resource.id, default: []],
                                    onOpen: { performResourceAction(resource, action: .open) },
                                    onReveal: { performResourceAction(resource, action: .reveal) },
                                    onCopy: { performResourceAction(resource, action: .copy) },
                                    onAlias: { createAlias(for: resource) },
                                    onReauthorize: { reauthorize(resource) },
                                    onInspect: {
                                        onInspect(.resource(resource.id))
                                        onStatus("Showing info for \(resource.displayName)")
                                    },
                                    onSelect: {
                                        onSelect?(resource)
                                    },
                                    onRename: { renamingResource = resource },
                                    onTogglePin: { togglePin(resource) },
                                    canRemove: canRemove(resource),
                                    onRemove: { onRemove(resource) },
                                    onSelectWorkspace: onSelectWorkspace
                                )
                            }
                        }
                    }
                }
            }
            .frame(minHeight: effectiveListMinHeight, maxHeight: listMaxHeight)
            .background(.background)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isDropTarget ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
                FileDropLoader.loadFileURLs(from: providers) { urls in
                    importDropped(urls)
                }
            }
        }
        .sheet(item: $renamingResource) { resource in
            ResourceRenameSheet(resource: resource) {
                do {
                    try modelContext.save()
                    onStatus("Renamed MindDesk metadata: \(resource.displayName)")
                } catch {
                    modelContext.rollback()
                    onStatus(error.localizedDescription)
                }
            }
        }
    }

    private var effectiveListMinHeight: CGFloat {
        filteredResources.isEmpty && compactEmptyState ? min(listMinHeight, 112) : listMinHeight
    }

    private var emptyTitle: String {
        if let targetFilter {
            return targetFilter == .folder ? "No folders yet" : "No files yet"
        }
        return "No resources yet"
    }

    private enum ResourceAction: Equatable {
        case open
        case reveal
        case copy
    }

    private func addResource() {
        let url: URL?
        switch targetFilter {
        case .folder:
            url = FileDialogs.chooseDirectory(message: "Choose a folder to pin in MindDesk.")
        case .file:
            url = FileDialogs.chooseFile(message: "Choose a file to pin in MindDesk.")
        case nil:
            url = FileDialogs.chooseResource()
        }
        guard let url else { return }
        do {
            let summary = try ResourceImportService().importURLs(
                [url],
                existingResources: knownResources,
                into: modelContext,
                scope: scope,
                workspaceId: workspaceId,
                pinImported: pinImported
            )
            onStatus(summary.statusText)
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func importDropped(_ urls: [URL]) {
        guard !urls.isEmpty else {
            onStatus("Drop did not include files or folders.")
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
            onStatus("Drop did not include matching \(targetDescription).")
            return
        }
        do {
            let summary = try ResourceImportService().importURLs(
                acceptedURLs,
                existingResources: knownResources,
                into: modelContext,
                scope: scope,
                workspaceId: workspaceId,
                pinImported: pinImported
            )
            let skippedText = skippedCount > 0 ? " Skipped \(skippedCount) unmatched item\(skippedCount == 1 ? "" : "s")." : ""
            onStatus("\(summary.statusText)\(skippedText)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func performResourceAction(_ resource: ResourcePinModel, action: ResourceAction) {
        if action == .copy {
            ClipboardService().copy(resource.displayPath)
            onStatus("Copied path: \(resource.displayPath)")
            return
        }

        let bookmarkService = BookmarkService()
        do {
            let resolved = try bookmarkService.resolveAuthorizedBookmark(
                resource.securityScopedBookmarkData,
                fallbackPath: resource.lastResolvedPath,
                statusRaw: resource.statusRaw
            )
            let url = resolved.url
            try bookmarkService.access(url) {
                switch action {
                case .open:
                    switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                    case .open:
                        try FinderService().open(url)
                    case .reveal:
                        try FinderService().reveal(url)
                    }
                    resource.lastOpenedAt = .now
                    resource.status = .available
                    onStatus("Opened \(resource.displayName) in Finder")
                case .reveal:
                    try FinderService().reveal(url)
                    resource.status = .available
                    onStatus("Revealed \(resource.displayName) in Finder")
                case .copy:
                    break
                }
            }
            resource.lastResolvedPath = url.path
            resource.displayPath = url.path
            resource.refreshSearchText()
            resource.updatedAt = .now
            try modelContext.save()
        } catch {
            resource.status = ResourceAccessStatusResolver.failureStatus(for: error, fallbackPath: resource.lastResolvedPath)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
            onStatus(error.localizedDescription)
        }
    }

    private func createAlias(for resource: ResourcePinModel) {
        guard let requestedAliasURL = FileDialogs.saveAlias(defaultName: "\(resource.effectiveName) alias") else { return }
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
            MindDeskHiddenMaintenanceLogger.log(.finderAliasCreateResult(
                sourceObjectType: aliasRecord.sourceObjectType,
                status: aliasRecord.statusRaw,
                hasAliasBookmark: aliasRecord.aliasFileBookmarkData != nil,
                hasTargetBookmark: aliasRecord.aliasTargetBookmarkData != nil
            ))
            onStatus("Created Finder alias: \(aliasURL.path)")
        } catch {
            let failed = FinderAliasRecordModel(sourceObjectType: "resourcePin", sourceObjectId: resource.id, aliasDisplayPath: requestedAliasURL.path, status: .failed)
            modelContext.insert(failed)
            do {
                try modelContext.save()
                MindDeskHiddenMaintenanceLogger.log(.finderAliasCreateResult(
                    sourceObjectType: failed.sourceObjectType,
                    status: failed.statusRaw,
                    hasAliasBookmark: failed.aliasFileBookmarkData != nil,
                    hasTargetBookmark: failed.aliasTargetBookmarkData != nil
                ))
            } catch {
                modelContext.rollback()
            }
            onStatus(error.localizedDescription)
        }
    }

    private func reauthorize(_ resource: ResourcePinModel) {
        guard let url = FileDialogs.chooseResource() else { return }
        var didMutateResource = false
        do {
            let selectedType = ResourceImportService.targetType(for: url)
            guard ResourceAuthorizationPolicy.acceptsReauthorization(
                existingTargetType: resource.targetTypeRaw,
                selectedTargetType: selectedType.rawValue
            ) else {
                throw WorkbenchError.resourceTypeMismatch(expected: resource.targetTypeRaw, selected: selectedType.rawValue)
            }
            let bookmarkData = try BookmarkService().makeBookmark(for: url)
            didMutateResource = true
            resource.securityScopedBookmarkData = bookmarkData
            resource.displayPath = url.path
            resource.lastResolvedPath = url.path
            resource.originalName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            resource.status = .available
            resource.updatedAt = .now
            resource.refreshSearchText()
            try modelContext.save()
            onStatus("Reauthorized \(url.path)")
        } catch {
            if didMutateResource {
                modelContext.rollback()
            }
            onStatus(error.localizedDescription)
        }
    }

    private func togglePin(_ resource: ResourcePinModel) {
        resource.isPinned.toggle()
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try modelContext.save()
            onStatus(resource.isPinned ? "Pinned \(resource.displayName)" : "Unpinned \(resource.displayName)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }
}

struct ResourcePreviewView: View {
    @Environment(\.modelContext) private var modelContext
    let resource: ResourcePinModel
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onRemove: (ResourcePinModel) -> Void
    @State private var folderItems: [FolderPreviewItem] = []
    @State private var isLoadingFolder = false
    @State private var previewError: String?
    @State private var folderPreviewTask: Task<Void, Never>?
    @State private var renamingResource: ResourcePinModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            resourceHeader
            Divider()

            if resource.targetType == .folder {
                folderPreview
            } else {
                filePreview
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            onInspect(.resource(resource.id))
            previewError = nil
            if resource.targetType == .folder {
                loadFolderContents()
            }
        }
        .onChange(of: resource.id) { _, _ in
            onInspect(.resource(resource.id))
            folderPreviewTask?.cancel()
            folderItems = []
            previewError = nil
            if resource.targetType == .folder {
                loadFolderContents()
            }
        }
        .onChange(of: resource.statusRaw) { _, _ in
            previewError = nil
        }
        .onChange(of: resource.lastResolvedPath) { _, _ in
            previewError = nil
        }
        .onChange(of: resource.securityScopedBookmarkData) { _, _ in
            previewError = nil
        }
        .onDisappear {
            folderPreviewTask?.cancel()
            folderPreviewTask = nil
        }
        .sheet(item: $renamingResource) { resource in
            ResourceRenameSheet(resource: resource) {
                resource.refreshSearchText()
                resource.updatedAt = .now
                do {
                    try modelContext.save()
                    onStatus("Renamed MindDesk metadata: \(resource.displayName)")
                } catch {
                    modelContext.rollback()
                    onStatus(error.localizedDescription)
                }
            }
        }
    }

    private var resourceHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: resource.targetType == .folder ? "folder.fill" : "doc.fill")
                .font(.system(size: 30))
                .foregroundStyle(resource.targetType == .folder ? Color.accentColor : Color.secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(resource.displayName)
                        .font(.title2.bold())
                        .lineLimit(1)
                    if resource.isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(resource.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(resource.note.isEmpty ? "No description yet." : resource.note)
                    .font(.callout)
                    .foregroundStyle(resource.note.isEmpty ? .secondary : .primary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    performResourceAction(.open)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                Button {
                    performResourceAction(.copy)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
                Button {
                    performResourceAction(.reveal)
                } label: {
                    Label("Reveal", systemImage: "arrow.right.square")
                }
                Button {
                    onInspect(.resource(resource.id))
                    onStatus("Showing info for \(resource.displayName)")
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Show details")
                Menu {
                    Button("Rename in MindDesk") { renamingResource = resource }
                    Button(resource.isPinned ? "Unpin Shortcut" : "Pin Shortcut") { togglePin() }
                    Divider()
                    Button("Remove from MindDesk", role: .destructive) { onRemove(resource) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More actions")
            }
            .buttonStyle(.bordered)
        }
    }

    private var folderPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Folder Contents")
                    .font(.headline)
                Spacer()
                Button {
                    loadFolderContents()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if isLoadingFolder {
                ProgressView("Loading folder...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let previewError {
                ContentUnavailableView("Folder unavailable", systemImage: "exclamationmark.triangle", description: Text(previewError))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderItems.isEmpty {
                ContentUnavailableView("Folder is empty", systemImage: "folder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(folderItems) { item in
                    FolderPreviewRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            openPreviewItem(item)
                        }
                        .contextMenu {
                            Button(item.isDirectory ? "Open in Finder" : "Reveal in Finder") {
                                openPreviewItem(item)
                            }
                            Button("Copy Full Path") {
                                ClipboardService().copy(item.path)
                                onStatus("Copied path: \(item.path)")
                            }
                        }
                }
                .listStyle(.inset)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Preview")
                .font(.headline)

            if let previewError {
                ContentUnavailableView("Preview unavailable", systemImage: "doc", description: Text(previewError))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !ResourceAuthorizationPolicy.canAccessFileSystem(status: resource.statusRaw, hasBookmarkData: resource.securityScopedBookmarkData != nil) {
                ContentUnavailableView("Reauthorization required", systemImage: "lock", description: Text(resource.displayPath))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                QuickLookPreview(
                    bookmarkData: resource.securityScopedBookmarkData,
                    fallbackPath: resource.lastResolvedPath,
                    statusRaw: resource.statusRaw
                ) { message in
                    previewError = message
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            }
        }
    }

    private enum ResourcePreviewAction: Equatable {
        case open
        case reveal
        case copy
    }

    private func performResourceAction(_ action: ResourcePreviewAction) {
        if action == .copy {
            ClipboardService().copy(resource.displayPath)
            onStatus("Copied path: \(resource.displayPath)")
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
                switch action {
                case .open:
                    switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                    case .open:
                        try FinderService().open(resolved.url)
                    case .reveal:
                        try FinderService().reveal(resolved.url)
                    }
                    resource.lastOpenedAt = .now
                    onStatus("Opened \(resource.displayName) in Finder")
                case .reveal:
                    try FinderService().reveal(resolved.url)
                    onStatus("Revealed \(resource.displayName) in Finder")
                case .copy:
                    break
                }
            }
            resource.lastResolvedPath = resolved.url.path
            resource.displayPath = resolved.url.path
            resource.status = .available
            resource.updatedAt = .now
            resource.refreshSearchText()
            try modelContext.save()
        } catch {
            resource.status = ResourceAccessStatusResolver.failureStatus(for: error, fallbackPath: resource.lastResolvedPath)
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
            onStatus(error.localizedDescription)
        }
    }

    private func loadFolderContents() {
        guard resource.targetType == .folder else { return }
        let bookmarkData = resource.securityScopedBookmarkData
        let fallbackPath = resource.lastResolvedPath
        let statusRaw = resource.statusRaw
        folderPreviewTask?.cancel()
        isLoadingFolder = true
        previewError = nil

        folderPreviewTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try FolderPreviewService().contents(bookmarkData: bookmarkData, fallbackPath: fallbackPath, statusRaw: statusRaw)
                }
            }.value

            guard !Task.isCancelled else { return }
            isLoadingFolder = false
            switch result {
            case .success(let items):
                folderItems = items
            case .failure(let error):
                folderItems = []
                previewError = error.localizedDescription
            }
        }
    }

    private func openPreviewItem(_ item: FolderPreviewItem) {
        let bookmarkService = BookmarkService()
        do {
            let resolved = try bookmarkService.resolveAuthorizedBookmark(
                resource.securityScopedBookmarkData,
                fallbackPath: resource.lastResolvedPath,
                statusRaw: resource.statusRaw
            )
            try bookmarkService.access(resolved.url) {
                if item.isDirectory {
                    try FinderService().open(item.url)
                    onStatus("Opened \(item.name) in Finder")
                } else {
                    try FinderService().reveal(item.url)
                    onStatus("Revealed \(item.name) in Finder")
                }
            }
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    private func togglePin() {
        resource.isPinned.toggle()
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try modelContext.save()
            onStatus(resource.isPinned ? "Pinned \(resource.displayName)" : "Unpinned \(resource.displayName)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }
}

private struct ResourceEmptyState: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "tray")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 18)
    }
}

private struct FolderPreviewRow: View {
    let item: FolderPreviewItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let sizeText {
                Text(sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 3)
    }

    private var sizeText: String? {
        guard !item.isDirectory, let size = item.size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let bookmarkData: Data?
    let fallbackPath: String
    let statusRaw: String
    let onUnavailable: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> QuickLookPreviewContainerView {
        QuickLookPreviewContainerView()
    }

    func updateNSView(_ nsView: QuickLookPreviewContainerView, context: Context) {
        guard let previewView = nsView.previewView else {
            context.coordinator.reportPreviewUnavailable(onUnavailable: onUnavailable)
            return
        }
        context.coordinator.update(
            bookmarkData: bookmarkData,
            fallbackPath: fallbackPath,
            statusRaw: statusRaw,
            onUnavailable: onUnavailable,
            in: previewView
        )
    }

    static func dismantleNSView(_ nsView: QuickLookPreviewContainerView, coordinator: Coordinator) {
        if let previewView = nsView.previewView {
            coordinator.stop(in: previewView)
        }
    }

    final class QuickLookPreviewContainerView: NSView {
        let previewView: QLPreviewView?

        override init(frame frameRect: NSRect) {
            let previewView = QLPreviewView(frame: .zero, style: .normal)
            self.previewView = previewView
            super.init(frame: frameRect)
            if let previewView {
                previewView.autostarts = true
                previewView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(previewView)
                NSLayoutConstraint.activate([
                    previewView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    previewView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    previewView.topAnchor.constraint(equalTo: topAnchor),
                    previewView.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
            } else {
                let fallback = NSTextField(wrappingLabelWithString: "Preview unavailable.")
                fallback.alignment = .center
                fallback.textColor = .secondaryLabelColor
                fallback.translatesAutoresizingMaskIntoConstraints = false
                addSubview(fallback)
                NSLayoutConstraint.activate([
                    fallback.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
                    fallback.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
                    fallback.centerXAnchor.constraint(equalTo: centerXAnchor),
                    fallback.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }
    }

    @MainActor
    final class Coordinator {
        private struct ActiveResource: Equatable {
            let bookmarkData: Data?
            let fallbackPath: String
            let statusRaw: String
        }

        private var activeResource: ActiveResource?
        private var activeURL: URL?
        private var didAccess = false
        private var didReportPreviewUnavailable = false

        func update(bookmarkData: Data?, fallbackPath: String, statusRaw: String, onUnavailable: @escaping (String) -> Void, in previewView: QLPreviewView) {
            didReportPreviewUnavailable = false
            let resource = ActiveResource(bookmarkData: bookmarkData, fallbackPath: fallbackPath, statusRaw: statusRaw)
            guard activeResource != resource else {
                if let activeURL {
                    previewView.previewItem = activeURL as NSURL
                }
                return
            }

            stop(in: previewView)
            do {
                let resolved = try BookmarkService().resolveAuthorizedBookmark(bookmarkData, fallbackPath: fallbackPath, statusRaw: statusRaw)
                let didStartAccess = resolved.url.startAccessingSecurityScopedResource()
                guard FileManager.default.fileExists(atPath: resolved.url.path) else {
                    if didStartAccess {
                        resolved.url.stopAccessingSecurityScopedResource()
                    }
                    activeResource = resource
                    reportUnavailable("Missing file: \(resolved.url.path)", for: resource, onUnavailable: onUnavailable)
                    return
                }
                activeResource = resource
                activeURL = resolved.url
                didAccess = didStartAccess
                previewView.previewItem = resolved.url as NSURL
            } catch {
                activeResource = resource
                reportUnavailable(error.localizedDescription, for: resource, onUnavailable: onUnavailable)
            }
        }

        private func reportUnavailable(_ message: String, for resource: ActiveResource, onUnavailable: @escaping (String) -> Void) {
            Task { @MainActor [weak self] in
                guard self?.activeResource == resource else { return }
                onUnavailable(message)
            }
        }

        func reportPreviewUnavailable(onUnavailable: @escaping (String) -> Void) {
            guard !didReportPreviewUnavailable else { return }
            didReportPreviewUnavailable = true
            onUnavailable("Quick Look preview is unavailable.")
        }

        func stop(in previewView: QLPreviewView) {
            previewView.previewItem = nil
            if didAccess {
                activeURL?.stopAccessingSecurityScopedResource()
            }
            activeResource = nil
            activeURL = nil
            didAccess = false
        }
    }
}

private struct ResourceListHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Name")
                .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
            Text("Status")
                .frame(width: 80, alignment: .leading)
            Text("Workspaces")
                .frame(width: 180, alignment: .leading)
            Text("Path")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Actions")
                .frame(width: 238, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.28))
    }
}

private struct ResourceRowView: View {
    let resource: ResourcePinModel
    let workspaceUsage: [ResourceWorkspaceUsage]
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onCopy: () -> Void
    let onAlias: () -> Void
    let onReauthorize: () -> Void
    let onInspect: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onTogglePin: () -> Void
    let canRemove: Bool
    let onRemove: () -> Void
    let onSelectWorkspace: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: resource.targetType == .folder ? "folder" : "doc")
                    .foregroundStyle(resource.isPinned ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(resource.targetType == .folder ? "Folder" : "File")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 180, maxWidth: 260, alignment: .leading)

            Text(resource.statusRaw)
                .font(.caption)
                .foregroundStyle(resource.status == .available ? Color.secondary : Color.red)
                .frame(width: 80, alignment: .leading)

            WorkspaceUsageColumn(
                usage: workspaceUsage,
                onSelectWorkspace: onSelectWorkspace
            )
            .frame(width: 180, alignment: .leading)

            Text(resource.displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                ForEach(ResourceRowActionPresentationPolicy.primaryActions(isPinned: resource.isPinned)) { action in
                    iconButton(action.systemImage ?? "circle", action.helpText) {
                        perform(action.id)
                    }
                }
                Menu {
                    ForEach(ResourceRowActionPresentationPolicy.moreMenuActions(canRemove: canRemove)) { action in
                        if action.id == .remove {
                            Divider()
                            Button(action.title, role: .destructive) {
                                perform(action.id)
                            }
                        } else {
                            Button(action.title) {
                                perform(action.id)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .help("More actions")
            }
            .frame(width: 238, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .simultaneousGesture(TapGesture(count: 2).onEnded { _ in
            perform(ResourceRowGestureActionPolicy.doubleClickActionID)
        })
        .contextMenu {
            ForEach(ResourceRowActionPresentationPolicy.contextMenuActions(isPinned: resource.isPinned, canRemove: canRemove)) { action in
                if action.id == .remove {
                    Divider()
                    Button(action.title, role: .destructive) {
                        perform(action.id)
                    }
                } else {
                    Button(action.title) {
                        perform(action.id)
                    }
                }
            }
        }
        Divider()
    }

    private func perform(_ actionID: ResourceRowActionID) {
        switch actionID {
        case .open:
            onOpen()
        case .reveal:
            onReveal()
        case .copyPath:
            onCopy()
        case .pinToggle:
            onTogglePin()
        case .details:
            onInspect()
        case .rename:
            onRename()
        case .createAlias:
            onAlias()
        case .reauthorize:
            onReauthorize()
        case .remove:
            onRemove()
        }
    }

    private func iconButton(_ systemImage: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct WorkspaceUsageColumn: View {
    let usage: [ResourceWorkspaceUsage]
    let onSelectWorkspace: ((String) -> Void)?

    var body: some View {
        if usage.isEmpty {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 0) {
                let visibleUsage = Array(usage.prefix(2))
                ForEach(Array(visibleUsage.enumerated()), id: \.element.id) { index, workspace in
                    Button {
                        onSelectWorkspace?(workspace.id)
                    } label: {
                        Text(workspace.title)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(onSelectWorkspace == nil ? Color.secondary : Color.accentColor)
                    .disabled(onSelectWorkspace == nil)
                    .help("Open workspace: \(workspace.title)")

                    if index < visibleUsage.count - 1 || usage.count > visibleUsage.count {
                        Text("; ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if usage.count > 2 {
                    Menu("+\(usage.count - 2)") {
                        ForEach(usage.dropFirst(2)) { workspace in
                            Button(workspace.title) {
                                onSelectWorkspace?(workspace.id)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.leading, 2)
                    .disabled(onSelectWorkspace == nil)
                    .help("More workspaces")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum FileDropLoader {
    static func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        let store = DropURLStore()

        for (index, provider) in fileProviders.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                if let url, url.isFileURL {
                    store.append(url, at: index)
                }
            }
        }

        group.notify(queue: .main) {
            completion(store.values)
        }
        return true
    }
}

private final class DropURLStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int: URL] = [:]

    var values: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage.keys.sorted().compactMap { storage[$0] }
    }

    func append(_ url: URL, at index: Int) {
        lock.lock()
        storage[index] = url
        lock.unlock()
    }
}

enum SnippetCreationActionID: String, Equatable, Sendable {
    case prompt
    case command
}

struct SnippetCreationActionPresentation: Equatable, Identifiable, Sendable {
    let id: SnippetCreationActionID
    let title: String
    let systemImage: String
    let helpText: String
}

enum SnippetCreationPresentationPolicy {
    static let creationActions = [
        SnippetCreationActionPresentation(
            id: .prompt,
            title: "New Prompt",
            systemImage: "text.quote",
            helpText: "Create prompt snippet"
        ),
        SnippetCreationActionPresentation(
            id: .command,
            title: "New Command",
            systemImage: "terminal",
            helpText: "Create command snippet"
        )
    ]

    static func initialKind(for actionID: SnippetCreationActionID) -> SnippetKind {
        switch actionID {
        case .prompt:
            .prompt
        case .command:
            .command
        }
    }
}

enum SnippetActionID: String, Equatable, Sendable {
    case copy
    case edit
    case delete
}

struct SnippetActionPresentation: Equatable, Identifiable, Sendable {
    let id: SnippetActionID
    let title: String
    let systemImage: String
    let helpText: String
}

enum SnippetActionPresentationPolicy {
    static let managementActions = [
        SnippetActionPresentation(id: .copy, title: "Copy", systemImage: "doc.on.doc", helpText: "Copy snippet"),
        SnippetActionPresentation(id: .edit, title: "Edit", systemImage: "pencil", helpText: "Edit snippet"),
        SnippetActionPresentation(id: .delete, title: "Delete Snippet", systemImage: "trash", helpText: "Delete snippet")
    ]

    static var nonDestructiveManagementActions: [SnippetActionPresentation] {
        managementActions.filter { $0.id != .delete }
    }

    static var destructiveManagementActions: [SnippetActionPresentation] {
        managementActions.filter { $0.id == .delete }
    }
}

enum SnippetExpansionActionID: String, Equatable, Sendable {
    case toggleExpanded
}

enum SnippetExpansionPresentationPolicy {
    static let doubleClickActionID: SnippetExpansionActionID = .toggleExpanded
    static let expandedEditAction = SnippetActionPresentation(
        id: .edit,
        title: "Edit",
        systemImage: "pencil",
        helpText: "Edit full snippet"
    )

    static func bodyText(for body: String) -> String {
        body.isEmpty ? "No snippet body." : body
    }
}

enum SnippetActionCardReadabilityPolicy {
    nonisolated static func titleLineLimit(compact: Bool) -> Int {
        compact ? 3 : 1
    }

    nonisolated static func subtitleLineLimit(compact: Bool) -> Int {
        compact ? 2 : 2
    }

    nonisolated static func expandedBodyLineLimit(compact _: Bool) -> Int? {
        nil
    }

    nonisolated static func minimumHeight(compact: Bool, isExpanded: Bool) -> CGFloat {
        guard compact else { return 96 }
        return isExpanded ? 176 : 128
    }
}

struct SnippetLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    let snippets: [SnippetModel]
    let resources: [ResourcePinModel]
    let scope: WorkbenchScope?
    let workspaceId: String?
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onEdit: (SnippetModel) -> Void
    let onDelete: (SnippetModel) -> Void
    var listMinHeight: CGFloat = 220
    var listMaxHeight: CGFloat?
    var compactEmptyState = false
    @State private var searchText = ""
    @State private var creatingSnippetKind: SnippetKind?
    @State private var pendingRun: CommandRunRequest?
    @State private var expandedSnippetIDs: Set<String> = []

    private var filteredSnippets: [SnippetModel] {
        let snippetById = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
        let records = snippets.map {
            SnippetLibraryRecord(id: $0.id, scope: $0.scopeRaw, workspaceId: $0.workspaceId, title: $0.title, updatedAt: $0.updatedAt)
        }
        let visible = SnippetLibraryFiltering
            .visible(records, scope: scope?.rawValue, workspaceId: workspaceId)
            .compactMap { snippetById[$0.id] }
        guard !searchText.isEmpty else { return visible }
        return visible.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.details.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snippets")
                    .font(.headline)
                Spacer()
                ForEach(SnippetCreationPresentationPolicy.creationActions) { action in
                    Button {
                        creatingSnippetKind = SnippetCreationPresentationPolicy.initialKind(for: action.id)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                    }
                    .help(action.helpText)
                }
            }
            TextField("Search snippets", text: $searchText)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if filteredSnippets.isEmpty {
                        ResourceEmptyState(title: "No snippets yet")
                            .frame(maxWidth: .infinity, minHeight: compactEmptyState ? 72 : 112)
                    } else {
                        ForEach(filteredSnippets) { snippet in
                            SnippetActionCard(
                                snippet: snippet,
                                isExpanded: expandedSnippetIDs.contains(snippet.id),
                                compact: false,
                                onToggleExpanded: { toggleSnippet(snippet) },
                                onCopy: { copy(snippet) },
                                onEdit: { onEdit(snippet) },
                                onDelete: { onDelete(snippet) },
                                onInspect: { onInspect(.snippet(snippet.id)) },
                                onOpenTerminal: snippet.kind == .command ? { openTerminal(snippet) } : nil,
                                onRun: snippet.kind == .command ? { prepareRun(snippet) } : nil
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: effectiveListMinHeight, maxHeight: listMaxHeight)
        }
        .sheet(item: $creatingSnippetKind) { kind in
            SnippetEditor(initialKind: kind, scope: scope ?? .global, workspaceId: workspaceId, resources: resources) { draft in
                let snippet = draft.makeSnippet()
                modelContext.insert(snippet)
                do {
                    try modelContext.save()
                    onStatus("Created snippet: \(snippet.title)")
                } catch {
                    modelContext.rollback()
                    onStatus(error.localizedDescription)
                }
            }
        }
        .alert("Run command in Terminal?", isPresented: Binding(
            get: { pendingRun != nil },
            set: { if !$0 { pendingRun = nil } }
        )) {
            Button("Run", role: .destructive) {
                if let pendingRun {
                    run(pendingRun)
                }
                pendingRun = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRun = nil
            }
        } message: {
            if let pendingRun {
                Text("\(pendingRun.snippet.body)\n\nWorking directory: \(pendingRun.workingDirectory)")
            }
        }
    }

    private var effectiveListMinHeight: CGFloat {
        filteredSnippets.isEmpty && compactEmptyState ? min(listMinHeight, 112) : listMinHeight
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

    private func copy(_ snippet: SnippetModel) {
        ClipboardService().copy(snippet.body)
        snippet.lastCopiedAt = .now
        snippet.updatedAt = .now
        do {
            try modelContext.save()
            onStatus("Copied \(snippet.kind.rawValue): \(snippet.title)")
        } catch {
            modelContext.rollback()
            onStatus("Copied \(snippet.kind.rawValue), but could not update metadata. \(error.localizedDescription)")
        }
    }

    private func openTerminal(_ snippet: SnippetModel) {
        do {
            let directory = try resolvedWorkingDirectory(for: snippet)
            try TerminalService().prefill(command: snippet.body, workingDirectory: directory)
            snippet.lastUsedAt = .now
            do {
                try modelContext.save()
                onStatus("Opened Terminal with command prefilled at \(directory)")
            } catch {
                modelContext.rollback()
                onStatus("Opened Terminal with command prefilled, but could not update metadata. \(error.localizedDescription)")
            }
        } catch {
            onStatus("Terminal automation failed. \(error.localizedDescription)")
        }
    }

    private func prepareRun(_ snippet: SnippetModel) {
        do {
            let request = CommandRunRequest(snippet: snippet, workingDirectory: try resolvedWorkingDirectory(for: snippet))
            if CommandRunConfirmationPolicy.shouldConfirm(kind: snippet.kindRaw, requiresConfirmation: snippet.requiresConfirmation) {
                pendingRun = request
            } else {
                run(request)
            }
        } catch {
            onStatus("Could not resolve working directory. \(error.localizedDescription)")
        }
    }

    private func run(_ request: CommandRunRequest) {
        let snippet = request.snippet
        do {
            try TerminalService().run(command: snippet.body, workingDirectory: request.workingDirectory)
            snippet.lastUsedAt = .now
            do {
                try modelContext.save()
                onStatus("Requested Terminal run: \(snippet.title)")
            } catch {
                modelContext.rollback()
                onStatus("Requested Terminal run, but could not update metadata. \(error.localizedDescription)")
            }
        } catch {
            let runError = error
            ClipboardService().copy(snippet.body)
            snippet.lastCopiedAt = .now
            snippet.updatedAt = .now
            do {
                try TerminalService().prefill(command: snippet.body, workingDirectory: request.workingDirectory)
                do {
                    try modelContext.save()
                    onStatus("Terminal run failed; copied command and opened Terminal with command prefilled at \(request.workingDirectory). \(runError.localizedDescription)")
                } catch {
                    modelContext.rollback()
                    onStatus("Terminal run failed; copied command and opened Terminal with command prefilled, but could not update metadata. \(error.localizedDescription)")
                }
            } catch {
                let prefillError = error
                do {
                    try TerminalService().open(at: request.workingDirectory)
                    do {
                        try modelContext.save()
                        onStatus("Terminal run failed; copied command and opened Terminal at \(request.workingDirectory). Could not prefill command: \(prefillError.localizedDescription). \(runError.localizedDescription)")
                    } catch {
                        modelContext.rollback()
                        onStatus("Terminal run failed; copied command and opened Terminal, but could not update metadata. \(error.localizedDescription)")
                    }
                } catch {
                    modelContext.rollback()
                    onStatus("Terminal run failed; copied command. Could not open Terminal at \(request.workingDirectory): \(error.localizedDescription)")
                }
            }
        }
    }

    private func resolvedWorkingDirectory(for snippet: SnippetModel) throws -> String {
        guard !CommandWorkingDirectoryPolicy.allowsHomeFallback(workingDirectoryRef: snippet.workingDirectoryRef) else {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        guard let ref = snippet.workingDirectoryRef,
              let resource = resources.first(where: { $0.id == ref }) else {
            throw WorkbenchError.invalidWorkingDirectory("Configured working directory is missing. Choose a folder or clear the working directory.")
        }
        let records = resources.map {
            ResourceLibraryRecord(
                id: $0.id,
                targetType: $0.targetTypeRaw,
                title: $0.title,
                originalName: $0.originalName,
                customName: $0.customName,
                displayPath: $0.displayPath,
                isPinned: $0.isPinned,
                scope: $0.scopeRaw,
                workspaceId: $0.workspaceId
            )
        }
        guard SnippetWorkingDirectoryOptions.validSelection(ref, in: records) != nil else {
            throw WorkbenchError.invalidWorkingDirectory("Configured working directory is not an available folder. Choose a folder or clear the working directory.")
        }

        let bookmarkService = BookmarkService()
        let resolved = try bookmarkService.resolveAuthorizedBookmark(
            resource.securityScopedBookmarkData,
            fallbackPath: resource.lastResolvedPath,
            statusRaw: resource.statusRaw
        )
        var isDirectory: ObjCBool = false
        try bookmarkService.access(resolved.url) {
            guard FileManager.default.fileExists(atPath: resolved.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw WorkbenchError.missingPath(resolved.url.path)
            }
        }

        resource.lastResolvedPath = resolved.url.path
        resource.displayPath = resolved.url.path
        resource.status = .available
        resource.updatedAt = .now
        try modelContext.save()
        return resolved.url.path
    }
}

private struct CommandRunRequest {
    let snippet: SnippetModel
    let workingDirectory: String
}

struct SnippetActionCard: View {
    let snippet: SnippetModel
    let isExpanded: Bool
    var compact = false
    let onToggleExpanded: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onInspect: () -> Void
    let onOpenTerminal: (() -> Void)?
    let onRun: (() -> Void)?
    @State private var feedback: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: snippet.kind == .prompt ? "text.quote" : "terminal")
                        .font(.title3)
                        .frame(width: 24)
                        .foregroundStyle(snippet.kind == .prompt ? Color.secondary : Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snippet.title)
                            .font(.headline)
                            .lineLimit(SnippetActionCardReadabilityPolicy.titleLineLimit(compact: compact))
                            .minimumScaleFactor(0.8)
                        Text(snippetSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(SnippetActionCardReadabilityPolicy.subtitleLineLimit(compact: compact))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !compact {
                        actionBar
                    }
                }

                if compact {
                    HStack {
                        Spacer(minLength: 0)
                        actionBar
                    }
                }

                if isExpanded {
                    expandedContent
                }
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                minHeight: SnippetActionCardReadabilityPolicy.minimumHeight(compact: compact, isExpanded: isExpanded),
                alignment: .topLeading
            )
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                performExpansionGestureAction(SnippetExpansionPresentationPolicy.doubleClickActionID)
            })

            if let feedback {
                Text(feedback)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.92))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 38)
                    .padding(.trailing, 8)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contextMenu {
            ForEach(SnippetActionPresentationPolicy.managementActions) { action in
                if action.id == .delete {
                    Button(action.title, role: .destructive) {
                        performSnippetManagementAction(action.id)
                    }
                } else {
                    Button(action.title) {
                        performSnippetManagementAction(action.id)
                    }
                }
            }
            Button(isExpanded ? "Collapse" : "Expand", action: onToggleExpanded)
            Button("Details", action: onInspect)
            if let onOpenTerminal {
                Button("Open Terminal", action: onOpenTerminal)
            }
            if let onRun {
                Button("Run Command", action: onRun)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: compact ? 4 : 5) {
            Button(action: onToggleExpanded) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(CardIconButtonStyle())
            .help(isExpanded ? "Collapse snippet" : "Expand snippet")

            ForEach(SnippetActionPresentationPolicy.nonDestructiveManagementActions) { action in
                Button {
                    performSnippetManagementAction(action.id)
                } label: {
                    Image(systemName: action.systemImage)
                }
                .buttonStyle(CardIconButtonStyle())
                .help(action.helpText)
            }

            Button(action: onInspect) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(CardIconButtonStyle())
            .help("Show details")

            if let onOpenTerminal {
                Button(action: onOpenTerminal) {
                    Image(systemName: "terminal")
                }
                .buttonStyle(CardIconButtonStyle())
                .help("Open Terminal with command prefilled")
            }

            if let onRun {
                Button(action: onRun) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(CardIconButtonStyle())
                .help("Run command")
            }

            ForEach(SnippetActionPresentationPolicy.destructiveManagementActions) { action in
                Button(role: .destructive) {
                    performSnippetManagementAction(action.id)
                } label: {
                    Image(systemName: action.systemImage)
                }
                .buttonStyle(CardIconButtonStyle())
                .help(action.helpText)
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !snippet.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(snippet.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(SnippetExpansionPresentationPolicy.bodyText(for: snippet.body))
                .font(.system(.caption, design: snippet.kind == .command ? .monospaced : .default))
                .lineLimit(SnippetActionCardReadabilityPolicy.expandedBodyLineLimit(compact: compact))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            let editAction = SnippetExpansionPresentationPolicy.expandedEditAction
            Button {
                performSnippetManagementAction(editAction.id)
            } label: {
                Label(editAction.title, systemImage: editAction.systemImage)
            }
            .help(editAction.helpText)
            .buttonStyle(.borderless)
        }
        .padding(.top, 2)
    }

    private var snippetSubtitle: String {
        let kind = snippet.kind.rawValue.capitalized
        if snippet.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return kind
        }
        return "\(kind) · \(snippet.details)"
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

    private func performSnippetManagementAction(_ actionID: SnippetActionID) {
        switch actionID {
        case .copy:
            onCopy()
            showFeedback("Copied")
        case .edit:
            onEdit()
        case .delete:
            onDelete()
        }
    }

    private func performExpansionGestureAction(_ actionID: SnippetExpansionActionID) {
        switch actionID {
        case .toggleExpanded:
            onToggleExpanded()
        }
    }
}

struct SnippetEditorDraft {
    var title: String
    var kind: SnippetKind
    var body: String
    var details: String
    var tags: [String]
    var scope: WorkbenchScope
    var workspaceId: String?
    var requiresConfirmation: Bool
    var workingDirectoryRef: String?

    func makeSnippet() -> SnippetModel {
        SnippetModel(
            workspaceId: scope == .workspace ? workspaceId : nil,
            title: title,
            kind: kind,
            body: body,
            details: details,
            tags: tags,
            scope: scope,
            workingDirectoryRef: kind == .command ? workingDirectoryRef : nil,
            requiresConfirmation: kind == .command
        )
    }
}

struct SnippetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let snippet: SnippetModel?
    let scope: WorkbenchScope
    let workspaceId: String?
    let resources: [ResourcePinModel]
    let onSave: (SnippetEditorDraft) -> Void

    @State private var title = ""
    @State private var kind: SnippetKind = .prompt
    @State private var snippetBody = ""
    @State private var details = ""
    @State private var tags = ""
    @State private var workingDirectoryRef: String?

    init(
        snippet: SnippetModel? = nil,
        initialKind: SnippetKind = .prompt,
        scope: WorkbenchScope,
        workspaceId: String?,
        resources: [ResourcePinModel],
        onSave: @escaping (SnippetEditorDraft) -> Void
    ) {
        self.snippet = snippet
        self.scope = scope
        self.workspaceId = workspaceId
        self.resources = resources
        self.onSave = onSave
        _title = State(initialValue: snippet?.title ?? "")
        _kind = State(initialValue: snippet?.kind ?? initialKind)
        _snippetBody = State(initialValue: snippet?.body ?? "")
        _details = State(initialValue: snippet?.details ?? "")
        _tags = State(initialValue: snippet?.tags.joined(separator: ", ") ?? "")
        _workingDirectoryRef = State(initialValue: snippet?.workingDirectoryRef)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(snippet == nil ? "New Snippet" : "Edit Snippet")
                .font(.title2.bold())
            TextField("Title", text: $title)
            Picker("Kind", selection: $kind) {
                ForEach(SnippetKind.allCases) { kind in
                    Text(kind.rawValue.capitalized).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            TextField("Tags", text: $tags)
            TextField("Description", text: $details, axis: .vertical)
            TextEditor(text: $snippetBody)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            if kind == .command {
                commandSafetyNotice
                workingDirectoryPicker
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let savedWorkingDirectoryRef = SnippetWorkingDirectoryOptions.validSelection(
                        workingDirectoryRef,
                        in: workingDirectoryRecords
                    )
                    let draft = SnippetEditorDraft(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Snippet" : title.trimmingCharacters(in: .whitespacesAndNewlines),
                        kind: kind,
                        body: snippetBody,
                        details: details,
                        tags: tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                        scope: scope,
                        workspaceId: workspaceId,
                        requiresConfirmation: kind == .command,
                        workingDirectoryRef: kind == .command ? savedWorkingDirectoryRef : nil
                    )
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 590)
    }

    private var commandSafetyNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.secondary)
            Text("Command snippets always require confirmation before running. This safety policy is global and cannot be disabled per snippet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workingDirectoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Working Directory", selection: workingDirectorySelection) {
                Text("Home Folder").tag("")
                ForEach(workingDirectoryOptions) { resource in
                    Text(resource.displayName).tag(resource.id)
                }
            }
            if let selectedWorkingDirectoryPath {
                Text(selectedWorkingDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            } else if workingDirectoryOptions.isEmpty {
                Text("No folder resources available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workingDirectorySelection: Binding<String> {
        Binding(
            get: {
                SnippetWorkingDirectoryOptions.validSelection(
                    workingDirectoryRef,
                    in: workingDirectoryRecords
                ) ?? ""
            },
            set: { newValue in
                workingDirectoryRef = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var selectedWorkingDirectoryPath: String? {
        guard let id = SnippetWorkingDirectoryOptions.validSelection(workingDirectoryRef, in: workingDirectoryRecords),
              let resource = resources.first(where: { $0.id == id }) else {
            return nil
        }
        return resource.displayPath
    }

    private var workingDirectoryOptions: [ResourcePinModel] {
        let resourceById = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        return SnippetWorkingDirectoryOptions.folders(in: workingDirectoryRecords)
            .compactMap { resourceById[$0.id] }
    }

    private var workingDirectoryRecords: [ResourceLibraryRecord] {
        resources.map { resource in
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
}
