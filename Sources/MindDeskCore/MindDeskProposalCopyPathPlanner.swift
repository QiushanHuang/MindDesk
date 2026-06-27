import Foundation

public struct MindDeskProposalCopyPathPlan: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(envelopeID):\(proposalID):\(operationID)"
    }

    public let envelopeID: String
    public let proposalID: String
    public let operationID: String
    public let target: WorkbenchObjectReference

    public init(
        envelopeID: String,
        proposalID: String,
        operationID: String,
        target: WorkbenchObjectReference
    ) {
        self.envelopeID = envelopeID
        self.proposalID = proposalID
        self.operationID = operationID
        self.target = target
    }
}

public enum MindDeskProposalCopyPathPlanner {
    public static func approvedResourcePinPlans(
        in session: MindDeskProposalReviewSession
    ) -> [MindDeskProposalCopyPathPlan] {
        guard session.state == .approved,
              session.validationReport.summary.isValid else {
            return []
        }

        return session.envelope.proposals.flatMap { proposal in
            proposal.operations.compactMap { operation in
                guard operation.kind == .copyPath,
                      operation.kind.externalAction == .copyPathToClipboard,
                      let target = operation.target,
                      target.kind == .resourcePin,
                      operation.payload.isEmptyForCopyPathPlanning else {
                    return nil
                }
                return MindDeskProposalCopyPathPlan(
                    envelopeID: session.envelope.id,
                    proposalID: proposal.id,
                    operationID: operation.id,
                    target: target
                )
            }
        }
    }
}

private extension MindDeskProposalOperationPayload {
    var isEmptyForCopyPathPlanning: Bool {
        url == nil &&
            command == nil &&
            workingDirectory == nil &&
            proposedText == nil &&
            unknownFieldNames.isEmpty
    }
}
