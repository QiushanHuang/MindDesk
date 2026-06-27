import Foundation

public struct MindDeskProposalReviewSession: Codable, Equatable, Sendable {
    public var envelope: MindDeskProposalEnvelope
    public var sourceContext: MindDeskProposalContextSnapshot
    public var validationReport: MindDeskValidationReport
    public var state: MindDeskProposalReviewState
    public var gatedAt: Date

    public init(
        envelope: MindDeskProposalEnvelope,
        sourceContext: MindDeskProposalContextSnapshot,
        validationReport: MindDeskValidationReport,
        state: MindDeskProposalReviewState = .pendingReview,
        gatedAt: Date
    ) {
        self.envelope = envelope
        self.sourceContext = sourceContext
        self.validationReport = validationReport
        self.state = state
        self.gatedAt = gatedAt
    }
}

public enum MindDeskProposalReviewGateResult: Equatable, Sendable {
    case ready(MindDeskProposalReviewSession)
    case blocked(MindDeskValidationReport)
}

public enum MindDeskProposalReviewGateDataError: Error, Equatable, Sendable {
    case invalidProposalEnvelope
    case invalidSourcePackage
}

public enum MindDeskProposalReviewGate {
    public static func evaluate(
        proposalEnvelopeData: Data,
        sourcePackageData: Data,
        gatedAt: Date = .now
    ) throws -> MindDeskProposalReviewGateResult {
        guard MindDeskJSONDocumentKind.classify(proposalEnvelopeData) == .proposalEnvelope else {
            throw MindDeskProposalReviewGateDataError.invalidProposalEnvelope
        }
        guard MindDeskJSONDocumentKind.classify(sourcePackageData) == .interchangePackage else {
            throw MindDeskProposalReviewGateDataError.invalidSourcePackage
        }

        let decoder = JSONDecoder.minddesk
        let envelope: MindDeskProposalEnvelope
        do {
            envelope = try decoder.decode(MindDeskProposalEnvelope.self, from: proposalEnvelopeData)
        } catch let error as MindDeskProposalEnvelopeDecodeLimitError {
            return .blocked(
                MindDeskValidationReport(
                    issues: MindDeskProposalValidationReport.issues(from: error.diagnostics),
                    generatedAt: gatedAt
                )
            )
        }
        let sourcePackage = try decoder.decode(MindDeskInterchangePackage.self, from: sourcePackageData)
        let rawSourceIssues = MindDeskProposalSourcePackageRawValidation.issues(
            in: sourcePackageData,
            package: sourcePackage
        )
        if !rawSourceIssues.isEmpty {
            return .blocked(
                MindDeskValidationReport(
                    issues: rawSourceIssues,
                    generatedAt: gatedAt
                )
            )
        }

        return try evaluate(
            envelope: envelope,
            sourcePackage: sourcePackage,
            gatedAt: gatedAt
        )
    }

    public static func evaluate(
        envelope: MindDeskProposalEnvelope,
        sourcePackage: MindDeskInterchangePackage,
        gatedAt: Date = .now
    ) throws -> MindDeskProposalReviewGateResult {
        let packageIssues = MindDeskInterchangePackageValidationReport.issues(in: sourcePackage)
        let proposalIssues = try MindDeskProposalValidationReport.issues(in: envelope, package: sourcePackage)
        let report = MindDeskValidationReport(
            issues: packageIssues + proposalIssues,
            generatedAt: gatedAt
        )

        guard report.summary.isValid else {
            return .blocked(report)
        }

        return .ready(
            MindDeskProposalReviewSession(
                envelope: envelope,
                sourceContext: MindDeskProposalContextSnapshot(package: sourcePackage),
                validationReport: report,
                gatedAt: gatedAt
            )
        )
    }
}
