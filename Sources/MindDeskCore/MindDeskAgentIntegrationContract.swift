import Foundation

public enum MindDeskAgentAudience: String, Codable, CaseIterable, Sendable {
    case codex
    case genericAgent

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported agent audience."
            )
        }
        self = value
    }
}

public enum MindDeskAgentAuthorityMode: String, Codable, CaseIterable, Sendable {
    case advisoryOnly

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported agent authority mode."
            )
        }
        self = value
    }
}

public enum MindDeskAgentReferenceKind: String, Codable, CaseIterable, Sendable {
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
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported agent reference kind."
            )
        }
        self = value
    }
}

public enum MindDeskAgentOperationPayloadField: String, Codable, CaseIterable, Sendable {
    case url
    case command
    case workingDirectory
    case proposedText

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported agent operation payload field."
            )
        }
        self = value
    }
}

public enum MindDeskAgentOperationPayloadValueShape: String, Codable, CaseIterable, Sendable {
    case string
    case url
    case workbenchObjectReference

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported agent operation payload value shape."
            )
        }
        self = value
    }
}

public struct MindDeskAgentOperationPayloadFieldSchema: Codable, Equatable, Sendable {
    public var field: MindDeskAgentOperationPayloadField
    public var valueShape: MindDeskAgentOperationPayloadValueShape
    public var required: Bool

    public init(
        field: MindDeskAgentOperationPayloadField,
        valueShape: MindDeskAgentOperationPayloadValueShape,
        required: Bool
    ) {
        self.field = field
        self.valueShape = valueShape
        self.required = required
    }
}

public struct MindDeskAgentAuthorityContract: Codable, Equatable, Sendable {
    public var mode: MindDeskAgentAuthorityMode
    public var authorizesSideEffects: Bool
    public var enforcedBy: String
    public var promptAuthority: String

    public init(
        mode: MindDeskAgentAuthorityMode,
        authorizesSideEffects: Bool,
        enforcedBy: String,
        promptAuthority: String
    ) {
        self.mode = mode
        self.authorizesSideEffects = authorizesSideEffects
        self.enforcedBy = enforcedBy
        self.promptAuthority = promptAuthority
    }
}

public struct MindDeskAgentFileFormatContract: Codable, Equatable, Sendable {
    public var format: String
    public var currentFormatVersion: Int
    public var supportedFormatVersions: [Int]
    public var role: String

    public init(
        format: String,
        currentFormatVersion: Int,
        supportedFormatVersions: [Int],
        role: String
    ) {
        self.format = format
        self.currentFormatVersion = currentFormatVersion
        self.supportedFormatVersions = supportedFormatVersions
        self.role = role
    }
}

public struct MindDeskAgentProposalEnvelopeContract: Codable, Equatable, Sendable {
    public var format: String
    public var currentFormatVersion: Int
    public var supportedFormatVersions: [Int]
    public var requiredProposedBy: WorkbenchExternalActor
    public var contextBindingFields: [String]

    public init(
        format: String,
        currentFormatVersion: Int,
        supportedFormatVersions: [Int],
        requiredProposedBy: WorkbenchExternalActor,
        contextBindingFields: [String]
    ) {
        self.format = format
        self.currentFormatVersion = currentFormatVersion
        self.supportedFormatVersions = supportedFormatVersions
        self.requiredProposedBy = requiredProposedBy
        self.contextBindingFields = contextBindingFields
    }
}

public struct MindDeskAgentReferenceSchemas: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case wireShape
        case citationWireShape
        case proposalReferenceWireShape
        case proposalReferenceFields
        case citationReferenceKinds
        case proposalReferenceKinds
    }

    public var wireShape: String
    public var citationWireShape: String
    public var proposalReferenceWireShape: String
    public var proposalReferenceFields: [String]
    public var citationReferenceKinds: [MindDeskAgentReferenceKind]
    public var proposalReferenceKinds: [WorkbenchObjectKind]

    public init(
        wireShape: String,
        citationWireShape: String,
        proposalReferenceWireShape: String,
        proposalReferenceFields: [String],
        citationReferenceKinds: [MindDeskAgentReferenceKind],
        proposalReferenceKinds: [WorkbenchObjectKind]
    ) {
        self.wireShape = wireShape
        self.citationWireShape = citationWireShape
        self.proposalReferenceWireShape = proposalReferenceWireShape
        self.proposalReferenceFields = proposalReferenceFields
        self.citationReferenceKinds = citationReferenceKinds
        self.proposalReferenceKinds = proposalReferenceKinds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.wireShape = try container.decode(String.self, forKey: .wireShape)
        self.citationWireShape = try container.decode(String.self, forKey: .citationWireShape)
        self.proposalReferenceWireShape = try container.decode(String.self, forKey: .proposalReferenceWireShape)
        self.proposalReferenceFields = try container.decode([String].self, forKey: .proposalReferenceFields)
        self.citationReferenceKinds = try container.decode([MindDeskAgentReferenceKind].self, forKey: .citationReferenceKinds)
        self.proposalReferenceKinds = try container.decode([WorkbenchObjectKind].self, forKey: .proposalReferenceKinds)
    }
}

public struct MindDeskAgentOperationRiskContract: Codable, Equatable, Sendable {
    public var actor: WorkbenchExternalActor
    public var riskTier: MindDeskProposalOperationRiskTier

    public init(actor: WorkbenchExternalActor, riskTier: MindDeskProposalOperationRiskTier) {
        self.actor = actor
        self.riskTier = riskTier
    }
}

public struct MindDeskAgentOperationContract: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case externalAction
        case requiresTarget
        case supportedTargetKinds
        case requiredPayloadFields
        case allowedPayloadFields
        case payloadFieldSchemas
        case riskByActor
    }

    public var kind: MindDeskProposalOperationKind
    public var externalAction: WorkbenchExternalAction
    public var requiresTarget: Bool
    public var supportedTargetKinds: [WorkbenchObjectKind]
    public var requiredPayloadFields: [MindDeskAgentOperationPayloadField]
    public var allowedPayloadFields: [MindDeskAgentOperationPayloadField]
    public var payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema]
    public var riskByActor: [MindDeskAgentOperationRiskContract]

    public init(
        kind: MindDeskProposalOperationKind,
        externalAction: WorkbenchExternalAction,
        requiresTarget: Bool,
        supportedTargetKinds: [WorkbenchObjectKind],
        requiredPayloadFields: [MindDeskAgentOperationPayloadField],
        allowedPayloadFields: [MindDeskAgentOperationPayloadField],
        payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema],
        riskByActor: [MindDeskAgentOperationRiskContract]
    ) {
        self.kind = kind
        self.externalAction = externalAction
        self.requiresTarget = requiresTarget
        self.supportedTargetKinds = supportedTargetKinds
        self.requiredPayloadFields = requiredPayloadFields
        self.allowedPayloadFields = allowedPayloadFields
        self.payloadFieldSchemas = payloadFieldSchemas
        self.riskByActor = riskByActor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(MindDeskProposalOperationKind.self, forKey: .kind)
        self.externalAction = try container.decode(WorkbenchExternalAction.self, forKey: .externalAction)
        self.requiresTarget = try container.decode(Bool.self, forKey: .requiresTarget)
        self.supportedTargetKinds = try container.decode([WorkbenchObjectKind].self, forKey: .supportedTargetKinds)
        self.requiredPayloadFields = try container.decode([MindDeskAgentOperationPayloadField].self, forKey: .requiredPayloadFields)
        self.allowedPayloadFields = try container.decode([MindDeskAgentOperationPayloadField].self, forKey: .allowedPayloadFields)
        self.payloadFieldSchemas = try container.decode([MindDeskAgentOperationPayloadFieldSchema].self, forKey: .payloadFieldSchemas)
        self.riskByActor = try container.decode([MindDeskAgentOperationRiskContract].self, forKey: .riskByActor)
    }
}

public struct MindDeskAgentPromptTemplate: Codable, Equatable, Sendable {
    public var audience: MindDeskAgentAudience
    public var title: String
    public var body: String

    public init(audience: MindDeskAgentAudience, title: String, body: String) {
        self.audience = audience
        self.title = title
        self.body = body
    }
}

public struct MindDeskAgentReviewGateContract: Codable, Equatable, Sendable {
    public var reviewActor: WorkbenchExternalActor
    public var states: [MindDeskProposalReviewState]
    public var events: [MindDeskProposalReviewEvent]
    public var notes: [String]

    public init(
        reviewActor: WorkbenchExternalActor,
        states: [MindDeskProposalReviewState],
        events: [MindDeskProposalReviewEvent],
        notes: [String]
    ) {
        self.reviewActor = reviewActor
        self.states = states
        self.events = events
        self.notes = notes
    }
}

public struct MindDeskAgentIntegrationContract: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
        case createdAt
        case supportedAudiences
        case authority
        case interchangePackage
        case proposalEnvelope
        case context
        case referenceSchemas
        case operationContracts
        case actionPolicy
        case agentPolicy
        case guide
        case promptTemplates
        case reviewGate
    }

    public static let currentFormat = "minddesk.agent.integration.contract"
    public static let currentFormatVersion = 1

    public var format: String
    public var formatVersion: Int
    public var createdAt: Date
    public var supportedAudiences: [MindDeskAgentAudience]
    public var authority: MindDeskAgentAuthorityContract
    public var interchangePackage: MindDeskAgentFileFormatContract
    public var proposalEnvelope: MindDeskAgentProposalEnvelopeContract
    public var context: MindDeskProposalContextSnapshot
    public var referenceSchemas: MindDeskAgentReferenceSchemas
    public var operationContracts: [MindDeskAgentOperationContract]
    public var actionPolicy: MindDeskInterchangeExternalActionPolicy
    public var agentPolicy: MindDeskAgentPolicy
    public var guide: MindDeskAgentGuide
    public var promptTemplates: [MindDeskAgentPromptTemplate]
    public var reviewGate: MindDeskAgentReviewGateContract

    public init(
        format: String,
        formatVersion: Int,
        createdAt: Date,
        supportedAudiences: [MindDeskAgentAudience],
        authority: MindDeskAgentAuthorityContract,
        interchangePackage: MindDeskAgentFileFormatContract,
        proposalEnvelope: MindDeskAgentProposalEnvelopeContract,
        context: MindDeskProposalContextSnapshot,
        referenceSchemas: MindDeskAgentReferenceSchemas,
        operationContracts: [MindDeskAgentOperationContract],
        actionPolicy: MindDeskInterchangeExternalActionPolicy,
        agentPolicy: MindDeskAgentPolicy,
        guide: MindDeskAgentGuide,
        promptTemplates: [MindDeskAgentPromptTemplate],
        reviewGate: MindDeskAgentReviewGateContract
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.supportedAudiences = supportedAudiences
        self.authority = authority
        self.interchangePackage = interchangePackage
        self.proposalEnvelope = proposalEnvelope
        self.context = context
        self.referenceSchemas = referenceSchemas
        self.operationContracts = operationContracts
        self.actionPolicy = actionPolicy
        self.agentPolicy = agentPolicy
        self.guide = guide
        self.promptTemplates = promptTemplates
        self.reviewGate = reviewGate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        let formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard format == Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription: "Unsupported agent integration contract format."
            )
        }
        guard formatVersion == Self.currentFormatVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .formatVersion,
                in: container,
                debugDescription: "Unsupported agent integration contract format version."
            )
        }

        self.format = format
        self.formatVersion = formatVersion
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.supportedAudiences = try container.decode([MindDeskAgentAudience].self, forKey: .supportedAudiences)
        self.authority = try container.decode(MindDeskAgentAuthorityContract.self, forKey: .authority)
        self.interchangePackage = try container.decode(MindDeskAgentFileFormatContract.self, forKey: .interchangePackage)
        self.proposalEnvelope = try container.decode(MindDeskAgentProposalEnvelopeContract.self, forKey: .proposalEnvelope)
        self.context = try container.decode(MindDeskProposalContextSnapshot.self, forKey: .context)
        self.referenceSchemas = try container.decode(MindDeskAgentReferenceSchemas.self, forKey: .referenceSchemas)
        self.operationContracts = try container.decode([MindDeskAgentOperationContract].self, forKey: .operationContracts)
        self.actionPolicy = try container.decode(MindDeskInterchangeExternalActionPolicy.self, forKey: .actionPolicy)
        self.agentPolicy = try container.decode(MindDeskAgentPolicy.self, forKey: .agentPolicy)
        self.guide = try container.decode(MindDeskAgentGuide.self, forKey: .guide)
        self.promptTemplates = try container.decode([MindDeskAgentPromptTemplate].self, forKey: .promptTemplates)
        self.reviewGate = try container.decode(MindDeskAgentReviewGateContract.self, forKey: .reviewGate)
    }
}

public enum MindDeskAgentIntegrationContractValidationIssue: Equatable, Hashable, Sendable {
    case unsupportedContractFormat(String)
    case unsupportedContractFormatVersion(Int)
    case supportedAudiencesMismatch
    case authorityMismatch
    case referenceSchemasMismatch
    case proposalEnvelopeMismatch
    case operationContractMismatch
}

public enum MindDeskAgentIntegrationContractValidation {
    public static func issues(
        in contract: MindDeskAgentIntegrationContract
    ) -> [MindDeskAgentIntegrationContractValidationIssue] {
        var issues: [MindDeskAgentIntegrationContractValidationIssue] = []
        if contract.format != MindDeskAgentIntegrationContract.currentFormat {
            issues.append(.unsupportedContractFormat(contract.format))
        }
        if contract.formatVersion != MindDeskAgentIntegrationContract.currentFormatVersion {
            issues.append(.unsupportedContractFormatVersion(contract.formatVersion))
        }
        if contract.supportedAudiences.isEmpty {
            issues.append(.supportedAudiencesMismatch)
        }
        if contract.authority.authorizesSideEffects {
            issues.append(.authorityMismatch)
        }
        if contract.referenceSchemas.proposalReferenceFields.isEmpty {
            issues.append(.referenceSchemasMismatch)
        }
        if contract.proposalEnvelope.contextBindingFields.isEmpty {
            issues.append(.proposalEnvelopeMismatch)
        }
        if Set(contract.operationContracts.map(\.kind)).count != contract.operationContracts.count {
            issues.append(.operationContractMismatch)
        }
        return issues
    }
}
