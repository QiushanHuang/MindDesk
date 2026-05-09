import Foundation
import MindDeskCore
import SwiftData

enum PersistentStoreBootstrap {
    static func makeModelContainer(fileManager: FileManager = .default) throws -> ModelContainer {
        let layout = try makeLayout(fileManager: fileManager)
        try prepareStore(at: layout, fileManager: fileManager)

        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(schema: schema, url: layout.storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static var modelTypes: [any PersistentModel.Type] {
        [
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            WorkspaceTodoModel.self,
            WorkspaceTodoGroupModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ]
    }

    private static func makeLayout(fileManager: FileManager) throws -> MindDeskStoreLayout {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return MindDeskStoreLayout(applicationSupportDirectory: support)
    }

    private static func prepareStore(at layout: MindDeskStoreLayout, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: layout.storeDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.backupDirectory, withIntermediateDirectories: true)

        var migratedStore = false
        if !fileManager.fileExists(atPath: layout.storeURL.path) {
            if fileManager.fileExists(atPath: layout.legacyStoreURL.path) {
                try copySQLiteFileSet(from: layout.legacyStoreURL, to: layout.storeURL, fileManager: fileManager)
                migratedStore = true
            } else if fileManager.fileExists(atPath: layout.legacyDefaultStoreURL.path) {
                try copySQLiteFileSet(from: layout.legacyDefaultStoreURL, to: layout.storeURL, fileManager: fileManager)
                migratedStore = true
            } else {
                _ = try restoreLatestBackupIfPresent(layout: layout, fileManager: fileManager)
            }
        }

        let backupFolders = try existingBackupFolders(layout: layout, fileManager: fileManager)
        if migratedStore {
            try? backupSQLiteFileSetIfPresent(layout: layout, reason: .migration, fileManager: fileManager)
        } else if MindDeskStoreLayout.shouldCreateStartupBackup(
            storeExists: fileManager.fileExists(atPath: layout.storeURL.path),
            backupFolders: backupFolders,
            now: .now
        ) {
            try? backupSQLiteFileSetIfPresent(layout: layout, reason: .startup, fileManager: fileManager)
        }
        try? pruneOldBackups(layout: layout, fileManager: fileManager)
    }

    private static func copySQLiteFileSet(from sourceStore: URL, to destinationStore: URL, fileManager: FileManager) throws {
        let pairs = zip(
            MindDeskStoreLayout.sqliteFileSet(for: sourceStore),
            MindDeskStoreLayout.sqliteFileSet(for: destinationStore)
        )
        .filter { source, _ in fileManager.fileExists(atPath: source.path) }
        guard !pairs.isEmpty else { return }

        let tempDirectory = destinationStore
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationStore.lastPathComponent).copy-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: false)
            for (source, destination) in pairs {
                let tempFile = tempDirectory.appendingPathComponent(destination.lastPathComponent, isDirectory: false)
                try fileManager.copyItem(at: source, to: tempFile)
            }
            for (_, destination) in pairs where fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            for (_, destination) in pairs {
                let tempFile = tempDirectory.appendingPathComponent(destination.lastPathComponent, isDirectory: false)
                try fileManager.moveItem(at: tempFile, to: destination)
            }
            try? fileManager.removeItem(at: tempDirectory)
        } catch {
            try? fileManager.removeItem(at: tempDirectory)
            for (_, destination) in pairs where fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            throw error
        }
    }

    private static func backupSQLiteFileSetIfPresent(
        layout: MindDeskStoreLayout,
        reason: MindDeskStoreBackupReason,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: layout.storeURL.path) else { return }

        let folderName = MindDeskStoreLayout.backupFolderName(for: .now, reason: reason)
        var backupFolder = layout.backupDirectory.appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: backupFolder.path) {
            backupFolder = layout.backupDirectory.appendingPathComponent("\(folderName)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        }
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        for source in MindDeskStoreLayout.sqliteFileSet(for: layout.storeURL) where fileManager.fileExists(atPath: source.path) {
            let destination = backupFolder.appendingPathComponent(source.lastPathComponent, isDirectory: false)
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func restoreLatestBackupIfPresent(layout: MindDeskStoreLayout, fileManager: FileManager) throws -> Bool {
        for folder in MindDeskStoreLayout.recoveryCandidateFolders(try existingBackupFolders(layout: layout, fileManager: fileManager)) {
            let backupStore = folder.appendingPathComponent(MindDeskStoreLayout.storeFileName, isDirectory: false)
            guard fileManager.fileExists(atPath: backupStore.path) else { continue }
            try copySQLiteFileSet(from: backupStore, to: layout.storeURL, fileManager: fileManager)
            return true
        }
        return false
    }

    private static func existingBackupFolders(layout: MindDeskStoreLayout, fileManager: FileManager) throws -> [URL] {
        guard fileManager.fileExists(atPath: layout.backupDirectory.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: layout.backupDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    private static func pruneOldBackups(layout: MindDeskStoreLayout, fileManager: FileManager) throws {
        let folders = try existingBackupFolders(layout: layout, fileManager: fileManager)
        for folder in MindDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: MindDeskStoreLayout.backupRetentionCount) {
            try fileManager.removeItem(at: folder)
        }
    }
}
