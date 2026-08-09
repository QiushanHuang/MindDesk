import Foundation

public struct MindDeskExtensionCapabilityCatalog: Codable, Equatable, Sendable {
    public static let currentFormat = "minddesk.extension.capability.catalog"
    public static let currentFormatVersion = 1

    public var format: String
    public var formatVersion: Int
    public var authorizesSideEffects: Bool
    public var capabilities: [MindDeskExtensionCapability]
    public var notes: [String]

    public init(
        format: String,
        formatVersion: Int,
        authorizesSideEffects: Bool,
        capabilities: [MindDeskExtensionCapability],
        notes: [String]
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.authorizesSideEffects = authorizesSideEffects
        self.capabilities = capabilities
        self.notes = notes
    }
}

public struct MindDeskExtensionCapability: Codable, Equatable, Identifiable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case operationKind
        case externalAction
        case isProposalOperation
        case requiresTarget
        case supportedTargetKinds
        case requiredPayloadFields
        case allowedPayloadFields
        case payloadFieldSchemas
        case policyDecisions
        case notes
    }

    public var id: String
    public var title: String
    public var operationKind: MindDeskProposalOperationKind
    public var externalAction: WorkbenchExternalAction
    public var isProposalOperation: Bool
    public var requiresTarget: Bool
    public var supportedTargetKinds: [WorkbenchObjectKind]
    public var requiredPayloadFields: [MindDeskAgentOperationPayloadField]
    public var allowedPayloadFields: [MindDeskAgentOperationPayloadField]
    public var payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema]
    public var policyDecisions: [MindDeskExtensionCapabilityPolicyDecision]
    public var notes: [String]

    public init(
        id: String,
        title: String,
        operationKind: MindDeskProposalOperationKind,
        externalAction: WorkbenchExternalAction,
        isProposalOperation: Bool,
        requiresTarget: Bool,
        supportedTargetKinds: [WorkbenchObjectKind],
        requiredPayloadFields: [MindDeskAgentOperationPayloadField],
        allowedPayloadFields: [MindDeskAgentOperationPayloadField],
        payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema],
        policyDecisions: [MindDeskExtensionCapabilityPolicyDecision],
        notes: [String]
    ) {
        self.id = id
        self.title = title
        self.operationKind = operationKind
        self.externalAction = externalAction
        self.isProposalOperation = isProposalOperation
        self.requiresTarget = requiresTarget
        self.supportedTargetKinds = supportedTargetKinds
        self.requiredPayloadFields = requiredPayloadFields
        self.allowedPayloadFields = allowedPayloadFields
        self.payloadFieldSchemas = payloadFieldSchemas
        self.policyDecisions = policyDecisions
        self.notes = notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.operationKind = try container.decode(MindDeskProposalOperationKind.self, forKey: .operationKind)
        self.externalAction = try container.decode(WorkbenchExternalAction.self, forKey: .externalAction)
        self.isProposalOperation = try container.decode(Bool.self, forKey: .isProposalOperation)
        self.requiresTarget = try container.decode(Bool.self, forKey: .requiresTarget)
        self.supportedTargetKinds = try container.decode([WorkbenchObjectKind].self, forKey: .supportedTargetKinds)
        self.requiredPayloadFields = try container.decode([MindDeskAgentOperationPayloadField].self, forKey: .requiredPayloadFields)
        self.allowedPayloadFields = try container.decode([MindDeskAgentOperationPayloadField].self, forKey: .allowedPayloadFields)
        self.payloadFieldSchemas = try container.decode([MindDeskAgentOperationPayloadFieldSchema].self, forKey: .payloadFieldSchemas)
        self.policyDecisions = try container.decode([MindDeskExtensionCapabilityPolicyDecision].self, forKey: .policyDecisions)
        self.notes = try container.decode([String].self, forKey: .notes)
    }
}

public struct MindDeskExtensionCapabilityPolicyDecision: Codable, Equatable, Sendable {
    public var actor: WorkbenchExternalActor
    public var decision: WorkbenchExternalActionDecision
    public var riskTier: MindDeskProposalOperationRiskTier
    public var requiresUserMediation: Bool

    public init(
        actor: WorkbenchExternalActor,
        decision: WorkbenchExternalActionDecision,
        riskTier: MindDeskProposalOperationRiskTier,
        requiresUserMediation: Bool
    ) {
        self.actor = actor
        self.decision = decision
        self.riskTier = riskTier
        self.requiresUserMediation = requiresUserMediation
    }
}

public enum MindDeskExtensionCapabilityCatalogValidationIssue: Equatable, Hashable, Sendable {
    case unsupportedCatalogFormat(String)
    case unsupportedCatalogFormatVersion(Int)
    case capabilitySetMismatch
    case duplicateCapabilityID(String)
    case duplicateOperationKind(MindDeskProposalOperationKind)
    case operationContractMismatch(operationKind: MindDeskProposalOperationKind)
    case policyDecisionMismatch(operationKind: MindDeskProposalOperationKind)
    case catalogAuthorityMismatch
    case catalogNotesMissingAuthorityBoundary
}

public enum MindDeskExtensionCapabilityCatalogValidation {
    private static let frozenOperationKinds: [MindDeskProposalOperationKind] = [
        .openObject,
        .revealObject,
        .openURL,
        .copyPath,
        .openTerminal,
        .runCommand,
        .createFinderAlias,
        .applyMindDeskChange,
        .readAgentContext,
        .proposeAgentAction
    ]

    public static func issues(
        in catalog: MindDeskExtensionCapabilityCatalog
    ) -> [MindDeskExtensionCapabilityCatalogValidationIssue] {
        var issues: [MindDeskExtensionCapabilityCatalogValidationIssue] = []
        if catalog.format != MindDeskExtensionCapabilityCatalog.currentFormat {
            issues.append(.unsupportedCatalogFormat(catalog.format))
        }
        if catalog.formatVersion != MindDeskExtensionCapabilityCatalog.currentFormatVersion {
            issues.append(.unsupportedCatalogFormatVersion(catalog.formatVersion))
        }
        if catalog.authorizesSideEffects {
            issues.append(.catalogAuthorityMismatch)
        }

        let actualKinds = Set(catalog.capabilities.map(\.operationKind))
        if actualKinds != Set(frozenOperationKinds) {
            issues.append(.capabilitySetMismatch)
        }

        appendDuplicateIDIssues(catalog.capabilities, issues: &issues)
        appendDuplicateKindIssues(catalog.capabilities, issues: &issues)

        let actualByKind = Dictionary(
            catalog.capabilities.map { ($0.operationKind, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for kind in frozenOperationKinds {
            guard let actual = actualByKind[kind] else { continue }
            if !matchesFrozenOperationContract(actual, kind: kind) {
                issues.append(.operationContractMismatch(operationKind: kind))
            }
            if actual.policyDecisions != frozenPolicyDecisions(for: kind) {
                issues.append(.policyDecisionMismatch(operationKind: kind))
            }
        }

        let notes = catalog.notes.joined(separator: " ").lowercased()
        for required in [
            "not authorization",
            "helptopics",
            "custom guidance",
            "agentguide",
            "agentintegrationcontract",
            "agentpolicy",
            "externalactionpolicy",
            "validationreport",
            "policydecisions",
            "target requirements",
            "allowed payload fields",
            "payloadfieldschemas",
            "proposal review gate",
            "in-app confirmation"
        ] where !notes.contains(required) {
            issues.append(.catalogNotesMissingAuthorityBoundary)
            break
        }
        return issues
    }

    private static func appendDuplicateIDIssues(
        _ capabilities: [MindDeskExtensionCapability],
        issues: inout [MindDeskExtensionCapabilityCatalogValidationIssue]
    ) {
        var seen: Set<String> = []
        for id in capabilities.map(\.id) where !seen.insert(id).inserted {
            issues.append(.duplicateCapabilityID(id))
        }
    }

    private static func appendDuplicateKindIssues(
        _ capabilities: [MindDeskExtensionCapability],
        issues: inout [MindDeskExtensionCapabilityCatalogValidationIssue]
    ) {
        var seen: Set<MindDeskProposalOperationKind> = []
        for kind in capabilities.map(\.operationKind) where !seen.insert(kind).inserted {
            issues.append(.duplicateOperationKind(kind))
        }
    }

    private static func matchesFrozenOperationContract(
        _ capability: MindDeskExtensionCapability,
        kind: MindDeskProposalOperationKind
    ) -> Bool {
        let expected = frozenOperationContract(for: kind)
        return capability.id == "proposal.\(kind.rawValue)" &&
            capability.title == expected.title &&
            capability.operationKind == kind &&
            capability.externalAction == expected.externalAction &&
            capability.isProposalOperation == expected.isProposalOperation &&
            capability.requiresTarget == expected.requiresTarget &&
            capability.supportedTargetKinds == expected.supportedTargetKinds &&
            capability.requiredPayloadFields == expected.requiredPayloadFields &&
            capability.allowedPayloadFields == expected.allowedPayloadFields &&
            capability.payloadFieldSchemas == expected.payloadFieldSchemas &&
            capability.notes == expected.notes
    }

    private static func frozenOperationContract(
        for kind: MindDeskProposalOperationKind
    ) -> (
        title: String,
        externalAction: WorkbenchExternalAction,
        isProposalOperation: Bool,
        requiresTarget: Bool,
        supportedTargetKinds: [WorkbenchObjectKind],
        requiredPayloadFields: [MindDeskAgentOperationPayloadField],
        allowedPayloadFields: [MindDeskAgentOperationPayloadField],
        payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema],
        notes: [String]
    ) {
        let proposalNotes = [
            "This capability may appear only as a proposal operation from the default agent.",
            "Use policyDecisions to understand actor policy, but execution is not authorized by the catalog.",
            "The Proposal Review gate and in-app confirmation are required before any side effect; user confirmation remains mandatory."
        ]
        let metaNotes = [
            "This meta action describes agent workflow and cannot be proposed inside a proposal envelope.",
            "It does not authorize file, Finder, URL, clipboard, Terminal, command, alias, import/export, or apply side effects.",
            "It does not bypass the Proposal Review gate or in-app confirmation."
        ]
        switch kind {
        case .openObject:
            return ("Open Object", .openFileSystemItem, true, true, [.workspace, .resourcePin, .snippet, .webURL], [], [], [], proposalNotes)
        case .revealObject:
            return ("Reveal In Finder", .revealInFinder, true, true, [.workspace, .resourcePin, .snippet, .webURL], [], [], [], proposalNotes)
        case .openURL:
            return ("Open URL", .openURL, true, false, [], [.url], [.url], [schema(.url, .url, true)], proposalNotes)
        case .copyPath:
            return ("Copy Path", .copyPathToClipboard, true, true, [.resourcePin], [], [], [], proposalNotes)
        case .openTerminal:
            return ("Open Terminal", .openTerminal, true, false, [], [.workingDirectory], [.workingDirectory], [schema(.workingDirectory, .workbenchObjectReference, true)], proposalNotes)
        case .runCommand:
            return ("Run Command", .runCommand, true, false, [], [.command], [.command, .workingDirectory], [schema(.command, .string, true), schema(.workingDirectory, .workbenchObjectReference, false)], proposalNotes)
        case .createFinderAlias:
            return ("Create Finder Alias", .createFinderAlias, true, true, [.resourcePin, .snippet], [], [], [], proposalNotes)
        case .applyMindDeskChange:
            return ("Apply MindDesk Change", .applyAgentAction, true, false, [], [.proposedText], [.proposedText], [schema(.proposedText, .string, true)], proposalNotes)
        case .readAgentContext:
            return ("Read Agent Context", .readAgentContext, false, false, [], [], [], [], metaNotes)
        case .proposeAgentAction:
            return ("Propose Agent Action", .proposeAgentAction, false, false, [], [], [], [], metaNotes)
        }
    }

    private static func schema(
        _ field: MindDeskAgentOperationPayloadField,
        _ valueShape: MindDeskAgentOperationPayloadValueShape,
        _ required: Bool
    ) -> MindDeskAgentOperationPayloadFieldSchema {
        MindDeskAgentOperationPayloadFieldSchema(
            field: field,
            valueShape: valueShape,
            required: required
        )
    }

    private static func frozenPolicyDecisions(
        for kind: MindDeskProposalOperationKind
    ) -> [MindDeskExtensionCapabilityPolicyDecision] {
        switch kind {
        case .readAgentContext, .proposeAgentAction:
            return [
                policy(.directUser, .allow, .readOnly, false),
                policy(.defaultAgent, .allow, .readOnly, false),
                policy(.approvedAgent, .allow, .readOnly, false)
            ]
        case .openObject, .revealObject, .openURL, .copyPath:
            return [
                policy(.directUser, .requireExplicitUserIntent, .userMediated, true),
                policy(.defaultAgent, .deny, .denied, true),
                policy(.approvedAgent, .requireModalConfirmation, .confirmationRequired, true)
            ]
        case .openTerminal, .runCommand, .createFinderAlias, .applyMindDeskChange:
            return [
                policy(.directUser, .requireModalConfirmation, .confirmationRequired, true),
                policy(.defaultAgent, .deny, .denied, true),
                policy(.approvedAgent, .requireModalConfirmation, .confirmationRequired, true)
            ]
        }
    }

    private static func policy(
        _ actor: WorkbenchExternalActor,
        _ decision: WorkbenchExternalActionDecision,
        _ riskTier: MindDeskProposalOperationRiskTier,
        _ requiresUserMediation: Bool
    ) -> MindDeskExtensionCapabilityPolicyDecision {
        MindDeskExtensionCapabilityPolicyDecision(
            actor: actor,
            decision: decision,
            riskTier: riskTier,
            requiresUserMediation: requiresUserMediation
        )
    }
}
