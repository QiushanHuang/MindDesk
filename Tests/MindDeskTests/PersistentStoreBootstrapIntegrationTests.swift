import Foundation
import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class PersistentStoreBootstrapIntegrationTests: XCTestCase {
    func testMakeModelContainerUsesExplicitApplicationSupportOverrideForUISmokeIsolation() throws {
        let fallbackSupportDirectory = try makeTemporarySupportDirectory()
        let overrideSupportDirectory = try makeTemporarySupportDirectory()
        let fallbackLayout = MindDeskStoreLayout(applicationSupportDirectory: fallbackSupportDirectory)
        let overrideLayout = MindDeskStoreLayout(applicationSupportDirectory: overrideSupportDirectory)
        try writeWorkspaceStore(at: fallbackLayout.storeURL, title: "Fallback Workspace")
        try writeWorkspaceStore(at: overrideLayout.storeURL, title: "UI Smoke Workspace")

        try withEnvironmentValue(
            key: "MINDDESK_APPLICATION_SUPPORT_DIR",
            value: overrideSupportDirectory.path
        ) {
            let container = try PersistentStoreBootstrap.makeModelContainer(
                fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: fallbackSupportDirectory)
            )

            XCTAssertEqual(try workspaceTitles(in: container), ["UI Smoke Workspace"])
        }
    }

    func testMakeModelContainerOpensExistingStoreAndPreservesWorkbenchObjects() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        try writeFullWorkbenchStore(at: layout.storeURL)

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )
        let context = ModelContext(container)

        let workspaces = try context.fetch(FetchDescriptor<WorkspaceModel>())
        let resources = try context.fetch(FetchDescriptor<ResourcePinModel>())
        let snippets = try context.fetch(FetchDescriptor<SnippetModel>())
        let canvases = try context.fetch(FetchDescriptor<CanvasModel>())
        let nodes = try context.fetch(FetchDescriptor<CanvasNodeModel>())

        XCTAssertEqual(workspaces.map(\.title), ["Existing Workspace"])
        XCTAssertEqual(resources.map(\.title), ["Existing Folder"])
        XCTAssertEqual(snippets.map(\.title), ["Existing Prompt"])
        XCTAssertEqual(canvases.map(\.title), ["Existing Canvas"])
        XCTAssertEqual(nodes.map(\.title), ["Existing Snippet Card"])
        XCTAssertEqual(resources.first?.workspaceId, workspaces.first?.id)
        XCTAssertEqual(snippets.first?.workspaceId, workspaces.first?.id)
        XCTAssertEqual(canvases.first?.workspaceId, workspaces.first?.id)
        XCTAssertEqual(nodes.first?.canvasId, canvases.first?.id)
        XCTAssertEqual(nodes.first?.objectType, "snippet")
        XCTAssertEqual(nodes.first?.objectId, snippets.first?.id)
    }

    func testMakeModelContainerMigratesLegacyStoreAndCreatesCompleteMigrationBackup() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        try writeWorkspaceStore(at: layout.legacyStoreURL, title: "Legacy Workspace")

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(try workspaceTitles(in: container), ["Legacy Workspace"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.storeURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.legacyStoreURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: layout.storeDirectory.appendingPathComponent(".migration-in-progress").path
            )
        )

        let migrationBackups = try backupFolders(in: layout)
            .filter { $0.lastPathComponent.hasSuffix("-migration") }
        XCTAssertEqual(migrationBackups.count, 1)
        let migrationBackup = try XCTUnwrap(migrationBackups.first)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: migrationBackup.appendingPathComponent(".complete").path
            )
        )
        XCTAssertEqual(
            try workspaceTitles(at: migrationBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName)),
            ["Legacy Workspace"]
        )
    }

    func testMakeModelContainerRetriesLegacyMigrationAfterInterruptedMigrationMarker() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        let partialPrimaryStoreSentinel = Data("partial-primary-store".utf8)
        try writeWorkspaceStore(at: layout.legacyStoreURL, title: "Retried Legacy Workspace")
        try writeCorruptStore(at: layout.storeURL, data: partialPrimaryStoreSentinel)
        try "in-progress".write(
            to: layout.storeDirectory.appendingPathComponent(".migration-in-progress", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(try workspaceTitles(in: container), ["Retried Legacy Workspace"])
        XCTAssertNotEqual(try Data(contentsOf: layout.storeURL), partialPrimaryStoreSentinel)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: layout.storeDirectory.appendingPathComponent(".migration-in-progress").path
            )
        )
        XCTAssertTrue(
            try backupFolders(in: layout).contains { $0.lastPathComponent.hasSuffix("-migration") }
        )
    }

    func testMakeModelContainerPreservesReadablePrimaryStoreWhenMigrationMarkerCleanupFailed() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        let migrationMarker = layout.storeDirectory.appendingPathComponent(".migration-in-progress", isDirectory: false)
        try writeWorkspaceStore(at: layout.legacyStoreURL, title: "Legacy Workspace")

        do {
            let migratedContainer = try PersistentStoreBootstrap.makeModelContainer(
                fileManager: TestApplicationSupportFileManager(
                    applicationSupportDirectory: supportDirectory,
                    failRemovingURLOnce: migrationMarker
                )
            )
            try insertWorkspace(title: "Post Migration Workspace", into: migratedContainer)

            XCTAssertEqual(
                try workspaceTitles(in: migratedContainer),
                ["Legacy Workspace", "Post Migration Workspace"]
            )
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: migrationMarker.path))

        let reopenedContainer = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(
            try workspaceTitles(in: reopenedContainer),
            ["Legacy Workspace", "Post Migration Workspace"]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: migrationMarker.path))
    }

    func testMakeModelContainerRestoresNewestValidBackupWhenPrimaryStoreIsMissing() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        try FileManager.default.createDirectory(at: layout.backupDirectory, withIntermediateDirectories: true)

        let validBackup = layout.backupDirectory.appendingPathComponent("20260101-010000-startup", isDirectory: true)
        try writeWorkspaceStore(
            at: validBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName),
            title: "Recovered Workspace"
        )
        try markBackupComplete(validBackup)

        let olderValidBackup = layout.backupDirectory.appendingPathComponent("20251231-010000-startup", isDirectory: true)
        try writeWorkspaceStore(
            at: olderValidBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName),
            title: "Older Workspace"
        )
        try markBackupComplete(olderValidBackup)

        let newerCorruptBackup = layout.backupDirectory.appendingPathComponent("20260102-010000-startup", isDirectory: true)
        try writeCorruptStore(at: newerCorruptBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName))
        try markBackupComplete(newerCorruptBackup)

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(try workspaceTitles(in: container), ["Recovered Workspace"])
        XCTAssertEqual(try workspaceTitles(at: layout.storeURL), ["Recovered Workspace"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.storeURL.path))
        XCTAssertTrue(try restoreStagingFolders(in: layout).isEmpty)
        XCTAssertTrue(try directoryChildren(in: layout.quarantineDirectory).isEmpty)
    }

    func testMakeModelContainerCreatesRestoreBackupBeforePruningRecoveredStore() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        try FileManager.default.createDirectory(at: layout.backupDirectory, withIntermediateDirectories: true)

        let validBackup = layout.backupDirectory.appendingPathComponent("19991231-010000-startup", isDirectory: true)
        try writeWorkspaceStore(
            at: validBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName),
            title: "Only Recoverable Workspace"
        )
        try markBackupComplete(validBackup)

        for day in 1...21 {
            let newerUnrecoverableBackup = layout.backupDirectory.appendingPathComponent(
                String(format: "200001%02d-010000-startup", day),
                isDirectory: true
            )
            try markBackupComplete(newerUnrecoverableBackup)
        }

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(try workspaceTitles(in: container), ["Only Recoverable Workspace"])
        let restoreBackups = try backupFolders(in: layout)
            .filter { $0.lastPathComponent.hasSuffix("-restore") }
        XCTAssertEqual(restoreBackups.count, 1)
        let restoreBackup = try XCTUnwrap(restoreBackups.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreBackup.appendingPathComponent(".complete").path))
        XCTAssertEqual(
            try workspaceTitles(at: restoreBackup.appendingPathComponent(MindDeskStoreLayout.storeFileName)),
            ["Only Recoverable Workspace"]
        )
    }

    func testStartupBackupDoesNotPublishVisibleFolderWhenCopyFailsInsideIncompleteFolder() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        try writeWorkspaceStore(at: layout.storeURL, title: "Primary Workspace")

        XCTAssertThrowsError(
            try PersistentStoreBootstrap.backupSQLiteFileSetIfPresent(
                layout: layout,
                reason: .startup,
                fileManager: TestApplicationSupportFileManager(
                    applicationSupportDirectory: supportDirectory,
                    failCopyingToPathContaining: ".incomplete-"
                )
            )
        )

        let backupFolderNames = try backupFolders(in: layout).map(\.lastPathComponent)
        XCTAssertFalse(backupFolderNames.contains { $0.hasSuffix("-startup") && !$0.hasPrefix(".") })
        XCTAssertFalse(backupFolderNames.contains { MindDeskStoreLayout.isIncompleteBackupFolderName($0) })
    }

    func testMakeModelContainerQuarantinesCorruptPrimaryStoreFileSetBeforeRestoringBackup() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        let corruptStoreSentinels: [String: Data] = [
            MindDeskStoreLayout.storeFileName: Data("corrupt-main-sentinel".utf8),
            "\(MindDeskStoreLayout.storeFileName)-wal": Data("corrupt-wal-sentinel".utf8),
            "\(MindDeskStoreLayout.storeFileName)-shm": Data("corrupt-shm-sentinel".utf8)
        ]
        try writeCorruptStore(
            at: layout.storeURL,
            data: try XCTUnwrap(corruptStoreSentinels[MindDeskStoreLayout.storeFileName])
        )
        for (fileName, data) in corruptStoreSentinels where fileName != MindDeskStoreLayout.storeFileName {
            try data.write(to: layout.storeDirectory.appendingPathComponent(fileName, isDirectory: false))
        }

        let backup = layout.backupDirectory.appendingPathComponent("20260101-010000-startup", isDirectory: true)
        try writeWorkspaceStore(
            at: backup.appendingPathComponent(MindDeskStoreLayout.storeFileName),
            title: "Restored Workspace"
        )
        try markBackupComplete(backup)

        let container = try PersistentStoreBootstrap.makeModelContainer(
            fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
        )

        XCTAssertEqual(try workspaceTitles(in: container), ["Restored Workspace"])
        XCTAssertTrue(try restoreStagingFolders(in: layout).isEmpty)

        let quarantineFolders = try directoryChildren(in: layout.quarantineDirectory)
            .filter { $0.lastPathComponent.hasSuffix("-failed-open") }
        XCTAssertEqual(quarantineFolders.count, 1)
        let quarantineFolder = try XCTUnwrap(quarantineFolders.first)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: quarantineFolder.appendingPathComponent(MindDeskStoreLayout.storeFileName).path
            )
        )
        XCTAssertEqual(
            try Data(contentsOf: quarantineFolder.appendingPathComponent(MindDeskStoreLayout.storeFileName)),
            corruptStoreSentinels[MindDeskStoreLayout.storeFileName]
        )
        for (fileName, sentinel) in corruptStoreSentinels {
            let quarantinedURL = quarantineFolder.appendingPathComponent(fileName, isDirectory: false)
            XCTAssertTrue(FileManager.default.fileExists(atPath: quarantinedURL.path))
            XCTAssertEqual(try Data(contentsOf: quarantinedURL), sentinel)
            XCTAssertNotEqual(
                try? Data(contentsOf: layout.storeDirectory.appendingPathComponent(fileName, isDirectory: false)),
                sentinel
            )
        }
    }

    func testRecoveredStorePublishFailureRollsBackQuarantinedPrimaryFileSet() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        let corruptStoreSentinels: [String: Data] = [
            MindDeskStoreLayout.storeFileName: Data("rollback-main-sentinel".utf8),
            "\(MindDeskStoreLayout.storeFileName)-wal": Data("rollback-wal-sentinel".utf8),
            "\(MindDeskStoreLayout.storeFileName)-shm": Data("rollback-shm-sentinel".utf8)
        ]
        try writeCorruptStore(
            at: layout.storeURL,
            data: try XCTUnwrap(corruptStoreSentinels[MindDeskStoreLayout.storeFileName])
        )
        for (fileName, data) in corruptStoreSentinels where fileName != MindDeskStoreLayout.storeFileName {
            try data.write(to: layout.storeDirectory.appendingPathComponent(fileName, isDirectory: false))
        }
        let backup = layout.backupDirectory.appendingPathComponent("20260101-010000-startup", isDirectory: true)
        try writeWorkspaceStore(
            at: backup.appendingPathComponent(MindDeskStoreLayout.storeFileName),
            title: "Recovered Workspace"
        )
        try markBackupComplete(backup)

        XCTAssertThrowsError(
            try PersistentStoreBootstrap.makeModelContainer(
                fileManager: TestApplicationSupportFileManager(
                    applicationSupportDirectory: supportDirectory,
                    failMovingToURLOnce: layout.storeURL
                )
            )
        )

        for (fileName, sentinel) in corruptStoreSentinels {
            let originalURL = layout.storeDirectory.appendingPathComponent(fileName, isDirectory: false)
            XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
            XCTAssertEqual(try Data(contentsOf: originalURL), sentinel)
        }

        let quarantineFolders = try directoryChildren(in: layout.quarantineDirectory)
            .filter { $0.lastPathComponent.hasSuffix("-failed-open") }
        for quarantineFolder in quarantineFolders {
            for fileName in corruptStoreSentinels.keys {
                XCTAssertFalse(
                    FileManager.default.fileExists(
                        atPath: quarantineFolder.appendingPathComponent(fileName, isDirectory: false).path
                    )
                )
            }
        }
    }

    func testMakeModelContainerLeavesCorruptPrimaryInPlaceWhenNoBackupCanRecover() throws {
        let supportDirectory = try makeTemporarySupportDirectory()
        let layout = MindDeskStoreLayout(applicationSupportDirectory: supportDirectory)
        let corruptPrimaryStoreSentinel = Data("unrecoverable-primary-store".utf8)
        try writeCorruptStore(at: layout.storeURL, data: corruptPrimaryStoreSentinel)

        XCTAssertThrowsError(
            try PersistentStoreBootstrap.makeModelContainer(
                fileManager: TestApplicationSupportFileManager(applicationSupportDirectory: supportDirectory)
            )
        )

        XCTAssertEqual(try Data(contentsOf: layout.storeURL), corruptPrimaryStoreSentinel)
        XCTAssertTrue(try directoryChildren(in: layout.quarantineDirectory).isEmpty)
        XCTAssertTrue(try restoreStagingFolders(in: layout).isEmpty)
    }

    private func makeTemporarySupportDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-store-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func withEnvironmentValue<T>(key: String, value: String, body: () throws -> T) rethrows -> T {
        let previous = getenv(key).map { String(cString: $0) }
        setenv(key, value, 1)
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        return try body()
    }

    private func writeWorkspaceStore(at storeURL: URL, title: String) throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let container = try ModelContainer(for: modelSchema, configurations: [
            ModelConfiguration(schema: modelSchema, url: storeURL)
        ])
        let context = ModelContext(container)
        context.insert(WorkspaceModel(title: title))
        try context.save()
    }

    private func writeFullWorkbenchStore(at storeURL: URL) throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let container = try ModelContainer(for: modelSchema, configurations: [
            ModelConfiguration(schema: modelSchema, url: storeURL)
        ])
        let context = ModelContext(container)
        let workspace = WorkspaceModel(id: "workspace-existing", title: "Existing Workspace")
        let resource = ResourcePinModel(
            id: "resource-existing",
            workspaceId: workspace.id,
            title: "Existing Folder",
            targetType: .folder,
            displayPath: "/tmp/existing-folder",
            lastResolvedPath: "/tmp/existing-folder",
            scope: .workspace
        )
        let snippet = SnippetModel(
            id: "snippet-existing",
            workspaceId: workspace.id,
            title: "Existing Prompt",
            kind: .prompt,
            body: "Keep this prompt",
            scope: .workspace
        )
        let canvas = CanvasModel(
            id: "canvas-existing",
            workspaceId: workspace.id,
            title: "Existing Canvas"
        )
        let node = CanvasNodeModel(
            id: "node-existing",
            canvasId: canvas.id,
            title: "Existing Snippet Card",
            body: "Pinned prompt",
            nodeType: .snippet,
            objectType: "snippet",
            objectId: snippet.id,
            x: 120,
            y: 160
        )
        context.insert(workspace)
        context.insert(resource)
        context.insert(snippet)
        context.insert(canvas)
        context.insert(node)
        try context.save()
    }

    private func writeCorruptStore(at storeURL: URL, data: Data = Data("not a sqlite store".utf8)) throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: storeURL)
    }

    private func markBackupComplete(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "complete".write(
            to: folder.appendingPathComponent(".complete", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
    }

    private func workspaceTitles(in container: ModelContainer) throws -> [String] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<WorkspaceModel>())
            .map(\.title)
            .sorted()
    }

    private func insertWorkspace(title: String, into container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(WorkspaceModel(title: title))
        try context.save()
    }

    private func workspaceTitles(at storeURL: URL) throws -> [String] {
        let container = try ModelContainer(for: modelSchema, configurations: [
            ModelConfiguration(schema: modelSchema, url: storeURL)
        ])
        return try workspaceTitles(in: container)
    }

    private func backupFolders(in layout: MindDeskStoreLayout) throws -> [URL] {
        try directoryChildren(in: layout.backupDirectory)
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
    }

    private func restoreStagingFolders(in layout: MindDeskStoreLayout) throws -> [URL] {
        try directoryChildren(in: layout.storeDirectory)
            .filter { $0.lastPathComponent.hasPrefix(".restore-") }
    }

    private func directoryChildren(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
    }

    private var modelSchema: Schema {
        Schema([
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            WorkspaceTodoModel.self,
            WorkspaceTodoGroupModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ])
    }
}

private final class TestApplicationSupportFileManager: FileManager {
    private let applicationSupportDirectory: URL
    private let failRemovingURLOnce: URL?
    private let failMovingToURLOnce: URL?
    private let failCopyingToPathContaining: String?
    private var didFailRemovingURL = false
    private var didFailMovingToURL = false
    private var didFailCopying = false

    init(
        applicationSupportDirectory: URL,
        failRemovingURLOnce: URL? = nil,
        failMovingToURLOnce: URL? = nil,
        failCopyingToPathContaining: String? = nil
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.failRemovingURLOnce = failRemovingURLOnce?.standardizedFileURL
        self.failMovingToURLOnce = failMovingToURLOnce?.standardizedFileURL
        self.failCopyingToPathContaining = failCopyingToPathContaining
        super.init()
    }

    override func url(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask,
        appropriateFor url: URL?,
        create shouldCreate: Bool
    ) throws -> URL {
        guard directory == .applicationSupportDirectory, domainMask == .userDomainMask else {
            return try super.url(for: directory, in: domainMask, appropriateFor: url, create: shouldCreate)
        }
        if shouldCreate {
            try createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        }
        return applicationSupportDirectory
    }

    override func removeItem(at url: URL) throws {
        if !didFailRemovingURL,
           let failRemovingURLOnce,
           url.standardizedFileURL.path == failRemovingURLOnce.path {
            didFailRemovingURL = true
            throw CocoaError(.fileWriteUnknown)
        }
        try super.removeItem(at: url)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if !didFailMovingToURL,
           let failMovingToURLOnce,
           dstURL.standardizedFileURL.path == failMovingToURLOnce.path {
            didFailMovingToURL = true
            throw CocoaError(.fileWriteUnknown)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if !didFailCopying,
           let failCopyingToPathContaining,
           dstURL.path.contains(failCopyingToPathContaining) {
            didFailCopying = true
            throw CocoaError(.fileWriteUnknown)
        }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}
