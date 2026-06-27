import AppKit
import Foundation
import MindDeskCore
import SwiftData
import UniformTypeIdentifiers

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
    case missingWorkspaceIdForWorkspaceScope

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
        case .missingWorkspaceIdForWorkspaceScope:
            return "Workspace-scoped resource import requires a workspace ID."
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

enum ResourceAccessStatusResolver {
    static func failureStatus(for error: Error, fallbackPath: String, fileManager: FileManager = .default) -> ResourceStatus {
        if case WorkbenchError.reauthorizationRequired = error {
            return .staleAuthorization
        }
        if case WorkbenchError.missingPath = error {
            return .missingVolume
        }
        guard !fallbackPath.isEmpty else {
            return .unavailable
        }
        return fileManager.fileExists(atPath: fallbackPath) ? .unavailable : .missingVolume
    }
}

struct ResourceImportSummary {
    var resources: [ResourcePinModel]
    var insertedCount: Int
    var reusedCount: Int
    var skipped: [ResourceImportItemIssue] = []
    var failed: [ResourceImportItemIssue] = []
    var truncatedCount: Int = 0
    var maximumInputCount: Int = 200

    var statusText: String {
        ResourceImportBatchSummary(
            insertedCount: insertedCount,
            reusedCount: reusedCount,
            skipped: skipped,
            failed: failed,
            truncatedCount: truncatedCount,
            maximumInputCount: maximumInputCount
        ).statusText
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
        let effectiveWorkspaceId: String?
        if scope == .workspace {
            let trimmedWorkspaceId = workspaceId?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmedWorkspaceId, !trimmedWorkspaceId.isEmpty else {
                throw WorkbenchError.missingWorkspaceIdForWorkspaceScope
            }
            effectiveWorkspaceId = trimmedWorkspaceId
        } else {
            effectiveWorkspaceId = nil
        }

        let maximumInputCount = 200
        let cleanURLs = Array(urls.prefix(maximumInputCount))
        let truncatedCount = max(0, urls.count - maximumInputCount)
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
        var skipped: [ResourceImportItemIssue] = []
        var failed: [ResourceImportItemIssue] = []
        var seenImportKeys: Set<String> = []

        for url in cleanURLs {
            let path = Self.normalizedPath(url.path)
            guard !path.isEmpty else {
                skipped.append(ResourceImportItemIssue(path: url.path, reason: "Empty path"))
                continue
            }
            let importKey = ResourceImportDeduplication.importKey(
                path: path,
                scope: scope.rawValue,
                workspaceId: effectiveWorkspaceId
            )
            guard seenImportKeys.insert(importKey).inserted else {
                skipped.append(ResourceImportItemIssue(path: path, reason: "Duplicate input"))
                continue
            }

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
            let bookmarkData: Data
            do {
                bookmarkData = try bookmarkService.makeBookmark(for: url)
            } catch {
                failed.append(ResourceImportItemIssue(path: path, reason: error.localizedDescription))
                continue
            }
            let originalName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            let resource = ResourcePinModel(
                workspaceId: effectiveWorkspaceId,
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
        return ResourceImportSummary(
            resources: imported,
            insertedCount: insertedCount,
            reusedCount: reusedCount,
            skipped: skipped,
            failed: failed,
            truncatedCount: truncatedCount,
            maximumInputCount: maximumInputCount
        )
    }

    static func normalizedPath(_ path: String) -> String {
        ResourceIdentity.normalizedPath(path)
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

    func prefill(command: String, workingDirectory: String) throws {
        try runner.run(Self.prefillAppleScript(command: command, workingDirectory: workingDirectory))
    }

    func run(command: String, workingDirectory: String) throws {
        try runTerminalCommand(ShellQuoter.terminalCommand(command: command, workingDirectory: workingDirectory))
    }

    static func prefillAppleScript(command: String, workingDirectory: String) -> String {
        let prefillCommand = ShellQuoter.terminalPrefillCommand(command: command, workingDirectory: workingDirectory)
        return """
        tell application "Terminal"
            activate
            do script ""
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Terminal"
                keystroke \(ShellQuoter.appleScriptString(prefillCommand))
            end tell
        end tell
        """
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
    static let schemaVersion = 2
    static let manifestExportDefaultFilename = "MindDesk-Backup.json"
    static let manifestExportPanelMessage = "Export MindDesk metadata. Bookmark authorization data is not exported."
    static let globalLibraryOnlyExclusionText = "Global Library Only excludes workspaces, canvases, cards, links, aliases, todo groups, task groups, todos, and tasks."
    static let manifestExportOptionsHelpText = "\(globalLibraryOnlyExclusionText) Portable JSON never includes security-scoped bookmark authorization data, but it can include paths, notes, snippets, and canvas text."
    static let agentReviewPackageDefaultFilename = "MindDesk-Agent-Review.mip.json"
    static let agentReviewPackagePanelMessage = "Export a read-only MindDesk Interchange Package for Codex or other agents. It is not a backup and cannot be imported as a manifest."
    static let proposalEnvelopeOpenPanelMessage = "Open a MindDesk proposal envelope JSON from Codex or another agent."
    static let proposalSourcePackageOpenPanelMessage = "Open the original Agent Review .mip.json source package for this proposal."
    static let agentReviewPackageConfirmationMessage = "Choose what this read-only .mip.json package contains. It is for Codex or other agents, not a backup, cannot be imported as a manifest, and includes curated helpTopics for non-authoritative retrieval help; helpTopics are not authorization. payloadFieldSchemas document payload field schema/help only; they are not authorization and not an allowlist. The package does not authorize Finder, Terminal, URL, clipboard, alias, command, import/export, or apply actions. \(MindDeskAgentReviewCustomGuidancePolicy.sideEffectBoundary) \(globalLibraryOnlyExclusionText)"
    static let agentReviewPackagePrivacyDisclosure = "The package may include paths, notes, snippets and command bodies, task group titles, task text, canvas text, web URLs including query details, alias paths, search text, original or custom names, custom guidance, and usage dates when enabled. \(MindDeskAgentReviewCustomGuidancePolicy.exportPrivacyDisclosure) Payload field schemas are proposal schema/help only, not authorization or payload allowlists. validationReport redaction applies only to structured diagnostics; diagnostic fields are tokenized while raw manifest metadata records remain in the package. Raw manifest records are metadata records, not raw file contents. It never includes security-scoped bookmarks, bookmark authorization data, raw file contents, SQLite stores, backup archives, quarantine data, directory listings, or command output logs."

    func makeManifest(
        workspaces: [WorkspaceModel],
        resources: [ResourcePinModel],
        snippets: [SnippetModel],
        canvases: [CanvasModel],
        nodes: [CanvasNodeModel],
        edges: [CanvasEdgeModel],
        aliases: [FinderAliasRecordModel],
        todoGroups: [WorkspaceTodoGroupModel],
        todos: [WorkspaceTodoModel]
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
            },
            todoGroups: todoGroups.map {
                TodoGroupRecord(id: $0.id, workspaceId: $0.workspaceId, title: $0.title, isPinned: $0.isPinned, sortIndex: $0.sortIndex, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            todos: todos.map {
                TodoRecord(id: $0.id, workspaceId: $0.workspaceId, groupId: $0.groupId, title: $0.title, details: $0.details, isCompleted: $0.isCompleted, isPinned: $0.isPinned, sortIndex: $0.sortIndex, createdAt: $0.createdAt, updatedAt: $0.updatedAt, completedAt: $0.completedAt, dueAt: $0.dueAt, linkedResourceId: $0.linkedResourceId)
            }
        )
    }

    func decodeManifest(from data: Data) throws -> ExportManifest {
        let decoder = JSONDecoder.minddesk
        let classification = MindDeskJSONDocumentClassifier.classify(data)
        switch classification.kind {
        case .interchangePackage:
            throw WorkbenchError.invalidManifestReferences("MindDesk interchange packages are read-only review files and cannot be imported as manifests.")
        case .proposalEnvelope:
            throw WorkbenchError.invalidManifestReferences("MindDesk proposal envelopes must be reviewed with Review Agent Proposal and cannot be imported as manifests.")
        case .validationReport:
            throw WorkbenchError.invalidManifestReferences("MindDesk validation reports are diagnostic files and cannot be imported as manifests.")
        case .unknown where classification.hasTopLevelFormat:
            throw WorkbenchError.invalidManifestReferences("MindDesk formatted JSON files that are not manifests cannot be imported as manifests.")
        case .manifest, .unknown:
            break
        }
        let manifest: ExportManifest
        do {
            manifest = try decoder.decode(ExportManifest.self, from: data)
        } catch ExportManifestWireFormatError.unsupportedFormatVersion {
            throw WorkbenchError.invalidManifestReferences("MindDesk manifest format version is not supported.")
        } catch ExportManifestWireFormatError.unsupportedFormat {
            throw WorkbenchError.invalidManifestReferences("MindDesk formatted JSON files that are not manifests cannot be imported as manifests.")
        }
        guard manifest.schemaVersion == 1 || manifest.schemaVersion == Self.schemaVersion else {
            throw WorkbenchError.unsupportedManifestVersion(manifest.schemaVersion)
        }
        return manifest
    }

    func makeAgentReviewPackage(
        from manifest: ExportManifest,
        createdAt: Date = .now,
        customPromptGuidance: String = AppPreferenceDefaults.agentReviewCustomPromptGuidance
    ) -> MindDeskInterchangePackage {
        MindDeskInterchangePackage(
            manifest: manifest,
            createdAt: createdAt,
            agentGuide: .defaultGuide(appendingCustomPromptGuidance: customPromptGuidance)
        )
    }

    func encodeAgentReviewPackage(
        from manifest: ExportManifest,
        createdAt: Date = .now,
        customPromptGuidance: String = AppPreferenceDefaults.agentReviewCustomPromptGuidance
    ) throws -> Data {
        try JSONEncoder.minddesk.encode(
            makeAgentReviewPackage(
                from: manifest,
                createdAt: createdAt,
                customPromptGuidance: customPromptGuidance
            )
        )
    }

    func encodeAgentReviewPackage(_ package: MindDeskInterchangePackage) throws -> Data {
        try JSONEncoder.minddesk.encode(package)
    }

    func decodeProposalReviewImport(
        proposalEnvelopeData: Data,
        sourcePackageData: Data,
        gatedAt: Date = .now,
        maximumProposalEnvelopeBytes: Int = ProposalImportLimits.maximumProposalEnvelopeBytes,
        maximumSourcePackageBytes: Int = ProposalImportLimits.maximumSourcePackageBytes
    ) throws -> MindDeskProposalReviewGateResult {
        try Self.validateImportDataSize(
            proposalEnvelopeData,
            maximumBytes: maximumProposalEnvelopeBytes,
            maximumBytesDescription: ProposalImportLimits.byteLimitDescription(for: maximumProposalEnvelopeBytes),
            label: "proposal envelope data"
        )
        try Self.validateImportDataSize(
            sourcePackageData,
            maximumBytes: maximumSourcePackageBytes,
            maximumBytesDescription: ProposalImportLimits.byteLimitDescription(for: maximumSourcePackageBytes),
            label: "source package data"
        )
        do {
            return try MindDeskProposalReviewGate.evaluate(
                proposalEnvelopeData: proposalEnvelopeData,
                sourcePackageData: sourcePackageData,
                gatedAt: gatedAt
            )
        } catch MindDeskProposalReviewGateDataError.invalidProposalEnvelope {
            throw WorkbenchError.invalidManifestReferences("Proposal import requires a MindDesk proposal envelope JSON file.")
        } catch MindDeskProposalReviewGateDataError.invalidSourcePackage {
            throw WorkbenchError.invalidManifestReferences("Proposal import requires the original Agent Review .mip.json source package.")
        } catch let error as DecodingError {
            throw Self.proposalReviewDecodeError(error, proposalEnvelopeData: proposalEnvelopeData)
        }
    }

    private static func proposalReviewDecodeError(
        _ error: DecodingError,
        proposalEnvelopeData: Data
    ) -> WorkbenchError {
        let path = proposalReviewDecodingPath(from: error).map(\.stringValue)
        let proposalEnvelopeField = path.first == "proposals" ||
            path.first == "context" ||
            path.first == "proposedBy" ||
            path.contains("operations")
        if proposalEnvelopeField || MindDeskJSONDocumentKind.classify(proposalEnvelopeData) != .proposalEnvelope {
            return WorkbenchError.invalidManifestReferences("Proposal import requires a MindDesk proposal envelope JSON file.")
        }
        return WorkbenchError.invalidManifestReferences("Proposal import requires the original Agent Review .mip.json source package.")
    }

    private static func proposalReviewDecodingPath(from error: DecodingError) -> [CodingKey] {
        switch error {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            return context.codingPath
        @unknown default:
            return []
        }
    }

    func decodeProposalEnvelope(from data: Data) throws -> MindDeskProposalEnvelope {
        let decoder = JSONDecoder.minddesk
        guard MindDeskJSONDocumentKind.classify(data) == .proposalEnvelope else {
            throw WorkbenchError.invalidManifestReferences("Proposal import requires a MindDesk proposal envelope JSON file.")
        }
        do {
            return try decoder.decode(MindDeskProposalEnvelope.self, from: data)
        } catch let error as MindDeskProposalEnvelopeDecodeLimitError {
            throw error
        } catch {
            throw WorkbenchError.invalidManifestReferences("Proposal import requires a MindDesk proposal envelope JSON file.")
        }
    }

    func decodeProposalSourcePackage(from data: Data) throws -> MindDeskInterchangePackage {
        let decoder = JSONDecoder.minddesk
        guard MindDeskJSONDocumentKind.classify(data) == .interchangePackage,
              let package = try? decoder.decode(MindDeskInterchangePackage.self, from: data) else {
            throw WorkbenchError.invalidManifestReferences("Proposal import requires the original Agent Review .mip.json source package.")
        }
        return package
    }

    static func readJSONImportData(
        from url: URL,
        blockedPrefix: String,
        maximumBytes: Int,
        maximumBytesDescription: String
    ) throws -> Data {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        } catch {
            throw Self.importReadFailure(blockedPrefix: blockedPrefix)
        }
        guard values.isRegularFile == true else {
            throw WorkbenchError.invalidManifestReferences("\(blockedPrefix): choose a regular JSON file.")
        }
        guard let fileSize = values.fileSize else {
            throw WorkbenchError.invalidManifestReferences("\(blockedPrefix): file size could not be read.")
        }
        guard fileSize <= maximumBytes else {
            throw WorkbenchError.invalidManifestReferences(
                "\(blockedPrefix): file is larger than \(maximumBytesDescription)."
            )
        }

        let file: FileHandle
        do {
            file = try FileHandle(forReadingFrom: url)
        } catch {
            throw Self.importReadFailure(blockedPrefix: blockedPrefix)
        }
        defer {
            try? file.close()
        }
        let data: Data
        do {
            data = try file.read(upToCount: maximumBytes + 1) ?? Data()
        } catch {
            throw Self.importReadFailure(blockedPrefix: blockedPrefix)
        }
        guard data.count <= maximumBytes else {
            throw WorkbenchError.invalidManifestReferences(
                "\(blockedPrefix): file is larger than \(maximumBytesDescription)."
            )
        }
        return data
    }

    private static func importReadFailure(blockedPrefix: String) -> WorkbenchError {
        WorkbenchError.invalidManifestReferences("\(blockedPrefix): file could not be read.")
    }

    private static func validateImportDataSize(
        _ data: Data,
        maximumBytes: Int,
        maximumBytesDescription: String,
        label: String
    ) throws {
        guard data.count <= maximumBytes else {
            throw WorkbenchError.invalidManifestReferences(
                "Proposal import blocked: \(label) is larger than \(maximumBytesDescription)."
            )
        }
    }

    static func manifestImportBlockedStatus(
        for manifest: ExportManifest,
        maximumIssueDetails: Int = 5
    ) -> String? {
        let issues = MindDeskManifestValidationReport
            .issues(in: manifest)
            .filter { $0.source == .manifest && $0.severity == .error }
        guard !issues.isEmpty else { return nil }

        let issueCount = "\(issues.count) validation issue\(issues.count == 1 ? "" : "s")"
        let details = issues
            .prefix(maximumIssueDetails)
            .map(Self.validationDiagnosticSummary)
            .joined(separator: " ")
        let remaining = issues.count - min(issues.count, maximumIssueDetails)
        let suffix = remaining > 0 ? " \(remaining) more issue\(remaining == 1 ? "" : "s")." : ""
        return "Manifest import blocked: \(issueCount). \(details)\(suffix)"
    }

    static func proposalReviewImportBlockedStatus(
        for report: MindDeskValidationReport,
        maximumIssueDetails: Int = 5
    ) -> String? {
        let issues = report.issues.filter { $0.severity == .error }
        guard !issues.isEmpty else { return nil }

        let issueCount = "\(issues.count) validation issue\(issues.count == 1 ? "" : "s")"
        let details = issues
            .prefix(maximumIssueDetails)
            .map(Self.validationDiagnosticSummary)
            .joined(separator: " ")
        let remaining = issues.count - min(issues.count, maximumIssueDetails)
        let suffix = remaining > 0 ? " \(remaining) more issue\(remaining == 1 ? "" : "s")." : ""
        return "Proposal import blocked: \(issueCount). \(details)\(suffix)"
    }

    static func proposalReviewImportReadyStatus(
        for session: MindDeskProposalReviewSession
    ) -> String {
        let proposalCount = session.envelope.proposals.count
        let operationCount = session.envelope.proposals.reduce(0) { $0 + $1.operations.count }
        let summary = MindDeskValidationReportSummary(issues: session.validationReport.issues)
        let validity = summary.isValid ? "valid" : "invalid"
        let issues = "\(summary.issueCount) issue\(summary.issueCount == 1 ? "" : "s")"
        let errors = "\(summary.errorCount) error\(summary.errorCount == 1 ? "" : "s")"
        let warnings = "\(summary.warningCount) warning\(summary.warningCount == 1 ? "" : "s")"
        return "Proposal review ready: \(proposalCount) proposal\(proposalCount == 1 ? "" : "s"), \(operationCount) operation\(operationCount == 1 ? "" : "s"). State: pending review. Validation: \(validity), \(issues), \(errors), \(warnings)."
    }

    private static func validationDiagnosticSummary(
        for issue: MindDeskValidationReportIssue
    ) -> String {
        let message = ProposalReviewSafeDisplayText.safeDiagnosticMessage(issue.message)
        let location = ProposalReviewSafeDisplayText.safeIssueLocation(
            path: issue.path,
            field: issue.field,
            ownerKind: issue.ownerKind,
            source: issue.source
        )
        return "\(message) (\(issue.code)) at \(location)."
    }

    static func agentReviewPackageExportStatus(
        path: String,
        report: MindDeskValidationReport
    ) -> String {
        let summary = MindDeskValidationReportSummary(issues: report.issues)
        let validity = summary.isValid ? "valid" : "invalid"
        let issues = "\(summary.issueCount) issue\(summary.issueCount == 1 ? "" : "s")"
        let errors = "\(summary.errorCount) error\(summary.errorCount == 1 ? "" : "s")"
        let warnings = "\(summary.warningCount) warning\(summary.warningCount == 1 ? "" : "s")"
        return "Exported Agent Review package. Validation: \(validity), \(issues), \(errors), \(warnings)."
    }

}

struct ProposalReviewOpenStep: Equatable {
    enum Kind: Equatable {
        case proposalEnvelope
        case sourcePackage
    }

    let kind: Kind
    let message: String
    let allowedContentTypes: [UTType]
    let canChooseFiles: Bool
    let canChooseDirectories: Bool
    let allowsMultipleSelection: Bool
}

struct FileDialogs {
    static let proposalEnvelopeOpenStep = ProposalReviewOpenStep(
        kind: .proposalEnvelope,
        message: ImportExportService.proposalEnvelopeOpenPanelMessage,
        allowedContentTypes: [.json],
        canChooseFiles: true,
        canChooseDirectories: false,
        allowsMultipleSelection: false
    )
    static let proposalSourcePackageOpenStep = ProposalReviewOpenStep(
        kind: .sourcePackage,
        message: ImportExportService.proposalSourcePackageOpenPanelMessage,
        allowedContentTypes: [.json],
        canChooseFiles: true,
        canChooseDirectories: false,
        allowsMultipleSelection: false
    )
    static let proposalReviewOpenSteps = [
        proposalEnvelopeOpenStep,
        proposalSourcePackageOpenStep
    ]

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
        panel.nameFieldStringValue = ImportExportService.manifestExportDefaultFilename
        panel.message = ImportExportService.manifestExportPanelMessage
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func saveAgentReviewPackage() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = ImportExportService.agentReviewPackageDefaultFilename
        panel.message = ImportExportService.agentReviewPackagePanelMessage
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

    @MainActor
    static func openProposalEnvelope() -> URL? {
        openProposalReviewFile(for: proposalEnvelopeOpenStep)
    }

    @MainActor
    static func openProposalSourcePackage() -> URL? {
        openProposalReviewFile(for: proposalSourcePackageOpenStep)
    }

    @MainActor
    private static func openProposalReviewFile(for step: ProposalReviewOpenStep) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = step.allowedContentTypes
        panel.canChooseFiles = step.canChooseFiles
        panel.canChooseDirectories = step.canChooseDirectories
        panel.allowsMultipleSelection = step.allowsMultipleSelection
        panel.message = step.message
        return panel.runModal() == .OK ? panel.url : nil
    }
}
