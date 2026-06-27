import Foundation

public struct MindDeskAgentReviewPackageReadiness: Equatable, Sendable {
    public var isValid: Bool
    public var issueCount: Int
    public var errorCount: Int
    public var warningCount: Int
    public var helpTopicCount: Int
    public var proposalCapabilityCount: Int
    public var validationSummaryText: String
    public var retrievalSummaryText: String
    public var workflowSummaryText: String
    public var safetyBoundaryText: String
    public var bannerSummaryText: String

    public init(
        isValid: Bool,
        issueCount: Int,
        errorCount: Int,
        warningCount: Int,
        helpTopicCount: Int,
        proposalCapabilityCount: Int,
        validationSummaryText: String,
        retrievalSummaryText: String,
        workflowSummaryText: String,
        safetyBoundaryText: String,
        bannerSummaryText: String
    ) {
        self.isValid = isValid
        self.issueCount = issueCount
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.helpTopicCount = helpTopicCount
        self.proposalCapabilityCount = proposalCapabilityCount
        self.validationSummaryText = validationSummaryText
        self.retrievalSummaryText = retrievalSummaryText
        self.workflowSummaryText = workflowSummaryText
        self.safetyBoundaryText = safetyBoundaryText
        self.bannerSummaryText = bannerSummaryText
    }
}

public enum MindDeskAgentReviewPackageReadinessBuilder {
    public static func build(package: MindDeskInterchangePackage) -> MindDeskAgentReviewPackageReadiness {
        let summary = package.validationReport.summary
        let helpTopicCount = MindDeskHelpCatalog.agentReviewPackageTopics.count
        let proposalCapabilityCount = MindDeskExtensionCapabilityCatalog.current.proposalCapabilities.count
        let validationState = summary.isValid ? "Valid" : "Invalid"
        let issueLabel = plural("issue", summary.issueCount)
        let errorLabel = plural("error", summary.errorCount)
        let warningLabel = plural("warning", summary.warningCount)
        let helpTopicLabel = plural("help topic", helpTopicCount)
        let proposalCapabilityLabel = plural("proposal capability", proposalCapabilityCount)
        let validationSummary = "\(validationState) package: \(summary.issueCount) \(issueLabel), \(summary.errorCount) \(errorLabel), \(summary.warningCount) \(warningLabel)."
        let retrievalSummary = "Includes \(helpTopicCount) \(helpTopicLabel) and \(proposalCapabilityCount) \(proposalCapabilityLabel) for agent review."
        let workflowSummary = "Read-only readiness summary. Inspect validationReport first, then runtime-search helpTopics before drafting proposal envelope JSON."
        let safetyBoundary = "Package validity is not authorization. Proposal Review plus explicit immediate in-app confirmation outside the proposal review sheet is required before any side effects."
        let bannerSummary = "\(validationSummary) \(retrievalSummary) \(workflowSummary)"

        return MindDeskAgentReviewPackageReadiness(
            isValid: summary.isValid,
            issueCount: summary.issueCount,
            errorCount: summary.errorCount,
            warningCount: summary.warningCount,
            helpTopicCount: helpTopicCount,
            proposalCapabilityCount: proposalCapabilityCount,
            validationSummaryText: validationSummary,
            retrievalSummaryText: retrievalSummary,
            workflowSummaryText: workflowSummary,
            safetyBoundaryText: safetyBoundary,
            bannerSummaryText: bannerSummary
        )
    }

    private static func plural(_ noun: String, _ count: Int) -> String {
        count == 1 ? noun : "\(noun)s"
    }
}
