import Foundation

func mindDeskDecodeStringBackedEnum<Value: RawRepresentable>(
    _ type: Value.Type,
    from decoder: Decoder,
    debugDescription: String
) throws -> Value where Value.RawValue == String {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    guard let value = Value(rawValue: rawValue) else {
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: debugDescription
        )
    }
    return value
}

public enum WorkbenchObjectKind: String, Codable, CaseIterable, Sendable {
    case workspace
    case resourcePin
    case snippet
    case canvas
    case node
    case edge
    case alias
    case todoGroup
    case todo
    case webURL

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported workbench object kind."
        )
    }
}

public struct WorkbenchObjectReference: Codable, Equatable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case id
    }

    public let kind: WorkbenchObjectKind
    public let id: String

    public var objectType: String { kind.rawValue }
    public var objectId: String { id }

    public init?(kind: WorkbenchObjectKind, id: String) {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return nil }
        self.kind = kind
        self.id = trimmedId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(WorkbenchObjectKind.self, forKey: .kind)
        let id = try container.decode(String.self, forKey: .id)
        guard let reference = WorkbenchObjectReference(kind: kind, id: id) else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Workbench object reference id must not be empty."
            )
        }
        self = reference
    }

    public static func fromLegacy(objectType: String?, objectId: String?, body: String = "") -> WorkbenchObjectReference? {
        guard let objectType else { return nil }
        let trimmedType = objectType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let kind = WorkbenchObjectKind(rawValue: trimmedType),
              WorkbenchObjectReferencePolicy.canvasObjectKinds.contains(kind) else { return nil }

        if kind == .webURL {
            let trimmedObjectId = objectId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let urlSource = trimmedObjectId?.isEmpty == false ? trimmedObjectId ?? "" : body
            guard let url = WebCardURL.normalized(urlSource) else { return nil }
            return WorkbenchObjectReference(kind: kind, id: url.absoluteString)
        }

        guard let objectId else { return nil }
        let trimmedObjectId = objectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedObjectId.isEmpty else { return nil }
        return WorkbenchObjectReference(kind: kind, id: trimmedObjectId)
    }
}

public enum WorkbenchObjectReferencePolicy {
    public static let canvasObjectKinds: Set<WorkbenchObjectKind> = [.resourcePin, .snippet, .workspace, .webURL]
    public static let evidenceObjectKinds: Set<WorkbenchObjectKind> = Set(WorkbenchObjectKind.allCases)
    public static let actionableTargetKinds: Set<WorkbenchObjectKind> = canvasObjectKinds
    public static let aliasSourceKinds: Set<WorkbenchObjectKind> = [.resourcePin, .snippet]
    public static let importableCanvasObjectKinds: Set<WorkbenchObjectKind> = canvasObjectKinds
    public static let importableCanvasObjectTypes: Set<String> = Set(canvasObjectKinds.map(\.rawValue))
    public static let importableAliasSourceTypes: Set<String> = Set(aliasSourceKinds.map(\.rawValue))

    public static func isCompatible(nodeType: String, objectKind: WorkbenchObjectKind) -> Bool {
        switch nodeType {
        case "resource":
            return objectKind == .resourcePin
        case "snippet":
            return objectKind == .snippet || objectKind == .workspace || objectKind == .webURL
        case "note", "groupFrame":
            return false
        default:
            return true
        }
    }

    public static func isCompatible(nodeType: String, objectType: String) -> Bool {
        guard let objectKind = WorkbenchObjectKind(rawValue: objectType) else {
            switch nodeType {
            case "resource", "snippet", "note", "groupFrame":
                return false
            default:
                return true
            }
        }
        return isCompatible(nodeType: nodeType, objectKind: objectKind)
    }
}

public enum WorkbenchExternalAction: String, Codable, CaseIterable, Sendable {
    case readAgentContext
    case proposeAgentAction
    case applyAgentAction
    case runCommand
    case openTerminal
    case openFileSystemItem
    case revealInFinder
    case createFinderAlias
    case openURL
    case copyPathToClipboard

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported workbench external action."
        )
    }
}

public enum WorkbenchExternalActor: String, Codable, CaseIterable, Sendable {
    case directUser
    case defaultAgent
    case approvedAgent

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported workbench external actor."
        )
    }
}

public enum WorkbenchExternalActionDecision: String, Codable, Equatable, Sendable {
    case allow
    case requireExplicitUserIntent
    case requireModalConfirmation
    case deny

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported workbench external action decision."
        )
    }
}

public enum WorkbenchExternalActionPolicy {
    public static func decision(
        for action: WorkbenchExternalAction,
        actor: WorkbenchExternalActor
    ) -> WorkbenchExternalActionDecision {
        switch actor {
        case .directUser:
            return directUserDecision(for: action)
        case .defaultAgent:
            return defaultAgentDecision(for: action)
        case .approvedAgent:
            return approvedAgentDecision(for: action)
        }
    }

    public static func requiresUserConfirmation(_ action: WorkbenchExternalAction) -> Bool {
        requiresUserMediation(action, actor: .directUser) || requiresModalConfirmation(action, actor: .approvedAgent)
    }

    public static func requiresModalConfirmation(
        _ action: WorkbenchExternalAction,
        actor: WorkbenchExternalActor
    ) -> Bool {
        decision(for: action, actor: actor) == .requireModalConfirmation
    }

    public static func requiresUserMediation(
        _ action: WorkbenchExternalAction,
        actor: WorkbenchExternalActor
    ) -> Bool {
        switch decision(for: action, actor: actor) {
        case .requireExplicitUserIntent, .requireModalConfirmation:
            return true
        case .deny:
            return true
        case .allow:
            return false
        }
    }

    public static func isAllowedForDefaultAgent(_ action: WorkbenchExternalAction) -> Bool {
        decision(for: action, actor: .defaultAgent) == .allow
    }

    private static func directUserDecision(for action: WorkbenchExternalAction) -> WorkbenchExternalActionDecision {
        switch action {
        case .readAgentContext, .proposeAgentAction:
            return .allow
        case .applyAgentAction,
             .runCommand,
             .openTerminal,
             .createFinderAlias:
            return .requireModalConfirmation
        case .openFileSystemItem,
             .revealInFinder,
             .openURL,
             .copyPathToClipboard:
            return .requireExplicitUserIntent
        }
    }

    private static func defaultAgentDecision(for action: WorkbenchExternalAction) -> WorkbenchExternalActionDecision {
        switch action {
        case .readAgentContext, .proposeAgentAction:
            return .allow
        case .applyAgentAction,
             .runCommand,
             .openTerminal,
             .openFileSystemItem,
             .revealInFinder,
             .createFinderAlias,
             .openURL,
             .copyPathToClipboard:
            return .deny
        }
    }

    private static func approvedAgentDecision(for action: WorkbenchExternalAction) -> WorkbenchExternalActionDecision {
        switch action {
        case .readAgentContext, .proposeAgentAction:
            return .allow
        case .applyAgentAction,
             .runCommand,
             .openTerminal,
             .openFileSystemItem,
             .revealInFinder,
             .createFinderAlias,
             .openURL,
             .copyPathToClipboard:
            return .requireModalConfirmation
        }
    }
}
