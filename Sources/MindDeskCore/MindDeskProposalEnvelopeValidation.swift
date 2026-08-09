import Foundation

struct MindDeskAnyCodingKey: CodingKey {
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

enum MindDeskProposalDecodeLimitGuards {
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
                            .metaActionCannotBeProposed(operationID: operation.id, action: externalAction(for: operation.kind)),
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
        switch kind {
        case .openURL:
            return ["url"]
        case .runCommand:
            return ["command", "workingDirectory"]
        case .openTerminal:
            return ["workingDirectory"]
        case .applyMindDeskChange:
            return ["proposedText"]
        case .openObject,
             .revealObject,
             .copyPath,
             .createFinderAlias,
             .readAgentContext,
             .proposeAgentAction:
            return []
        }
    }

    private static func externalAction(
        for kind: MindDeskProposalOperationKind
    ) -> WorkbenchExternalAction {
        switch kind {
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
