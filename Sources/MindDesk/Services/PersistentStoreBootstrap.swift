import Foundation
import MindDeskCore
import SwiftData

enum PersistentStoreBootstrap {
    static func makeModelContainer(fileManager: FileManager = .default) throws -> ModelContainer {
        let layout = try makeLayout(fileManager: fileManager)
        let schema = Schema(modelTypes)
        let preparation = try prepareStore(at: layout, schema: schema, fileManager: fileManager)
        let configuration = ModelConfiguration(schema: schema, url: layout.storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            postOpenMaintenance(preparation: preparation, layout: layout, fileManager: fileManager)
            return container
        } catch {
            guard let restoredStoreURL = try recoverFromOpenFailure(layout: layout, schema: schema, fileManager: fileManager) else {
                throw error
            }
            try publishRecoveredStore(from: restoredStoreURL, to: layout.storeURL, layout: layout, fileManager: fileManager)
            let finalContainer = try ModelContainer(for: schema, configurations: [configuration])
            postOpenMaintenance(
                preparation: PersistentStorePreparation(didMigrateStore: false, didRestoreStore: true),
                layout: layout,
                fileManager: fileManager
            )
            return finalContainer
        }
    }

    private struct PersistentStorePreparation {
        var didMigrateStore: Bool
        var didRestoreStore: Bool
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

    private static func prepareStore(
        at layout: MindDeskStoreLayout,
        schema: Schema,
        fileManager: FileManager
    ) throws -> PersistentStorePreparation {
        try fileManager.createDirectory(at: layout.appDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.storeDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.backupDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.quarantineDirectory, withIntermediateDirectories: true)
        try cleanIncompleteBackupFolders(layout: layout, fileManager: fileManager)
        try recoverInterruptedMigrationIfNeeded(layout: layout, fileManager: fileManager)

        var preparation = PersistentStorePreparation(didMigrateStore: false, didRestoreStore: false)
        if !fileManager.fileExists(atPath: layout.storeURL.path) {
            if fileManager.fileExists(atPath: layout.legacyStoreURL.path) {
                try migrateSQLiteFileSet(from: layout.legacyStoreURL, to: layout.storeURL, layout: layout, fileManager: fileManager)
                preparation.didMigrateStore = true
            } else if fileManager.fileExists(atPath: layout.legacyDefaultStoreURL.path) {
                try migrateSQLiteFileSet(from: layout.legacyDefaultStoreURL, to: layout.storeURL, layout: layout, fileManager: fileManager)
                preparation.didMigrateStore = true
            } else {
                if let restoredStoreURL = try restoreLatestBackupToStagingIfPresent(
                    layout: layout,
                    schema: schema,
                    fileManager: fileManager
                ) {
                    try publishRecoveredStore(from: restoredStoreURL, to: layout.storeURL, layout: layout, fileManager: fileManager)
                    preparation.didRestoreStore = true
                }
            }
        }

        return preparation
    }

    private static func postOpenMaintenance(
        preparation: PersistentStorePreparation,
        layout: MindDeskStoreLayout,
        fileManager: FileManager
    ) {
        if preparation.didMigrateStore {
            try? backupSQLiteFileSetIfPresent(layout: layout, reason: .migration, fileManager: fileManager)
        } else if !preparation.didRestoreStore {
            let backupFolders = (try? existingBackupFolders(layout: layout, fileManager: fileManager)) ?? []
            if MindDeskStoreLayout.shouldCreateStartupBackup(
                storeExists: fileManager.fileExists(atPath: layout.storeURL.path),
                backupFolders: backupFolders,
                now: .now
            ) {
                try? backupSQLiteFileSetIfPresent(layout: layout, reason: .startup, fileManager: fileManager)
            }
        }
        try? pruneOldBackups(layout: layout, fileManager: fileManager)
    }

    private static func migrateSQLiteFileSet(
        from sourceStore: URL,
        to destinationStore: URL,
        layout: MindDeskStoreLayout,
        fileManager: FileManager
    ) throws {
        let marker = migrationMarkerURL(layout: layout)
        try "in-progress".write(to: marker, atomically: true, encoding: .utf8)
        do {
            try copySQLiteFileSet(from: sourceStore, to: destinationStore, fileManager: fileManager)
            try? fileManager.removeItem(at: marker)
        } catch {
            removeSQLiteFileSet(for: destinationStore, fileManager: fileManager)
            try? fileManager.removeItem(at: marker)
            throw error
        }
    }

    private static func recoverInterruptedMigrationIfNeeded(layout: MindDeskStoreLayout, fileManager: FileManager) throws {
        let marker = migrationMarkerURL(layout: layout)
        guard fileManager.fileExists(atPath: marker.path) else { return }
        removeSQLiteFileSet(for: layout.storeURL, fileManager: fileManager)
        try? fileManager.removeItem(at: marker)
    }

    private static func migrationMarkerURL(layout: MindDeskStoreLayout) -> URL {
        layout.storeDirectory.appendingPathComponent(".migration-in-progress", isDirectory: false)
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
            removeSQLiteFileSet(for: destinationStore, fileManager: fileManager)
            for (_, destination) in pairs {
                let tempFile = tempDirectory.appendingPathComponent(destination.lastPathComponent, isDirectory: false)
                try fileManager.moveItem(at: tempFile, to: destination)
            }
            try? fileManager.removeItem(at: tempDirectory)
        } catch {
            try? fileManager.removeItem(at: tempDirectory)
            throw error
        }
    }

    private static func removeSQLiteFileSet(for storeURL: URL, fileManager: FileManager) {
        for url in MindDeskStoreLayout.sqliteFileSet(for: storeURL) where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func backupSQLiteFileSetIfPresent(
        layout: MindDeskStoreLayout,
        reason: MindDeskStoreBackupReason,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: layout.storeURL.path) else { return }

        let folderName = MindDeskStoreLayout.backupFolderName(for: .now, reason: reason)
        let backupFolder = uniqueBackupFolder(layout: layout, folderName: folderName, fileManager: fileManager)
        let tempFolder = layout.backupDirectory.appendingPathComponent(".\(folderName).incomplete-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: tempFolder, withIntermediateDirectories: true)
            for source in MindDeskStoreLayout.sqliteFileSet(for: layout.storeURL) where fileManager.fileExists(atPath: source.path) {
                let destination = tempFolder.appendingPathComponent(source.lastPathComponent, isDirectory: false)
                try fileManager.copyItem(at: source, to: destination)
            }
            try "complete".write(to: tempFolder.appendingPathComponent(".complete", isDirectory: false), atomically: true, encoding: .utf8)
            try fileManager.moveItem(at: tempFolder, to: backupFolder)
        } catch {
            try? fileManager.removeItem(at: tempFolder)
            throw error
        }
    }

    private static func uniqueBackupFolder(
        layout: MindDeskStoreLayout,
        folderName: String,
        fileManager: FileManager
    ) -> URL {
        uniqueBackupFolder(parentDirectory: layout.backupDirectory, folderName: folderName, fileManager: fileManager)
    }

    private static func uniqueBackupFolder(
        parentDirectory: URL,
        folderName: String,
        fileManager: FileManager
    ) -> URL {
        var backupFolder = parentDirectory.appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: backupFolder.path) {
            backupFolder = parentDirectory.appendingPathComponent("\(folderName)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        }
        return backupFolder
    }

    private static func restoreLatestBackupToStagingIfPresent(
        layout: MindDeskStoreLayout,
        schema: Schema,
        fileManager: FileManager
    ) throws -> URL? {
        for folder in MindDeskStoreLayout.recoveryCandidateFolders(try existingBackupFolders(layout: layout, fileManager: fileManager)) {
            guard isRecoverableBackupFolder(folder, fileManager: fileManager) else { continue }
            let backupStore = folder.appendingPathComponent(MindDeskStoreLayout.storeFileName, isDirectory: false)
            guard fileManager.fileExists(atPath: backupStore.path) else { continue }
            let stagingDirectory = layout.storeDirectory.appendingPathComponent(".restore-\(UUID().uuidString)", isDirectory: true)
            let stagingStore = stagingDirectory.appendingPathComponent(MindDeskStoreLayout.storeFileName, isDirectory: false)
            do {
                try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
                try copySQLiteFileSet(from: backupStore, to: stagingStore, fileManager: fileManager)
                try validateStore(at: stagingStore, schema: schema)
                return stagingStore
            } catch {
                try? fileManager.removeItem(at: stagingDirectory)
                continue
            }
        }
        return nil
    }

    private static func recoverFromOpenFailure(
        layout: MindDeskStoreLayout,
        schema: Schema,
        fileManager: FileManager
    ) throws -> URL? {
        guard fileManager.fileExists(atPath: layout.storeURL.path) else { return nil }
        return try restoreLatestBackupToStagingIfPresent(layout: layout, schema: schema, fileManager: fileManager)
    }

    private static func publishRecoveredStore(
        from restoredStoreURL: URL,
        to destinationStoreURL: URL,
        layout: MindDeskStoreLayout,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: restoredStoreURL.path) else { return }
        let quarantineFolder = uniqueBackupFolder(
            parentDirectory: layout.quarantineDirectory,
            folderName: MindDeskStoreLayout.backupFolderName(for: .now, reason: .failedOpen),
            fileManager: fileManager
        )
        let existingStoreFiles = MindDeskStoreLayout.sqliteFileSet(for: destinationStoreURL)
            .filter { fileManager.fileExists(atPath: $0.path) }
        var movedStoreFiles: [(quarantined: URL, original: URL)] = []
        if !existingStoreFiles.isEmpty {
            try fileManager.createDirectory(at: quarantineFolder, withIntermediateDirectories: true)
        }
        do {
            for source in existingStoreFiles {
                let destination = quarantineFolder.appendingPathComponent(source.lastPathComponent, isDirectory: false)
                try fileManager.moveItem(at: source, to: destination)
                movedStoreFiles.append((quarantined: destination, original: source))
            }
            try copySQLiteFileSet(from: restoredStoreURL, to: destinationStoreURL, fileManager: fileManager)
            try? fileManager.removeItem(at: restoredStoreURL.deletingLastPathComponent())
        } catch {
            var rollbackFailures: [String] = []
            for partialFile in MindDeskStoreLayout.sqliteFileSet(for: destinationStoreURL) where fileManager.fileExists(atPath: partialFile.path) {
                do {
                    try fileManager.removeItem(at: partialFile)
                } catch {
                    rollbackFailures.append("Could not remove partial store file \(partialFile.path): \(error.localizedDescription)")
                }
            }
            for movedStoreFile in movedStoreFiles where fileManager.fileExists(atPath: movedStoreFile.quarantined.path) && !fileManager.fileExists(atPath: movedStoreFile.original.path) {
                do {
                    try fileManager.moveItem(at: movedStoreFile.quarantined, to: movedStoreFile.original)
                } catch {
                    rollbackFailures.append("Could not restore quarantined store file \(movedStoreFile.original.path): \(error.localizedDescription)")
                }
            }
            if !rollbackFailures.isEmpty {
                throw NSError(
                    domain: "MindDeskStoreRecovery",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Recovered store publish failed and rollback was incomplete. Original error: \(error.localizedDescription). \(rollbackFailures.joined(separator: " "))"
                    ]
                )
            }
            throw error
        }
    }

    private static func validateStore(at storeURL: URL, schema: Schema) throws {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        _ = try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func isRecoverableBackupFolder(_ folder: URL, fileManager: FileManager) -> Bool {
        if fileManager.fileExists(atPath: folder.appendingPathComponent(".complete", isDirectory: false).path) {
            return true
        }
        return fileManager.fileExists(
            atPath: folder.appendingPathComponent(MindDeskStoreLayout.storeFileName, isDirectory: false).path
        )
    }

    private static func cleanIncompleteBackupFolders(layout: MindDeskStoreLayout, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: layout.backupDirectory.path) else { return }
        let folders = try fileManager.contentsOfDirectory(
            at: layout.backupDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        for folder in folders {
            let isDirectory = (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDirectory, MindDeskStoreLayout.isIncompleteBackupFolderName(folder.lastPathComponent) else {
                continue
            }
            try? fileManager.removeItem(at: folder)
        }
    }

    private static func existingBackupFolders(layout: MindDeskStoreLayout, fileManager: FileManager) throws -> [URL] {
        guard fileManager.fileExists(atPath: layout.backupDirectory.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: layout.backupDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private static func pruneOldBackups(layout: MindDeskStoreLayout, fileManager: FileManager) throws {
        let folders = try existingBackupFolders(layout: layout, fileManager: fileManager)
        for folder in MindDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: MindDeskStoreLayout.backupRetentionCount) {
            try fileManager.removeItem(at: folder)
        }
    }
}
