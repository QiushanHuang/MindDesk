import Foundation

public struct MindDeskProposalEnvelopeTemplate: Equatable, Sendable {
    public var title: String
    public var bodyJSON: String
    public var byteCount: Int

    public init(title: String, bodyJSON: String, byteCount: Int) {
        self.title = title
        self.bodyJSON = bodyJSON
        self.byteCount = byteCount
    }
}

public enum MindDeskProposalEnvelopeTemplateBuilder {
    public static func build(
        package: MindDeskInterchangePackage,
        id: String = "proposal-envelope-template-\(UUID().uuidString)",
        createdAt: Date = .now
    ) -> MindDeskProposalEnvelopeTemplate {
        let envelope = MindDeskProposalEnvelope(
            id: id,
            createdAt: createdAt,
            proposedBy: .defaultAgent,
            context: MindDeskProposalContextSnapshot(package: package),
            proposals: []
        )
        let bodyJSON = encodedJSON(envelope)
        return MindDeskProposalEnvelopeTemplate(
            title: "Proposal Envelope Template",
            bodyJSON: bodyJSON,
            byteCount: bodyJSON.utf8.count
        )
    }

    private static func encodedJSON(_ envelope: MindDeskProposalEnvelope) -> String {
        do {
            let data = try JSONEncoder.minddesk.encode(envelope)
            guard let json = String(data: data, encoding: .utf8) else {
                preconditionFailure("Proposal envelope template JSON is not valid UTF-8.")
            }
            return json
        } catch {
            preconditionFailure("Proposal envelope template encoding failed: \(error)")
        }
    }
}
