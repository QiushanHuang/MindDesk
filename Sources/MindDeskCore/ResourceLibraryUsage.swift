import Foundation

public struct WorkspaceLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct GlobalResourceLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String { resource.id }
    public var resource: ResourceLibraryRecord
    public var workspaceIDs: [String]
    public var workspaceTitles: [String]

    public init(resource: ResourceLibraryRecord, workspaceIDs: [String], workspaceTitles: [String]) {
        self.resource = resource
        self.workspaceIDs = workspaceIDs
        self.workspaceTitles = workspaceTitles
    }
}

public struct ResourceCanvasUsageRecord: Equatable, Sendable {
    public var resourceId: String
    public var workspaceId: String

    public init(resourceId: String, workspaceId: String) {
        self.resourceId = resourceId
        self.workspaceId = workspaceId
    }
}

public enum GlobalResourceLibrary {
    public static func displayRecords(
        resources: [ResourceLibraryRecord],
        workspaces: [WorkspaceLibraryRecord],
        canvasUsages: [ResourceCanvasUsageRecord] = [],
        workspaceFilterId: String? = nil
    ) -> [GlobalResourceLibraryRecord] {
        let workspaceTitleById = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0.title) })
        let canvasWorkspaceIDsByResourceID = Dictionary(grouping: canvasUsages, by: \.resourceId)
            .mapValues { Set($0.map(\.workspaceId)) }
        let grouped = Dictionary(grouping: resources, by: resourceKey)

        let records = grouped.values.compactMap { group -> GlobalResourceLibraryRecord? in
            let workspaceIDs = orderedWorkspaceIDs(
                in: group,
                canvasWorkspaceIDsByResourceID: canvasWorkspaceIDsByResourceID,
                workspaceTitleById: workspaceTitleById
            )
            if let workspaceFilterId, !workspaceIDs.contains(workspaceFilterId) {
                return nil
            }
            guard let resource = canonicalResource(in: group) else { return nil }
            let workspaceTitles = workspaceIDs.map { workspaceTitleById[$0] ?? $0 }
            return GlobalResourceLibraryRecord(resource: resource, workspaceIDs: workspaceIDs, workspaceTitles: workspaceTitles)
        }

        let orderedResources = ResourceLibraryFiltering.ordered(records.map(\.resource))
        let recordByResourceId = Dictionary(uniqueKeysWithValues: records.map { ($0.resource.id, $0) })
        return orderedResources.compactMap { recordByResourceId[$0.id] }
    }

    private static func canonicalResource(in group: [ResourceLibraryRecord]) -> ResourceLibraryRecord? {
        let global = group.filter { $0.scope == "global" }
        return ResourceLibraryFiltering.ordered(global.isEmpty ? group : global).first
    }

    private static func orderedWorkspaceIDs(
        in group: [ResourceLibraryRecord],
        canvasWorkspaceIDsByResourceID: [String: Set<String>],
        workspaceTitleById: [String: String]
    ) -> [String] {
        let directIDs = group.compactMap { resource -> String? in
            guard resource.scope == "workspace" else { return nil }
            return resource.workspaceId
        }
        let canvasIDs = group.flatMap { resource in
            Array(canvasWorkspaceIDsByResourceID[resource.id, default: []])
        }
        let ids = Set(directIDs + canvasIDs)
        return ids.sorted {
            let lhsTitle = workspaceTitleById[$0] ?? $0
            let rhsTitle = workspaceTitleById[$1] ?? $1
            let comparison = lhsTitle.localizedStandardCompare(rhsTitle)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            return $0 < $1
        }
    }

    private static func resourceKey(_ resource: ResourceLibraryRecord) -> String {
        let path = resource.lastResolvedPath.isEmpty ? resource.displayPath : resource.lastResolvedPath
        return (path as NSString).standardizingPath
    }
}

public struct ResourceImportExistingRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var scope: String
    public var workspaceId: String?

    public init(id: String, path: String, scope: String, workspaceId: String?) {
        self.id = id
        self.path = path
        self.scope = scope
        self.workspaceId = workspaceId
    }
}

public enum ResourceImportDeduplication {
    public static func reusableRecordID(
        forPath path: String,
        scope: String,
        workspaceId: String?,
        existingRecords: [ResourceImportExistingRecord]
    ) -> String? {
        let key = importKey(path: path, scope: scope, workspaceId: workspaceId)
        return existingRecords.first {
            importKey(path: $0.path, scope: $0.scope, workspaceId: $0.workspaceId) == key
        }?.id
    }

    public static func importKey(path: String, scope: String, workspaceId: String?) -> String {
        let normalizedPath = (path as NSString).standardizingPath
        let normalizedWorkspaceId = scope == "workspace" ? workspaceId ?? "" : ""
        return "\(normalizedPath)|\(scope)|\(normalizedWorkspaceId)"
    }
}
