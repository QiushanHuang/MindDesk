import AppKit
import Foundation
import MindDeskCore
import SwiftData

enum WorkbenchError: LocalizedError {
    case missingPath(String)
    case destinationExists(String)
    case notWritable(String)
    case appleScript(String)
    case cancelled
    case unsupportedManifestVersion(Int)
    case reauthorizationRequired(String)
    case resourceTypeMismatch(expected: String, selected: String)
    case invalidManifestReferences(String)
    case invalidWorkingDirectory(String)

    var errorDescription: String? {
        switch self {
        case .missingPath(let path):
            return "Path is unavailable: \(path)"
        case .destinationExists(let path):
            return "Destination already exists: \(path)"
        case .notWritable(let path):
            return "Destination is not writable: \(path)"
        case .appleScript(let message):
            return message
        case .cancelled:
            return "Operation cancelled."
        case .unsupportedManifestVersion(let version):
            return "Unsupported manifest version: \(version)"
        case .reauthorizationRequired(let path):
            return "Reauthorize this resource before accessing the file system: \(path)"
        case .resourceTypeMismatch(let expected, let selected):
            return "Selected \(selected) does not match this resource's \(expected) type."
        case .invalidManifestReferences(let message):
            return message
        case .invalidWorkingDirectory(let message):
            return message
        }
    }
}

struct ClipboardService {
    func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}

struct FinderService {
    func open(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WorkbenchError.missingPath(url.path)
        }
        NSWorkspace.shared.open(url)
    }

    func reveal(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WorkbenchError.missingPath(url.path)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct FolderPreviewItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let url: URL
    let isDirectory: Bool
    let size: Int64?
}

struct FolderPreviewService {
    private let bookmarkService = BookmarkService()

    func contents(of resource: ResourcePinModel, limit: Int = 200) throws -> [FolderPreviewItem] {
        try contents(
            bookmarkData: resource.securityScopedBookmarkData,
            fallbackPath: resource.lastResolvedPath,
            statusRaw: resource.statusRaw,
            limit: limit
        )
    }

    func contents(bookmarkData: Data?, fallbackPath: String, statusRaw: String, limit: Int = 200) throws -> [FolderPreviewItem] {
        let resolved = try bookmarkService.resolveAuthorizedBookmark(bookmarkData, fallbackPath: fallbackPath, statusRaw: statusRaw)
        let folderURL = resolved.url
        let boundedLimit = max(0, limit)
        let scanLimit = FolderPreviewScanPolicy.scanLimit(requestedLimit: boundedLimit)
        guard boundedLimit > 0 else { return [] }

        return try bookmarkService.access(folderURL) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw WorkbenchError.missingPath(folderURL.path)
            }
            guard let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                throw WorkbenchError.missingPath(folderURL.path)
            }
            var items: [FolderPreviewItem] = []
            while let url = enumerator.nextObject() as? URL {
                enumerator.skipDescendants()
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                let isDirectory = values?.isDirectory ?? false
                items.append(FolderPreviewItem(
                    id: url.path,
                    name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                    path: url.path,
                    url: url,
                    isDirectory: isDirectory,
                    size: values?.fileSize.map(Int64.init)
                ))
                if items.count >= scanLimit {
                    break
                }
            }
            let records = items.map { FolderPreviewItemRecord(id: $0.id, name: $0.name, isDirectory: $0.isDirectory) }
            let itemById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            return FolderPreviewOrdering.ordered(records)
                .prefix(boundedLimit)
                .compactMap { itemById[$0.id] }
        }
    }
}

struct BookmarkService {
    func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveBookmark(_ data: Data?, fallbackPath: String) -> (url: URL, stale: Bool) {
        guard let data else {
            return (URL(fileURLWithPath: fallbackPath), false)
        }

        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return (url, stale)
        } catch {
            return (URL(fileURLWithPath: fallbackPath), true)
        }
    }

    func resolveAuthorizedBookmark(_ data: Data?, fallbackPath: String, statusRaw: String) throws -> (url: URL, stale: Bool) {
        guard ResourceAuthorizationPolicy.canAccessFileSystem(status: statusRaw, hasBookmarkData: data != nil) else {
            throw WorkbenchError.reauthorizationRequired(fallbackPath)
        }
        let resolved = resolveBookmark(data, fallbackPath: fallbackPath)
        guard !resolved.stale else {
            throw WorkbenchError.reauthorizationRequired(resolved.url.path)
        }
        return resolved
    }

    func access<T>(_ url: URL, perform: () throws -> T) rethrows -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try perform()
    }
}

struct ResourceImportSummary {
    var resources: [ResourcePinModel]
    var insertedCount: Int
    var reusedCount: Int

    var statusText: String {
        let imported = insertedCount + reusedCount
        if imported == 0 {
            return "No files or folders imported."
        }
        if reusedCount > 0 {
            return "Imported \(insertedCount), reused \(reusedCount)."
        }
        return "Imported \(insertedCount) item\(insertedCount == 1 ? "" : "s")."
    }
}

struct ResourceImportService {
    private let bookmarkService = BookmarkService()

    func importURLs(
        _ urls: [URL],
        existingResources: [ResourcePinModel],
        into context: ModelContext,
        scope: WorkbenchScope = .global,
        workspaceId: String? = nil,
        pinImported: Bool,
        saveChanges: Bool = true
    ) throws -> ResourceImportSummary {
        let cleanURLs = Array(urls.prefix(200))
        var resourcesByImportKey: [String: ResourcePinModel] = [:]
        for resource in existingResources {
            resourcesByImportKey[ResourceImportDeduplication.importKey(
                path: resource.lastResolvedPath,
                scope: resource.scopeRaw,
                workspaceId: resource.workspaceId
            )] = resource
        }
        var imported: [ResourcePinModel] = []
        var insertedCount = 0
        var reusedCount = 0

        for url in cleanURLs {
            let path = Self.normalizedPath(url.path)
            guard !path.isEmpty else { continue }
            let importKey = ResourceImportDeduplication.importKey(
                path: path,
                scope: scope.rawValue,
                workspaceId: scope == .workspace ? workspaceId : nil
            )

            if let existing = resourcesByImportKey[importKey] {
                if pinImported, !existing.isPinned {
                    existing.isPinned = true
                    existing.updatedAt = .now
                }
                existing.refreshSearchText()
                imported.append(existing)
                reusedCount += 1
                continue
            }

            let type = Self.targetType(for: url)
            let bookmarkData = try bookmarkService.makeBookmark(for: url)
            let originalName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let resource = ResourcePinModel(
                workspaceId: scope == .workspace ? workspaceId : nil,
                title: originalName,
                targetType: type,
                displayPath: url.path,
                lastResolvedPath: url.path,
                securityScopedBookmarkData: bookmarkData,
                scope: scope,
                isPinned: pinImported,
                originalName: originalName,
                customName: ""
            )
            resource.refreshSearchText()
            resourcesByImportKey[importKey] = resource
            context.insert(resource)
            imported.append(resource)
            insertedCount += 1
        }

        if saveChanges {
            try context.save()
        }
        return ResourceImportSummary(resources: imported, insertedCount: insertedCount, reusedCount: reusedCount)
    }

    static func normalizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func targetType(for url: URL) -> ResourceTargetType {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? .folder : .file
        }
        return url.hasDirectoryPath ? .folder : .file
    }
}

struct AppleScriptRunner {
    func run(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw WorkbenchError.appleScript("Could not compile AppleScript.")
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "AppleScript failed."
            throw WorkbenchError.appleScript(message)
        }
    }
}

struct TerminalService {
    private let runner = AppleScriptRunner()

    func open(at path: String) throws {
        let command = ShellQuoter.changeDirectoryCommand(workingDirectory: path)
        try runTerminalCommand(command)
    }

    func run(command: String, workingDirectory: String) throws {
        try runTerminalCommand(ShellQuoter.terminalCommand(command: command, workingDirectory: workingDirectory))
    }

    private func runTerminalCommand(_ command: String) throws {
        let script = """
        tell application "Terminal"
            activate
            do script \(ShellQuoter.appleScriptString(command))
        end tell
        """
        try runner.run(script)
    }
}

struct AliasService {
    private let runner = AppleScriptRunner()

    func createAlias(source: URL, destinationDirectory: URL, name: String) throws -> URL {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw WorkbenchError.missingPath(source.path)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WorkbenchError.missingPath(destinationDirectory.path)
        }

        guard FileManager.default.isWritableFile(atPath: destinationDirectory.path) else {
            throw WorkbenchError.notWritable(destinationDirectory.path)
        }

        let aliasURL = destinationDirectory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: aliasURL.path) else {
            throw WorkbenchError.destinationExists(aliasURL.path)
        }

        let script = """
        set sourceItem to POSIX file \(ShellQuoter.appleScriptString(source.path)) as alias
        set destinationFolder to POSIX file \(ShellQuoter.appleScriptString(destinationDirectory.path)) as alias
        tell application "Finder"
            make new alias file at destinationFolder to sourceItem with properties {name:\(ShellQuoter.appleScriptString(name))}
        end tell
        """
        try runner.run(script)
        return aliasURL
    }
}

struct ImportExportService {
    static let schemaVersion = 1

    func makeManifest(
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel],
        aliases: [FinderAliasRecordModel]
    ) -> ExportManifest {
        ExportManifest(
            schemaVersion: Self.schemaVersion,
            exportedAt: .now,
            workspaces: workspaces.map {
                WorkspaceRecord(id: $0.id, title: $0.title, details: $0.details, createdAt: $0.createdAt, updatedAt: $0.updatedAt, lastOpenedAt: $0.lastOpenedAt, isPinned: $0.isPinned, sortIndex: $0.sortIndex)
            },
            resources: resources.map {
                ResourceRecord(id: $0.id, workspaceId: $0.workspaceId, title: $0.title, targetType: $0.targetTypeRaw, displayPath: $0.displayPath, lastResolvedPath: $0.lastResolvedPath, note: $0.note, tags: $0.tags, scope: $0.scopeRaw, sortIndex: $0.sortIndex, isPinned: $0.isPinned, originalName: $0.originalName, customName: $0.customName, searchText: $0.searchText, status: $0.statusRaw, createdAt: $0.createdAt, updatedAt: $0.updatedAt, lastOpenedAt: $0.lastOpenedAt)
            },
            snippets: snippets.map {
                SnippetRecord(id: $0.id, workspaceId: $0.workspaceId, title: $0.title, kind: $0.kindRaw, body: $0.body, details: $0.details, tags: $0.tags, scope: $0.scopeRaw, workingDirectoryRef: $0.workingDirectoryRef, requiresConfirmation: $0.requiresConfirmation, lastCopiedAt: $0.lastCopiedAt, lastUsedAt: $0.lastUsedAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            canvases: canvases.map {
                CanvasRecord(id: $0.id, workspaceId: $0.workspaceId, title: $0.title, viewportX: $0.viewportX, viewportY: $0.viewportY, zoom: $0.zoom, linkAnimationTheme: $0.linkAnimationThemeRaw, animationsEnabled: $0.animationsEnabled, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            nodes: nodes.map {
                CanvasNodeRecord(id: $0.id, canvasId: $0.canvasId, title: $0.title, body: $0.body, nodeType: $0.nodeTypeRaw, objectType: $0.objectType, objectId: $0.objectId, x: $0.x, y: $0.y, width: $0.width, height: $0.height, collapsed: $0.collapsed, parentNodeId: $0.parentNodeId, zIndex: $0.zIndex, locked: $0.locked, style: $0.styleRaw, accentColor: $0.accentColorRaw, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            edges: edges.map {
                CanvasEdgeRecord(id: $0.id, canvasId: $0.canvasId, sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId, label: $0.label, style: $0.style, sourceArrow: $0.sourceArrowRaw, targetArrow: $0.targetArrowRaw, animated: $0.animated, animationTheme: $0.animationThemeRaw, controlPointX: $0.controlPointX, controlPointY: $0.controlPointY, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            aliases: aliases.map {
                AliasRecord(id: $0.id, sourceObjectType: $0.sourceObjectType, sourceObjectId: $0.sourceObjectId, aliasDisplayPath: $0.aliasDisplayPath, status: $0.statusRaw, createdAt: $0.createdAt)
            }
        )
    }

    func decodeManifest(from data: Data) throws -> ExportManifest {
        let manifest = try JSONDecoder.minddesk.decode(ExportManifest.self, from: data)
        guard manifest.schemaVersion == Self.schemaVersion else {
            throw WorkbenchError.unsupportedManifestVersion(manifest.schemaVersion)
        }
        return manifest
    }
}

struct FileDialogs {
    @MainActor
    static func chooseResource() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file or folder to pin in MindDesk."
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func chooseDirectory(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func chooseFile(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func saveAlias(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName
        panel.message = "Choose the Finder alias name and destination."
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func saveJSON() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MindDesk-Backup.json"
        panel.message = "Export MindDesk metadata. Bookmark authorization data is not exported."
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func openJSON() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Import a MindDesk JSON manifest."
        return panel.runModal() == .OK ? panel.url : nil
    }
}
