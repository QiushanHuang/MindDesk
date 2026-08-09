import CryptoKit
import Foundation

public typealias MindDeskValidationSeverity = MindDeskInterchangeValidationSeverity

enum MindDeskValidationReportToken {
    static func token(_ value: String) -> String {
        let data = Data(value.utf8)
        let hash = SHA256.hash(data: data)
        let prefix = hash.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "sha256:\(prefix)"
    }

    static func stringDetails(
        tokenKey: String = "actualValueToken",
        lengthKey: String = "actualValueLength",
        kindKey: String? = "actualValueKind",
        value: String
    ) -> [String: String] {
        var details = [
            tokenKey: token(value),
            lengthKey: String(value.count)
        ]
        if let kindKey {
            details[kindKey] = "string"
        }
        return details
    }
}

public enum MindDeskValidationReportSource: String, Codable, CaseIterable, Sendable {
    case package
    case manifest
    case proposalEnvelope
    case agentIntegrationContract
    case extensionCapabilityCatalog

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported validation report source."
            )
        }
        self = value
    }
}

public struct MindDeskValidationReportIssue: Codable, Equatable, Sendable {
    public var source: MindDeskValidationReportSource
    public var code: String
    public var severity: MindDeskValidationSeverity
    public var message: String
    public var ownerKind: String?
    public var ownerID: String?
    public var field: String?
    public var path: String?
    public var helpTopicID: String?
    public var details: [String: String]

    public init(
        source: MindDeskValidationReportSource,
        code: String,
        severity: MindDeskValidationSeverity,
        message: String,
        ownerKind: String? = nil,
        ownerID: String? = nil,
        field: String? = nil,
        path: String? = nil,
        helpTopicID: String? = nil,
        details: [String: String] = [:]
    ) {
        self.source = source
        self.code = code
        self.severity = severity
        self.message = message
        self.ownerKind = ownerKind
        self.ownerID = ownerID
        self.field = field
        self.path = path
        self.helpTopicID = helpTopicID
        self.details = details
    }
}

public struct MindDeskValidationReportSummary: Codable, Equatable, Sendable {
    public var issueCount: Int
    public var errorCount: Int
    public var warningCount: Int
    public var isValid: Bool

    public init(
        issueCount: Int,
        errorCount: Int,
        warningCount: Int,
        isValid: Bool
    ) {
        self.issueCount = issueCount
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.isValid = isValid
    }

    init(issues: [MindDeskValidationReportIssue]) {
        self.init(
            issueCount: issues.count,
            errorCount: issues.filter { $0.severity == .error }.count,
            warningCount: issues.filter { $0.severity == .warning }.count,
            isValid: !issues.contains { $0.severity == .error }
        )
    }
}

public struct MindDeskValidationReportRedactionPolicy: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
        case manifestIssueOwnerID
        case manifestIssueIDDetails
        case unknownManifestIssueDetails
        case tokenFormat
        case locatorField
        case rawManifestRecordsRemainInPackage
        case messagesAreStatic
        case nonManifestUnsupportedFormatDetails
        case nonManifestReferenceIDDetails
        case nonManifestIssueOwnerID
        case tokenizedDetailKeys
        case rawSafeDetailKeys
    }

    public static let currentFormat = "minddesk.validation.redaction-policy"
    public static let currentFormatVersion = 1

    public var format: String
    public var formatVersion: Int
    public var manifestIssueOwnerID: String
    public var manifestIssueIDDetails: String
    public var unknownManifestIssueDetails: String
    public var tokenFormat: String
    public var locatorField: String
    public var rawManifestRecordsRemainInPackage: Bool
    public var messagesAreStatic: Bool
    public var nonManifestUnsupportedFormatDetails: String
    public var nonManifestReferenceIDDetails: String
    public var nonManifestIssueOwnerID: String
    public var tokenizedDetailKeys: [String]
    public var rawSafeDetailKeys: [String]

    public init(
        format: String,
        formatVersion: Int,
        manifestIssueOwnerID: String,
        manifestIssueIDDetails: String,
        unknownManifestIssueDetails: String,
        tokenFormat: String,
        locatorField: String,
        rawManifestRecordsRemainInPackage: Bool,
        messagesAreStatic: Bool,
        nonManifestUnsupportedFormatDetails: String,
        nonManifestReferenceIDDetails: String,
        nonManifestIssueOwnerID: String,
        tokenizedDetailKeys: [String],
        rawSafeDetailKeys: [String]
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.manifestIssueOwnerID = manifestIssueOwnerID
        self.manifestIssueIDDetails = manifestIssueIDDetails
        self.unknownManifestIssueDetails = unknownManifestIssueDetails
        self.tokenFormat = tokenFormat
        self.locatorField = locatorField
        self.rawManifestRecordsRemainInPackage = rawManifestRecordsRemainInPackage
        self.messagesAreStatic = messagesAreStatic
        self.nonManifestUnsupportedFormatDetails = nonManifestUnsupportedFormatDetails
        self.nonManifestReferenceIDDetails = nonManifestReferenceIDDetails
        self.nonManifestIssueOwnerID = nonManifestIssueOwnerID
        self.tokenizedDetailKeys = tokenizedDetailKeys
        self.rawSafeDetailKeys = rawSafeDetailKeys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            format: try container.decode(String.self, forKey: .format),
            formatVersion: try container.decode(Int.self, forKey: .formatVersion),
            manifestIssueOwnerID: try container.decode(String.self, forKey: .manifestIssueOwnerID),
            manifestIssueIDDetails: try container.decode(String.self, forKey: .manifestIssueIDDetails),
            unknownManifestIssueDetails: try container.decode(String.self, forKey: .unknownManifestIssueDetails),
            tokenFormat: try container.decode(String.self, forKey: .tokenFormat),
            locatorField: try container.decode(String.self, forKey: .locatorField),
            rawManifestRecordsRemainInPackage: try container.decode(Bool.self, forKey: .rawManifestRecordsRemainInPackage),
            messagesAreStatic: try container.decode(Bool.self, forKey: .messagesAreStatic),
            nonManifestUnsupportedFormatDetails: try container.decode(String.self, forKey: .nonManifestUnsupportedFormatDetails),
            nonManifestReferenceIDDetails: try container.decode(String.self, forKey: .nonManifestReferenceIDDetails),
            nonManifestIssueOwnerID: try container.decode(String.self, forKey: .nonManifestIssueOwnerID),
            tokenizedDetailKeys: try container.decode([String].self, forKey: .tokenizedDetailKeys),
            rawSafeDetailKeys: try container.decode([String].self, forKey: .rawSafeDetailKeys)
        )
    }
}

public struct MindDeskValidationReport: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
        case redactionPolicy
        case generatedAt
        case summary
        case issues
    }

    public static let currentFormat = "minddesk.validation.report"
    public static let currentFormatVersion = 1

    public var format: String
    public var formatVersion: Int
    public var redactionPolicy: MindDeskValidationReportRedactionPolicy
    public var generatedAt: Date
    public var summary: MindDeskValidationReportSummary
    public var issues: [MindDeskValidationReportIssue]

    public init(
        format: String,
        formatVersion: Int,
        redactionPolicy: MindDeskValidationReportRedactionPolicy,
        generatedAt: Date,
        summary: MindDeskValidationReportSummary,
        issues: [MindDeskValidationReportIssue]
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.redactionPolicy = redactionPolicy
        self.generatedAt = generatedAt
        self.summary = summary
        self.issues = issues
    }

    init(issues: [MindDeskValidationReportIssue], generatedAt: Date) {
        self.init(
            format: Self.currentFormat,
            formatVersion: Self.currentFormatVersion,
            redactionPolicy: mindDeskOrdinaryValidationRedactionPolicy(),
            generatedAt: generatedAt,
            summary: MindDeskValidationReportSummary(issues: issues),
            issues: issues
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        let formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard format == Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription: "Unsupported validation report format."
            )
        }
        guard formatVersion == Self.currentFormatVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .formatVersion,
                in: container,
                debugDescription: "Unsupported validation report format version."
            )
        }

        self.format = format
        self.formatVersion = formatVersion
        self.redactionPolicy = mindDeskSanitizedDecodedValidationReportPolicy(
            try container.decode(MindDeskValidationReportRedactionPolicy.self, forKey: .redactionPolicy)
        )
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.summary = try container.decode(MindDeskValidationReportSummary.self, forKey: .summary)
        self.issues = try container
            .decode([MindDeskValidationReportIssue].self, forKey: .issues)
            .map(mindDeskSanitizedDecodedValidationReportIssue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(redactionPolicy, forKey: .redactionPolicy)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(summary, forKey: .summary)
        try container.encode(issues, forKey: .issues)
    }
}

private func mindDeskSanitizedDecodedValidationReportPolicy(
    _ policy: MindDeskValidationReportRedactionPolicy
) -> MindDeskValidationReportRedactionPolicy {
    MindDeskValidationReportRedactionPolicy(
        format: mindDeskSanitizedLeaf(policy.format),
        formatVersion: policy.formatVersion,
        manifestIssueOwnerID: mindDeskSanitizedLeaf(policy.manifestIssueOwnerID),
        manifestIssueIDDetails: mindDeskSanitizedLeaf(policy.manifestIssueIDDetails),
        unknownManifestIssueDetails: mindDeskSanitizedLeaf(policy.unknownManifestIssueDetails),
        tokenFormat: mindDeskSanitizedLeaf(policy.tokenFormat),
        locatorField: mindDeskSanitizedLeaf(policy.locatorField),
        rawManifestRecordsRemainInPackage: policy.rawManifestRecordsRemainInPackage,
        messagesAreStatic: policy.messagesAreStatic,
        nonManifestUnsupportedFormatDetails: mindDeskSanitizedLeaf(policy.nonManifestUnsupportedFormatDetails),
        nonManifestReferenceIDDetails: mindDeskSanitizedLeaf(policy.nonManifestReferenceIDDetails),
        nonManifestIssueOwnerID: mindDeskSanitizedLeaf(policy.nonManifestIssueOwnerID),
        tokenizedDetailKeys: policy.tokenizedDetailKeys.map(mindDeskSanitizedLeaf),
        rawSafeDetailKeys: policy.rawSafeDetailKeys.map(mindDeskSanitizedLeaf)
    )
}

private func mindDeskSanitizedDecodedValidationReportIssue(
    _ issue: MindDeskValidationReportIssue
) -> MindDeskValidationReportIssue {
    var details = mindDeskSanitizedDecodedValidationReportDetails(issue.details)
    let ownerID: String?
    if let rawOwnerID = issue.ownerID, mindDeskValueContainsUnsafeAgentText(rawOwnerID) {
        ownerID = MindDeskValidationReportToken.token(rawOwnerID)
        details["ownerIDLength"] = String(rawOwnerID.count)
    } else {
        ownerID = issue.ownerID
    }

    let message: String
    if mindDeskValueContainsUnsafeAgentText(issue.message) {
        message = issue.source == .manifest
            ? MindDeskManifestValidationReport.message(for: issue.code)
            : "Validation report issue."
    } else {
        message = issue.message
    }

    return MindDeskValidationReportIssue(
        source: issue.source,
        code: mindDeskSafeStructuralValue(issue.code) ?? "validation.issue",
        severity: issue.severity,
        message: message,
        ownerKind: mindDeskSafeStructuralValue(issue.ownerKind),
        ownerID: ownerID,
        field: mindDeskSafeStructuralValue(issue.field),
        path: mindDeskSafePathValue(issue.path),
        helpTopicID: mindDeskSafeStructuralValue(issue.helpTopicID),
        details: details
    )
}

private func mindDeskSanitizedDecodedValidationReportDetails(
    _ rawDetails: [String: String]
) -> [String: String] {
    let entries = rawDetails.compactMap { rawKey, value -> (
        key: String,
        value: String,
        valueIsUnsafe: Bool,
        producerPriority: Int
    )? in
        guard let key = mindDeskSafeDetailKey(rawKey) else { return nil }
        let valueIsUnsafe = mindDeskValueContainsUnsafeAgentText(value)
        let producerPriority = valueIsUnsafe
            ? (key.hasSuffix("Token") ? 1 : 0)
            : 2
        return (
            key: key,
            value: value,
            valueIsUnsafe: valueIsUnsafe,
            producerPriority: producerPriority
        )
    }.sorted { lhs, rhs in
        if lhs.producerPriority != rhs.producerPriority {
            return lhs.producerPriority < rhs.producerPriority
        }
        return lhs.key.utf8.lexicographicallyPrecedes(rhs.key.utf8)
    }

    var details: [String: String] = [:]
    var reservedKeys: Set<String> = []
    for entry in entries {
        if entry.valueIsUnsafe {
            let derivedDetails = mindDeskDerivedDecodedReportDetails(
                key: entry.key,
                value: entry.value
            )
            for (key, value) in derivedDetails where reservedKeys.insert(key).inserted {
                details[key] = value
            }
        } else if reservedKeys.insert(entry.key).inserted {
            details[entry.key] = entry.value
        }
    }
    return details
}

private func mindDeskDerivedDecodedReportDetails(
    key: String,
    value: String
) -> [(key: String, value: String)] {
    let token = MindDeskValidationReportToken.token(value)
    if mindDeskDecodedReportIdentifierDetailKeys.contains(key) {
        return [
            (key, token),
            ("\(key)Length", String(value.count))
        ]
    }
    if key.hasSuffix("Token") {
        return [(key, token)]
    }
    return [
        ("\(key)Token", token),
        ("\(key)Length", String(value.count))
    ]
}

private let mindDeskDecodedReportIdentifierDetailKeys: Set<String> = [
    "duplicateID",
    "referencedOwnerID",
    "ownerWorkspaceID",
    "referencedWorkspaceID",
    "ownerCanvasID",
    "referencedCanvasID",
    "canvasID",
    "reportedNodeID"
]

private func mindDeskSafeStructuralValue(_ value: String?) -> String? {
    guard let value, !mindDeskValueContainsUnsafeAgentText(value) else { return nil }
    return value
}

private func mindDeskSafePathValue(_ value: String?) -> String? {
    guard let value,
          value.hasPrefix("/"),
          !mindDeskValueContainsUnsafeAgentText(value)
    else { return nil }
    return value
}

private func mindDeskSafeDetailKey(_ key: String) -> String? {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    guard !key.isEmpty,
          key.rangeOfCharacter(from: allowed.inverted) == nil,
          !mindDeskValueContainsUnsafeAgentText(key)
    else { return nil }
    return key
}

private func mindDeskSanitizedLeaf(_ value: String) -> String {
    mindDeskValueContainsUnsafeAgentText(value)
        ? MindDeskValidationReportToken.token(value)
        : value
}

private func mindDeskValueContainsUnsafeAgentText(_ value: String) -> Bool {
    if value.unicodeScalars.contains(where: { scalar in
        scalar.properties.generalCategory == .control ||
            scalar.properties.generalCategory == .format ||
            scalar.properties.isDefaultIgnorableCodePoint
    }) {
        return true
    }

    let folded = value.folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
    if mindDeskContainsTokenAssignment(in: folded) || mindDeskContainsHTTPURL(in: folded) {
        return true
    }

    let tokens = mindDeskAgentTextTokens(in: folded)
    let containsProtectedObject = tokens.contains { mindDeskProtectedAgentTextObjects.contains($0) }
    if containsProtectedObject && tokens.contains(where: { mindDeskInstructionOverrideVerbs.contains($0) }) {
        return true
    }
    return containsProtectedObject &&
        tokens.contains("instead") &&
        tokens.contains(where: { mindDeskInstructionFollowVerbs.contains($0) })
}

private let mindDeskInstructionOverrideVerbs: Set<String> = [
    "ignore", "ignored", "ignores", "ignoring",
    "disregard", "disregarded", "disregards", "disregarding",
    "override", "overrode", "overridden", "overrides", "overriding",
    "bypass", "bypassed", "bypasses", "bypassing",
    "forget", "forgets", "forgetting", "forgot", "forgotten",
    "replace", "replaced", "replaces", "replacing"
]

private let mindDeskInstructionFollowVerbs: Set<String> = [
    "follow", "followed", "following", "follows"
]

private let mindDeskProtectedAgentTextObjects: Set<String> = [
    "instruction", "instructions",
    "directive", "directives",
    "direction", "directions",
    "validation",
    "policy", "policies",
    "safety",
    "confirmation", "confirmations",
    "rule", "rules",
    "guardrail", "guardrails",
    "restriction", "restrictions"
]

private func mindDeskAgentTextTokens(in value: String) -> [String] {
    var tokens: [String] = []
    var token = ""
    for scalar in value.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            token.unicodeScalars.append(scalar)
        } else if !token.isEmpty {
            tokens.append(token)
            token.removeAll(keepingCapacity: true)
        }
    }
    if !token.isEmpty {
        tokens.append(token)
    }
    return tokens
}

private func mindDeskContainsTokenAssignment(in value: String) -> Bool {
    let scalars = Array(value.unicodeScalars)
    let marker = Array("token".unicodeScalars)
    guard scalars.count >= marker.count else { return false }

    for start in 0...(scalars.count - marker.count) {
        let end = start + marker.count
        guard Array(scalars[start..<end]) == marker,
              (start == 0 || !CharacterSet.alphanumerics.contains(scalars[start - 1])),
              (end == scalars.count || !CharacterSet.alphanumerics.contains(scalars[end]))
        else { continue }

        var cursor = end
        while cursor < scalars.count,
              !CharacterSet.alphanumerics.contains(scalars[cursor]),
              scalars[cursor] != "="
        {
            cursor += 1
        }
        if cursor < scalars.count, scalars[cursor] == "=" {
            return true
        }
    }
    return false
}

private func mindDeskContainsHTTPURL(in value: String) -> Bool {
    let scalars = Array(value.unicodeScalars)
    for scheme in ["http", "https"] {
        let marker = Array(scheme.unicodeScalars)
        guard scalars.count >= marker.count else { continue }
        for start in 0...(scalars.count - marker.count) {
            let end = start + marker.count
            guard Array(scalars[start..<end]) == marker,
                  (start == 0 || !CharacterSet.alphanumerics.contains(scalars[start - 1])),
                  (end == scalars.count || !CharacterSet.alphanumerics.contains(scalars[end]))
            else { continue }

            var cursor = end
            mindDeskSkipAgentTextWhitespace(in: scalars, cursor: &cursor)
            guard cursor < scalars.count, scalars[cursor] == ":" else { continue }
            cursor += 1
            mindDeskSkipAgentTextWhitespace(in: scalars, cursor: &cursor)
            guard cursor < scalars.count, scalars[cursor] == "/" else { continue }
            cursor += 1
            mindDeskSkipAgentTextWhitespace(in: scalars, cursor: &cursor)
            if cursor < scalars.count, scalars[cursor] == "/" {
                return true
            }
        }
    }
    return false
}

private func mindDeskSkipAgentTextWhitespace(
    in scalars: [Unicode.Scalar],
    cursor: inout Int
) {
    while cursor < scalars.count, CharacterSet.whitespacesAndNewlines.contains(scalars[cursor]) {
        cursor += 1
    }
}

private func mindDeskOrdinaryValidationRedactionPolicy() -> MindDeskValidationReportRedactionPolicy {
    MindDeskValidationReportRedactionPolicy(
        format: MindDeskValidationReportRedactionPolicy.currentFormat,
        formatVersion: MindDeskValidationReportRedactionPolicy.currentFormatVersion,
        manifestIssueOwnerID: "token",
        manifestIssueIDDetails: "token",
        unknownManifestIssueDetails: "token",
        tokenFormat: "sha256-prefix-16",
        locatorField: "path",
        rawManifestRecordsRemainInPackage: true,
        messagesAreStatic: true,
        nonManifestUnsupportedFormatDetails: "actualValueToken",
        nonManifestReferenceIDDetails: "referenceIDToken",
        nonManifestIssueOwnerID: "token",
        tokenizedDetailKeys: [
            "actualValueToken",
            "proposalIDToken",
            "payloadFieldToken",
            "referenceIDToken",
            "capabilityIDToken",
            "unexpectedBindingFieldsToken"
        ],
        rawSafeDetailKeys: [
            "actor",
            "action",
            "actual",
            "actualLength",
            "bindingField",
            "count",
            "duplicateOperationIndex",
            "duplicateProposalIndex",
            "expected",
            "expectedTargetType",
            "firstOperationIndex",
            "firstProposalIndex",
            "kind",
            "mismatchedFields",
            "missingBindingFields",
            "operationKind",
            "operationIndex",
            "operationIndexes",
            "payloadField",
            "payloadFieldLength",
            "proposalIndex",
            "proposalIndexes",
            "maximum",
            "referenceIndex",
            "referenceKind",
            "referenceRole",
            "supportedVersions",
            "targetKind",
            "unexpectedBindingFieldsCount",
            "unexpectedBindingFieldsLength"
        ]
    )
}

public enum MindDeskManifestValidationReport {
    public static func report(
        in manifest: ExportManifest,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        let issues = issues(in: manifest)
        return MindDeskValidationReport(
            format: MindDeskValidationReport.currentFormat,
            formatVersion: MindDeskValidationReport.currentFormatVersion,
            redactionPolicy: mindDeskOrdinaryValidationRedactionPolicy(),
            generatedAt: generatedAt,
            summary: MindDeskValidationReportSummary(issues: issues),
            issues: issues
        )
    }

    public static func issues(in manifest: ExportManifest) -> [MindDeskValidationReportIssue] {
        ManifestImportValidation.diagnostics(in: manifest).map { diagnostic in
            let sanitizedDetails = sanitizedManifestDetails(for: diagnostic)
            return MindDeskValidationReportIssue(
                source: .manifest,
                code: diagnostic.code,
                severity: .error,
                message: message(for: diagnostic.code),
                ownerKind: diagnostic.ownerKind,
                ownerID: diagnostic.ownerID.map(manifestToken),
                field: diagnostic.field,
                path: diagnostic.path,
                details: sanitizedDetails
            )
        }
    }

    private static func sanitizedManifestDetails(for diagnostic: ManifestImportValidationDiagnostic) -> [String: String] {
        var details: [String: String] = [:]
        if let ownerID = diagnostic.ownerID {
            details["ownerIDLength"] = String(ownerID.count)
        }

        for (key, value) in diagnostic.details {
            if manifestIdentifierDetailKeys.contains(key) {
                details[key] = manifestToken(value)
                details["\(key)Length"] = String(value.count)
            } else if key == "cycleNodeIDs" {
                details["cycleNodeIDsToken"] = manifestToken(value)
                details["cycleNodeIDsLength"] = String(value.count)
            } else if key == "actual", diagnostic.code == "manifest.field.unsupported-value" {
                details["actualValueToken"] = manifestToken(value)
                details["actualValueLength"] = String(value.count)
                details["actualValueKind"] = "string"
            } else if let safeValue = safeManifestDetailValue(for: key, value: value) {
                details[key] = safeValue
            } else {
                appendTokenizedManifestDetail(key: key, value: value, to: &details)
            }
        }
        return details
    }

    private static func safeManifestDetailValue(for key: String, value: String) -> String? {
        switch key {
        case "actualTargetType":
            return safeManifestTargetTypeValues.contains(value) ? value : nil
        case "nodeType":
            return safeManifestNodeTypes.contains(value) ? value : nil
        case "objectType":
            return WorkbenchObjectReferencePolicy.importableCanvasObjectTypes.contains(value) ? value : nil
        case "sourceObjectType":
            return WorkbenchObjectReferencePolicy.importableAliasSourceTypes.contains(value) ? value : nil
        default:
            return safeManifestDetailKeys.contains(key) ? value : nil
        }
    }

    private static func appendTokenizedManifestDetail(
        key: String,
        value: String,
        to details: inout [String: String]
    ) {
        details["\(key)Token"] = manifestToken(value)
        details["\(key)Length"] = String(value.count)
    }

    private static let manifestIdentifierDetailKeys: Set<String> = [
        "duplicateID",
        "referencedOwnerID",
        "ownerWorkspaceID",
        "referencedWorkspaceID",
        "ownerCanvasID",
        "referencedCanvasID",
        "canvasID",
        "reportedNodeID"
    ]

    private static let safeManifestDetailKeys: Set<String> = [
        "actualLength",
        "actualNumber",
        "actualTargetType",
        "actualVersion",
        "allowedObjectTypes",
        "allowedSchemes",
        "allowedSourceObjectTypes",
        "allowedValues",
        "count",
        "duplicateIndex",
        "expectedTargetType",
        "fallbackSource",
        "firstIndex",
        "indexes",
        "legacyIssueIndex",
        "maximum",
        "minimum",
        "nodeType",
        "normalizedReferenceIDLength",
        "objectType",
        "objectTypeStatus",
        "reason",
        "referencedOwnerKind",
        "sourceField",
        "sourceObjectType",
        "supportedVersions"
    ]

    private static let safeManifestNodeTypes: Set<String> = [
        "resource",
        "snippet",
        "note",
        "groupFrame"
    ]

    private static let safeManifestTargetTypeValues: Set<String> = safeManifestNodeTypes.union([
        "file",
        "folder"
    ])

    private static func manifestToken(_ value: String) -> String {
        MindDeskValidationReportToken.token(value)
    }

    fileprivate static func message(for code: String) -> String {
        switch code {
        case "manifest.schema.unsupported-version":
            return "Manifest schema version is unsupported."
        case "manifest.collection.too-large":
            return "Manifest collection exceeds the supported count."
        case "manifest.id.empty":
            return "Manifest record ID is missing."
        case "manifest.id.duplicate":
            return "Manifest contains a duplicate ID."
        case "manifest.id.too-long":
            return "Manifest record ID exceeds the supported length."
        case "manifest.text.too-long":
            return "Manifest text field exceeds the supported length."
        case "manifest.path.too-long":
            return "Manifest path field exceeds the supported length."
        case "manifest.field.unsupported-value":
            return "Manifest field contains an unsupported value."
        case "manifest.range.out-of-bounds":
            return "Manifest numeric field is outside the supported range."
        case "manifest.scope.workspace-id-required":
            return "Manifest record is missing a required workspace ID."
        case "manifest.scope.workspace-id-forbidden":
            return "Manifest record has a workspace ID that is not allowed for its scope."
        case "manifest.reference.missing":
            return "Manifest reference is missing."
        case "manifest.reference.unsupported-target":
            return "Manifest reference points to an unsupported target type."
        case "manifest.reference.cross-workspace":
            return "Manifest reference crosses workspace boundaries."
        case "manifest.reference.cross-canvas":
            return "Manifest reference crosses canvas boundaries."
        case "manifest.reference.incompatible":
            return "Manifest reference is incompatible with its owner."
        case "manifest.reference.invalid-url":
            return "Manifest web URL reference is invalid."
        case "manifest.reference.id-required":
            return "Manifest reference ID is required."
        case "manifest.reference.id-whitespace":
            return "Manifest reference ID has invalid whitespace."
        case "manifest.node.parent.self-reference":
            return "Manifest node cannot be its own parent."
        case "manifest.node.parent.cycle":
            return "Manifest frame parent relationship contains a cycle."
        case "manifest.alias.source-type.unsupported":
            return "Manifest alias source object type is unsupported."
        default:
            return "Manifest import validation issue."
        }
    }
}
