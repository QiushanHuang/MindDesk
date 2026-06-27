import Foundation

private struct MindDeskAnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

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
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported proposal operation kind."
        )
    }

    public var externalAction: WorkbenchExternalAction {
        switch self {
        case .openObject:
            return .openFileSystemItem
        case .revealObject:
            return .revealInFinder
        case .openURL:
            return .openURL
        case .copyPath:
            return .copyPathToClipboard
        case .openTerminal:
            return .openTerminal
        case .runCommand:
            return .runCommand
        case .createFinderAlias:
            return .createFinderAlias
        case .applyMindDeskChange:
            return .applyAgentAction
        case .readAgentContext:
            return .readAgentContext
        case .proposeAgentAction:
            return .proposeAgentAction
        }
    }

    public func riskTier(for actor: WorkbenchExternalActor) -> MindDeskProposalOperationRiskTier {
        switch WorkbenchExternalActionPolicy.decision(for: externalAction, actor: actor) {
        case .allow:
            return .readOnly
        case .requireExplicitUserIntent:
            return .userMediated
        case .requireModalConfirmation:
            return .confirmationRequired
        case .deny:
            return .denied
        }
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
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported proposal operation risk tier."
        )
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

    fileprivate static func decodeLimitAware(
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

private enum MindDeskProposalDecodeLimitGuards {
    static func decodeLimitedArray<Element, Key>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        maximumCount: Int,
        diagnostic: (Int, Int) -> MindDeskProposalValidationDiagnostic
    ) throws -> [Element] where Element: Decodable, Key: CodingKey {
        var values = try container.nestedUnkeyedContainer(forKey: key)
        if let count = values.count, count > maximumCount {
            throw MindDeskProposalEnvelopeDecodeLimitError(diagnostic(count, maximumCount))
        }

        var decoded: [Element] = []
        decoded.reserveCapacity(min(values.count ?? maximumCount, maximumCount))
        while !values.isAtEnd {
            if decoded.count >= maximumCount {
                throw MindDeskProposalEnvelopeDecodeLimitError(diagnostic(maximumCount + 1, maximumCount))
            }
            decoded.append(try values.decode(Element.self))
        }
        return decoded
    }

    static func decodeString<Key>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        maximumBytes: Int,
        diagnostic: (Int, Int) -> MindDeskProposalValidationDiagnostic
    ) throws -> String where Key: CodingKey {
        let value = try container.decode(String.self, forKey: key)
        try validateText(value, maximumBytes: maximumBytes, diagnostic: diagnostic)
        return value
    }

    static func decodePayloadStringIfPresent<Key>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        operationID: String,
        field: String,
        basePath: String
    ) throws -> String? where Key: CodingKey {
        guard let value = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        try validateText(
            value,
            maximumBytes: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength,
            diagnostic: { actualLength, maximum in
                MindDeskProposalValidationDiagnostic(
                    issue: .operationPayloadTooLong(
                        operationID: operationID,
                        field: field,
                        actualLength: actualLength,
                        maximum: maximum
                    ),
                    path: "\(basePath)/\(field)",
                    details: textLimitDetails(
                        actualLength: actualLength,
                        maximum: maximum,
                        extra: ["payloadField": field]
                    )
                )
            }
        )
        return value
    }

    static func pointer(from codingPath: [CodingKey], appending components: [String]) -> String {
        let pathComponents = codingPath.map { key in
            if let intValue = key.intValue {
                return String(intValue)
            }
            return key.stringValue
        } + components
        return "/" + pathComponents.joined(separator: "/")
    }

    static func limitDetails(
        count: Int,
        maximum: Int,
        extra: [String: String] = [:]
    ) -> [String: String] {
        extra.merging([
            "count": String(count),
            "maximum": String(maximum)
        ]) { current, _ in current }
    }

    static func textLimitDetails(
        actualLength: Int,
        maximum: Int,
        extra: [String: String] = [:]
    ) -> [String: String] {
        extra.merging([
            "actualLength": String(actualLength),
            "maximum": String(maximum)
        ]) { current, _ in current }
    }

    private static func validateText(
        _ value: String,
        maximumBytes: Int,
        diagnostic: (Int, Int) -> MindDeskProposalValidationDiagnostic
    ) throws {
        let actualLength = value.utf8.count
        guard actualLength <= maximumBytes else {
            throw MindDeskProposalEnvelopeDecodeLimitError(diagnostic(actualLength, maximumBytes))
        }
    }
}

public enum MindDeskProposalValidationIssue: Equatable, Hashable, Sendable {
    case emptyEnvelopeID
    case unsupportedEnvelopeFormat(String)
    case unsupportedEnvelopeFormatVersion(Int)
    case unsupportedContextPackageFormat(String)
    case unsupportedContextPackageFormatVersion(Int)
    case staleProposalContext
    case proposalCreatedBeforePackage(proposalCreatedAt: Date, packageCreatedAt: Date)
    case invalidProposer(WorkbenchExternalActor)
    case missingProposals
    case emptyProposalID
    case emptyProposalTitle(proposalID: String)
    case missingProposalEvidence(proposalID: String)
    case missingProposalOperations(proposalID: String)
    case duplicateProposalID(String)
    case tooManyProposals(count: Int, maximum: Int)
    case tooManyProposalEvidenceReferences(proposalID: String, count: Int, maximum: Int)
    case tooManyProposalOperations(proposalID: String, count: Int, maximum: Int)
    case proposalTitleTooLong(proposalID: String, actualLength: Int, maximum: Int)
    case proposalRationaleTooLong(proposalID: String, actualLength: Int, maximum: Int)
    case emptyOperationID
    case duplicateOperationID(proposalID: String, operationID: String)
    case tooManyOperationAffectedObjects(operationID: String, count: Int, maximum: Int)
    case operationTitleTooLong(operationID: String, actualLength: Int, maximum: Int)
    case operationPayloadTooLong(operationID: String, field: String, actualLength: Int, maximum: Int)
    case unexpectedOperationPayload(operationID: String, kind: MindDeskProposalOperationKind, field: String)
    case unknownOperationPayloadField(
        operationID: String,
        kind: MindDeskProposalOperationKind,
        fieldToken: String,
        fieldLength: Int
    )
    case missingOperationTarget(operationID: String, kind: MindDeskProposalOperationKind)
    case unsupportedOperationTarget(operationID: String, kind: MindDeskProposalOperationKind, targetKind: WorkbenchObjectKind)
    case unsupportedWorkingDirectory(operationID: String, kind: MindDeskProposalOperationKind, reference: WorkbenchObjectReference)
    case unresolvedManifestReference(ownerID: String, kind: WorkbenchObjectKind, id: String)
    case ambiguousManifestReference(ownerID: String, kind: WorkbenchObjectKind, id: String)
    case missingOperationPayload(operationID: String, kind: MindDeskProposalOperationKind)
    case metaActionCannotBeProposed(operationID: String, action: WorkbenchExternalAction)
}

public struct MindDeskProposalValidationDiagnostic: Equatable, Sendable {
    public var issue: MindDeskProposalValidationIssue
    public var path: String?
    public var details: [String: String]

    public init(
        issue: MindDeskProposalValidationIssue,
        path: String? = nil,
        details: [String: String] = [:]
    ) {
        self.issue = issue
        self.path = path
        self.details = details
    }
}

public enum MindDeskProposalEnvelopeValidation {
    public static let maximumProposalCount = 25
    public static let maximumProposalEvidenceReferenceCount = 50
    public static let maximumProposalOperationCount = 25
    public static let maximumOperationAffectedObjectCount = 50
    public static let maximumProposalTitleLength = 200
    public static let maximumProposalRationaleLength = 4_000
    public static let maximumOperationTitleLength = 200
    public static let maximumPayloadTextLength = 16_000

    public static func issues(in envelope: MindDeskProposalEnvelope) -> [MindDeskProposalValidationIssue] {
        diagnostics(in: envelope).map(\.issue)
    }

    public static func diagnostics(in envelope: MindDeskProposalEnvelope) -> [MindDeskProposalValidationDiagnostic] {
        var diagnostics: [MindDeskProposalValidationDiagnostic] = []
        if envelope.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(diagnostic(.emptyEnvelopeID, path: "/id"))
        }
        if envelope.format != MindDeskProposalEnvelope.currentFormat {
            diagnostics.append(diagnostic(.unsupportedEnvelopeFormat(envelope.format), path: "/format"))
        }
        if envelope.formatVersion != MindDeskProposalEnvelope.currentFormatVersion {
            diagnostics.append(diagnostic(.unsupportedEnvelopeFormatVersion(envelope.formatVersion), path: "/formatVersion"))
        }
        if envelope.context.packageFormat != MindDeskInterchangePackage.currentFormat {
            diagnostics.append(
                diagnostic(
                    .unsupportedContextPackageFormat(envelope.context.packageFormat),
                    path: "/context/packageFormat"
                )
            )
        }
        if envelope.context.packageFormatVersion != MindDeskInterchangePackage.currentFormatVersion {
            diagnostics.append(
                diagnostic(
                    .unsupportedContextPackageFormatVersion(envelope.context.packageFormatVersion),
                    path: "/context/packageFormatVersion"
                )
            )
        }
        if envelope.proposedBy != .defaultAgent {
            diagnostics.append(diagnostic(.invalidProposer(envelope.proposedBy), path: "/proposedBy"))
        }
        if envelope.proposals.isEmpty {
            diagnostics.append(diagnostic(.missingProposals, path: "/proposals"))
        }
        if envelope.proposals.count > maximumProposalCount {
            diagnostics.append(
                diagnostic(
                    .tooManyProposals(count: envelope.proposals.count, maximum: maximumProposalCount),
                    path: "/proposals",
                    details: limitDetails(count: envelope.proposals.count, maximum: maximumProposalCount)
                )
            )
        }

        var firstProposalIndexByID: [String: Int] = [:]
        for (proposalIndex, proposal) in envelope.proposals.prefix(maximumProposalCount).enumerated() {
            let proposalID = proposal.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if proposalID.isEmpty {
                diagnostics.append(
                    diagnostic(
                        .emptyProposalID,
                        path: "/proposals/\(proposalIndex)/id",
                        details: ["proposalIndex": String(proposalIndex)]
                    )
                )
            } else if let firstProposalIndex = firstProposalIndexByID[proposalID] {
                diagnostics.append(
                    diagnostic(
                        .duplicateProposalID(proposalID),
                        path: "/proposals/\(proposalIndex)/id",
                        details: [
                            "proposalIndex": String(proposalIndex),
                            "firstProposalIndex": String(firstProposalIndex),
                            "duplicateProposalIndex": String(proposalIndex),
                            "proposalIndexes": "\(firstProposalIndex),\(proposalIndex)"
                        ]
                    )
                )
            } else {
                firstProposalIndexByID[proposalID] = proposalIndex
            }
            if proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(
                    diagnostic(
                        .emptyProposalTitle(proposalID: proposal.id),
                        path: "/proposals/\(proposalIndex)/title",
                        details: ["proposalIndex": String(proposalIndex)]
                    )
                )
            }
            let proposalTitleLength = textLength(proposal.title)
            if proposalTitleLength > maximumProposalTitleLength {
                diagnostics.append(
                    diagnostic(
                        .proposalTitleTooLong(
                            proposalID: proposal.id,
                            actualLength: proposalTitleLength,
                            maximum: maximumProposalTitleLength
                        ),
                        path: "/proposals/\(proposalIndex)/title",
                        details: textLimitDetails(
                            length: proposalTitleLength,
                            maximum: maximumProposalTitleLength,
                            extra: ["proposalIndex": String(proposalIndex)]
                        )
                    )
                )
            }
            let rationaleLength = textLength(proposal.rationale)
            if rationaleLength > maximumProposalRationaleLength {
                diagnostics.append(
                    diagnostic(
                        .proposalRationaleTooLong(
                            proposalID: proposal.id,
                            actualLength: rationaleLength,
                            maximum: maximumProposalRationaleLength
                        ),
                        path: "/proposals/\(proposalIndex)/rationale",
                        details: textLimitDetails(
                            length: rationaleLength,
                            maximum: maximumProposalRationaleLength,
                            extra: ["proposalIndex": String(proposalIndex)]
                        )
                    )
                )
            }
            if proposal.evidenceReferences.isEmpty {
                diagnostics.append(
                    diagnostic(
                        .missingProposalEvidence(proposalID: proposal.id),
                        path: "/proposals/\(proposalIndex)/evidenceReferences",
                        details: ["proposalIndex": String(proposalIndex)]
                    )
                )
            }
            if proposal.evidenceReferences.count > maximumProposalEvidenceReferenceCount {
                diagnostics.append(
                    diagnostic(
                        .tooManyProposalEvidenceReferences(
                            proposalID: proposal.id,
                            count: proposal.evidenceReferences.count,
                            maximum: maximumProposalEvidenceReferenceCount
                        ),
                        path: "/proposals/\(proposalIndex)/evidenceReferences",
                        details: limitDetails(
                            count: proposal.evidenceReferences.count,
                            maximum: maximumProposalEvidenceReferenceCount,
                            extra: ["proposalIndex": String(proposalIndex)]
                        )
                    )
                )
            }
            if proposal.operations.isEmpty {
                diagnostics.append(
                    diagnostic(
                        .missingProposalOperations(proposalID: proposal.id),
                        path: "/proposals/\(proposalIndex)/operations",
                        details: ["proposalIndex": String(proposalIndex)]
                    )
                )
            }
            if proposal.operations.count > maximumProposalOperationCount {
                diagnostics.append(
                    diagnostic(
                        .tooManyProposalOperations(
                            proposalID: proposal.id,
                            count: proposal.operations.count,
                            maximum: maximumProposalOperationCount
                        ),
                        path: "/proposals/\(proposalIndex)/operations",
                        details: limitDetails(
                            count: proposal.operations.count,
                            maximum: maximumProposalOperationCount,
                            extra: ["proposalIndex": String(proposalIndex)]
                        )
                    )
                )
            }
            var firstOperationIndexByID: [String: Int] = [:]
            for (operationIndex, operation) in proposal.operations.prefix(maximumProposalOperationCount).enumerated() {
                let operationID = operation.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if operationID.isEmpty {
                    diagnostics.append(
                        diagnostic(
                            .emptyOperationID,
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/id",
                            details: [
                                "proposalIndex": String(proposalIndex),
                                "operationIndex": String(operationIndex)
                            ]
                        )
                    )
                } else if let firstOperationIndex = firstOperationIndexByID[operationID] {
                    diagnostics.append(
                        diagnostic(
                            .duplicateOperationID(proposalID: proposal.id, operationID: operationID),
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/id",
                            details: [
                                "proposalIndex": String(proposalIndex),
                                "operationIndex": String(operationIndex),
                                "firstOperationIndex": String(firstOperationIndex),
                                "duplicateOperationIndex": String(operationIndex),
                                "operationIndexes": "\(firstOperationIndex),\(operationIndex)"
                            ]
                        )
                    )
                } else {
                    firstOperationIndexByID[operationID] = operationIndex
                }
                let operationTitleLength = textLength(operation.title)
                if operationTitleLength > maximumOperationTitleLength {
                    diagnostics.append(
                        diagnostic(
                            .operationTitleTooLong(
                                operationID: operation.id,
                                actualLength: operationTitleLength,
                                maximum: maximumOperationTitleLength
                            ),
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/title",
                            details: textLimitDetails(
                                length: operationTitleLength,
                                maximum: maximumOperationTitleLength,
                                extra: [
                                    "proposalIndex": String(proposalIndex),
                                    "operationIndex": String(operationIndex)
                                ]
                            )
                        )
                    )
                }
                if operation.affectedObjects.count > maximumOperationAffectedObjectCount {
                    diagnostics.append(
                        diagnostic(
                            .tooManyOperationAffectedObjects(
                                operationID: operation.id,
                                count: operation.affectedObjects.count,
                                maximum: maximumOperationAffectedObjectCount
                            ),
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/affectedObjects",
                            details: limitDetails(
                                count: operation.affectedObjects.count,
                                maximum: maximumOperationAffectedObjectCount,
                                extra: [
                                    "proposalIndex": String(proposalIndex),
                                    "operationIndex": String(operationIndex)
                                ]
                            )
                        )
                    )
                }
                diagnostics.append(
                    contentsOf: oversizedPayloadDiagnostics(
                        for: operation,
                        proposalIndex: proposalIndex,
                        operationIndex: operationIndex
                    )
                )
                diagnostics.append(
                    contentsOf: unexpectedPayloadDiagnostics(
                        for: operation,
                        proposalIndex: proposalIndex,
                        operationIndex: operationIndex
                    )
                )
                diagnostics.append(
                    contentsOf: unknownPayloadFieldDiagnostics(
                        for: operation,
                        proposalIndex: proposalIndex,
                        operationIndex: operationIndex
                    )
                )
                if operation.kind.isMetaAction {
                    diagnostics.append(
                        diagnostic(
                            .metaActionCannotBeProposed(operationID: operation.id, action: operation.kind.externalAction),
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/kind",
                            details: [
                                "proposalIndex": String(proposalIndex),
                                "operationIndex": String(operationIndex)
                            ]
                        )
                    )
                }
                if operation.kind.requiresTarget {
                    if let target = operation.target {
                        if !operation.kind.supportsTargetKind(target.kind) {
                            diagnostics.append(
                                diagnostic(
                                    .unsupportedOperationTarget(
                                        operationID: operation.id,
                                        kind: operation.kind,
                                        targetKind: target.kind
                                    ),
                                    path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/target",
                                    details: [
                                        "proposalIndex": String(proposalIndex),
                                        "operationIndex": String(operationIndex)
                                    ]
                                )
                            )
                        }
                    } else {
                        diagnostics.append(
                            diagnostic(
                                .missingOperationTarget(operationID: operation.id, kind: operation.kind),
                                path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/target",
                                details: [
                                    "proposalIndex": String(proposalIndex),
                                    "operationIndex": String(operationIndex)
                                ]
                            )
                        )
                    }
                }
                if !operation.payload.hasRequiredPayload(for: operation.kind) {
                    let payloadField = payloadField(for: operation.kind) ?? "payload"
                    diagnostics.append(
                        diagnostic(
                            .missingOperationPayload(operationID: operation.id, kind: operation.kind),
                            path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload/\(payloadField)",
                            details: [
                                "proposalIndex": String(proposalIndex),
                                "operationIndex": String(operationIndex)
                            ]
                        )
                    )
                }
            }
        }

        return diagnostics
    }

    public static func issues(
        in envelope: MindDeskProposalEnvelope,
        currentContext: MindDeskProposalContextSnapshot
    ) -> [MindDeskProposalValidationIssue] {
        diagnostics(in: envelope, currentContext: currentContext).map(\.issue)
    }

    public static func diagnostics(
        in envelope: MindDeskProposalEnvelope,
        currentContext: MindDeskProposalContextSnapshot
    ) -> [MindDeskProposalValidationDiagnostic] {
        var diagnostics = diagnostics(in: envelope)
        if envelope.createdAt < currentContext.packageCreatedAt.addingTimeInterval(-300) {
            diagnostics.append(
                diagnostic(
                    .proposalCreatedBeforePackage(
                        proposalCreatedAt: envelope.createdAt,
                        packageCreatedAt: currentContext.packageCreatedAt
                    ),
                    path: "/createdAt"
                )
            )
        }
        if MindDeskProposalContextFreshness.isStale(proposal: envelope.context, current: currentContext) {
            diagnostics.append(diagnostic(.staleProposalContext, path: "/context"))
        }
        return diagnostics
    }

    public static func issues(
        in envelope: MindDeskProposalEnvelope,
        package: MindDeskInterchangePackage
    ) throws -> [MindDeskProposalValidationIssue] {
        try diagnostics(in: envelope, package: package).map(\.issue)
    }

    public static func diagnostics(
        in envelope: MindDeskProposalEnvelope,
        package: MindDeskInterchangePackage
    ) throws -> [MindDeskProposalValidationDiagnostic] {
        var diagnostics = diagnostics(
            in: envelope,
            currentContext: MindDeskProposalContextSnapshot(package: package)
        )
        let referenceIndex = WorkbenchObjectReferenceIndex(manifest: package.manifest)
        func appendReferenceIssue(
            ownerID: String,
            reference: WorkbenchObjectReference,
            path: String,
            details: [String: String]
        ) -> Bool {
            if referenceIndex.isAmbiguous(reference) {
                diagnostics.append(
                    diagnostic(
                        .ambiguousManifestReference(ownerID: ownerID, kind: reference.kind, id: reference.id),
                        path: path,
                        details: details
                    )
                )
                return false
            } else if !referenceIndex.contains(reference) {
                diagnostics.append(
                    diagnostic(
                        .unresolvedManifestReference(ownerID: ownerID, kind: reference.kind, id: reference.id),
                        path: path,
                        details: details
                    )
                )
                return false
            }
            return true
        }

        for (proposalIndex, proposal) in envelope.proposals.prefix(maximumProposalCount).enumerated() {
            for (referenceIndex, reference) in proposal.evidenceReferences
                .prefix(maximumProposalEvidenceReferenceCount)
                .enumerated() {
                _ = appendReferenceIssue(
                    ownerID: proposal.id,
                    reference: reference,
                    path: "/proposals/\(proposalIndex)/evidenceReferences/\(referenceIndex)",
                    details: [
                        "proposalIndex": String(proposalIndex),
                        "referenceIndex": String(referenceIndex),
                        "referenceRole": "evidenceReference"
                    ]
                )
            }
            for (operationIndex, operation) in proposal.operations.prefix(maximumProposalOperationCount).enumerated() {
                if let target = operation.target {
                    _ = appendReferenceIssue(
                        ownerID: operation.id,
                        reference: target,
                        path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/target",
                        details: [
                            "proposalIndex": String(proposalIndex),
                            "operationIndex": String(operationIndex),
                            "referenceRole": "target"
                        ]
                    )
                }
                for (referenceIndex, reference) in operation.affectedObjects
                    .prefix(maximumOperationAffectedObjectCount)
                    .enumerated() {
                    _ = appendReferenceIssue(
                        ownerID: operation.id,
                        reference: reference,
                        path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/affectedObjects/\(referenceIndex)",
                        details: [
                            "proposalIndex": String(proposalIndex),
                            "operationIndex": String(operationIndex),
                            "referenceIndex": String(referenceIndex),
                            "referenceRole": "affectedObject"
                        ]
                    )
                }
                if let workingDirectory = operation.payload.workingDirectory {
                    let workingDirectoryIsResolvable = appendReferenceIssue(
                        ownerID: operation.id,
                        reference: workingDirectory,
                        path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload/workingDirectory",
                        details: [
                            "proposalIndex": String(proposalIndex),
                            "operationIndex": String(operationIndex),
                            "referenceRole": "workingDirectory"
                        ]
                    )
                    if workingDirectoryIsResolvable,
                       operation.kind.usesWorkingDirectoryPayload,
                       !referenceIndex.isFolderResource(workingDirectory) {
                        diagnostics.append(
                            diagnostic(
                                .unsupportedWorkingDirectory(
                                    operationID: operation.id,
                                    kind: operation.kind,
                                    reference: workingDirectory
                                ),
                                path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload/workingDirectory",
                                details: [
                                    "proposalIndex": String(proposalIndex),
                                    "operationIndex": String(operationIndex),
                                    "referenceRole": "workingDirectory"
                                ]
                            )
                        )
                    }
                }
            }
        }
        return diagnostics
    }

    private static func diagnostic(
        _ issue: MindDeskProposalValidationIssue,
        path: String? = nil,
        details: [String: String] = [:]
    ) -> MindDeskProposalValidationDiagnostic {
        MindDeskProposalValidationDiagnostic(issue: issue, path: path, details: details)
    }

    private static func oversizedPayloadDiagnostics(
        for operation: MindDeskProposalOperation,
        proposalIndex: Int,
        operationIndex: Int
    ) -> [MindDeskProposalValidationDiagnostic] {
        [
            ("url", operation.payload.url),
            ("command", operation.payload.command),
            ("proposedText", operation.payload.proposedText)
        ].compactMap { field, value in
            guard let value else { return nil }
            let length = textLength(value)
            guard length > maximumPayloadTextLength else { return nil }
            return diagnostic(
                .operationPayloadTooLong(
                    operationID: operation.id,
                    field: field,
                    actualLength: length,
                    maximum: maximumPayloadTextLength
                ),
                path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload/\(field)",
                details: textLimitDetails(
                    length: length,
                    maximum: maximumPayloadTextLength,
                    extra: [
                        "proposalIndex": String(proposalIndex),
                        "operationIndex": String(operationIndex),
                        "payloadField": field
                    ]
                )
            )
        }
    }

    private static func unexpectedPayloadDiagnostics(
        for operation: MindDeskProposalOperation,
        proposalIndex: Int,
        operationIndex: Int
    ) -> [MindDeskProposalValidationDiagnostic] {
        let allowedFields = allowedPayloadFields(for: operation.kind)
        return presentPayloadFields(in: operation.payload).compactMap { field in
            guard !allowedFields.contains(field) else { return nil }
            return diagnostic(
                .unexpectedOperationPayload(
                    operationID: operation.id,
                    kind: operation.kind,
                    field: field
                ),
                path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload/\(field)",
                details: [
                    "proposalIndex": String(proposalIndex),
                    "operationIndex": String(operationIndex),
                    "kind": operation.kind.rawValue,
                    "payloadField": field
                ]
            )
        }
    }

    private static func unknownPayloadFieldDiagnostics(
        for operation: MindDeskProposalOperation,
        proposalIndex: Int,
        operationIndex: Int
    ) -> [MindDeskProposalValidationDiagnostic] {
        operation.payload.unknownFieldNames.map { field in
            let fieldToken = MindDeskValidationReportToken.token(field)
            return diagnostic(
                .unknownOperationPayloadField(
                    operationID: operation.id,
                    kind: operation.kind,
                    fieldToken: fieldToken,
                    fieldLength: field.count
                ),
                path: "/proposals/\(proposalIndex)/operations/\(operationIndex)/payload",
                details: [
                    "proposalIndex": String(proposalIndex),
                    "operationIndex": String(operationIndex),
                    "kind": operation.kind.rawValue,
                    "payloadFieldToken": fieldToken,
                    "payloadFieldLength": String(field.count)
                ]
            )
        }
    }

    private static func presentPayloadFields(in payload: MindDeskProposalOperationPayload) -> [String] {
        [
            ("url", payload.url != nil),
            ("command", payload.command != nil),
            ("workingDirectory", payload.workingDirectory != nil),
            ("proposedText", payload.proposedText != nil)
        ].compactMap { field, isPresent in
            isPresent ? field : nil
        }
    }

    private static func allowedPayloadFields(for kind: MindDeskProposalOperationKind) -> Set<String> {
        Set(MindDeskAgentOperationContract.allowedPayloadFields(for: kind).map(\.rawValue))
    }

    private static func textLength(_ value: String) -> Int {
        value.utf8.count
    }

    private static func limitDetails(
        count: Int,
        maximum: Int,
        extra: [String: String] = [:]
    ) -> [String: String] {
        extra.merging([
            "count": String(count),
            "maximum": String(maximum)
        ]) { current, _ in current }
    }

    private static func textLimitDetails(
        length: Int,
        maximum: Int,
        extra: [String: String] = [:]
    ) -> [String: String] {
        extra.merging([
            "actualLength": String(length),
            "maximum": String(maximum)
        ]) { current, _ in current }
    }

    private static func payloadField(for kind: MindDeskProposalOperationKind) -> String? {
        switch kind {
        case .openURL:
            return "url"
        case .runCommand:
            return "command"
        case .openTerminal:
            return "workingDirectory"
        case .applyMindDeskChange:
            return "proposedText"
        case .openObject,
             .revealObject,
             .copyPath,
             .createFinderAlias,
             .readAgentContext,
             .proposeAgentAction:
            return nil
        }
    }
}

private extension MindDeskProposalOperationKind {
    var usesWorkingDirectoryPayload: Bool {
        switch self {
        case .openTerminal, .runCommand:
            return true
        case .openObject,
             .revealObject,
             .openURL,
             .copyPath,
             .createFinderAlias,
             .applyMindDeskChange,
             .readAgentContext,
             .proposeAgentAction:
            return false
        }
    }
}

public enum MindDeskProposalReviewState: String, Codable, CaseIterable, Sendable {
    case pendingReview
    case approved
    case rejected
    case applied
    case expired
    case superseded

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported proposal review state."
        )
    }
}

public enum MindDeskProposalReviewEvent: String, Codable, CaseIterable, Sendable {
    case approve
    case reject
    case markApplied
    case expire
    case supersede

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported proposal review event."
        )
    }
}

public enum MindDeskProposalReviewPolicy {
    public static func nextState(
        from state: MindDeskProposalReviewState,
        event: MindDeskProposalReviewEvent,
        actor: WorkbenchExternalActor
    ) -> MindDeskProposalReviewState? {
        guard actor == .directUser else { return nil }
        switch (state, event) {
        case (.pendingReview, .approve):
            return .approved
        case (.approved, .approve):
            return nil
        case (.pendingReview, .reject), (.approved, .reject):
            return .rejected
        case (.pendingReview, .expire), (.approved, .expire):
            return .expired
        case (.pendingReview, .supersede), (.approved, .supersede):
            return .superseded
        case (.approved, .markApplied):
            return .applied
        case (.rejected, _),
             (.applied, _),
             (.expired, _),
             (.superseded, _),
             (.pendingReview, .markApplied):
            return nil
        }
    }
}

public enum MindDeskProposalContextFreshness {
    public static func mismatchedBindingFields(
        proposal: MindDeskProposalContextSnapshot,
        current: MindDeskProposalContextSnapshot
    ) -> [String] {
        var fields: [String] = []
        if proposal.packageFormat != current.packageFormat {
            fields.append("packageFormat")
        }
        if proposal.packageFormatVersion != current.packageFormatVersion {
            fields.append("packageFormatVersion")
        }
        if proposal.packageInstanceID != current.packageInstanceID {
            fields.append("packageInstanceID")
        }
        if proposal.packageCreatedAt != current.packageCreatedAt {
            fields.append("packageCreatedAt")
        }
        if proposal.manifestSchemaVersion != current.manifestSchemaVersion {
            fields.append("manifestSchemaVersion")
        }
        if proposal.manifestExportedAt != current.manifestExportedAt {
            fields.append("manifestExportedAt")
        }
        if proposal.manifestDigest != current.manifestDigest {
            fields.append("manifestDigest")
        }
        return fields
    }

    public static func isStale(
        proposal: MindDeskProposalContextSnapshot,
        current: MindDeskProposalContextSnapshot
    ) -> Bool {
        !mismatchedBindingFields(proposal: proposal, current: current).isEmpty
    }
}
