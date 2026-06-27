import Foundation
import OSLog

public enum MindDeskHiddenMaintenanceSubject: String, Equatable, Sendable {
    case canvasEdgeViewportIndexCache
    case finderAlias
}

public enum MindDeskHiddenMaintenanceAction: String, Equatable, Sendable {
    case create
    case reuse
    case cleanup
}

public enum MindDeskHiddenMaintenanceResult: String, Equatable, Sendable {
    case succeeded
    case failed
}

public struct MindDeskHiddenMaintenanceLogEvent: Equatable, Sendable {
    public var subject: MindDeskHiddenMaintenanceSubject
    public var action: MindDeskHiddenMaintenanceAction
    public var result: MindDeskHiddenMaintenanceResult
    public var details: [String: String]

    public init(
        subject: MindDeskHiddenMaintenanceSubject,
        action: MindDeskHiddenMaintenanceAction,
        result: MindDeskHiddenMaintenanceResult,
        details: [String: String] = [:]
    ) {
        self.subject = subject
        self.action = action
        self.result = result
        self.details = details
    }

    public var message: String {
        let prefix = "hidden-maintenance subject=\(subject.rawValue) action=\(action.rawValue) result=\(result.rawValue)"
        let detailsText = details.keys.sorted().map { key in
            "\(key)=\(details[key] ?? "")"
        }.joined(separator: " ")
        return detailsText.isEmpty ? prefix : "\(prefix) \(detailsText)"
    }

    public static func canvasEdgeViewportIndexCacheCreated(
        reason: CanvasEdgeViewportIndexCacheInvalidationReason,
        buildCount: Int,
        totalEdgeCount: Int,
        indexedEdgeCount: Int
    ) -> MindDeskHiddenMaintenanceLogEvent {
        MindDeskHiddenMaintenanceLogEvent(
            subject: .canvasEdgeViewportIndexCache,
            action: .create,
            result: .succeeded,
            details: [
                "reason": reason.rawValue,
                "buildCount": safeCount(buildCount),
                "totalEdgeCount": safeCount(totalEdgeCount),
                "indexedEdgeCount": safeCount(indexedEdgeCount)
            ]
        )
    }

    public static func canvasEdgeViewportIndexCacheReused(
        reuseCount: Int
    ) -> MindDeskHiddenMaintenanceLogEvent {
        MindDeskHiddenMaintenanceLogEvent(
            subject: .canvasEdgeViewportIndexCache,
            action: .reuse,
            result: .succeeded,
            details: [
                "reuseCount": safeCount(reuseCount)
            ]
        )
    }

    public static func canvasEdgeViewportIndexCacheCleanedUp(
        reason: CanvasEdgeViewportIndexCacheInvalidationReason,
        buildCount: Int,
        reuseCount: Int
    ) -> MindDeskHiddenMaintenanceLogEvent {
        MindDeskHiddenMaintenanceLogEvent(
            subject: .canvasEdgeViewportIndexCache,
            action: .cleanup,
            result: .succeeded,
            details: [
                "reason": reason.rawValue,
                "buildCount": safeCount(buildCount),
                "reuseCount": safeCount(reuseCount)
            ]
        )
    }

    public static func finderAliasCreateResult(
        sourceObjectType: String,
        status: String,
        hasAliasBookmark: Bool,
        hasTargetBookmark: Bool
    ) -> MindDeskHiddenMaintenanceLogEvent {
        let sanitizedStatus = safeAliasStatus(status)
        return MindDeskHiddenMaintenanceLogEvent(
            subject: .finderAlias,
            action: .create,
            result: sanitizedStatus == "created" ? .succeeded : .failed,
            details: [
                "sourceObjectType": safeAliasSourceObjectType(sourceObjectType),
                "status": sanitizedStatus,
                "hasAliasBookmark": String(hasAliasBookmark),
                "hasTargetBookmark": String(hasTargetBookmark)
            ]
        )
    }

    private static func safeCount(_ value: Int) -> String {
        String(max(0, value))
    }

    private static func safeAliasSourceObjectType(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "resourcePin", "snippet":
            return trimmed
        default:
            return "other"
        }
    }

    private static func safeAliasStatus(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "created", "missing", "failed", "staleAuthorization":
            return trimmed
        default:
            return "other"
        }
    }
}

public enum MindDeskHiddenMaintenanceLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MindDesk",
        category: "HiddenMaintenance"
    )

    public static func log(_ event: MindDeskHiddenMaintenanceLogEvent) {
        logger.info("\(event.message, privacy: .public)")
    }
}
