import Foundation

public enum MindDeskInterchangePackageFormat {
    public static let currentVersion = 1
    public static let supportedVersions: Set<Int> = [currentVersion]
}

public struct MindDeskInterchangePackage: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case format
        case formatVersion
        case packageInstanceID
        case createdAt
        case summary
        case privacy
        case agentGuide
        case agentPolicy
        case agentIntegrationContract
        case extensionCapabilities
        case externalActionPolicy
        case helpTopics
        case validationIssues
        case validationReport
        case manifest
    }

    public static let currentFormat = "minddesk.interchange.package"
    public static let currentFormatVersion = MindDeskInterchangePackageFormat.currentVersion

    public var format: String
    public var formatVersion: Int
    public var packageInstanceID: String
    public var createdAt: Date
    public var summary: MindDeskInterchangeSummary
    public var privacy: MindDeskInterchangePrivacy
    public var agentGuide: MindDeskAgentGuide
    public var agentPolicy: MindDeskAgentPolicy
    public var agentIntegrationContract: MindDeskAgentIntegrationContract
    public var extensionCapabilities: MindDeskExtensionCapabilityCatalog
    public var externalActionPolicy: MindDeskInterchangeExternalActionPolicy
    public var helpTopics: [MindDeskHelpTopic]
    public var validationIssues: [MindDeskInterchangeValidationIssue]
    public var validationReport: MindDeskValidationReport
    public var manifest: ExportManifest

    public init(
        format: String,
        formatVersion: Int,
        packageInstanceID: String,
        createdAt: Date,
        summary: MindDeskInterchangeSummary,
        privacy: MindDeskInterchangePrivacy,
        agentGuide: MindDeskAgentGuide,
        agentPolicy: MindDeskAgentPolicy,
        agentIntegrationContract: MindDeskAgentIntegrationContract,
        extensionCapabilities: MindDeskExtensionCapabilityCatalog,
        externalActionPolicy: MindDeskInterchangeExternalActionPolicy,
        helpTopics: [MindDeskHelpTopic],
        validationIssues: [MindDeskInterchangeValidationIssue],
        validationReport: MindDeskValidationReport,
        manifest: ExportManifest
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.packageInstanceID = packageInstanceID
        self.createdAt = createdAt
        self.summary = summary
        self.privacy = privacy
        self.agentGuide = agentGuide
        self.agentPolicy = agentPolicy
        self.agentIntegrationContract = agentIntegrationContract
        self.extensionCapabilities = extensionCapabilities
        self.externalActionPolicy = externalActionPolicy
        self.helpTopics = helpTopics
        self.validationIssues = validationIssues
        self.validationReport = validationReport
        self.manifest = manifest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decode(String.self, forKey: .format)
        let formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard format == Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription: "Unsupported interchange package format."
            )
        }
        guard MindDeskInterchangePackageFormat.supportedVersions.contains(formatVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .formatVersion,
                in: container,
                debugDescription: "Unsupported interchange package format version."
            )
        }

        self.format = format
        self.formatVersion = formatVersion
        self.packageInstanceID = try container.decode(String.self, forKey: .packageInstanceID)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.summary = try container.decode(MindDeskInterchangeSummary.self, forKey: .summary)
        self.privacy = try container.decode(MindDeskInterchangePrivacy.self, forKey: .privacy)
        self.agentGuide = try container.decode(MindDeskAgentGuide.self, forKey: .agentGuide)
        self.agentPolicy = try container.decode(MindDeskAgentPolicy.self, forKey: .agentPolicy)
        self.agentIntegrationContract = try container.decode(MindDeskAgentIntegrationContract.self, forKey: .agentIntegrationContract)
        self.extensionCapabilities = try container.decode(MindDeskExtensionCapabilityCatalog.self, forKey: .extensionCapabilities)
        self.externalActionPolicy = try container.decode(MindDeskInterchangeExternalActionPolicy.self, forKey: .externalActionPolicy)
        self.helpTopics = try container.decode([MindDeskHelpTopic].self, forKey: .helpTopics)
        self.validationIssues = try container.decode([MindDeskInterchangeValidationIssue].self, forKey: .validationIssues)
        self.validationReport = try container.decode(MindDeskValidationReport.self, forKey: .validationReport)
        self.manifest = try container.decode(ExportManifest.self, forKey: .manifest)
    }
}

public struct MindDeskInterchangeSummary: Codable, Equatable, Sendable {
    public var workspaces: Int
    public var resources: Int
    public var snippets: Int
    public var canvases: Int
    public var nodes: Int
    public var edges: Int
    public var aliases: Int
    public var todoGroups: Int
    public var todos: Int
    public var validationIssues: [String]

    public init(
        workspaces: Int,
        resources: Int,
        snippets: Int,
        canvases: Int,
        nodes: Int,
        edges: Int,
        aliases: Int,
        todoGroups: Int,
        todos: Int,
        validationIssues: [String]
    ) {
        self.workspaces = workspaces
        self.resources = resources
        self.snippets = snippets
        self.canvases = canvases
        self.nodes = nodes
        self.edges = edges
        self.aliases = aliases
        self.todoGroups = todoGroups
        self.todos = todos
        self.validationIssues = validationIssues
    }

    func matchesManifestCounts(_ manifest: ExportManifest) -> Bool {
        workspaces == manifest.workspaces.count &&
            resources == manifest.resources.count &&
            snippets == manifest.snippets.count &&
            canvases == manifest.canvases.count &&
            nodes == manifest.nodes.count &&
            edges == manifest.edges.count &&
            aliases == manifest.aliases.count &&
            todoGroups == manifest.todoGroups.count &&
            todos == manifest.todos.count
    }
}

public enum MindDeskInterchangeValidationSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case error

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported interchange validation severity."
            )
        }
        self = value
    }
}

public enum MindDeskInterchangeValidationSource: String, Codable, CaseIterable, Sendable {
    case package
    case manifest

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported interchange validation source."
            )
        }
        self = value
    }
}

public struct MindDeskInterchangeValidationIssue: Codable, Equatable, Sendable {
    public var source: MindDeskInterchangeValidationSource
    public var severity: MindDeskInterchangeValidationSeverity
    public var message: String

    public init(
        source: MindDeskInterchangeValidationSource,
        severity: MindDeskInterchangeValidationSeverity,
        message: String
    ) {
        self.source = source
        self.severity = severity
        self.message = message
    }

    public static func manifestIssues(in manifest: ExportManifest) -> [MindDeskInterchangeValidationIssue] {
        ManifestImportValidation.issues(in: manifest)
            .sorted()
            .map { issue in
                MindDeskInterchangeValidationIssue(source: .manifest, severity: .error, message: issue)
            }
    }
}

public enum MindDeskInterchangePackageValidation {
    public static func issues(in package: MindDeskInterchangePackage) -> [MindDeskInterchangeValidationIssue] {
        var issues: [MindDeskInterchangeValidationIssue] = []
        if !MindDeskInterchangePackageFormat.supportedVersions.contains(package.formatVersion) {
            issues.append(
                MindDeskInterchangeValidationIssue(
                    source: .package,
                    severity: .error,
                    message: "Unsupported interchange package format version \(package.formatVersion)."
                )
            )
        }
        if !package.summary.matchesManifestCounts(package.manifest) {
            issues.append(
                MindDeskInterchangeValidationIssue(
                    source: .package,
                    severity: .warning,
                    message: "Package summary does not match manifest contents."
                )
            )
        }
        issues.append(contentsOf: MindDeskInterchangeValidationIssue.manifestIssues(in: package.manifest))
        return issues
    }
}

public struct MindDeskInterchangePrivacy: Codable, Equatable, Sendable {
    public var includesUsageDates: Bool
    public var includesPaths: Bool
    public var includesPromptBodies: Bool
    public var neverIncludes: [String]
    public var redactionNotes: [String]

    public init(
        includesUsageDates: Bool,
        includesPaths: Bool,
        includesPromptBodies: Bool,
        neverIncludes: [String],
        redactionNotes: [String]
    ) {
        self.includesUsageDates = includesUsageDates
        self.includesPaths = includesPaths
        self.includesPromptBodies = includesPromptBodies
        self.neverIncludes = neverIncludes
        self.redactionNotes = redactionNotes
    }
}

public struct MindDeskAgentGuide: Codable, Equatable, Sendable {
    public var systemPrompt: String
    public var workflowSteps: [MindDeskAgentWorkflowStep]
    public var customPromptGuidance: [String]
    public var referenceFormat: String

    public init(
        systemPrompt: String,
        workflowSteps: [MindDeskAgentWorkflowStep],
        customPromptGuidance: [String],
        referenceFormat: String
    ) {
        self.systemPrompt = systemPrompt
        self.workflowSteps = workflowSteps
        self.customPromptGuidance = customPromptGuidance
        self.referenceFormat = referenceFormat
    }
}

public struct MindDeskInterchangeExternalActionPolicy: Codable, Equatable, Sendable {
    public var actorPolicies: [MindDeskInterchangeExternalActorPolicy]

    public init(actorPolicies: [MindDeskInterchangeExternalActorPolicy]) {
        self.actorPolicies = actorPolicies
    }
}

public struct MindDeskInterchangeExternalActorPolicy: Codable, Equatable, Sendable {
    public var actor: WorkbenchExternalActor
    public var decisions: [MindDeskInterchangeExternalActionDecision]

    public init(actor: WorkbenchExternalActor, decisions: [MindDeskInterchangeExternalActionDecision]) {
        self.actor = actor
        self.decisions = decisions
    }
}

public struct MindDeskInterchangeExternalActionDecision: Codable, Equatable, Sendable {
    public var action: WorkbenchExternalAction
    public var decision: WorkbenchExternalActionDecision

    public init(action: WorkbenchExternalAction, decision: WorkbenchExternalActionDecision) {
        self.action = action
        self.decision = decision
    }
}

public struct MindDeskAgentWorkflowStep: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var instruction: String

    public init(id: String, title: String, instruction: String) {
        self.id = id
        self.title = title
        self.instruction = instruction
    }
}

public struct MindDeskAgentPolicy: Codable, Equatable, Sendable {
    public var allowedDefaultAgentActions: [WorkbenchExternalAction]
    public var deniedDefaultAgentActions: [WorkbenchExternalAction]
    public var confirmationRequiredActions: [WorkbenchExternalAction]

    public init(
        allowedDefaultAgentActions: [WorkbenchExternalAction],
        deniedDefaultAgentActions: [WorkbenchExternalAction],
        confirmationRequiredActions: [WorkbenchExternalAction]
    ) {
        self.allowedDefaultAgentActions = allowedDefaultAgentActions
        self.deniedDefaultAgentActions = deniedDefaultAgentActions
        self.confirmationRequiredActions = confirmationRequiredActions
    }
}
