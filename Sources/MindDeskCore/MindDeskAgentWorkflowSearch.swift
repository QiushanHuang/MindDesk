import Foundation

public struct MindDeskAgentWorkflowSearchResponse: Codable, Equatable, Sendable {
    public static let currentFormat = "minddesk.agent.workflow.search.response"
    public static let currentFormatVersion = 1
    public static let boundaryText = "Agent workflow search responses are read-only retrieval results, not authorization."

    public var format: String
    public var formatVersion: Int
    public var query: String
    public var help: MindDeskHelpSearchResponse
    public var capabilities: MindDeskExtensionCapabilitySearchResponse
    public var authorizesSideEffects: Bool
    public var boundaryText: String

    public init(
        format: String = MindDeskAgentWorkflowSearchResponse.currentFormat,
        formatVersion: Int = MindDeskAgentWorkflowSearchResponse.currentFormatVersion,
        query: String,
        help: MindDeskHelpSearchResponse,
        capabilities: MindDeskExtensionCapabilitySearchResponse,
        authorizesSideEffects: Bool = false,
        boundaryText: String = MindDeskAgentWorkflowSearchResponse.boundaryText
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.query = query
        self.help = help
        self.capabilities = capabilities
        self.authorizesSideEffects = authorizesSideEffects
        self.boundaryText = boundaryText
    }
}

public struct MindDeskAgentWorkflowSearchRequest: Codable, Equatable, Sendable {
    public static let maximumQueryCharacterCount = 256
    public static let maximumHelpLimit = 12
    public static let maximumCapabilityLimit = 12

    public var query: String
    public var helpLimit: Int
    public var capabilityLimit: Int
    public var includeMetaActions: Bool

    public init(
        query: String,
        helpLimit: Int = 4,
        capabilityLimit: Int = 4,
        includeMetaActions: Bool = true
    ) {
        self.query = Self.normalizedQuery(query)
        self.helpLimit = Self.boundedLimit(helpLimit, maximum: Self.maximumHelpLimit)
        self.capabilityLimit = Self.boundedLimit(capabilityLimit, maximum: Self.maximumCapabilityLimit)
        self.includeMetaActions = includeMetaActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            query: try container.decode(String.self, forKey: .query),
            helpLimit: try container.decode(Int.self, forKey: .helpLimit),
            capabilityLimit: try container.decode(Int.self, forKey: .capabilityLimit),
            includeMetaActions: try container.decode(Bool.self, forKey: .includeMetaActions)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case helpLimit
        case capabilityLimit
        case includeMetaActions
    }

    private static func boundedLimit(_ limit: Int, maximum: Int) -> Int {
        min(max(limit, 0), maximum)
    }

    private static func normalizedQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumQueryCharacterCount else {
            return trimmed
        }
        return String(trimmed.prefix(maximumQueryCharacterCount))
    }
}

public enum MindDeskAgentWorkflowSearch {
    public static func response(
        package: MindDeskInterchangePackage,
        request: MindDeskAgentWorkflowSearchRequest
    ) -> MindDeskAgentWorkflowSearchResponse {
        response(
            for: request.query,
            package: package,
            helpLimit: request.helpLimit,
            capabilityLimit: request.capabilityLimit,
            includeMetaActions: request.includeMetaActions
        )
    }

    public static func response(
        request: MindDeskAgentWorkflowSearchRequest
    ) -> MindDeskAgentWorkflowSearchResponse {
        response(
            for: request.query,
            helpLimit: request.helpLimit,
            capabilityLimit: request.capabilityLimit,
            includeMetaActions: request.includeMetaActions
        )
    }

    public static func response(
        for query: String,
        package: MindDeskInterchangePackage,
        helpLimit: Int = 4,
        capabilityLimit: Int = 4,
        includeMetaActions: Bool = true
    ) -> MindDeskAgentWorkflowSearchResponse {
        response(
            for: query,
            helpTopics: package.helpTopics,
            capabilityCatalog: package.extensionCapabilities,
            helpLimit: helpLimit,
            capabilityLimit: capabilityLimit,
            includeMetaActions: includeMetaActions
        )
    }

    public static func response(
        for query: String,
        helpTopics: [MindDeskHelpTopic] = MindDeskHelpCatalog.agentReviewPackageTopics,
        capabilityCatalog: MindDeskExtensionCapabilityCatalog = .current,
        helpLimit: Int = 4,
        capabilityLimit: Int = 4,
        includeMetaActions: Bool = true
    ) -> MindDeskAgentWorkflowSearchResponse {
        MindDeskAgentWorkflowSearchResponse(
            query: query,
            help: MindDeskHelpSearch.summaryResponse(
                for: query,
                in: helpTopics,
                limit: helpLimit
            ),
            capabilities: capabilityCatalog.searchCapabilitySummaries(
                for: query,
                limit: capabilityLimit,
                includeMetaActions: includeMetaActions
            )
        )
    }
}
