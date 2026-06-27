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
        if let kindKey = kindKey {
            details[kindKey] = "string"
        }
        return details
    }
}

private func mindDeskUnsupportedStringDetails(actual: String, expected: String) -> [String: String] {
    var details = MindDeskValidationReportToken.stringDetails(value: actual)
    details["expected"] = expected
    return details
}

private func mindDeskTokenizedIDDetails(tokenKey: String, lengthKey: String, id: String) -> [String: String] {
    [
        tokenKey: MindDeskValidationReportToken.token(id),
        lengthKey: String(id.count)
    ]
}

public enum MindDeskValidationReportSource: String, Codable, CaseIterable, Sendable {
    case package
    case manifest
    case proposalEnvelope
    case agentIntegrationContract
    case extensionCapabilityCatalog

    public init(from decoder: Decoder) throws {
        self = try mindDeskDecodeStringBackedEnum(
            Self.self,
            from: decoder,
            debugDescription: "Unsupported validation report source."
        )
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

    public init(issues: [MindDeskValidationReportIssue]) {
        self.issueCount = issues.count
        self.errorCount = issues.filter { $0.severity == .error }.count
        self.warningCount = issues.filter { $0.severity == .warning }.count
        self.isValid = errorCount == 0
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
    public static let currentTokenizedDetailKeys = [
        "actualValueToken",
        "proposalIDToken",
        "payloadFieldToken",
        "referenceIDToken",
        "capabilityIDToken",
        "unexpectedBindingFieldsToken"
    ]
    public static let currentRawSafeDetailKeys = [
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
    public static let current = MindDeskValidationReportRedactionPolicy()

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
        format: String = MindDeskValidationReportRedactionPolicy.currentFormat,
        formatVersion: Int = MindDeskValidationReportRedactionPolicy.currentFormatVersion,
        manifestIssueOwnerID: String = "token",
        manifestIssueIDDetails: String = "token",
        unknownManifestIssueDetails: String = "token",
        tokenFormat: String = "sha256-prefix-16",
        locatorField: String = "path",
        rawManifestRecordsRemainInPackage: Bool = true,
        messagesAreStatic: Bool = true,
        nonManifestUnsupportedFormatDetails: String = "actualValueToken",
        nonManifestReferenceIDDetails: String = "referenceIDToken",
        nonManifestIssueOwnerID: String = "token",
        tokenizedDetailKeys: [String] = MindDeskValidationReportRedactionPolicy.currentTokenizedDetailKeys,
        rawSafeDetailKeys: [String] = MindDeskValidationReportRedactionPolicy.currentRawSafeDetailKeys
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
            format: try container.decodeIfPresent(String.self, forKey: .format) ?? Self.currentFormat,
            formatVersion: try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? Self.currentFormatVersion,
            manifestIssueOwnerID: try container.decodeIfPresent(String.self, forKey: .manifestIssueOwnerID) ?? "token",
            manifestIssueIDDetails: try container.decodeIfPresent(String.self, forKey: .manifestIssueIDDetails) ?? "token",
            unknownManifestIssueDetails: try container.decodeIfPresent(String.self, forKey: .unknownManifestIssueDetails) ?? "token",
            tokenFormat: try container.decodeIfPresent(String.self, forKey: .tokenFormat) ?? "sha256-prefix-16",
            locatorField: try container.decodeIfPresent(String.self, forKey: .locatorField) ?? "path",
            rawManifestRecordsRemainInPackage: try container.decodeIfPresent(
                Bool.self,
                forKey: .rawManifestRecordsRemainInPackage
            ) ?? true,
            messagesAreStatic: try container.decodeIfPresent(Bool.self, forKey: .messagesAreStatic) ?? true,
            nonManifestUnsupportedFormatDetails: try container.decodeIfPresent(
                String.self,
                forKey: .nonManifestUnsupportedFormatDetails
            ) ?? "actualValueToken",
            nonManifestReferenceIDDetails: try container.decodeIfPresent(
                String.self,
                forKey: .nonManifestReferenceIDDetails
            ) ?? "referenceIDToken",
            nonManifestIssueOwnerID: try container.decodeIfPresent(
                String.self,
                forKey: .nonManifestIssueOwnerID
            ) ?? "token",
            tokenizedDetailKeys: try container.decodeIfPresent(
                [String].self,
                forKey: .tokenizedDetailKeys
            ) ?? Self.currentTokenizedDetailKeys,
            rawSafeDetailKeys: try container.decodeIfPresent(
                [String].self,
                forKey: .rawSafeDetailKeys
            ) ?? Self.currentRawSafeDetailKeys
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
        issues: [MindDeskValidationReportIssue],
        generatedAt: Date,
        format: String = MindDeskValidationReport.currentFormat,
        formatVersion: Int = MindDeskValidationReport.currentFormatVersion,
        redactionPolicy: MindDeskValidationReportRedactionPolicy = .current
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.redactionPolicy = redactionPolicy
        self.generatedAt = generatedAt
        self.summary = MindDeskValidationReportSummary(issues: issues)
        self.issues = issues
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentFormat, forKey: .format)
        try container.encode(Self.currentFormatVersion, forKey: .formatVersion)
        try container.encode(MindDeskValidationReportRedactionPolicy.current, forKey: .redactionPolicy)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(MindDeskValidationReportSummary(issues: issues), forKey: .summary)
        try container.encode(issues, forKey: .issues)
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

        _ = try? container.decode(MindDeskValidationReportSummary.self, forKey: .summary)
        let issues = try container
            .decode([MindDeskValidationReportIssue].self, forKey: .issues)
            .map(mindDeskSanitizedDecodedValidationReportIssue)
        self.format = format
        self.formatVersion = formatVersion
        _ = try? container.decodeIfPresent(
            MindDeskValidationReportRedactionPolicy.self,
            forKey: .redactionPolicy
        )
        self.redactionPolicy = .current
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.summary = MindDeskValidationReportSummary(issues: issues)
        self.issues = issues
    }
}

private func mindDeskSanitizedDecodedValidationReportIssue(
    _ issue: MindDeskValidationReportIssue
) -> MindDeskValidationReportIssue {
    var details = mindDeskSanitizedDecodedValidationReportDetails(issue.details)
    let ownerID: String?
    if let rawOwnerID = issue.ownerID {
        if mindDeskValidationReportValueIsToken(rawOwnerID) {
            ownerID = rawOwnerID
        } else {
            ownerID = MindDeskValidationReportToken.token(rawOwnerID)
            details["ownerIDLength"] = String(rawOwnerID.count)
        }
    } else {
        ownerID = nil
    }

    return MindDeskValidationReportIssue(
        source: issue.source,
        code: mindDeskSafeStructuralValue(issue.code) ?? "validation.issue",
        severity: issue.severity,
        message: mindDeskSanitizedDecodedValidationReportMessage(issue),
        ownerKind: mindDeskSafeStructuralValue(issue.ownerKind),
        ownerID: ownerID,
        field: mindDeskSafeStructuralValue(issue.field),
        path: mindDeskSafePathValue(issue.path),
        helpTopicID: mindDeskSafeStructuralValue(issue.helpTopicID),
        details: details
    )
}

private func mindDeskSanitizedDecodedValidationReportMessage(
    _ issue: MindDeskValidationReportIssue
) -> String {
    if issue.source == .manifest {
        return MindDeskInterchangePackageValidationReport.manifestMessage(for: issue.code)
    }
    if mindDeskValueContainsUnsafeAgentText(issue.message) {
        return "Validation report issue."
    }
    return issue.message
}

private func mindDeskSanitizedDecodedValidationReportDetails(
    _ rawDetails: [String: String]
) -> [String: String] {
    var details: [String: String] = [:]
    for (rawKey, value) in rawDetails {
        guard let key = mindDeskSafeDetailKey(rawKey) else { continue }
        if mindDeskDecodedReportIDDetailKeys.contains(key) {
            details[key] = mindDeskValidationReportValueIsToken(value)
                ? value
                : MindDeskValidationReportToken.token(value)
            details["\(key)Length"] = String(value.count)
        } else if key == "actual" {
            details["actualValueToken"] = MindDeskValidationReportToken.token(value)
            details["actualValueLength"] = String(value.count)
            details["actualValueKind"] = "string"
        } else if key == "referenceID" {
            details["referenceIDToken"] = MindDeskValidationReportToken.token(value)
            details["referenceIDLength"] = String(value.count)
        } else if key == "proposalID" {
            details["proposalIDToken"] = MindDeskValidationReportToken.token(value)
            details["proposalIDLength"] = String(value.count)
        } else if key == "capabilityID" {
            details["capabilityIDToken"] = MindDeskValidationReportToken.token(value)
            details["capabilityIDLength"] = String(value.count)
        } else if key == "unexpectedBindingFields" {
            details["unexpectedBindingFieldsToken"] = MindDeskValidationReportToken.token(value)
            details["unexpectedBindingFieldsLength"] = String(value.count)
        } else if key.hasSuffix("Token") {
            details[key] = mindDeskValidationReportValueIsToken(value)
                ? value
                : MindDeskValidationReportToken.token(value)
        } else if key.hasSuffix("Length") || key.hasSuffix("Count") || key.hasSuffix("Index") {
            if mindDeskValidationReportValueIsInteger(value) {
                details[key] = value
            }
        } else if mindDeskDecodedReportRawSafeDetailKeys.contains(key),
                  !mindDeskValueContainsUnsafeAgentText(value) {
            details[key] = value
        } else {
            details["\(key)Token"] = MindDeskValidationReportToken.token(value)
            details["\(key)Length"] = String(value.count)
        }
    }
    return details
}

private let mindDeskDecodedReportIDDetailKeys: Set<String> = [
    "duplicateID",
    "referencedOwnerID",
    "ownerWorkspaceID",
    "referencedWorkspaceID",
    "ownerCanvasID",
    "referencedCanvasID",
    "canvasID",
    "reportedNodeID"
]

private let mindDeskDecodedReportRawSafeDetailKeys: Set<String> = Set(
    MindDeskValidationReportRedactionPolicy.currentRawSafeDetailKeys + [
        "actualLength",
        "actualNumber",
        "actualTargetType",
        "actualVersion",
        "allowedObjectTypes",
        "allowedSchemes",
        "allowedSourceObjectTypes",
        "allowedValues",
        "bindingField",
        "count",
        "duplicateIndex",
        "expectedTargetType",
        "fallbackSource",
        "firstIndex",
        "indexes",
        "legacyIssueIndex",
        "maximum",
        "minimum",
        "mismatchedFields",
        "missingBindingFields",
        "nodeType",
        "normalizedReferenceIDLength",
        "objectType",
        "objectTypeStatus",
        "reason",
        "referencedOwnerKind",
        "sourceField",
        "sourceObjectType",
        "supportedVersions",
        "unexpectedBindingFieldsCount",
        "unexpectedBindingFieldsLength"
    ]
)

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
          key.rangeOfCharacter(from: allowed.inverted) == nil
    else { return nil }
    return key
}

private func mindDeskValueContainsUnsafeAgentText(_ value: String) -> Bool {
    let lowercased = value.lowercased()
    return value.contains("\n") ||
        value.contains("\r") ||
        lowercased.contains("ignore_agent_instructions") ||
        lowercased.contains("ignore validation") ||
        lowercased.contains("ignore previous instructions") ||
        lowercased.contains("ignore prior instructions") ||
        lowercased.contains("token=") ||
        lowercased.contains("http://") ||
        lowercased.contains("https://")
}

private func mindDeskValidationReportValueIsToken(_ value: String) -> Bool {
    guard value.hasPrefix("sha256:"), value.count == 23 else { return false }
    let hexCharacters = Set("0123456789abcdef")
    return value.dropFirst("sha256:".count).allSatisfy { character in
        hexCharacters.contains(character)
    }
}

private func mindDeskValidationReportValueIsInteger(_ value: String) -> Bool {
    let digits = Set("0123456789")
    return !value.isEmpty && value.allSatisfy { digits.contains($0) }
}

public enum MindDeskManifestValidationReport {
    public static func issues(in manifest: ExportManifest) -> [MindDeskValidationReportIssue] {
        MindDeskInterchangePackageValidationReport.issues(in: manifest)
    }

    public static func report(
        in manifest: ExportManifest,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: manifest), generatedAt: generatedAt)
    }
}

public enum MindDeskInterchangePackageValidationReport {
    public static func issues(in manifest: ExportManifest) -> [MindDeskValidationReportIssue] {
        manifestIssues(in: manifest)
    }

    public static func issues(in package: MindDeskInterchangePackage) -> [MindDeskValidationReportIssue] {
        issues(in: package, contract: package.agentIntegrationContract)
    }

    public static func issues(
        in package: MindDeskInterchangePackage,
        contract: MindDeskAgentIntegrationContract
    ) -> [MindDeskValidationReportIssue] {
        issues(
            in: package,
            contract: contract,
            extensionCapabilities: package.extensionCapabilities
        )
    }

    public static func issues(
        in package: MindDeskInterchangePackage,
        contract: MindDeskAgentIntegrationContract,
        extensionCapabilities: MindDeskExtensionCapabilityCatalog
    ) -> [MindDeskValidationReportIssue] {
        var issues: [MindDeskValidationReportIssue] = []
        let packageWrapperIsSupported = package.format == MindDeskInterchangePackage.currentFormat &&
            MindDeskInterchangePackageFormat.supportedVersions.contains(package.formatVersion)

        if package.format != MindDeskInterchangePackage.currentFormat {
            issues.append(
                packageIssue(
                    code: "package.format.unsupported",
                    severity: .error,
                    message: "Interchange package format is unsupported.",
                    field: "format",
                    details: mindDeskUnsupportedStringDetails(
                        actual: package.format,
                        expected: MindDeskInterchangePackage.currentFormat
                    )
                )
            )
        }
        if !MindDeskInterchangePackageFormat.supportedVersions.contains(package.formatVersion) {
            issues.append(
                packageIssue(
                    code: "package.format.unsupported-version",
                    severity: .error,
                    message: "Interchange package format version is unsupported.",
                    field: "formatVersion",
                    details: [
                        "actual": String(package.formatVersion),
                        "supportedVersions": MindDeskInterchangePackageFormat.supportedVersions
                            .sorted()
                            .map(String.init)
                            .joined(separator: ",")
                    ]
                )
            )
        }
        if !package.summary.matchesManifestCounts(package.manifest) {
            issues.append(
                packageIssue(
                    code: "package.summary.mismatch",
                    severity: .warning,
                    message: "Package summary does not match manifest contents.",
                    field: "summary"
                )
            )
        }

        issues.append(contentsOf: manifestIssues(in: package.manifest))
        if packageWrapperIsSupported {
            issues.append(contentsOf: MindDeskAgentIntegrationContractValidationReport.issues(in: contract, package: package))
            issues.append(contentsOf: MindDeskExtensionCapabilityCatalogValidationReport.issues(in: extensionCapabilities))
        }
        return issues
    }

    public static func report(
        in manifest: ExportManifest,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: manifest), generatedAt: generatedAt)
    }

    public static func report(
        in package: MindDeskInterchangePackage,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: package), generatedAt: generatedAt)
    }

    public static func report(
        in package: MindDeskInterchangePackage,
        contract: MindDeskAgentIntegrationContract,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: package, contract: contract), generatedAt: generatedAt)
    }

    public static func report(
        in package: MindDeskInterchangePackage,
        contract: MindDeskAgentIntegrationContract,
        extensionCapabilities: MindDeskExtensionCapabilityCatalog,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(
            issues: issues(
                in: package,
                contract: contract,
                extensionCapabilities: extensionCapabilities
            ),
            generatedAt: generatedAt
        )
    }

    private static func packageIssue(
        code: String,
        severity: MindDeskValidationSeverity,
        message: String,
        field: String,
        details: [String: String] = [:]
    ) -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: code,
            severity: severity,
            message: message,
            ownerKind: "interchangePackage",
            field: field,
            details: details
        )
    }

    private static func manifestIssues(in manifest: ExportManifest) -> [MindDeskValidationReportIssue] {
        ManifestImportValidation.diagnostics(in: manifest).map { diagnostic in
            let sanitizedDetails = sanitizedManifestDetails(for: diagnostic)
            return MindDeskValidationReportIssue(
                source: .manifest,
                code: diagnostic.code,
                severity: .error,
                message: manifestMessage(for: diagnostic.code),
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

    fileprivate static func manifestMessage(for code: String) -> String {
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

public enum MindDeskProposalValidationReport {
    public static func issues(from issues: [MindDeskProposalValidationIssue]) -> [MindDeskValidationReportIssue] {
        issues.map(reportIssue)
    }

    public static func issues(
        from diagnostics: [MindDeskProposalValidationDiagnostic]
    ) -> [MindDeskValidationReportIssue] {
        diagnostics.map { reportIssue($0) }
    }

    public static func issues(in envelope: MindDeskProposalEnvelope) -> [MindDeskValidationReportIssue] {
        issues(from: MindDeskProposalEnvelopeValidation.diagnostics(in: envelope))
    }

    public static func issues(
        in envelope: MindDeskProposalEnvelope,
        currentContext: MindDeskProposalContextSnapshot
    ) -> [MindDeskValidationReportIssue] {
        MindDeskProposalEnvelopeValidation
            .diagnostics(in: envelope, currentContext: currentContext)
            .map { reportIssue($0, proposalContext: envelope.context, currentContext: currentContext) }
    }

    public static func issues(
        in envelope: MindDeskProposalEnvelope,
        package: MindDeskInterchangePackage
    ) throws -> [MindDeskValidationReportIssue] {
        let currentContext = MindDeskProposalContextSnapshot(package: package)
        return try MindDeskProposalEnvelopeValidation
            .diagnostics(in: envelope, package: package)
            .map { reportIssue($0, proposalContext: envelope.context, currentContext: currentContext) }
    }

    public static func report(
        in envelope: MindDeskProposalEnvelope,
        package: MindDeskInterchangePackage,
        generatedAt: Date
    ) throws -> MindDeskValidationReport {
        MindDeskValidationReport(issues: try issues(in: envelope, package: package), generatedAt: generatedAt)
    }

    private static func reportIssue(
        _ diagnostic: MindDeskProposalValidationDiagnostic
    ) -> MindDeskValidationReportIssue {
        merged(reportIssue(diagnostic.issue), with: diagnostic)
    }

    private static func reportIssue(_ issue: MindDeskProposalValidationIssue) -> MindDeskValidationReportIssue {
        switch issue {
        case .emptyEnvelopeID:
            return proposalIssue(
                code: "proposal.envelope.empty-id",
                message: "Proposal envelope id is required.",
                ownerKind: "envelope",
                field: "id"
            )
        case .unsupportedEnvelopeFormat(let format):
            return proposalIssue(
                code: "proposal.envelope.unsupported-format",
                message: "Proposal envelope format is unsupported.",
                ownerKind: "envelope",
                field: "format",
                details: mindDeskUnsupportedStringDetails(
                    actual: format,
                    expected: MindDeskProposalEnvelope.currentFormat
                )
            )
        case .unsupportedEnvelopeFormatVersion(let version):
            return proposalIssue(
                code: "proposal.envelope.unsupported-version",
                message: "Proposal envelope format version is unsupported.",
                ownerKind: "envelope",
                field: "formatVersion",
                details: [
                    "actual": String(version),
                    "expected": String(MindDeskProposalEnvelope.currentFormatVersion)
                ]
            )
        case .unsupportedContextPackageFormat(let format):
            return proposalIssue(
                code: "proposal.context.unsupported-package-format",
                message: "Proposal context package format is unsupported.",
                ownerKind: "context",
                field: "context.packageFormat",
                details: mindDeskUnsupportedStringDetails(
                    actual: format,
                    expected: MindDeskInterchangePackage.currentFormat
                )
            )
        case .unsupportedContextPackageFormatVersion(let version):
            return proposalIssue(
                code: "proposal.context.unsupported-package-version",
                message: "Proposal context package format version is unsupported.",
                ownerKind: "context",
                field: "context.packageFormatVersion",
                details: [
                    "actual": String(version),
                    "expected": String(MindDeskInterchangePackage.currentFormatVersion)
                ]
            )
        case .staleProposalContext:
            return proposalIssue(
                code: "proposal.context.stale",
                message: "Proposal context no longer matches the current package export.",
                ownerKind: "context",
                field: "context"
            )
        case .proposalCreatedBeforePackage(let proposalCreatedAt, let packageCreatedAt):
            return proposalIssue(
                code: "proposal.envelope.created-before-package",
                message: "Proposal envelope was created before the package context.",
                ownerKind: "envelope",
                field: "createdAt",
                details: [
                    "proposalCreatedAt": String(proposalCreatedAt.timeIntervalSince1970),
                    "packageCreatedAt": String(packageCreatedAt.timeIntervalSince1970),
                    "allowedSkewSeconds": "300"
                ]
            )
        case .invalidProposer(let actor):
            return proposalIssue(
                code: "proposal.proposer.invalid",
                message: "Proposal envelope must be proposed by the default agent.",
                ownerKind: "envelope",
                field: "proposedBy",
                details: [
                    "actor": actor.rawValue,
                    "expected": WorkbenchExternalActor.defaultAgent.rawValue
                ]
            )
        case .missingProposals:
            return proposalIssue(
                code: "proposal.collection.empty",
                message: "Proposal envelope must contain at least one proposal.",
                ownerKind: "envelope",
                field: "proposals"
            )
        case .emptyProposalID:
            return proposalIssue(
                code: "proposal.id.empty",
                message: "Proposal id is required.",
                ownerKind: "proposal",
                field: "proposals.id"
            )
        case .emptyProposalTitle(let proposalID):
            return proposalIssue(
                code: "proposal.title.empty",
                message: "Proposal title is required.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "title",
                details: ["ownerIDLength": String(proposalID.count)]
            )
        case .missingProposalEvidence(let proposalID):
            return proposalIssue(
                code: "proposal.evidence.missing",
                message: "Proposal must include at least one evidence reference.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "evidenceReferences",
                details: ["ownerIDLength": String(proposalID.count)]
            )
        case .missingProposalOperations(let proposalID):
            return proposalIssue(
                code: "proposal.operation.collection-empty",
                message: "Proposal must include at least one operation.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "operations",
                details: ["ownerIDLength": String(proposalID.count)]
            )
        case .duplicateProposalID(let proposalID):
            return proposalIssue(
                code: "proposal.id.duplicate",
                message: "Proposal id must be unique within the envelope.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "id",
                details: ["ownerIDLength": String(proposalID.count)]
            )
        case .tooManyProposals(let count, let maximum):
            return proposalIssue(
                code: "proposal.collection.too-large",
                message: "Proposal envelope contains too many proposals.",
                ownerKind: "envelope",
                field: "proposals",
                details: limitDetails(count: count, maximum: maximum)
            )
        case .tooManyProposalEvidenceReferences(let proposalID, let count, let maximum):
            return proposalIssue(
                code: "proposal.evidence.collection-too-large",
                message: "Proposal contains too many evidence references.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "evidenceReferences",
                details: tokenizedProposalOwnerDetails(proposalID).merging(
                    limitDetails(count: count, maximum: maximum)
                ) { current, _ in current }
            )
        case .tooManyProposalOperations(let proposalID, let count, let maximum):
            return proposalIssue(
                code: "proposal.operation.collection-too-large",
                message: "Proposal contains too many operations.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "operations",
                details: tokenizedProposalOwnerDetails(proposalID).merging(
                    limitDetails(count: count, maximum: maximum)
                ) { current, _ in current }
            )
        case .proposalTitleTooLong(let proposalID, let actualLength, let maximum):
            return proposalIssue(
                code: "proposal.title.too-long",
                message: "Proposal title is too long.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "title",
                details: tokenizedProposalOwnerDetails(proposalID).merging(
                    lengthLimitDetails(actualLength: actualLength, maximum: maximum)
                ) { current, _ in current }
            )
        case .proposalRationaleTooLong(let proposalID, let actualLength, let maximum):
            return proposalIssue(
                code: "proposal.rationale.too-long",
                message: "Proposal rationale is too long.",
                ownerKind: "proposal",
                ownerID: MindDeskValidationReportToken.token(proposalID),
                field: "rationale",
                details: tokenizedProposalOwnerDetails(proposalID).merging(
                    lengthLimitDetails(actualLength: actualLength, maximum: maximum)
                ) { current, _ in current }
            )
        case .emptyOperationID:
            return proposalIssue(
                code: "proposal.operation.empty-id",
                message: "Proposal operation id is required.",
                ownerKind: "operation",
                field: "operations.id"
            )
        case .duplicateOperationID(let proposalID, let operationID):
            return proposalIssue(
                code: "proposal.operation.duplicate-id",
                message: "Proposal operation id must be unique within the proposal.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "id",
                details: tokenizedProposalOwnerDetails(operationID).merging(mindDeskTokenizedIDDetails(
                    tokenKey: "proposalIDToken",
                    lengthKey: "proposalIDLength",
                    id: proposalID
                )) { current, _ in current }
            )
        case .tooManyOperationAffectedObjects(let operationID, let count, let maximum):
            return proposalIssue(
                code: "proposal.operation.affected-objects-too-large",
                message: "Proposal operation contains too many affected objects.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "affectedObjects",
                details: tokenizedProposalOwnerDetails(operationID).merging(
                    limitDetails(count: count, maximum: maximum)
                ) { current, _ in current }
            )
        case .operationTitleTooLong(let operationID, let actualLength, let maximum):
            return proposalIssue(
                code: "proposal.operation.title.too-long",
                message: "Proposal operation title is too long.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "title",
                details: tokenizedProposalOwnerDetails(operationID).merging(
                    lengthLimitDetails(actualLength: actualLength, maximum: maximum)
                ) { current, _ in current }
            )
        case .operationPayloadTooLong(let operationID, let field, let actualLength, let maximum):
            return proposalIssue(
                code: "proposal.operation.payload-too-long",
                message: "Proposal operation payload is too long.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "payload.\(field)",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "payloadField": field
                ].merging(
                    lengthLimitDetails(actualLength: actualLength, maximum: maximum)
                ) { current, _ in current }) { current, _ in current }
            )
        case .unexpectedOperationPayload(let operationID, let kind, let field):
            return proposalIssue(
                code: "proposal.operation.unexpected-payload",
                message: "Proposal operation payload contains a field not allowed for this operation kind.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "payload.\(field)",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "kind": kind.rawValue,
                    "payloadField": field
                ]) { current, _ in current }
            )
        case .unknownOperationPayloadField(let operationID, let kind, let fieldToken, let fieldLength):
            return proposalIssue(
                code: "proposal.operation.unknown-payload-field",
                message: "Proposal operation payload contains an unknown raw field.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "payload",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "kind": kind.rawValue,
                    "payloadFieldToken": fieldToken,
                    "payloadFieldLength": String(fieldLength)
                ]) { current, _ in current }
            )
        case .missingOperationTarget(let operationID, let kind):
            return proposalIssue(
                code: "proposal.operation.missing-target",
                message: "Proposal operation is missing a required target.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "target",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "kind": kind.rawValue
                ]) { current, _ in current }
            )
        case .unsupportedOperationTarget(let operationID, let kind, let targetKind):
            return proposalIssue(
                code: "proposal.operation.unsupported-target",
                message: "Proposal operation target kind is unsupported for this operation.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "target",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "kind": kind.rawValue,
                    "targetKind": targetKind.rawValue
                ]) { current, _ in current }
            )
        case .unsupportedWorkingDirectory(let operationID, let kind, let reference):
            return proposalIssue(
                code: "proposal.operation.unsupported-working-directory",
                message: "Proposal operation working directory must reference a folder resource.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "payload.workingDirectory",
                details: tokenizedProposalOwnerDetails(operationID).merging(referenceDetails(
                    kind: reference.kind,
                    id: reference.id
                ).merging([
                    "kind": kind.rawValue,
                    "expectedTargetType": "folder"
                ]) { current, _ in current }) { current, _ in current }
            )
        case .unresolvedManifestReference(let ownerID, let kind, let id):
            return proposalIssue(
                code: "proposal.reference.unresolved",
                message: "Proposal reference does not resolve in the package manifest.",
                ownerID: tokenizedProposalOwnerID(ownerID),
                field: "references",
                details: tokenizedProposalOwnerDetails(ownerID).merging(referenceDetails(kind: kind, id: id)) {
                    current,
                    _ in current
                }
            )
        case .ambiguousManifestReference(let ownerID, let kind, let id):
            return proposalIssue(
                code: "proposal.reference.ambiguous",
                message: "Proposal reference matches multiple package manifest objects.",
                ownerID: tokenizedProposalOwnerID(ownerID),
                field: "references",
                details: tokenizedProposalOwnerDetails(ownerID).merging(referenceDetails(kind: kind, id: id)) {
                    current,
                    _ in current
                }
            )
        case .missingOperationPayload(let operationID, let kind):
            let payloadField = payloadField(for: kind)
            return proposalIssue(
                code: "proposal.operation.missing-payload",
                message: "Proposal operation is missing required payload.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: payloadField.map { "payload.\($0)" } ?? "payload",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "kind": kind.rawValue,
                    "payloadField": payloadField ?? "payload"
                ]) { current, _ in current }
            )
        case .metaActionCannotBeProposed(let operationID, let action):
            return proposalIssue(
                code: "proposal.operation.meta-action-forbidden",
                message: "Proposal operation cannot request an agent meta action.",
                ownerKind: "operation",
                ownerID: tokenizedProposalOwnerID(operationID),
                field: "kind",
                details: tokenizedProposalOwnerDetails(operationID).merging([
                    "action": action.rawValue
                ]) { current, _ in current }
            )
        }
    }

    private static func reportIssue(
        _ diagnostic: MindDeskProposalValidationDiagnostic,
        proposalContext: MindDeskProposalContextSnapshot,
        currentContext: MindDeskProposalContextSnapshot
    ) -> MindDeskValidationReportIssue {
        merged(
            reportIssue(diagnostic.issue, proposalContext: proposalContext, currentContext: currentContext),
            with: diagnostic
        )
    }

    private static func reportIssue(
        _ issue: MindDeskProposalValidationIssue,
        proposalContext: MindDeskProposalContextSnapshot,
        currentContext: MindDeskProposalContextSnapshot
    ) -> MindDeskValidationReportIssue {
        guard issue == .staleProposalContext else {
            return reportIssue(issue)
        }
        let fields = MindDeskProposalContextFreshness.mismatchedBindingFields(
            proposal: proposalContext,
            current: currentContext
        )
        return staleProposalContextIssue(mismatchedFields: fields)
    }

    private static func merged(
        _ issue: MindDeskValidationReportIssue,
        with diagnostic: MindDeskProposalValidationDiagnostic
    ) -> MindDeskValidationReportIssue {
        var mergedIssue = issue
        if mergedIssue.path == nil {
            mergedIssue.path = diagnostic.path
        }
        for (key, value) in diagnostic.details where mergedIssue.details[key] == nil {
            mergedIssue.details[key] = value
        }
        return mergedIssue
    }

    private static func staleProposalContextIssue(
        mismatchedFields: [String]
    ) -> MindDeskValidationReportIssue {
        var details: [String: String] = [:]
        if !mismatchedFields.isEmpty {
            details["mismatchedFields"] = mismatchedFields.joined(separator: ",")
        }
        if mismatchedFields.count == 1, let bindingField = mismatchedFields.first {
            details["bindingField"] = bindingField
        }
        let field = mismatchedFields.count == 1
            ? "context.\(mismatchedFields[0])"
            : "context"
        return proposalIssue(
            code: "proposal.context.stale",
            message: "Proposal context no longer matches the current package export.",
            ownerKind: "context",
            field: field,
            details: details
        )
    }

    private static func proposalIssue(
        code: String,
        message: String,
        ownerKind: String? = nil,
        ownerID: String? = nil,
        field: String? = nil,
        details: [String: String] = [:]
    ) -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .proposalEnvelope,
            code: code,
            severity: .error,
            message: message,
            ownerKind: ownerKind,
            ownerID: ownerID,
            field: field,
            details: details
        )
    }

    private static func tokenizedProposalOwnerID(_ ownerID: String) -> String {
        MindDeskValidationReportToken.token(ownerID)
    }

    private static func tokenizedProposalOwnerDetails(_ ownerID: String) -> [String: String] {
        ["ownerIDLength": String(ownerID.count)]
    }

    private static func referenceDetails(kind: WorkbenchObjectKind, id: String) -> [String: String] {
        [
            "referenceKind": kind.rawValue,
            "referenceIDToken": MindDeskValidationReportToken.token(id),
            "referenceIDLength": String(id.count)
        ]
    }

    private static func limitDetails(count: Int, maximum: Int) -> [String: String] {
        [
            "count": String(count),
            "maximum": String(maximum)
        ]
    }

    private static func lengthLimitDetails(actualLength: Int, maximum: Int) -> [String: String] {
        [
            "actualLength": String(actualLength),
            "maximum": String(maximum)
        ]
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

public enum MindDeskExtensionCapabilityCatalogValidationReport {
    public static func issues(
        from issues: [MindDeskExtensionCapabilityCatalogValidationIssue]
    ) -> [MindDeskValidationReportIssue] {
        issues.map(reportIssue)
    }

    public static func issues(
        in catalog: MindDeskExtensionCapabilityCatalog
    ) -> [MindDeskValidationReportIssue] {
        issues(from: MindDeskExtensionCapabilityCatalogValidation.issues(in: catalog))
    }

    public static func report(
        in catalog: MindDeskExtensionCapabilityCatalog,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: catalog), generatedAt: generatedAt)
    }

    private static func reportIssue(
        _ issue: MindDeskExtensionCapabilityCatalogValidationIssue
    ) -> MindDeskValidationReportIssue {
        switch issue {
        case .unsupportedCatalogFormat(let format):
            return capabilityIssue(
                code: "capability-catalog.unsupported-format",
                message: "Extension capability catalog format is unsupported.",
                field: "format",
                details: mindDeskUnsupportedStringDetails(
                    actual: format,
                    expected: MindDeskExtensionCapabilityCatalog.currentFormat
                )
            )
        case .unsupportedCatalogFormatVersion(let version):
            return capabilityIssue(
                code: "capability-catalog.unsupported-version",
                message: "Extension capability catalog format version is unsupported.",
                field: "formatVersion",
                details: [
                    "actual": String(version),
                    "expected": String(MindDeskExtensionCapabilityCatalog.currentFormatVersion)
                ]
            )
        case .capabilitySetMismatch:
            return capabilityIssue(
                code: "capability-catalog.capabilities.mismatch",
                message: "Extension capability set has drifted from the expected operation catalog.",
                field: "capabilities"
            )
        case .duplicateCapabilityID(let id):
            return capabilityIssue(
                code: "capability-catalog.capability.duplicate-id",
                message: "Extension capability id must be unique.",
                ownerID: MindDeskValidationReportToken.token(id),
                field: "capabilities.id",
                details: mindDeskTokenizedIDDetails(
                    tokenKey: "capabilityIDToken",
                    lengthKey: "capabilityIDLength",
                    id: id
                )
            )
        case .duplicateOperationKind(let kind):
            return capabilityIssue(
                code: "capability-catalog.operation-kind.duplicate",
                message: "Extension capability operation kind must be unique.",
                ownerID: "proposal.\(kind.rawValue)",
                field: "capabilities.operationKind",
                details: ["operationKind": kind.rawValue]
            )
        case .operationContractMismatch(let kind):
            return capabilityIssue(
                code: "capability-catalog.operation-contract.mismatch",
                message: "Extension capability operation contract has drifted from the expected operation model.",
                ownerID: "proposal.\(kind.rawValue)",
                field: "capabilities",
                details: ["operationKind": kind.rawValue]
            )
        case .policyDecisionMismatch(let kind):
            return capabilityIssue(
                code: "capability-catalog.policy-decision.mismatch",
                message: "Extension capability policy decisions have drifted from the expected action policy.",
                ownerID: "proposal.\(kind.rawValue)",
                field: "capabilities.policyDecisions",
                details: ["operationKind": kind.rawValue]
            )
        case .catalogAuthorityMismatch:
            return capabilityIssue(
                code: "capability-catalog.authority.mismatch",
                message: "Extension capability catalog authority boundary has drifted from the expected non-authorizing policy.",
                field: "authorizesSideEffects"
            )
        case .catalogNotesMissingAuthorityBoundary:
            return capabilityIssue(
                code: "capability-catalog.notes.authority-boundary-missing",
                message: "Extension capability catalog notes must state that the catalog is not authorization.",
                field: "notes"
            )
        }
    }

    private static func capabilityIssue(
        code: String,
        message: String,
        ownerID: String? = nil,
        field: String,
        details: [String: String] = [:]
    ) -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .extensionCapabilityCatalog,
            code: code,
            severity: .error,
            message: message,
            ownerKind: "extensionCapabilityCatalog",
            ownerID: ownerID,
            field: field,
            details: details
        )
    }
}

public enum MindDeskAgentIntegrationContractValidationReport {
    public static func issues(
        from issues: [MindDeskAgentIntegrationContractValidationIssue]
    ) -> [MindDeskValidationReportIssue] {
        issues.map(reportIssue)
    }

    public static func issues(
        in contract: MindDeskAgentIntegrationContract,
        package: MindDeskInterchangePackage
    ) -> [MindDeskValidationReportIssue] {
        let expectedContract = MindDeskAgentIntegrationContract(package: package)
        let expectedContext = MindDeskProposalContextSnapshot(package: package)
        return MindDeskAgentIntegrationContractValidation
            .issues(in: contract, package: package)
            .map {
                reportIssue(
                    $0,
                    contract: contract,
                    expectedContract: expectedContract,
                    expectedContext: expectedContext
                )
            }
    }

    public static func report(
        in contract: MindDeskAgentIntegrationContract,
        package: MindDeskInterchangePackage,
        generatedAt: Date
    ) -> MindDeskValidationReport {
        MindDeskValidationReport(issues: issues(in: contract, package: package), generatedAt: generatedAt)
    }

    private static func reportIssue(
        _ issue: MindDeskAgentIntegrationContractValidationIssue
    ) -> MindDeskValidationReportIssue {
        switch issue {
        case .unsupportedContractFormat(let format):
            return contractIssue(
                code: "contract.unsupported-format",
                message: "Agent integration contract format is unsupported.",
                field: "format",
                details: mindDeskUnsupportedStringDetails(
                    actual: format,
                    expected: MindDeskAgentIntegrationContract.currentFormat
                )
            )
        case .unsupportedContractFormatVersion(let version):
            return contractIssue(
                code: "contract.unsupported-version",
                message: "Agent integration contract format version is unsupported.",
                field: "formatVersion",
                details: [
                    "actual": String(version),
                    "expected": String(MindDeskAgentIntegrationContract.currentFormatVersion)
                ]
            )
        case .unsupportedPackageFormat(let format):
            return contractIssue(
                source: .package,
                code: "contract.package.unsupported-format",
                message: "Package format is unsupported by the agent integration contract.",
                field: "format",
                details: mindDeskUnsupportedStringDetails(
                    actual: format,
                    expected: MindDeskInterchangePackage.currentFormat
                )
            )
        case .unsupportedPackageFormatVersion(let version):
            return contractIssue(
                source: .package,
                code: "contract.package.unsupported-version",
                message: "Package format version is unsupported by the agent integration contract.",
                field: "formatVersion",
                details: [
                    "actual": String(version),
                    "supportedVersions": MindDeskInterchangePackageFormat.supportedVersions
                        .sorted()
                        .map(String.init)
                        .joined(separator: ",")
                ]
            )
        case .contextMismatch:
            return contractIssue(
                code: "contract.context.mismatch",
                message: "Agent integration contract context does not match the package.",
                field: "context"
            )
        case .supportedAudiencesMismatch:
            return contractIssue(
                code: "contract.audiences.mismatch",
                message: "Agent integration contract supported audiences have drifted from the expected audience list.",
                field: "supportedAudiences"
            )
        case .authorityMismatch:
            return contractIssue(
                code: "contract.authority.mismatch",
                message: "Agent integration authority contract has drifted from the expected read-only policy.",
                field: "authority"
            )
        case .interchangePackageMismatch:
            return contractIssue(
                code: "contract.interchange-package.mismatch",
                message: "Interchange package contract has drifted from the expected package descriptor.",
                field: "interchangePackage"
            )
        case .agentPolicyMismatch:
            return contractIssue(
                code: "contract.agent-policy.mismatch",
                message: "Agent policy has drifted from the expected policy.",
                field: "agentPolicy"
            )
        case .referenceSchemasMismatch:
            return contractIssue(
                code: "contract.reference-schemas.mismatch",
                message: "Reference schemas have drifted from the expected agent reference model.",
                field: "referenceSchemas"
            )
        case .proposalEnvelopeMismatch:
            return contractIssue(
                code: "contract.proposal-envelope.mismatch",
                message: "Proposal envelope contract has drifted from the expected contract.",
                field: "proposalEnvelope"
            )
        case .guideMismatch:
            return contractIssue(
                code: "contract.guide.mismatch",
                message: "Agent guide has drifted from the expected safety and workflow guidance.",
                field: "guide"
            )
        case .promptTemplatesMismatch:
            return contractIssue(
                code: "contract.prompt-templates.mismatch",
                message: "Agent prompt templates have drifted from the expected non-authoritative prompt guidance.",
                field: "promptTemplates"
            )
        case .reviewGateMismatch:
            return contractIssue(
                code: "contract.review-gate.mismatch",
                message: "Review gate contract has drifted from the expected human approval policy.",
                field: "reviewGate"
            )
        case .actionPolicyMismatch:
            return contractIssue(
                code: "contract.action-policy.mismatch",
                message: "External action policy has drifted from the expected policy.",
                field: "actionPolicy"
            )
        case .operationContractMismatch:
            return contractIssue(
                code: "contract.operation-contract.mismatch",
                message: "Operation contracts have drifted from the expected operation model.",
                field: "operationContracts"
            )
        }
    }

    private static func reportIssue(
        _ issue: MindDeskAgentIntegrationContractValidationIssue,
        contract: MindDeskAgentIntegrationContract,
        expectedContract: MindDeskAgentIntegrationContract,
        expectedContext: MindDeskProposalContextSnapshot
    ) -> MindDeskValidationReportIssue {
        switch issue {
        case .contextMismatch:
            let fields = mismatchedContextSnapshotFields(actual: contract.context, expected: expectedContext)
            return contractContextMismatchIssue(mismatchedFields: fields)
        case .proposalEnvelopeMismatch:
            return contractProposalEnvelopeMismatchIssue(
                proposalEnvelope: contract.proposalEnvelope,
                expectedProposalEnvelope: expectedContract.proposalEnvelope
            )
        default:
            return reportIssue(issue)
        }
    }

    private static func contractContextMismatchIssue(
        mismatchedFields: [String]
    ) -> MindDeskValidationReportIssue {
        var details: [String: String] = [:]
        if !mismatchedFields.isEmpty {
            details["mismatchedFields"] = mismatchedFields.joined(separator: ",")
        }
        if mismatchedFields.count == 1,
           let bindingField = mismatchedFields.first,
           proposalContextBindingFields.contains(bindingField) {
            details["bindingField"] = bindingField
        }
        let field = mismatchedFields.count == 1
            ? "context.\(mismatchedFields[0])"
            : "context"
        return contractIssue(
            code: "contract.context.mismatch",
            message: "Agent integration contract context does not match the package.",
            field: field,
            details: details
        )
    }

    private static func contractProposalEnvelopeMismatchIssue(
        proposalEnvelope: MindDeskAgentProposalEnvelopeContract,
        expectedProposalEnvelope: MindDeskAgentProposalEnvelopeContract
    ) -> MindDeskValidationReportIssue {
        var details: [String: String] = [:]
        let actualBindings = Set(proposalEnvelope.contextBindingFields)
        let expectedBindings = Set(expectedProposalEnvelope.contextBindingFields)
        let missingBindings = expectedProposalEnvelope.contextBindingFields.filter { !actualBindings.contains($0) }
        let unexpectedBindings = proposalEnvelope.contextBindingFields.filter { !expectedBindings.contains($0) }
        if !missingBindings.isEmpty {
            details["missingBindingFields"] = missingBindings.joined(separator: ",")
        }
        if !unexpectedBindings.isEmpty {
            let unexpectedBindingValue = unexpectedBindings.joined(separator: ",")
            details["unexpectedBindingFieldsToken"] = MindDeskValidationReportToken.token(unexpectedBindingValue)
            details["unexpectedBindingFieldsCount"] = String(unexpectedBindings.count)
            details["unexpectedBindingFieldsLength"] = String(unexpectedBindingValue.count)
        }
        if proposalEnvelope.contextBindingFields != expectedProposalEnvelope.contextBindingFields {
            details["mismatchedFields"] = "contextBindingFields"
        }
        let field = proposalEnvelope.contextBindingFields != expectedProposalEnvelope.contextBindingFields
            ? "proposalEnvelope.contextBindingFields"
            : "proposalEnvelope"
        return contractIssue(
            code: "contract.proposal-envelope.mismatch",
            message: "Proposal envelope contract has drifted from the expected contract.",
            field: field,
            details: details
        )
    }

    private static func mismatchedContextSnapshotFields(
        actual: MindDeskProposalContextSnapshot,
        expected: MindDeskProposalContextSnapshot
    ) -> [String] {
        MindDeskProposalContextFreshness.mismatchedBindingFields(
            proposal: actual,
            current: expected
        )
    }

    private static let proposalContextBindingFields: Set<String> = [
        "packageFormat",
        "packageFormatVersion",
        "packageInstanceID",
        "packageCreatedAt",
        "manifestSchemaVersion",
        "manifestExportedAt",
        "manifestDigest"
    ]

    private static func contractIssue(
        source: MindDeskValidationReportSource = .agentIntegrationContract,
        code: String,
        message: String,
        field: String,
        details: [String: String] = [:]
    ) -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: source,
            code: code,
            severity: .error,
            message: message,
            ownerKind: "agentIntegrationContract",
            field: field,
            details: details
        )
    }
}
