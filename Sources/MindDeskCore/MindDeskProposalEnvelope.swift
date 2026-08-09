import Foundation

public struct MindDeskProposalEnvelope: Codable, Equatable, Identifiable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case format
        case formatVersion
        case createdAt
        case proposedBy
        case context
        case proposals
    }

    public static let currentFormat = "minddesk.proposal.envelope"
    public static let currentFormatVersion = 1

    public var id: String
    public var format: String
    public var formatVersion: Int
    public var createdAt: Date
    public var proposedBy: WorkbenchExternalActor
    public var context: MindDeskProposalContextSnapshot
    public var proposals: [MindDeskProposal]

    public init(
        id: String,
        createdAt: Date,
        proposedBy: WorkbenchExternalActor,
        context: MindDeskProposalContextSnapshot,
        proposals: [MindDeskProposal],
        format: String = MindDeskProposalEnvelope.currentFormat,
        formatVersion: Int = MindDeskProposalEnvelope.currentFormatVersion
    ) {
        self.id = id
        self.format = format
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.proposedBy = proposedBy
        self.context = context
        self.proposals = proposals
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        let formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard format == Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription: "Unsupported proposal envelope format."
            )
        }
        guard formatVersion == Self.currentFormatVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .formatVersion,
                in: container,
                debugDescription: "Unsupported proposal envelope format version."
            )
        }

        self.id = try container.decode(String.self, forKey: .id)
        self.format = format
        self.formatVersion = formatVersion
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.proposedBy = try container.decode(WorkbenchExternalActor.self, forKey: .proposedBy)
        self.context = try container.decode(MindDeskProposalContextSnapshot.self, forKey: .context)
        self.proposals = try MindDeskProposalDecodeLimitGuards.decodeLimitedArray(
            from: container,
            forKey: .proposals,
            maximumCount: MindDeskProposalEnvelopeValidation.maximumProposalCount,
            diagnostic: { count, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .tooManyProposals(count: count, maximum: maximum),
                    path: "/proposals",
                    details: MindDeskProposalDecodeLimitGuards.limitDetails(
                        count: count,
                        maximum: maximum
                    )
                )
            }
        )
    }
}

public enum ProposalImportLimits {
    public static let maximumProposalEnvelopeBytes = 16 * 1024 * 1024
    public static let maximumSourcePackageBytes = ManifestImportLimits.maximumManifestBytes
    public static let proposalEnvelopeByteLimitDescription = "16 MiB"
    public static let sourcePackageByteLimitDescription = "64 MiB"

    public static func byteLimitDescription(for maximumBytes: Int) -> String {
        let mib = 1024 * 1024
        if maximumBytes > 0, maximumBytes % mib == 0 {
            return "\(maximumBytes / mib) MiB"
        }
        return "\(maximumBytes) bytes"
    }
}

public struct MindDeskProposalEnvelopeDecodeLimitError: Error, CustomStringConvertible, LocalizedError, Sendable {
    public var diagnostics: [MindDeskProposalValidationDiagnostic]

    public var description: String {
        "MindDesk proposal envelope exceeded proposal limits."
    }

    public var errorDescription: String? {
        description
    }

    public init(diagnostics: [MindDeskProposalValidationDiagnostic]) {
        self.diagnostics = diagnostics
    }

    public init(_ diagnostic: MindDeskProposalValidationDiagnostic) {
        self.diagnostics = [diagnostic]
    }
}

public struct MindDeskProposalContextSnapshot: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case packageFormat
        case packageFormatVersion
        case packageInstanceID
        case packageCreatedAt
        case manifestSchemaVersion
        case manifestExportedAt
        case manifestDigest
    }

    public var packageFormat: String
    public var packageFormatVersion: Int
    public var packageInstanceID: String
    public var packageCreatedAt: Date
    public var manifestSchemaVersion: Int
    public var manifestExportedAt: Date
    public var manifestDigest: MindDeskProposalContextDigest

    public init(
        packageFormat: String,
        packageFormatVersion: Int,
        packageInstanceID: String,
        packageCreatedAt: Date,
        manifestSchemaVersion: Int,
        manifestExportedAt: Date,
        manifestDigest: MindDeskProposalContextDigest
    ) {
        self.packageFormat = packageFormat
        self.packageFormatVersion = packageFormatVersion
        self.packageInstanceID = packageInstanceID
        self.packageCreatedAt = packageCreatedAt
        self.manifestSchemaVersion = manifestSchemaVersion
        self.manifestExportedAt = manifestExportedAt
        self.manifestDigest = manifestDigest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.packageFormat = try container.decode(String.self, forKey: .packageFormat)
        self.packageFormatVersion = try container.decode(Int.self, forKey: .packageFormatVersion)
        self.packageInstanceID = try container.decode(String.self, forKey: .packageInstanceID)
        self.packageCreatedAt = try container.decode(Date.self, forKey: .packageCreatedAt)
        self.manifestSchemaVersion = try container.decode(Int.self, forKey: .manifestSchemaVersion)
        self.manifestExportedAt = try container.decode(Date.self, forKey: .manifestExportedAt)
        self.manifestDigest = try container.decode(MindDeskProposalContextDigest.self, forKey: .manifestDigest)
    }
}

public struct MindDeskProposalContextDigest: Codable, Equatable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case algorithm
        case value
    }

    public var algorithm: String
    public var value: String

    public init?(algorithm: String, value: String) {
        let normalizedAlgorithm = algorithm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedAlgorithm == "sha256",
              normalizedValue.count == 64,
              normalizedValue.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (97...102).contains(byte)
              }) else {
            return nil
        }
        self.algorithm = normalizedAlgorithm
        self.value = normalizedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let algorithm = try container.decode(String.self, forKey: .algorithm)
        let value = try container.decode(String.self, forKey: .value)
        guard let digest = MindDeskProposalContextDigest(algorithm: algorithm, value: value) else {
            throw DecodingError.dataCorruptedError(
                forKey: .value,
                in: container,
                debugDescription: "Proposal context digest must be a sha256 hex digest."
            )
        }
        self = digest
    }
}

public struct MindDeskProposal: Codable, Equatable, Identifiable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case rationale
        case evidenceReferences
        case operations
    }

    public var id: String
    public var title: String
    public var rationale: String
    public var evidenceReferences: [WorkbenchObjectReference]
    public var operations: [MindDeskProposalOperation]

    public init(
        id: String,
        title: String,
        rationale: String,
        evidenceReferences: [WorkbenchObjectReference],
        operations: [MindDeskProposalOperation]
    ) {
        self.id = id
        self.title = title
        self.rationale = rationale
        self.evidenceReferences = evidenceReferences
        self.operations = operations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(String.self, forKey: .id)
        let decodedTitle = try MindDeskProposalDecodeLimitGuards.decodeString(
            from: container,
            forKey: .title,
            maximumBytes: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength,
            diagnostic: { actualLength, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .proposalTitleTooLong(
                        proposalID: decodedID,
                        actualLength: actualLength,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.title.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.textLimitDetails(
                        actualLength: actualLength,
                        maximum: maximum
                    )
                )
            }
        )
        let decodedRationale = try MindDeskProposalDecodeLimitGuards.decodeString(
            from: container,
            forKey: .rationale,
            maximumBytes: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength,
            diagnostic: { actualLength, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .proposalRationaleTooLong(
                        proposalID: decodedID,
                        actualLength: actualLength,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.rationale.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.textLimitDetails(
                        actualLength: actualLength,
                        maximum: maximum
                    )
                )
            }
        )
        let decodedEvidenceReferences: [WorkbenchObjectReference] = try MindDeskProposalDecodeLimitGuards.decodeLimitedArray(
            from: container,
            forKey: .evidenceReferences,
            maximumCount: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount,
            diagnostic: { count, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .tooManyProposalEvidenceReferences(
                        proposalID: decodedID,
                        count: count,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.evidenceReferences.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.limitDetails(
                        count: count,
                        maximum: maximum
                    )
                )
            }
        )
        let decodedOperations: [MindDeskProposalOperation] = try MindDeskProposalDecodeLimitGuards.decodeLimitedArray(
            from: container,
            forKey: .operations,
            maximumCount: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount,
            diagnostic: { count, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .tooManyProposalOperations(
                        proposalID: decodedID,
                        count: count,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.operations.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.limitDetails(
                        count: count,
                        maximum: maximum
                    )
                )
            }
        )

        self.id = decodedID
        self.title = decodedTitle
        self.rationale = decodedRationale
        self.evidenceReferences = decodedEvidenceReferences
        self.operations = decodedOperations
    }
}

public struct MindDeskProposalOperation: Codable, Equatable, Identifiable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case target
        case affectedObjects
        case payload
    }

    public var id: String
    public var kind: MindDeskProposalOperationKind
    public var title: String
    public var target: WorkbenchObjectReference?
    public var affectedObjects: [WorkbenchObjectReference]
    public var payload: MindDeskProposalOperationPayload

    public init(
        id: String,
        kind: MindDeskProposalOperationKind,
        title: String,
        target: WorkbenchObjectReference?,
        affectedObjects: [WorkbenchObjectReference],
        payload: MindDeskProposalOperationPayload
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.target = target
        self.affectedObjects = affectedObjects
        self.payload = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(String.self, forKey: .id)
        let decodedKind = try container.decode(MindDeskProposalOperationKind.self, forKey: .kind)
        let decodedTitle = try MindDeskProposalDecodeLimitGuards.decodeString(
            from: container,
            forKey: .title,
            maximumBytes: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength,
            diagnostic: { actualLength, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .operationTitleTooLong(
                        operationID: decodedID,
                        actualLength: actualLength,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.title.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.textLimitDetails(
                        actualLength: actualLength,
                        maximum: maximum
                    )
                )
            }
        )
        let decodedTarget = try container.decodeIfPresent(WorkbenchObjectReference.self, forKey: .target)
        let decodedAffectedObjects: [WorkbenchObjectReference] = try MindDeskProposalDecodeLimitGuards.decodeLimitedArray(
            from: container,
            forKey: .affectedObjects,
            maximumCount: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount,
            diagnostic: { count, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .tooManyOperationAffectedObjects(
                        operationID: decodedID,
                        count: count,
                        maximum: maximum
                    ),
                    path: MindDeskProposalDecodeLimitGuards.pointer(
                        from: decoder.codingPath,
                        appending: [CodingKeys.affectedObjects.rawValue]
                    ),
                    details: MindDeskProposalDecodeLimitGuards.limitDetails(
                        count: count,
                        maximum: maximum
                    )
                )
            }
        )
        let payloadBasePath = MindDeskProposalDecodeLimitGuards.pointer(
            from: decoder.codingPath,
            appending: [CodingKeys.payload.rawValue]
        )
        let decodedPayload = try MindDeskProposalOperationPayload.decodeLimitAware(
            from: container.superDecoder(forKey: .payload),
            operationID: decodedID,
            basePath: payloadBasePath
        )

        self.id = decodedID
        self.kind = decodedKind
        self.title = decodedTitle
        self.target = decodedTarget
        self.affectedObjects = decodedAffectedObjects
        self.payload = decodedPayload
    }
}

public enum MindDeskProposalOperationKind: String, Codable, CaseIterable, Sendable {
    case openObject
    case revealObject
    case openURL
    case copyPath
    case openTerminal
    case runCommand
    case createFinderAlias
    case applyMindDeskChange
    case readAgentContext
    case proposeAgentAction

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported proposal operation kind."
            )
        }
        self = value
    }

    var isMetaAction: Bool {
        switch self {
        case .readAgentContext, .proposeAgentAction:
            return true
        case .openObject,
             .revealObject,
             .openURL,
             .copyPath,
             .openTerminal,
             .runCommand,
             .createFinderAlias,
             .applyMindDeskChange:
            return false
        }
    }

    var requiresTarget: Bool {
        switch self {
        case .openObject, .revealObject, .copyPath, .createFinderAlias:
            return true
        case .openURL,
             .openTerminal,
             .runCommand,
             .applyMindDeskChange,
             .readAgentContext,
             .proposeAgentAction:
            return false
        }
    }

    func supportsTargetKind(_ kind: WorkbenchObjectKind) -> Bool {
        switch self {
        case .createFinderAlias:
            return WorkbenchObjectReferencePolicy.aliasSourceKinds.contains(kind)
        case .copyPath:
            return kind == .resourcePin
        case .openObject,
             .revealObject:
            return WorkbenchObjectReferencePolicy.actionableTargetKinds.contains(kind)
        case .openURL,
             .openTerminal,
             .runCommand,
             .applyMindDeskChange,
             .readAgentContext,
             .proposeAgentAction:
            return !requiresTarget
        }
    }
}

public enum MindDeskProposalOperationRiskTier: String, Codable, Equatable, Sendable {
    case readOnly
    case userMediated
    case confirmationRequired
    case denied

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported proposal operation risk tier."
            )
        }
        self = value
    }
}

public struct MindDeskProposalOperationPayload: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case url
        case command
        case workingDirectory
        case proposedText
    }

    public var url: String?
    public var command: String?
    public var workingDirectory: WorkbenchObjectReference?
    public var proposedText: String?
    public var unknownFieldNames: [String]

    public init(
        url: String? = nil,
        command: String? = nil,
        workingDirectory: WorkbenchObjectReference? = nil,
        proposedText: String? = nil,
        unknownFieldNames: [String] = []
    ) {
        self.url = url
        self.command = command
        self.workingDirectory = workingDirectory
        self.proposedText = proposedText
        self.unknownFieldNames = unknownFieldNames
    }

    public init(from decoder: Decoder) throws {
        let known = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try known.decodeIfPresent(String.self, forKey: .url)
        self.command = try known.decodeIfPresent(String.self, forKey: .command)
        self.workingDirectory = try known.decodeIfPresent(WorkbenchObjectReference.self, forKey: .workingDirectory)
        self.proposedText = try known.decodeIfPresent(String.self, forKey: .proposedText)

        let all = try decoder.container(keyedBy: MindDeskAnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map(\.rawValue))
        self.unknownFieldNames = all.allKeys
            .map(\.stringValue)
            .filter { !knownKeys.contains($0) }
            .sorted()
    }

    static func decodeLimitAware(
        from decoder: Decoder,
        operationID: String,
        basePath: String
    ) throws -> MindDeskProposalOperationPayload {
        let known = try decoder.container(keyedBy: CodingKeys.self)
        let url = try MindDeskProposalDecodeLimitGuards.decodePayloadStringIfPresent(
            from: known,
            forKey: .url,
            operationID: operationID,
            field: CodingKeys.url.rawValue,
            basePath: basePath
        )
        let command = try MindDeskProposalDecodeLimitGuards.decodePayloadStringIfPresent(
            from: known,
            forKey: .command,
            operationID: operationID,
            field: CodingKeys.command.rawValue,
            basePath: basePath
        )
        let proposedText = try MindDeskProposalDecodeLimitGuards.decodePayloadStringIfPresent(
            from: known,
            forKey: .proposedText,
            operationID: operationID,
            field: CodingKeys.proposedText.rawValue,
            basePath: basePath
        )
        let workingDirectory = try known.decodeIfPresent(WorkbenchObjectReference.self, forKey: .workingDirectory)

        let all = try decoder.container(keyedBy: MindDeskAnyCodingKey.self)
        let knownKeys = Set(CodingKeys.allCases.map(\.rawValue))
        let unknownFieldNames = all.allKeys
            .map(\.stringValue)
            .filter { !knownKeys.contains($0) }
            .sorted()

        return MindDeskProposalOperationPayload(
            url: url,
            command: command,
            workingDirectory: workingDirectory,
            proposedText: proposedText,
            unknownFieldNames: unknownFieldNames
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(proposedText, forKey: .proposedText)
    }

    func hasRequiredPayload(for kind: MindDeskProposalOperationKind) -> Bool {
        switch kind {
        case .openURL:
            guard let url else { return false }
            return WebCardURL.normalized(url) != nil
        case .runCommand:
            return command?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .openTerminal:
            return workingDirectory != nil
        case .applyMindDeskChange:
            return proposedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .openObject,
             .revealObject,
             .copyPath,
             .createFinderAlias,
             .readAgentContext,
             .proposeAgentAction:
            return true
        }
    }
}
