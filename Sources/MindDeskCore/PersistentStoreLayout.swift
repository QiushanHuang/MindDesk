import Foundation

public enum MindDeskStoreBackupReason: String, Sendable {
    case startup
    case migration
    case restore
    case failedOpen = "failed-open"
}

public struct MindDeskStoreLayout: Equatable, Sendable {
    public static let bundleIdentifier = "studio.qiushan.minddesk"
    public static let storeFileName = "MindDesk.store"
    public static let backupRetentionCount = 20
    public static let startupBackupMinimumInterval: TimeInterval = 30 * 60
    private static let previousBundleIdentifier = ["studio", "qiushan", "my" + "desk"].joined(separator: ".")
    private static let previousStoreFileName = "My" + "Desk.store"

    public let applicationSupportDirectory: URL

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    public var appDirectory: URL {
        applicationSupportDirectory.appendingPathComponent(Self.bundleIdentifier, isDirectory: true)
    }

    public var storeDirectory: URL {
        appDirectory.appendingPathComponent("Stores", isDirectory: true)
    }

    public var storeURL: URL {
        storeDirectory.appendingPathComponent(Self.storeFileName, isDirectory: false)
    }

    public var backupDirectory: URL {
        appDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    public var quarantineDirectory: URL {
        appDirectory.appendingPathComponent("Quarantine", isDirectory: true)
    }

    public var legacyStoreURL: URL {
        applicationSupportDirectory
            .appendingPathComponent(Self.previousBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Stores", isDirectory: true)
            .appendingPathComponent(Self.previousStoreFileName, isDirectory: false)
    }

    public var legacyDefaultStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("default.store", isDirectory: false)
    }

    public static func sqliteFileSet(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
    }

    public static func backupFolderName(
        for date: Date,
        reason: MindDeskStoreBackupReason? = nil,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: date)
        if let reason {
            return "\(timestamp)-\(reason.rawValue)"
        }
        return timestamp
    }

    public static func backupFoldersToPrune(_ folders: [URL], keepingNewest count: Int) -> [URL] {
        guard count >= 0 else { return [] }
        let newestFirst = recoveryCandidateFolders(folders)
        return Array(newestFirst.dropFirst(count)).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func shouldCreateStartupBackup(
        storeExists: Bool,
        backupFolders: [URL],
        now: Date,
        minimumInterval: TimeInterval = startupBackupMinimumInterval,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) -> Bool {
        guard storeExists else { return false }
        guard let latestBackup = latestBackupDate(in: backupFolders, timeZone: timeZone) else {
            return true
        }
        return now.timeIntervalSince(latestBackup) >= minimumInterval
    }

    public static func recoveryCandidateFolders(_ folders: [URL]) -> [URL] {
        folders
            .filter { isTimestampedBackupFolder($0.lastPathComponent) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func latestBackupDate(in folders: [URL], timeZone: TimeZone) -> Date? {
        recoveryCandidateFolders(folders)
            .compactMap { backupDate(fromFolderName: $0.lastPathComponent, timeZone: timeZone) }
            .max()
    }

    private static func backupDate(fromFolderName name: String, timeZone: TimeZone) -> Date? {
        guard let timestamp = backupTimestampPrefix(name) else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.date(from: timestamp)
    }

    private static func isTimestampedBackupFolder(_ name: String) -> Bool {
        backupTimestampPrefix(name) != nil
    }

    private static func backupTimestampPrefix(_ name: String) -> String? {
        guard name.count >= 15 else { return nil }
        let dashIndex = name.index(name.startIndex, offsetBy: 8)
        guard name[dashIndex] == "-" else { return nil }
        let timestampEnd = name.index(name.startIndex, offsetBy: 15)
        let timestamp = name[..<timestampEnd]
        guard timestamp.enumerated().allSatisfy({ index, character in
            index == 8 || character.isNumber
        }) else {
            return nil
        }
        guard timestampEnd < name.endIndex else { return String(timestamp) }
        guard name[timestampEnd] == "-" && name.index(after: timestampEnd) < name.endIndex else {
            return nil
        }
        return String(timestamp)
    }
}
